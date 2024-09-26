require "http"

module AZBlob::Models
  def self.to_date(str)
    return nil if str.nil? || str.blank?
    Time::Format::HTTP_DATE.parse(str) rescue nil
  end

  def self.to_date!(str)
    Time::Format::HTTP_DATE.parse(str)
  end

  def self.decode_b64(str)
    return nil if str.nil? || str.blank?
    Base64.decode_string(str)
  end

  def self.date_to_s(date)
    return nil if date.nil?
    Time::Format::HTTP_DATE.format(date)
  end

  private record Container, name : String, properties : Properties?, deleted : Bool, meta : Hash(String, String)?,
    version : String? do
    def self.from_node(container_node : XML::Node)
      node = AZBlob::XMLNode.new(container_node)

      name = node.as_s("Name")
      version = node.as_s("Version")
      deleted = node.as_bool("Deleted")
      prop_node = node.nodes("Properties")[0]
      meta_node = node.nodes("Metadata/*")
      metadata = {} of String => String
      meta_node.each { |e| metadata[e.name] = e.content }
      new(name, Properties.from_node(prop_node), deleted, metadata, version)
    end

    record Properties, etag : String, last_modified : Time, lease_status : String?, lease_state : String?,
      lease_duration : String?, public_access : String?, has_immutability_policy : Bool, has_legal_hold : Bool,
      deleted_time : Time?, remaining_retention_days : Int32? do
      def self.from_node(properties_node : XML::Node)
        node = AZBlob::XMLNode.new(properties_node)

        last_modified = node.as_s("Last-Modified")
        etag = node.as_s("Etag")
        lease_status = node.as_s("LeaseStatus")
        lease_state = node.as_s("LeaseState")
        lease_duration = node.as_s("LeaseDuration")
        public_access = node.as_s("PublicAccess")
        has_immutability_policy = node.as_bool("HasImmutabilityPolicy")
        has_legal_hold = node.as_bool("HasLegalHold")
        deleted_time = node.as_s("DeletedTime")
        remaining_retention_days = node.as_s("RemainingRetentionDays)").to_i rescue nil

        new(etag, Models.to_date!(last_modified), lease_status, lease_state, lease_duration, public_access,
          has_immutability_policy, has_legal_hold, Models.to_date(deleted_time), remaining_retention_days)
      end
    end
  end

  record ContainerListResp, service_endpoint : String, prefix : String, marker : String, max_results : Int32?,
    containers : Array(Container), next_marker : String? do
    def self.from_resp(resp : HTTP::Client::Response)
      raise Error.from_resp(resp) unless resp.success?
      xml_document = XML.parse(resp.body)
      node = AZBlob::XMLNode.new(xml_document)

      service_endpoint = node.attr("/EnumerationResults/@ServiceEndpoint")
      prefix = node.as_s("/EnumerationResults/Prefix")
      marker = node.as_s("/EnumerationResults/Marker")
      max_results = node.as_i("/EnumerationResults/MaxResults")
      next_marker = node.as_s("/EnumerationResults/NextMarker")
      containers = [] of Container
      node.nodes("/EnumerationResults/Containers/Container").each do |container_node|
        containers << Container.from_node(container_node)
      end
      new(service_endpoint, prefix, marker, max_results, containers, next_marker)
    end
  end

  record ContainCreateResp, client_request_id : String?, date : Time?, etag : String?, last_modified : Time?,
    request_id : String?, version : String? do
    def self.from_resp(resp : HTTP::Client::Response)
      raise Error.from_resp(resp) unless resp.success?

      hdr = resp.headers
      new(hdr[HeaderXMSClientRequestID]?, Models.to_date(hdr["Date"]?), hdr["ETag"]?, Models.to_date(hdr["Last-Modified"]?),
        hdr[HeaderXMSRequestID]?, hdr[HeaderXmsVersion]?)
    end
  end
end
