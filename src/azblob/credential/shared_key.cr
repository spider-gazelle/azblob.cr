require "base64"
require "openssl/hmac"
require "openssl/algorithm"
require "http/client"
require "time"
require "../constants"

module AZBlob
  struct SharedKeyCredential
    getter account_name : String
    getter account_key : Bytes

    def initialize(@account_name : String, account_key : String)
      @account_key = Base64.decode(account_key)
    end

    def account_key=(key : String)
      @account_key = Base64.decode(account_key)
    end

    def sign(request : HTTP::Request)
      request.headers.add(HeaderXmsDate, Time::Format::HTTP_DATE.format(Time.utc)) unless request.headers.has_key?(HeaderXmsDate)
      sign_str = build_string(request)
      signature = compute_hmac_sha256(sign_str)

      auth_header = ["SharedKey ", account_name, ":", signature].join("")
      request.headers.add(HeaderAuthorization, auth_header)
      request
    end

    def compute_hmac_sha256(msg : String)
      h = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, account_key, msg)
      Base64.strict_encode(h)
    end

    private def build_string(req : HTTP::Request)
      headers = req.headers
      clen = headers.fetch(HeaderContentLength, "")
      clen = clen.strip == "0" ? "" : clen.strip
      res = canonical_resource(req)

      [
        req.method,
        get_header(HeaderContentEncoding, headers),
        get_header(HeaderContentLanguage, headers),
        clen,
        get_header(HeaderContentMD5, headers),
        get_header(HeaderContentType, headers),
        "", # Empty date because x-ms-date is expected
        get_header(HeaderIfModifiedSince, headers),
        get_header(HeaderIfMatch, headers),
        get_header(HeaderIfNoneMatch, headers),
        get_header(HeaderIfUnmodifiedSince, headers),
        get_header(HeaderRange, headers),
        canonicalize_header(headers),
        res,
      ].join("\n")
    end

    private def get_header(key, headers)
      val = headers[key]?
      return "" unless val
      val.size > 0 ? val : ""
    end

    private def canonicalize_header(headers)
      cm = {} of String => Array(String)

      headers.each do |k, v|
        name = k.strip.downcase
        cm[name] = v if name.starts_with?("x-ms-")
      end
      return "" if cm.empty?
      keys = cm.keys
      keys.sort!
      String.build do |str|
        keys.each_with_index do |key, idx|
          str << "\n" if idx > 0
          str << key << ":" << cm[key].join(',')
        end
      end
    end

    private def canonical_resource(req)
      String.build do |str|
        str << "/" << account_name
        str << (req.path.size > 0 ? URI.encode_path(req.path) : '/')
        unless req.query_params.empty?
          names = [] of String
          req.query_params.each { |name, _| names << name }
          names.sort!.uniq!
          names.each do |name|
            val = req.query_params.fetch_all(name)
            val.sort!

            str << "\n" << name.downcase << ":" << val.join(',')
          end
        end
      end
    end
  end
end
