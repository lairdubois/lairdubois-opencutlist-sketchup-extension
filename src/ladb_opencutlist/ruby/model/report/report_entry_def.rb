module Ladb::OpenCutList

  require_relative 'report_entry'

  class AstractReportEntryDef

    attr_accessor :cutlist_group, :total_mass, :total_cost

    def initialize(cutlist_group)
      @cutlist_group = cutlist_group

      @total_mass = 0
      @total_cost = 0

    end

    # ---

    def create_entry
      raise 'Abstract method : Override it'
    end

  end

  class SolidWoodReportEntryDef < AstractReportEntryDef

    attr_accessor :total_volume

    def initialize(cutlist_group)
      super(cutlist_group)

      @total_volume = 0

    end

    # ---

    def create_entry
      SolidWoodReportEntry.new(self)
    end

  end

  class SheetGoodReportEntryDef < AstractReportEntryDef

    attr_accessor :total_count, :total_area

    def initialize(cutlist_group)
      super(cutlist_group)

      @total_count = 0
      @total_area = 0

    end

    # ---

    def create_entry
      SheetGoodReportEntry.new(self)
    end

  end

  class DimensionalReportEntryDef < AstractReportEntryDef

    attr_accessor :total_count, :total_length

    def initialize(cutlist_group)
      super(cutlist_group)

      @total_count = 0
      @total_length = 0

    end

    # ---

    def create_entry
      DimensionalReportEntry.new(self)
    end

  end

  class EdgeReportEntryDef < AstractReportEntryDef

    attr_accessor :total_length

    def initialize(cutlist_group)
      super(cutlist_group)

      @total_length = 0

    end

    # ---

    def create_entry
      EdgeReportEntry.new(self)
    end

  end

  class AccessoryReportEntryDef < AstractReportEntryDef

    attr_accessor :total_count

    def initialize(cutlist_group)
      super(cutlist_group)

      @total_count = 0

    end

    # ---

    def create_entry
      AccessoryReportEntry.new(self)
    end

  end

end
