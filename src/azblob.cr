module AZBlob
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}

  class Error < Exception
    def self.from_resp(resp)
      new("#{resp.status_code} - #{resp.status_message}\n #{resp.body}")
    end

    def self.from_resp(code, resp)
      new("#{code} : #{resp.status_code} #{resp.status_message}error recieved:\n #{resp.body}")
    end
  end

  def self.client_from_env
    Client.new(Client::Config.from_env)
  end

  def self.client(connection_string : String, proxy : Client::ProxyConfig? = nil)
    Client.new(Client::Config.with_connection_string(connection_string, proxy))
  end
end

require "./azblob/**"
