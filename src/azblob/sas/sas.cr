require "./permission.cr"

module AZBlob
  class Client
    def container_sas(container : String, expiry = 10.minutes, permissions : ContainerPermissions = ContainerPermissions.read | ContainerPermissions.list | ContainerPermissions.execute)
      params = SignatureValues.new(container: container, permissions: permissions, expiry: expiry).sign_with_sharedkey(@cred)
      params.add("restype", "container")
      params.add("comp", "list")
      "#{config.endpoint}#{container}?#{params}"
    end

    def blob_sas(container : String, blob : String, expiry = 10.minutes, permissions : BlobPermissions = BlobPermissions.read | BlobPermissions.list)
      params = SignatureValues.new(container: container, blob: blob, permissions: permissions, expiry: expiry).sign_with_sharedkey(@cred)
      "#{config.endpoint}#{container}/#{URI.encode_path_segment(blob)}?#{params}"
    end
  end

  # SignatureValues is used to generate a Shared Access Signature (SAS) for an Azure Storage container or blob.
  # For more information on creating service sas, see https://docs.microsoft.com/rest/api/storageservices/constructing-a-service-sas
  # For more information on creating user delegation sas, see https://docs.microsoft.com/rest/api/storageservices/create-user-delegation-sas
  record SignatureValues, container : String, permissions : SasPermissions, blob : String = "", version : String = ServiceVersion, protocol : String = "https,http",
    start : Time = Time.utc, expiry : Time::Span = 1.hour, snapshot_time : Time? = nil, ip_range : String? = nil, identifier : String? = nil, directory : String? = nil,
    cache_control : String? = nil, content_disposition : String? = nil, content_encoding : String? = nil, content_language : String? = nil, content_type : String? = nil,
    blob_version : String? = nil, authorized_objid : String? = nil, unauthorized_objid : String? = nil, correlation_id : String? = nil, encryption_scope : String? = nil do
    # uses an account's SharedKeyCredential to sign this signature values to produce the proper SAS query parameters.
    # ameba:disable Metrics/CyclomaticComplexity
    def sign_with_sharedkey(cred : SharedKeyCredential)
      resource = if snapshot_time
                   "bs"
                 elsif blob_version
                   "bv"
                 elsif directory
                   "d"
                 elsif blob.blank?
                   "c"
                 else
                   "b"
                 end

      # https://learn.microsoft.com/en-us/rest/api/storageservices/create-service-sas#construct-the-signature-string
      str_to_sign = [
        permissions.to_s,
        format_time(start),
        format_time(start + expiry),
        canonical_name(cred.account_name, container, blob, directory),
        identifier || "",
        ip_range || "",
        protocol,
        version,
        resource,
        format_time(snapshot_time),
        encryption_scope || "",
        cache_control || "",
        content_disposition || "",
        content_encoding || "",
        content_language || "",
        content_type || "",
      ].join('\n')

      signature = cred.compute_hmac_sha256(str_to_sign)
      build_params(resource, signature)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def build_params(resource, signature)
      param = URI::Params.new
      # Common SAS parameters
      param.add("sv", version)
      param.add("spr", protocol)
      param.add("st", format_time(start))
      param.add("se", format_time(start + expiry))
      param.add("sp", permissions.to_s)
      param.add("sip", ip_range.to_s) if ip_range
      param.add("ses", encryption_scope.to_s) if encryption_scope

      # Container/Blob-specific SAS parameters
      param.add("sr", resource)
      param.add("si", identifier.to_s) if identifier
      param.add("rscc", cache_control.to_s) if cache_control
      param.add("rscd", content_disposition.to_s) if content_disposition
      param.add("rsce", content_encoding.to_s) if content_encoding
      param.add("rscl", content_language.to_s) if content_language
      param.add("rsct", content_type.to_s) if content_type
      param.add("snapshot", format_time(snapshot_time)) if snapshot_time
      param.add("sdd", directory_depth(directory)) if directory
      param.add("saoid", authorized_objid.to_s) if authorized_objid
      param.add("suoid", unauthorized_objid.to_s) if unauthorized_objid
      param.add("scid", correlation_id.to_s) if correlation_id
      param.add("sig", signature)
      param
    end

    private def format_time(time)
      return "" unless time
      Time::Format::ISO_8601_DATE_TIME.format(time)
    end

    private def canonical_name(account, container, blob, dir)
      elems = ["/blob/", account, "/", container]
      unless blob.blank?
        elems << "/"
        elems << blob.gsub("\\", "/")
      end
      if d = dir
        elems << "/"
        elems << d
      end

      elems.join("")
    end

    private def directory_depth(dir)
      return "" unless dir
      (dir.count('/') + 1).to_s
    end
  end
end
