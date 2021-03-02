module Ladb::OpenCutList

  require_relative 'report_entry'

  class AbstractReportItemDef

    attr_accessor :total_mass, :total_cost

    def initialize

      @total_mass = 0
      @total_cost = 0

    end

  end

  class AbstractReportEntryDef < AbstractReportItemDef

    attr_accessor :cutlist_group

    def initialize(cutlist_group)
      super()

      @cutlist_group = cutlist_group

    end

    # ---

    def create_entry
      raise 'Abstract method : Override it'
    end

  end

  # -----

  class SolidWoodReportEntryDef < AbstractReportEntryDef

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

  # -----

  class SheetGoodReportEntryDef < AbstractReportEntryDef

    attr_accessor :total_count, :total_area
    attr_reader :sheet_defs

    def initialize(cutlist_group)
      super(cutlist_group)

      @total_count = 0
      @total_area = 0

      @sheet_defs = []

    end

    # ---

    def create_entry
      SheetGoodReportEntry.new(self)
    end

  end

  class SheetGoodReportEntrySheetDef < AbstractReportItemDef

    attr_reader :cuttingdiagram2d_summary_sheet

    def initialize(cuttingdiagram2d_summary_sheet)
      super()

      @cuttingdiagram2d_summary_sheet = cuttingdiagram2d_summary_sheet

    end

    # ---

    def create_sheet
      SheetGoodReportEntrySheet.new(self)
    end

  end

  # -----

  class DimensionalReportEntryDef < AbstractReportEntryDef

    attr_accessor :total_count, :total_length, :bar_defs

    def initialize(cutlist_group)
      super(cutlist_group)

      @total_count = 0
      @total_length = 0

      @bar_defs = []

    end

    # ---

    def create_entry
      DimensionalReportEntry.new(self)
    end

  end

  class DimensionalReportEntryBarDef < AbstractReportItemDef

    attr_reader :cuttingdiagram1d_summary_bar

    def initialize(cuttingdiagram1d_summary_bar)
      super()

      @cuttingdiagram1d_summary_bar = cuttingdiagram1d_summary_bar

    end

    # ---

    def create_bar
      DimensionalReportEntryBar.new(self)
    end

  end

  # -----

  class EdgeReportEntryDef < AbstractReportEntryDef

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

  # -----

  class AccessoryReportEntryDef < AbstractReportEntryDef

    attr_accessor :total_count
    attr_reader :part_defs

    def initialize(cutlist_group)
      super(cutlist_group)

      @total_count = 0

      @part_defs = []

    end

    # ---

    def create_entry
      AccessoryReportEntry.new(self)
    end

  end

  class AccessoryReportEntryPartDef < AbstractReportItemDef

    attr_reader :cutlist_part

    def initialize(cutlist_part)
      super()

      @cutlist_part = cutlist_part

    end

    # ---

    def create_part
      AccessoryReportEntryPart.new(self)
    end

  end

end
