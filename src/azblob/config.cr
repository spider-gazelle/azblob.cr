module AZBlob
  class Client
    record ProxyConfig, proxy_url : String, proxy_port : Int32, user : String? = nil, password : String? = nil

    struct Config
      getter account_name : String
      getter account_key : String
      getter proxy : ProxyConfig? = nil

      @endpoint_str : String

      getter(endpoint : URI) { URI.parse(@endpoint_str) }

      def initialize(account_name, account_key, proxy : ProxyConfig? = nil)
        initialize(account_name, account_key, sprintf(AZURE_ENDPOINT_URL, account_name), proxy)
      end

      protected def initialize(@account_name, @account_key, @endpoint_str, @proxy = nil)
      end

      def self.with_shared_key(account_name : String, account_key : String, proxy = nil)
        new(account_name, account_key, proxy)
      end

      def self.with_connection_string(connection_string : String, proxy = nil)
        ep, name, key = parse_conn_str(connection_string)
        new(name, key, ep, proxy)
      end

      def proxy=(proxy : ProxyConfig)
        @proxy = proxy
      end

      def self.from_env
        if name = AZURE_STORAGE_ACCOUNT_NAME
          if key = AZURE_STORAGE_ACCOUNT_KEY
            return new(name, key)
          end

          if key = AZURE_STORAGE_SHARED_ACCESS_SIGNATURE
            return new(name, "", sprintf(AZURE_ENDPOINT_URL_SHARED, account_name, key))
          end
        end

        if cs = AZURE_STORAGE_CONNECTION_STRING
          return with_connection_string(cs)
        end

        raise Error.new("none of the required environment variables found")
      end

      private def self.parse_conn_str(connect_str : String) : Tuple(String, String, String)
        key_vals = connect_str.split(';').map(&.split('=', 2))
        valid_pairs = key_vals.reject(&.size.!= 2)

        raise Error.new(INVALID_CONNECTION_STRING) unless key_vals.size == valid_pairs.size
        con_map = valid_pairs.to_h

        protocol = con_map.fetch("DefaultEndpointsProtocol", DEFUALT_SCHEME)
        suffix = con_map.fetch("EndpointSuffix", DEFUALT_SUFFIX)

        svc_url = if blob = con_map["BlobEndpoint"]?
                    blob
                  elsif act = con_map["AccountName"]?
                    sprintf("%s://%s.blob.%s", protocol, act, suffix)
                  else
                    raise Error.new("connection string needs either AccountName or BlobEndpoint")
                  end

        svc_url += "/" unless svc_url.ends_with?("/")

        if (act_key = con_map["AccountKey"]?) && (act_name = con_map["AccountName"]?)
          return {svc_url, act_name, act_key}
        elsif act_sig = con_map["SharedAccessSignature"]?
          svc_url = "#{svc_url}?#{act_sig}"
          return {svc_url, con_map["AccountName"], ""}
        else
          raise Error.new("connection string need either AccoutKey or SharedAccessSignature")
        end
      end
    end
  end
end
