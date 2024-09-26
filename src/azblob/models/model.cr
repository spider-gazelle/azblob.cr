module AZBlob::Models
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

  enum ArchiveStatus
    RehydratePendingToCold
    RehydratePendingToCool
    RehydratePendingToHot

    def to_s
      self.member_name.try &.underscore.gsub('_', '-')
    end
  end

  enum BlobType
    AppendBlob
    BlockBlob
    PageBlob
  end

  enum CopyStatusType
    Aborted
    Failed
    Pending
    Success

    def to_s
      self.member_name.try &.downcase
    end
  end

  enum LeaseStatusType
    Available
    Breaking
    Broken
    Expired
    Leased

    def to_s
      self.member_name.try &.downcase
    end
  end
end
