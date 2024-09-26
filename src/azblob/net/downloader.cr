require "http/status"

module AZBlob
  class Client
    private def download(container : String, blob_name : String, options : DownloadOptions) : Bytes
      options.block_size = DefaultDownloadBlockSize if options.block_size <= 0
      count = options.range.count
      if count == 0
        props = head_blob(container, blob_name, options)
        if content_length = props.content_length
          count = content_length - options.range.offset
        else
          raise Error.new("Unable to retrieve blob size")
        end
      end
      return Bytes.empty if count <= 0
      buffer = Bytes.new(count)

      num_blocks = ((count + options.block_size - 1) // options.block_size).to_i

      error = batch_transfer(options.block_size, num_blocks, count, options.concurrency, ->(offset : Int64, chunk_size : Int64) do
        options.range = HTTPRange.new(offset, chunk_size)
        req = do_download(container, blob_name, options)
        pool.checkout do |http|
          resp = http.exec(req)
          err = resp.success? ? nil : error_from_resp(resp)
          return err if err
          body = resp.body
          buffer[offset..].copy_from(body.to_slice.to_unsafe, [chunk_size, body.bytesize].min)
        end
        nil
      end
      )

      raise error if error
      buffer
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def do_download(container, blob_name, options)
      new_request("GET", "#{container}/#{URI.encode_path_segment(blob_name)}") do |args|
        args.query_params.add("snapshot", options.snapshot.to_s) if options.snapshot
        args.query_params.add("versionid", options.version_id.to_s) if options.version_id
        range = options.range.format
        args.headers.add("x-ms-range", range) unless range.blank?

        if mac = options.access_conditions.try &.modified_access
          args.headers.add(HeaderIfMatch, mac.if_match.to_s) if mac.if_match
          args.headers.add(HeaderIfUnmodifiedSince, Models.date_to_s(mac.if_modified_since).to_s) if mac.if_modified_since
          args.headers.add(HeaderIfNoneMatch, mac.if_none_match.to_s) if mac.if_none_match
          args.headers.add(HeaderIfUnmodifiedSince, Models.date_to_s(mac.if_unmodified_since).to_s) if mac.if_unmodified_since
          args.headers.add("x-ms-if-tags", mac.if_tags.to_s) if mac.if_tags
        end

        if cpk_info = options.cpk_info
          args.headers.add("x-ms-encryption-algorithm", cpk_info.encryption_algorithm.to_s) if cpk_info.encryption_algorithm
          args.headers.add("x-ms-encryption-key", cpk_info.encryption_key.to_s) if cpk_info.encryption_key
          args.headers.add("x-ms-encryption-key-sha256", cpk_info.encryption_key_sha256.to_s) if cpk_info.encryption_key_sha256
        end
      end
    end
  end
end
