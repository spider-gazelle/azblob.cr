require "connect-proxy"
require "http/headers"
require "http/request"
require "http/log"
require "uri"
require "db"
require "log"
require "./constants"
require "./config"
require "./credential/shared_key"
require "./models/*"

module AZBlob
  class Client
    Log = ::Log.for(self)

    getter config : Config
    private getter cred : SharedKeyCredential
    @pool : DB::Pool(ConnectProxy::HTTPClient)

    def initialize(@config)
      @cred = SharedKeyCredential.new(config.account_name, config.account_key)

      @pool = DB::Pool.new(DB::Pool::Options.new(max_pool_size: 5)) {
        http = ConnectProxy::HTTPClient.new(config.endpoint)
        http.before_request { |req| @cred.sign(req) }
        if use_proxy = @config.proxy
          proxy = ConnectProxy.new(use_proxy.proxy_url, use_proxy.proxy_port, {username: use_proxy.user, password: use_proxy.password})
          http.set_proxy(proxy)
        end
        http
      }
    end

    def list_containers(prefix : String? = nil, max_results : Int32? = nil) : Models::ContainerListResp
      Pager(Models::ContainerListResp).new(
        ->(page : Models::ContainerListResp) {
          return true if page && page.next_marker && !page.next_marker.to_s.blank?
          false
        }) do |page|
        req = new_request("GET", "") do |args|
          args.query_params.add("comp", "list")
          args.query_params.add("include", "deleted,metadata")
          args.query_params.add("prefix", prefix) if prefix
          args.query_params.add("marker", page.next_marker.to_s) if page && page.next_marker
          args.query_params.add("maxresults", max_results.to_s) if max_results
        end
        do_request(req, Models::ContainerListResp)
      end
    end

    def create_container(name : String, meta = {} of String => String) : Models::ContainCreateResp
      req = new_request("PUT", name) do |args|
        args.query_params.add("restype", "container")
        args.headers.merge!(meta.transform_keys { |k| "x-ms-meta-#{k}" })
      end
      do_request(req, Models::ContainCreateResp)
    end

    def delete_container(name : String) : Models::DeleteResp
      req = new_request("DELETE", name) do |args|
        args.query_params.add("restype", "container")
      end
      do_request(req, Models::DeleteResp)
    end

    def list_blobs(container : String, items : BlobInclude = BlobInclude::Metadata | BlobInclude::Snapshots | BlobInclude::Versions, prefix : String? = nil, max_results : Int32? = nil) : Models::BlobListResp
      Pager(Models::BlobListResp).new(
        ->(page : Models::BlobListResp) {
          return true if page && page.next_marker && !page.next_marker.to_s.blank?
          false
        }) do |page|
        req = new_request("GET", container) do |args|
          args.query_params.add("comp", "list")
          args.query_params.add("restype", "container")
          args.query_params.add("include", items.to_s)
          args.query_params.add("prefix", prefix) if prefix
          args.query_params.add("marker", page.next_marker.to_s) if page && page.next_marker
          args.query_params.add("maxresults", max_results.to_s) if max_results
        end
        do_request(req, Models::BlobListResp)
      end
    end

    def put_blob(container : String, blob_name : String, contents : String | Bytes, options : UploadOptions = UploadOptions.default)
      io = IO::Memory.new(contents.to_slice)
      upload(container, blob_name, io, io.size, options)
    end

    def put_blob(container : String, blob_name : String, contents : File, options : UploadOptions = UploadOptions.default)
      upload(container, blob_name, contents, contents.size, options)
    end

    def put_blob(container : String, blob_name : String, contents : IO, options : UploadOptions = UploadOptions.default)
      upload(container, blob_name, contents, contents.size, options)
    end

    def head_blob(container : String, blob_name : String, options : DownloadOptions = DownloadOptions.default) : Models::BlobProperties
      req = new_request("HEAD", "#{container}/#{URI.encode_path_segment(blob_name)}") do |args|
        args.query_params.add("snapshot", options.snapshot.to_s) if options.snapshot
        args.query_params.add("versionid", options.version_id.to_s) if options.version_id

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
      do_request(req, Models::BlobProperties)
    end

    def get_blob(container : String, blob_name : String, options : DownloadOptions = DownloadOptions.default) : Bytes
      download(container, blob_name, options)
    end

    def get_blob(container : String, blob_name : String, write_to : IO, options : DownloadOptions = DownloadOptions.default) : Nil
      bytes = download(container, blob_name, options)
      io = IO::Memory.new(bytes)
      IO.copy(io, write_to)
    end

    def delete_blob(container : String, blob_name : String, options : Models::BlobDeleteOptions? = nil)
      req = new_request("DELETE", "#{container}/#{URI.encode_path_segment(blob_name)}") do |args|
        if opts = options
          args.query_params.add("deletetype", opts.delete_type.to_s) if opts.delete_type
          args.query_params.add("snapshot", opts.snapshot.to_s) if opts.snapshot
          args.query_params.add("timeout", opts.timeout.to_s) if opts.timeout
          args.query_params.add("versionid", opts.version_id.to_s) if opts.version_id

          args.headers.add("x-ms-delete-snapshots", opts.delete_snaphots.to_s) if opts.delete_snaphots
        end
      end
      do_request(req, Models::DeleteResp)
    end

    # :nodoc
    def stats
      @pool.stats
    end

    protected def pool
      @pool
    end

    private class ReqSettings
      property body : String | Bytes | IO | Nil = nil
      property headers : HTTP::Headers = HTTP::Headers{"Accept" => ContentTypeAppXML, HeaderXmsVersion => ServiceVersion}
      property query_params : URI::Params = URI::Params.new
    end

    private def new_request(method : String, url : String, & : ReqSettings -> _) : HTTP::Request
      args = ReqSettings.new
      yield args
      req = HTTP::Request.new(method, url, args.headers, args.body)
      req.path = config.endpoint.path + url
      query = args.query_params.to_s
      req.query = query.blank? ? nil : query
      req
    end

    private def new_request(method : String, url : String) : HTTP::Request
      new_request(method, url) { }
    end

    private def do_request(req : HTTP::Request, clz : T.class) : T forall T
      pool.checkout do |http|
        resp = http.exec(req)
        return T.from_resp(resp) if resp.success?
        handle_error(resp)
      end
    end

    private def handle_error(resp)
      raise error_from_resp(resp)
    end

    private def error_from_resp(resp)
      if ec = resp.headers[HeaderXMSErrorCode]?
        Error.from_resp(ec, resp)
      else
        Error.from_resp(resp)
      end
    end
  end
end
