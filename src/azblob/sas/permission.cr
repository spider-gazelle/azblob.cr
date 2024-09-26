module AZBlob
  alias SasPermissions = BlobPermissions | ContainerPermissions
  # BlobPermissions type simplifies creating the permissions string for an Azure Storage blob SAS.
  @[Flags]
  enum BlobPermissions
    Read
    Add
    Create
    Write
    Delete
    DeletePreviousVersion
    PermanentDelete
    List
    Tag
    Move
    Execute
    Ownership
    Permissions
    SetImmutabilityPolicy

    def to_s(io : IO) : Nil
      io << to_s
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def to_s : String
      String.build do |str|
        str << 'r' if read?
        str << 'a' if add?
        str << 'c' if create?
        str << 'w' if write?
        str << 'd' if delete?
        str << 'x' if delete_previous_version?
        str << 'y' if permanent_delete?
        str << 'l' if list?
        str << 't' if tag?
        str << 'm' if move?
        str << 'e' if execute?
        str << 'o' if ownership?
        str << 'p' if permissions?
        str << 'i' if set_immutability_policy?
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def self.parse(string : String) : self
      result = BlobPermissions::None

      string.each_char do |chr|
        case chr
        when 'r' then result = result | BlobPermissions::Read
        when 'a' then result = result | BlobPermissions::Add
        when 'c' then result = result | BlobPermissions::Create
        when 'w' then result = result | BlobPermissions::Write
        when 'd' then result = result | BlobPermissions::Delete
        when 'x' then result = result | BlobPermissions::DeletePreviousVersion
        when 'y' then result = result | BlobPermissions::PermanentDelete
        when 'l' then result = result | BlobPermissions::List
        when 't' then result = result | BlobPermissions::Tag
        when 'm' then result = result | BlobPermissions::Move
        when 'e' then result = result | BlobPermissions::Execute
        when 'o' then result = result | BlobPermissions::Ownership
        when 'p' then result = result | BlobPermissions::Permissions
        when 'i' then result = result | BlobPermissions::SetImmutabilityPolicy
        else
          raise ArgumentError.new("invalid permission: #{chr}")
        end
      end
      result
    end

    {% for var in @type.constants %}
    def self.{{var.stringify.underscore.id}}
      {{var}}
    end
  {% end %}
  end

  # ContainerPermissions type simplifies creating the permissions string for an Azure Storage container SAS.
  @[Flags]
  enum ContainerPermissions
    Read
    Add
    Create
    Write
    Delete
    DeletePreviousVersion
    List
    Tag
    FilterByTags
    Move
    Execute
    ModifyOwnership
    ModifyPermissions
    SetImmutabilityPolicy

    def to_s(io : IO) : Nil
      io << to_s
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def to_s : String
      String.build do |str|
        str << 'r' if read?
        str << 'a' if add?
        str << 'c' if create?
        str << 'w' if write?
        str << 'd' if delete?
        str << 'x' if delete_previous_version?
        str << 'l' if list?
        str << 't' if tag?
        str << 'f' if filter_by_tags?
        str << 'm' if move?
        str << 'e' if execute?
        str << 'o' if modify_ownership?
        str << 'p' if modify_permissions?
        str << 'i' if set_immutability_policy?
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def self.parse(string : String) : self
      result = ContainerPermissions::None

      string.each_char do |chr|
        case chr
        when 'r' then result = result | ContainerPermissions::Read
        when 'a' then result = result | ContainerPermissions::Add
        when 'c' then result = result | ContainerPermissions::Create
        when 'w' then result = result | ContainerPermissions::Write
        when 'd' then result = result | ContainerPermissions::Delete
        when 'x' then result = result | ContainerPermissions::DeletePreviousVersion
        when 'l' then result = result | ContainerPermissions::List
        when 't' then result = result | ContainerPermissions::Tag
        when 'f' then result = result | ContainerPermissions::FilterByTags
        when 'm' then result = result | ContainerPermissions::Move
        when 'e' then result = result | ContainerPermissions::Execute
        when 'o' then result = result | ContainerPermissions::ModifyOwnership
        when 'p' then result = result | ContainerPermissions::ModifyPermissions
        when 'i' then result = result | ContainerPermissions::SetImmutabilityPolicy
        else
          raise ArgumentError.new("invalid permission: #{chr}")
        end
      end
      result
    end

    {% for var in @type.constants %}
    def self.{{var.stringify.underscore.id}}
      {{var}}
    end
  {% end %}
  end
end
