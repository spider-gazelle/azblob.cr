require "xml"

module AZBlob
  struct XMLNode
    getter node : XML::Node

    def initialize(@node)
    end

    def as_s(path : String) : String
      node.xpath_string("string(#{path})")
    end

    def as_bool(path : String)
      node.xpath_bool("boolean(#{path})")
    end

    def as_i(path : String)
      as_s(path).to_i rescue nil
    end

    def as_i64(path : String)
      as_s(path).to_i64 rescue nil
    end

    def nodes(path : String) : XML::NodeSet
      node.xpath_nodes(path)
    end

    def attr(path, pos = 0)
      node.xpath(path).as(XML::NodeSet)[pos].content
    end

    def as_enum(path : String, clz : Enum.class)
      val = as_s(path)
      return nil if val.blank?
      clz.parse(val) rescue nil
    end

    def as_time(path : String)
      Models.to_date(as_s(path))
    end
  end

  struct HeaderReader
    getter headers : HTTP::Headers

    def initialize(@headers)
    end

    def as_s(path : String) : String
      headers.fetch(path, "")
    end

    def as_bool(path : String)
      val = as_s(path)
      val.strip.downcase == "true"
    end

    def as_i(path : String)
      as_s(path).to_i rescue nil
    end

    def as_i64(path : String)
      as_s(path).to_i64 rescue nil
    end

    def as_enum(path : String, clz : Enum.class)
      val = as_s(path)
      return nil if val.blank?
      clz.parse(val) rescue nil
    end

    def as_time(path : String)
      Models.to_date(as_s(path))
    end
  end
end
