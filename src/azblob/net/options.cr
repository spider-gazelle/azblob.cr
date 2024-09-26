module AZBlob
  # HTTPRange defines a range of bytes within an HTTP resource, starting at offset and
  # ending at offset+count. A zero-value HTTPRange indicates the entire resource. An HTTPRange
  # which has an offset and zero value count indicates from the offset to the resource's end.
  class HTTPRange
    property offset : Int64
    property count : Int64

    def initialize(@offset = 0, @count = 0)
    end

    def self.empty
      new
    end

    def format : String
      return "" if offset == 0 && count == 0
      eoffset = count > 0 ? (offset + count - 1).to_s : ""
      "bytes=#{offset}-#{eoffset}"
    end
  end

  alias FailRead = (Int32, Error, HTTPRange, Bool) ->

  record RetryReaderOptions, max_tries : Int32, on_fail_read : FailRead?

  struct BlobHTTPHeaders
    getter cache_control : String?
    getter content_disposition : String?
    getter content_encoding : String?
    getter content_language : String?
    getter content_md5 : String?
    getter content_type : String?

    def initialize(@cache_control, @content_disposition, @content_encoding, @content_language, @content_md5, @content_type)
    end
  end

  enum EncryptionAlgorithmType
    None
    AES256
  end

  enum AccessTier
    Archive
    Cold
    Cool
    Hot
    P10
    P15
    P20
    P30
    P4
    P40
    P50
    P6
    P60
    P70
    P80
    Premium
  end

  record CPKInfo, encryption_algorithm : EncryptionAlgorithmType?, encryption_key : String?, encryption_key_sha256 : String?
  record CPKScopeInfo, encryption_scope : String?
  record LeaseAcessConditions, lease_id : String?
  record ModifiedAccessConditions, if_match : String?, if_modified_since : Time?, if_none_match : String?, if_tags : String?,
    if_unmodified_since : Time?
  record AccessConditions, lease_access : LeaseAcessConditions?, modified_access : ModifiedAccessConditions?
  record StageBlockOptions, cpk_info : CPKInfo?, cpk_scope_info : CPKScopeInfo?, lease_access : LeaseAcessConditions?

  class UploadOptions
    property block_size : Int64
    property concurrency : Int32
    property headers : BlobHTTPHeaders?
    property metadata : Hash(String, String)
    property access_conditions : AccessConditions?
    property access_tier : AccessTier?
    property tags : Hash(String, Array(String))
    property cpk_info : CPKInfo?
    property cpk_scope_info : CPKScopeInfo?
    property progress : Proc(Int64, Nil)?

    def initialize(@block_size = 0, @concurrency = 0, @headers = nil, @metadata = Hash(String, String).new,
                   @access_conditions = nil, @access_tier = nil, @tags = Hash(String, Array(String)).new, @cpk_info = nil,
                   @cpk_scope_info = nil, @progress = nil)
    end

    def self.default
      new(block_size: 1024 * 1024, concurrency: DefaultConcurrency)
    end

    def tags_str
      URI::Params.new(tags).to_s
    end

    def stage_block_options
      StageBlockOptions.new(cpk_info, cpk_scope_info, access_conditions.try &.lease_access)
    end
  end

  class DownloadOptions
    property block_size : Int64
    property concurrency : Int32
    property range : HTTPRange
    property? range_content_md5 : Bool
    property access_conditions : AccessConditions?
    property cpk_info : CPKInfo?
    property cpk_scope_info : CPKScopeInfo?
    property retry_read_options : RetryReaderOptions?
    property progress : Proc(Int64, Nil)?
    property snapshot : String?
    property version_id : String?

    def initialize(@block_size = 0, @concurrency = 0, @range = HTTPRange.empty, @range_content_md5 = false,
                   @access_conditions = nil, @cpk_info = nil, @cpk_scope_info = nil, @progress = nil,
                   @snapshot = nil, @version_id = nil)
    end

    def self.default
      new(block_size: DefaultDownloadBlockSize, concurrency: DefaultConcurrency)
    end
  end
end
