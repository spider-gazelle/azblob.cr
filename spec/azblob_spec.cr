require "./spec_helper"
require "http/server"

# Expose the private commit step so it can be exercised without a >256MB upload.
class AZBlob::Client
  def __spec_commit_block_list(resource, block_ids)
    commit_block_list(resource, block_ids, AZBlob::UploadOptions.default)
  end
end

ACCOUNT_NAME = "devaccount"
ACCOUNT_KEY  = Base64.strict_encode("spec-shared-key-0123456789abcdef")

# Minimal stand-in for Azure Blob Storage: it recomputes the SharedKey
# signature from the request it actually received (as Azure does) and
# rejects the request with 403 when the signatures differ.
private def with_signature_checking_server(&)
  cred = AZBlob::SharedKeyCredential.new(ACCOUNT_NAME, ACCOUNT_KEY)
  received = [] of {String, String?}

  server = HTTP::Server.new do |ctx|
    req = ctx.request
    body = req.body.try(&.gets_to_end) || ""
    sent_auth = req.headers["Authorization"]?

    headers = req.headers.dup
    headers.delete("Authorization")
    headers.delete("Transfer-Encoding")

    # Passing the body sets Content-Length to the bytes actually received, which
    # is what Azure signs over regardless of how the client framed the body.
    check = HTTP::Request.new(req.method, req.resource, headers, body)
    expected_auth = cred.sign(check).headers["Authorization"]

    received << {req.query_params["comp"]? || "", req.headers["Content-Length"]?}

    if sent_auth == expected_auth
      ctx.response.status_code = 201
      ctx.response.headers["ETag"] = %("0x1")
      ctx.response.headers["Last-Modified"] = HTTP.format_time(Time.utc)
    else
      ctx.response.status_code = 403
      ctx.response.headers["x-ms-error-code"] = "AuthenticationFailed"
      ctx.response.content_type = "application/xml"
      ctx.response.print %(<?xml version="1.0" encoding="utf-8"?><Error><Code>AuthenticationFailed</Code><Message>signature mismatch</Message></Error>)
    end
  end

  address = server.bind_tcp("127.0.0.1", 0)
  spawn { server.listen }
  Fiber.yield

  conn_str = "BlobEndpoint=http://127.0.0.1:#{address.port}/;AccountName=#{ACCOUNT_NAME};AccountKey=#{ACCOUNT_KEY}"
  client = AZBlob::Client.new(AZBlob::Client::Config.with_connection_string(conn_str))
  begin
    yield client, received
  ensure
    server.close
  end
end

describe AZBlob::Client do
  it "signs Put Block List requests with the Content-Length that is sent" do
    with_signature_checking_server do |client, received|
      block_ids = (1..300).map { Base64.strict_encode(UUID.random.to_s) }

      client.__spec_commit_block_list("backup/postgresql_dump.dump.gz", block_ids)

      comp, content_length = received.last
      comp.should eq "blocklist"
      content_length.should_not be_nil
    end
  end

  it "signs single-shot uploads correctly" do
    with_signature_checking_server do |client, received|
      client.put_blob("backup", "small.txt", "hello world")
      received.size.should eq 1
    end
  end
end
