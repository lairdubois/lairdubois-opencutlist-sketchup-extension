module Ladb::OpenCutList

  require_relative 'report_entry'

  class AbstractReportItemDef

    attr_accessor :total_mass, :total_used_mass, :total_cost, :total_used_cost

    def initialize

      @total_mass = 0
      @total_used_mass = 0

      @total_cost = 0
      @total_used_cost = 0

    end

  end

  class AbstractReportEntryDef < AbstractReportItemDef

    attr_accessor :cutlist_group, :raw_estimated, :errors

    def initialize(cutlist_group)
      super()

      @cutlist_group = cutlist_group

      @errors = []

      @raw_estimated = true

    end

    # ---

    def create_entry
      raise 'Abstract method : Override it'
    end

  end

  # -----

  class SolidWoodReportEntryDef < AbstractReportEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_volume, :total_used_volume

    def initialize(cutlist_group)
      super

      @std_volumic_mass = nil
      @std_price = nil

      @total_volume = 0
      @total_used_volume = 0

    end

    # ---

    def create_entry
      SolidWoodReportEntry.new(self)
    end

  end

  # -----

  class SheetGoodReportEntryDef < AbstractReportEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_area, :total_used_area
    attr_reader :sheet_defs

    def initialize(cutlist_group)
      super

      @std_volumic_mass = nil
      @std_price = nil

      @total_count = 0
      @total_area = 0
      @total_used_area = 0

      @sheet_defs = {}

    end

    # ---

    def create_entry
      SheetGoodReportEntry.new(self)
    end

  end

  class SheetGoodReportEntrySheetDef < AbstractReportItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_area, :total_used_area
    attr_reader :type, :length, :width

    def initialize(cuttingdiagram2d_sheet)
      super()

      @std_volumic_mass = nil
      @std_price = nil

      @type = cuttingdiagram2d_sheet.def.type
      @length = cuttingdiagram2d_sheet.def.length
      @width = cuttingdiagram2d_sheet.def.width

      @count = 0
      @total_area = 0
      @total_used_area = 0

    end

    # ---

    def create_sheet
      SheetGoodReportEntrySheet.new(self)
    end

  end

  # -----

  class DimensionalReportEntryDef < AbstractReportEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_length, :total_used_length
    attr_reader :bar_defs

    def initialize(cutlist_group)
      super

      @std_volumic_mass = nil
      @std_price = nil

      @total_count = 0
      @total_length = 0
      @total_used_length = 0

      @bar_defs = {}

    end

    # ---

    def create_entry
      DimensionalReportEntry.new(self)
    end

  end

  class DimensionalReportEntryBarDef < AbstractReportItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_length, :total_used_length
    attr_reader :type, :length

    def initialize(cuttingdiagram1d_bar)
      super()

      @std_volumic_mass = nil
      @std_price = nil

      @type = cuttingdiagram1d_bar.def.type
      @length = cuttingdiagram1d_bar.def.length

      @count = 0
      @total_length = 0
      @total_used_length = 0

    end

    # ---

    def create_bar
      DimensionalReportEntryBar.new(self)
    end

  end

  # -----

  class EdgeReportEntryDef < AbstractReportEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_length, :total_used_length
    attr_reader :bar_defs

    def initialize(cutlist_group)
      super

      @std_volumic_mass = nil
      @std_price = nil

      @total_count = 0
      @total_length = 0
      @total_used_length = 0

      @bar_defs = {}

    end

    # ---

    def create_entry
      EdgeReportEntry.new(self)
    end

  end

  class EdgeReportEntryBarDef < AbstractReportItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_length, :total_used_length
    attr_reader :type, :length

    def initialize(cuttingdiagram1d_bar)
      super()

      @std_volumic_mass = nil
      @std_price = nil

      @type = cuttingdiagram1d_bar.def.type
      @length = cuttingdiagram1d_bar.def.length

      @count = 0
      @total_length = 0
      @total_used_length = 0

    end

    # ---

    def create_bar
      EdgeReportEntryBar.new(self)
    end

  end

  # -----

  class HardwareReportEntryDef < AbstractReportEntryDef

    attr_accessor :total_count, :total_instance_count, :total_used_instance_count
    attr_reader :part_defs

    def initialize(cutlist_group)
      super

      @total_count = 0

      @total_instance_count = 0
      @total_used_instance_count = 0

      @part_defs = []

    end

    # ---

    def create_entry
      HardwareReportEntry.new(self)
    end

  end

  class HardwareReportEntryPartDef < AbstractReportItemDef

    attr_accessor :mass, :price, :total_instance_count, :total_used_instance_count
    attr_reader :cutlist_part

    def initialize(cutlist_part)
      super()

      @cutlist_part = cutlist_part

      @mass = nil
      @price = nil

      @total_instance_count = 0
      @total_used_instance_count = 0

    end

    # ---

    def create_part
      HardwareReportEntryPart.new(self)
    end

  end

  # -----

  class VeneerReportEntryDef < AbstractReportEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_area, :total_used_area
    attr_reader :sheet_defs

    def initialize(cutlist_group)
      super

      @std_volumic_mass = nil
      @std_price = nil

      @total_count = 0
      @total_area = 0
      @total_used_area = 0

      @sheet_defs = {}

    end

    # ---

    def create_entry
      VeneerReportEntry.new(self)
    end

  end

  class VeneerReportEntrySheetDef < AbstractReportItemDef

    attr_accessor :std_volumic_mass, :std_price, :std_volumic_mass, :std_price, :count, :total_area, :total_used_area
    attr_reader :type, :length, :width

    def initialize(cuttingdiagram2d_sheet)
      super()

      @std_volumic_mass = nil
      @std_price = nil

      @type = cuttingdiagram2d_sheet.def.type
      @length = cuttingdiagram2d_sheet.def.length
      @width = cuttingdiagram2d_sheet.def.width

      @count = 0
      @total_area = 0
      @total_used_area = 0

    end

    # ---

    def create_sheet
      VeneerReportEntrySheet.new(self)
    end

  end

end
