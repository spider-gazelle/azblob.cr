require "uuid"
require "mime"
require "./options"

module AZBlob
  class Client
    private def upload(container : String, blob_name : String, io : IO, size : Int64, options : UploadOptions)
      if options.block_size == 0
        raise Error.new("buffer is too large to upload to a block blob") if size > MaxStageBlockBytes*MaxBlocks
        if size <= MaxUploadBlobBytes
          options.block_size = MaxUploadBlobBytes
        else
          options.block_size = (size // MaxBlocks).ceil
          options.block_size = DefaultDownloadBlockSize if options.block_size < DefaultDownloadBlockSize
        end
      end
      resource = "#{container}/#{URI.encode_path_segment(blob_name)}"

      return do_upload(resource, size, io, options) if size <= MaxUploadBlobBytes

      do_multipart_upload(resource, size, io, options)
    end

    private def do_upload(resource : String, size : Int64, io : IO, options : UploadOptions)
      req = new_request("PUT", resource) do |args|
        args.headers.add(HeaderContentLength, size.to_s)
        args.headers.add("x-ms-blob-type", "BlockBlob")
        args.headers.add(HeaderContentType, content_type(io))
        if blob_hdr = options.headers
          args.headers.add("x-ms-blob-cache-control", blob_hdr.cache_control.to_s) if blob_hdr.cache_control
          args.headers.add("x-ms-blob-content-disposition", blob_hdr.content_disposition.to_s) if blob_hdr.content_disposition
          args.headers.add("x-ms-blob-content-encoding", blob_hdr.content_encoding.to_s) if blob_hdr.content_encoding
          args.headers.add("x-ms-blob-content-language", blob_hdr.content_language.to_s) if blob_hdr.content_language
          args.headers.add("x-ms-blob-content-md5", blob_hdr.content_md5.to_s) if blob_hdr.content_md5
          args.headers.add("x-ms-blob-content-type", blob_hdr.content_type.to_s) if blob_hdr.content_type
        end
        args.headers.merge!(options.metadata.transform_keys { |k| "x-ms-meta-#{k}" })
        args.headers.add("x-ms-tags", options.tags_str) unless options.tags_str.empty?
        args.body = io
      end
      do_request(req, Models::BlockBlobUploadResp)
    end

    private def do_multipart_upload(resource : String, size : Int64, io : IO, options : UploadOptions)
      num_blocks = ((size + options.block_size - 1) // options.block_size).to_i
      raise Error.new("block limit exceeded") unless num_blocks <= MaxBlocks
      names = resource.split('/')

      Log.debug { {message: "Trying to upload blob", container: names.first, blob: names.last, upload_size: size,
                   block_size: options.block_size, block_count: num_blocks} }

      block_ids = Array(String).new(num_blocks) { "" }
      error = batch_transfer(options.block_size, num_blocks, size, options.concurrency, ->(offset : Int64, chunk_size : Int64) do
        # when last block, actual size might be less than the calculated size due to
        # rounding up of the payload size to fit in a whole number of blocks
        chunk_size = (size - offset) if chunk_size < options.block_size
        block_num = offset // options.block_size
        io.seek(offset, IO::Seek::Set)
        chunk_io = IO::Memory.new
        IO.copy(io, chunk_io, chunk_size)
        chunk_io.rewind

        Log.debug { {message: "Trying to upload block", block_num: block_num, chunk_size: chunk_size.humanize} }

        options.progress.try &.call(io.size.to_i64)
        chunk_uuid = Base64.strict_encode(UUID.random.to_s)
        block_ids[block_num] = chunk_uuid
        stage_block(resource, chunk_uuid, chunk_io, options.stage_block_options)
      end
      )

      raise error if error
      commit_block_list(resource, block_ids, options)
    end

    private def batch_transfer(chunk_size : Int64, chunks : Int32, transfer_size : Int64, concurrency : Int32, operation : (Int64, Int64) -> Error?)
      raise Error.new("invalid chunk size. chunk size cannot be 0") unless chunk_size > 0
      concurrency = DefaultConcurrency if concurrency <= 0
      op_chan = Channel(-> Error?).new(concurrency)
      terminate = Channel(Nil).new

      exc_chan = Channel(Error?).new(chunks)

      spawn(name: "Batch - main handlder") do
        1.upto(concurrency) do |index|
          spawn(name: "Job#{index}") do
            loop do
              select
              when f = op_chan.receive
                begin
                  ret = f.call
                  exc_chan.send(ret)
                rescue ex
                  exc_chan.send(Error.new("exception raised by user proc in job#{index}: #{ex.message}", ex))
                end
              when terminate.receive?
                break
              end
            end
          end
        end
      end

      first_exc = nil

      0.upto(chunks - 1) do |index|
        break if op_chan.closed?
        cur_size = chunk_size
        offset = index.to_i64 * chunk_size
        cur_size = transfer_size - offset if index == chunks - 1
        op_chan.send(Proc(Error?).new { operation.call(offset, cur_size) }) unless op_chan.closed?
      end

      1.upto(chunks) do
        exc = exc_chan.receive
        if exc && first_exc.nil?
          first_exc = exc
          terminate.close
          break
        end
      end
      first_exc
    end

    private def stage_block(resource, block_id, io, options)
      cpk_info = options.cpk_info
      cpk_scope_info = options.cpk_scope_info
      lease_access = options.lease_access

      req = new_request("PUT", resource) do |args|
        args.body = io
        args.query_params.add("blockid", block_id)
        args.query_params.add("comp", "block")

        args.headers.add(HeaderContentLength, io.size.to_s)

        if cpk_info = options.cpk_info
          args.headers.add("x-ms-encryption-algorithm", cpk_info.encryption_algorithm.to_s) if cpk_info.encryption_algorithm
          args.headers.add("x-ms-encryption-key", cpk_info.encryption_key.to_s) if cpk_info.encryption_key
          args.headers.add("x-ms-encryption-key-sha256", cpk_info.encryption_key_sha256.to_s) if cpk_info.encryption_key_sha256
        end
        if cpk_scope_info = options.cpk_scope_info
          args.headers.add("x-ms-encryption-scope", cpk_scope_info.encryption_scope.to_s) if cpk_scope_info.encryption_scope
        end

        if lease_access = options.lease_access
          args.headers.add("x-ms-lease-id", lease_access.lease_id.to_s) if lease_access.lease_id
        end
      end
      pool.checkout do |http|
        resp = http.exec(req)
        resp.success? ? nil : error_from_resp(resp)
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def commit_block_list(resource, block_ids, options)
      req = new_request("PUT", resource) do |args|
        args.query_params.add("comp", "blocklist")
        if mac = options.access_conditions.try &.modified_access
          args.headers.add(HeaderIfMatch, mac.if_match.to_s) if mac.if_match
          args.headers.add(HeaderIfUnmodifiedSince, Models.date_to_s(mac.if_modified_since).to_s) if mac.if_modified_since
          args.headers.add(HeaderIfNoneMatch, mac.if_none_match.to_s) if mac.if_none_match
          args.headers.add(HeaderIfUnmodifiedSince, Models.date_to_s(mac.if_unmodified_since).to_s) if mac.if_unmodified_since
          args.headers.add("x-ms-if-tags", mac.if_tags.to_s) if mac.if_tags
        end

        args.headers.add("x-ms-access-tier", options.access_tier.to_s) if options.access_tier

        if blob_hdr = options.headers
          args.headers.add("x-ms-blob-cache-control", blob_hdr.cache_control.to_s) if blob_hdr.cache_control
          args.headers.add("x-ms-blob-content-disposition", blob_hdr.content_disposition.to_s) if blob_hdr.content_disposition
          args.headers.add("x-ms-blob-content-encoding", blob_hdr.content_encoding.to_s) if blob_hdr.content_encoding
          args.headers.add("x-ms-blob-content-language", blob_hdr.content_language.to_s) if blob_hdr.content_language
          args.headers.add("x-ms-blob-content-md5", blob_hdr.content_md5.to_s) if blob_hdr.content_md5
          args.headers.add("x-ms-blob-content-type", blob_hdr.content_type.to_s) if blob_hdr.content_type
        end

        if cpk_info = options.cpk_info
          args.headers.add("x-ms-encryption-algorithm", cpk_info.encryption_algorithm.to_s) if cpk_info.encryption_algorithm
          args.headers.add("x-ms-encryption-key", cpk_info.encryption_key.to_s) if cpk_info.encryption_key
          args.headers.add("x-ms-encryption-key-sha256", cpk_info.encryption_key_sha256.to_s) if cpk_info.encryption_key_sha256
        end
        if cpk_scope_info = options.cpk_scope_info
          args.headers.add("x-ms-encryption-scope", cpk_scope_info.encryption_scope.to_s) if cpk_scope_info.encryption_scope
        end

        if lease_access = options.access_conditions.try &.lease_access
          args.headers.add("x-ms-lease-id", lease_access.lease_id.to_s) if lease_access.lease_id
        end

        args.headers.merge!(options.metadata.transform_keys { |k| "x-ms-meta-#{k}" })
        args.headers.add("x-ms-tags", options.tags_str) unless options.tags_str.empty?
        args.body = IO::Memory.new(block_list_xml(block_ids))
      end
      do_request(req, Models::BlockCommitResp)
    end

    private def block_list_xml(block_ids)
      XML.build(encoding: "UTF-8") do |xml|
        xml.element("BlockList") do
          block_ids.each do |tag|
            xml.element("Latest") { xml.text(tag) }
          end
        end
      end
    end

    private def content_type(io : IO) : String
      if io.responds_to?(:path)
        io.path.try { |path| MIME.from_filename(path, ContentTypeBinary) } || ContentTypeBinary
      else
        ContentTypeBinary
      end
    end
  end
end
