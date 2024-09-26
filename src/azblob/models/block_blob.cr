module AZBlob::Models
  enum DeleteSnapshotOption
    Include
    Only

    def to_s
      self.member_name.try &.downcase
    end
  end

  enum DeleteType
    None
    Permanent
  end

  struct BlobDeleteOptions
    # Required if the blob has associated snapshots. Specify one of the following two options: include: Delete the base blob
    # and all of its snapshots. only: Delete only the blob's snapshots and not the blob itself
    getter delete_snaphots : DeleteSnapshotOption?

    # Optional. Only possible value is 'permanent', which specifies to permanently delete a blob if blob soft delete is enabled.
    getter delete_type : DeleteType?

    # The snapshot parameter is an opaque DateTime value that, when present, specifies the blob snapshot to retrieve. For more
    # information on working with blob snapshots, see Creating a Snapshot of a Blob.
    # [https://docs.microsoft.com/en-us/rest/api/storageservices/fileservices/creating-a-snapshot-of-a-blob]
    getter snapshot : String?

    # The timeout parameter is expressed in seconds. For more information, see Setting Timeouts for Blob Service Operations.
    # [https://docs.microsoft.com/en-us/rest/api/storageservices/fileservices/setting-timeouts-for-blob-service-operations]
    getter timeout : Int32?

    # The version id parameter is an opaque DateTime value that, when present, specifies the version of the blob to operate on.
    # It's for service version 2019-10-10 and newer.
    getter version_id : String?

    def initialize(@delete_snaphots = nil, @delete_type = nil, @snapshot = nil, @timeout = nil, @version_id = nil)
    end
  end

  record BlockBlobUploadResp,
    client_request_id : String?,
    content_md5 : String?,
    date : Time?,
    etag : String?,
    encryption_key_sha256 : String?,
    encryption_scope : String?,
    server_ecrypted : Bool?,
    last_modified : Time?,
    request_id : String?,
    version : String?,
    version_id : String? do
    def self.from_resp(resp : HTTP::Client::Response)
      raise Error.from_resp(resp) unless resp.success?

      hdr = resp.headers
      new(hdr[HeaderXMSClientRequestID]?, Models.decode_b64(hdr[HeaderContentMD5]?), Models.to_date(hdr["Date"]?), hdr["ETag"]?,
        hdr["x-ms-encryption-key-sha256"]?, hdr["x-ms-encryption-scope"]?, hdr["x-ms-request-server-encrypted"]?.try &.==("true"),
        Models.to_date(hdr["Last-Modified"]?), hdr[HeaderXMSRequestID]?, hdr[HeaderXmsVersion]?, hdr["x-ms-version-id"]?)
    end
  end

  record BlobStageBlockResp,
    client_request_id : String?,
    content_crc64 : String?,
    content_md5 : String?,
    date : Time?,
    encryption_key_sha256 : String?,
    encryption_scope : String?,
    server_ecrypted : Bool?,
    request_id : String?,
    version : String? do
    def self.from_resp(resp : HTTP::Client::Response)
      raise Error.from_resp(resp) unless resp.success?
      hdr = resp.headers
      new(hdr[HeaderXMSClientRequestID]?, Models.decode_b64(hdr["x-ms-content-crc64"]?), Models.decode_b64(hdr[HeaderContentMD5]?),
        Models.to_date(hdr["Date"]?), hdr["x-ms-encryption-key-sha256"]?, hdr["x-ms-encryption-scope"]?,
        hdr["x-ms-request-server-encrypted"]?.try &.==("true"), hdr[HeaderXMSRequestID]?, hdr[HeaderXmsVersion]?)
    end
  end

  record BlockCommitResp,
    client_request_id : String?,
    content_crc64 : String?,
    content_md5 : String?,
    date : Time?,
    etag : String?,
    encryption_key_sha256 : String?,
    encryption_scope : String?,
    server_ecrypted : Bool?,
    last_modified : Time?,
    request_id : String?,
    version : String?,
    version_id : String? do
    def self.from_resp(resp : HTTP::Client::Response)
      raise Error.from_resp(resp) unless resp.success?

      hdr = resp.headers
      new(hdr[HeaderXMSClientRequestID]?, Models.decode_b64(hdr["x-ms-content-crc64"]?), Models.decode_b64(hdr[HeaderContentMD5]?),
        Models.to_date(hdr["Date"]?), hdr["ETag"]?, hdr["x-ms-encryption-key-sha256"]?, hdr["x-ms-encryption-scope"]?,
        hdr["x-ms-request-server-encrypted"]?.try &.==("true"), Models.to_date(hdr["Last-Modified"]?), hdr[HeaderXMSRequestID]?,
        hdr[HeaderXmsVersion]?, hdr["x-ms-version-id"]?)
    end
  end

  record DeleteResp,
    client_request_id : String?,
    date : Time?,
    request_id : String?,
    version : String? do
    def self.from_resp(resp : HTTP::Client::Response)
      raise Error.from_resp(resp) unless resp.success?

      hdr = resp.headers
      new(hdr[HeaderXMSClientRequestID]?, Models.to_date(hdr["Date"]?), hdr[HeaderXMSRequestID]?, hdr[HeaderXmsVersion]?)
    end
  end
end
