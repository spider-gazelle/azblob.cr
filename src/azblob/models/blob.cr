module AZBlob
  @[Flags]
  enum BlobInclude
    Copy
    Deleted
    DeletedWithVersions
    ImmutablityPolicy
    LegalHold
    Metadata
    Snapshots
    Tags
    UncommittedBlobs
    Versions

    # ameba:disable Metrics/CyclomaticComplexity
    def to_s : String
      items = [] of String

      items << "copy" if copy?
      items << "deleted" if deleted?
      items << "deletedwithversions" if deleted_with_versions?
      items << "immutabilitypolicy" if immutablity_policy?
      items << "legalhold" if legal_hold?
      items << "metadata" if metadata?
      items << "snapshots" if snapshots?
      items << "tags" if tags?
      items << "uncommittedblobs" if uncommitted_blobs?
      items << "versions" if versions?
      items.join(',')
    end
  end

  module Models
    record Blob, deleted : Bool, name : String, properties : BlobProperties, snapshot : String, tags : Hash(String, String),
      version_only : Bool, current_version : Bool, metadata : Hash(String, String), or_metadata : Hash(String, String),
      version_id : String do
      def self.from_node(blob_node : XML::Node)
        node = AZBlob::XMLNode.new(blob_node)

        deleted = node.as_bool("Deleted")
        name = node.as_s("Name")
        prop_node = node.nodes("Properties")[0]
        snapshot = node.as_s("Snapshot")
        tags_node = node.nodes("Tags/TagSet/Tag")
        tags = {} of String => String
        tags_node.each { |e| tags[e.name] = e.content }
        version_only = node.as_bool("HasVersionsOnly")
        current_version = node.as_bool("IsCurrentVersion")
        meta_node = node.nodes("Metadata/*")
        metadata = {} of String => String
        meta_node.each { |e| metadata[e.name] = e.content }

        or_meta_node = node.nodes("OrMetadata/*")
        or_metadata = {} of String => String
        or_meta_node.each { |e| or_metadata[e.name] = e.content }

        version_id = node.as_s("VersionId")

        new(deleted, name, BlobProperties.from_node(prop_node), snapshot, tags, version_only, current_version,
          metadata, or_metadata, version_id)
      end
    end

    record BlobProperties, etag : String, last_modified : Time?, access_tier : AccessTier?, access_tier_change_time : Time?,
      access_tier_inferred : Bool, archive_status : ArchiveStatus?, blob_sequence_number : Int64?, blob_type : BlobType?,
      cache_control : String?, content_disposition : String?, content_encoding : String?, content_language : String,
      content_length : Int64?, content_md5 : Bytes?, content_type : String?, copy_completion_time : Time?, copy_id : String?,
      copy_progress : String?, copy_source : String?, copy_status : CopyStatusType?, copy_status_desc : String?,
      creation_time : Time?, customer_provided_key_sha256 : String?, deleted_time : Time?, destination_snapshot : String?,
      encryption_sceope : String?, expires_on : Time?, is_sealed : Bool?, last_access_on : Time?, lease_duration : String?,
      lease_state : LeaseStatusType?, lease_status : LeaseStatusType?, legal_hold : Bool?, server_encrypted : Bool?,
      tag_count : Int32?, accept_ranges : String? = nil, version : String? = nil, version_id : String? = nil,
      committed_blob_count : Int32? = nil, current_version : Bool? = nil do
      def self.from_resp(resp : HTTP::Client::Response)
        raise Error.from_resp(resp) unless resp.success?
        node = AZBlob::HeaderReader.new(resp.headers)

        accept_ranges = node.as_s("Accept-Ranges")
        version = node.as_s("x-ms-version")
        version_id = node.as_s("x-ms-version-id")
        committed_blob_count = node.as_i("x-ms-blob-committed-block-count")
        current_version = node.as_bool("x-ms-is-current-version")

        etag = node.as_s("Etag")
        last_modified = node.as_time("Last-Modified")
        access_tier = node.as_enum("x-ms-access-tier", Models::AccessTier)
        access_tier_change_time = Models.to_date(node.as_s("x-ms-access-tier-change-time"))
        access_tier_inferred = node.as_bool("x-ms-access-tier-inferred")
        archive_status = node.as_enum("x-ms-archive-status", Models::ArchiveStatus)
        blob_sequence_number = node.as_i64("x-ms-blob-sequence-number")
        blob_type = node.as_enum("x-ms-blob-type", Models::BlobType)

        cache_control = node.as_s("Cache-Control")
        content_disposition = node.as_s("Content-Disposition")
        content_encoding = node.as_s("Content-Encoding")
        content_language = node.as_s("Content-Language")
        content_length = node.as_i64("Content-Length")
        content_md5 = Base64.decode(node.as_s(HeaderContentMD5))

        content_type = node.as_s(HeaderContentType)
        copy_completion_time = node.as_time("x-ms-copy-completion-time")
        copy_id = node.as_s("x-ms-copy-id")
        copy_progress = node.as_s("x-ms-copy-progress")
        copy_source = node.as_s("x-ms-copy-source")
        copy_status = node.as_enum("x-ms-copy-status", Models::CopyStatusType)

        copy_status_desc = node.as_s("x-ms-copy-status-description")
        creation_time = node.as_time("x-ms-creation-time")
        customer_provided_key_sha256 = node.as_s("x-ms-encryption-key-sha256")
        deleted_time = node.as_time("DeletedTime")
        destination_snapshot = node.as_s("x-ms-copy-destination-snapshot")
        encryption_sceope = node.as_s("x-ms-encryption-scope")
        expires_on = node.as_time("x-ms-expiry-time")
        is_sealed = node.as_bool("x-ms-blob-sealed")
        last_access_on = node.as_time("x-ms-last-access-time")
        lease_duration = node.as_s("x-ms-lease-duration")
        lease_state = node.as_enum("x-ms-lease-state", Models::LeaseStatusType)
        lease_status = node.as_enum("x-ms-lease-status", Models::LeaseStatusType)
        legal_hold = node.as_bool("x-ms-legal-hold")
        server_encrypted = node.as_bool("x-ms-server-encrypted")
        tag_count = node.as_i("x-ms-tag-count")

        new(etag, last_modified, access_tier, access_tier_change_time, access_tier_inferred, archive_status, blob_sequence_number, blob_type,
          cache_control, content_disposition, content_encoding, content_language, content_length, content_md5, content_type,
          copy_completion_time, copy_id, copy_progress, copy_source, copy_status, copy_status_desc, creation_time, customer_provided_key_sha256,
          deleted_time, destination_snapshot, encryption_sceope, expires_on, is_sealed, last_access_on, lease_duration, lease_state,
          lease_status, legal_hold, server_encrypted, tag_count, accept_ranges, version, version_id, committed_blob_count, current_version
        )
      end

      def self.from_node(properties_node : XML::Node)
        node = AZBlob::XMLNode.new(properties_node)

        etag = node.as_s("Etag")
        last_modified = node.as_time("Last-Modified")
        access_tier = node.as_enum("AccessTier", Models::AccessTier)
        access_tier_change_time = Models.to_date(node.as_s("AccessTierChangeTime"))
        access_tier_inferred = node.as_bool("AccessTierInferred")
        archive_status = node.as_enum("ArchiveStatus", Models::ArchiveStatus)
        blob_sequence_number = node.as_i64("x-ms-blob-sequence-number")
        blob_type = node.as_enum("BlobType", Models::BlobType)

        cache_control = node.as_s("Cache-Control")
        content_disposition = node.as_s("Content-Disposition")
        content_encoding = node.as_s("Content-Encoding")
        content_language = node.as_s("Content-Language")
        content_length = node.as_i64("Content-Length")
        content_md5 = Base64.decode(node.as_s(HeaderContentMD5))

        content_type = node.as_s(HeaderContentType)
        copy_completion_time = node.as_time("CopyCompletionTime")
        copy_id = node.as_s("CopyId")
        copy_progress = node.as_s("CopyProgress")
        copy_source = node.as_s("CopySource")
        copy_status = node.as_enum("CopyStatus", Models::CopyStatusType)

        copy_status_desc = node.as_s("CopyStatusDescription")
        creation_time = node.as_time("Creation-Time")
        customer_provided_key_sha256 = node.as_s("CustomerProvidedKeySha256")
        deleted_time = node.as_time("DeletedTime")
        destination_snapshot = node.as_s("DestinationSnapshot")
        encryption_sceope = node.as_s("EncryptionScope")
        expires_on = node.as_time("Expiry-Time")
        is_sealed = node.as_bool("Sealed")
        last_access_on = node.as_time("LastAccessTime")
        lease_duration = node.as_s("LeaseDuration")
        lease_state = node.as_enum("LeaseState", Models::LeaseStatusType)
        lease_status = node.as_enum("LeaseStatus", Models::LeaseStatusType)
        legal_hold = node.as_bool("LegalHold")
        server_encrypted = node.as_bool("ServerEncrypted")
        tag_count = node.as_i("TagCount")

        new(etag, last_modified, access_tier, access_tier_change_time, access_tier_inferred, archive_status, blob_sequence_number, blob_type,
          cache_control, content_disposition, content_encoding, content_language, content_length, content_md5, content_type,
          copy_completion_time, copy_id, copy_progress, copy_source, copy_status, copy_status_desc, creation_time, customer_provided_key_sha256,
          deleted_time, destination_snapshot, encryption_sceope, expires_on, is_sealed, last_access_on, lease_duration, lease_state,
          lease_status, legal_hold, server_encrypted, tag_count
        )
      end
    end

    struct BlobListResp
      # contains the information returned from the x-ms-client-request-id header response.
      getter client_request_id : String?
      # contains the information returned from the Content-Type header response.
      getter content_type : String?
      # contains the information returned from the Date header response.
      getter date : Time?
      # contains the information returned from the x-ms-request-id header response.
      getter request_id : String?
      # contains the information returned from the x-ms-version header response.
      getter version : String?
      getter container_name : String
      getter service_endpoint : String
      getter marker : String?
      getter max_results : Int32?
      getter next_marker : String?
      getter prefix : String?

      getter blobs : Array(Blob)

      def initialize(@container_name, @service_endpoint, @max_results = nil, @marker = nil, @next_marker = nil, @client_request_id = nil,
                     @content_type = nil, @date = nil, @request_id = nil, @version = nil, @blobs = [] of Blob, @prefix = nil)
      end

      def self.from_resp(resp : HTTP::Client::Response)
        raise Error.from_resp(resp) unless resp.success?

        hdr = resp.headers
        cr = hdr[HeaderXMSClientRequestID]?
        ct = hdr[HeaderContentType]?
        dt = Models.to_date(hdr["Date"]?)
        ri = hdr[HeaderXMSRequestID]?
        ver = hdr[HeaderXmsVersion]?

        doc = XML.parse(resp.body)
        node = AZBlob::XMLNode.new(doc)
        service_endpoint = node.attr("/EnumerationResults/@ServiceEndpoint")
        container = node.attr("/EnumerationResults/@ContainerName")
        prefix = node.as_s("/EnumerationResults/Prefix")
        marker = node.as_s("/EnumerationResults/Marker")
        max_results = node.as_i("/EnumerationResults/MaxResults")
        next_marker = node.as_s("/EnumerationResults/NextMarker")
        blobs = [] of Blob
        node.nodes("/EnumerationResults/Blobs/Blob").each do |blob_node|
          blobs << Blob.from_node(blob_node)
        end

        new(container, service_endpoint, max_results, marker, next_marker, cr, ct, dt, ri, ver, blobs, prefix)
      end
    end
  end
end
