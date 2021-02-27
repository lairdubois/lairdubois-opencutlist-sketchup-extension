module Ladb::OpenCutList

  require_relative 'report_group'

  class AstractReportGroupDef

    attr_accessor :total_mass, :total_cost
    attr_reader :entry_defs

    def initialize
      @total_mass = 0
      @total_cost = 0
      @entry_defs = []
    end

    # ---

    def create_group
    end

    # Groups

    def add_entry_def(entry_def)
      @entry_defs.push(entry_def)
    end

  end

  class SolidWoodReportGroupDef < AstractReportGroupDef

    attr_accessor :total_volume

    def initialize
      super

      @total_volume = 0
    end

    # ---

    def create_group
      SolidWoodReportGroup.new(self)
    end

  end

  class SheetGoodReportGroupDef < AstractReportGroupDef

    attr_accessor :total_count, :total_area

    def initialize
      super

      @total_count = 0
      @total_area = 0
    end

    # ---

    def create_group
      SheetGoodReportGroup.new(self)
    end

  end

  class DimensionalReportGroupDef < AstractReportGroupDef

    attr_accessor :total_count, :total_length

    def initialize
      super

      @total_count = 0
      @total_length = 0
    end

    # ---

    def create_group
      DimensionalReportGroup.new(self)
    end

  end

  class EdgeReportGroupDef < AstractReportGroupDef

    attr_accessor :total_length

    def initialize
      super

      @total_length = 0
    end

    # ---

    def create_group
      EdgeReportGroup.new(self)
    end

  end

  class AccessoryReportGroupDef < AstractReportGroupDef

    attr_accessor :total_count

    def initialize
      super

      @total_count = 0
    end

    # ---

    def create_group
      AccessoryReportGroup.new(self)
    end

  end

end
