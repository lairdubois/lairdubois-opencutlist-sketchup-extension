module Ladb::OpenCutList

  require_relative 'estimate_group'

  class AbstractEstimateGroupDef

    attr_accessor :total_cost, :total_used_cost
    attr_reader :entry_defs

    def initialize

      @total_cost = 0
      @total_used_cost = 0

      @entry_defs = []

    end

    # ---

    def create_group
    end

    # ---

    def total_unused_cost
      [ @total_cost - @total_used_cost, 0 ].max
    end

  end

  class AbstractEstimateWeightedGroupDef < AbstractEstimateGroupDef

    attr_accessor :total_mass, :total_used_mass
    attr_reader :entry_defs

    def initialize
      super

      @total_mass = 0
      @total_used_mass = 0

    end

    # ---

    def create_group
    end

    # ---

    def total_unused_mass
      [ @total_mass - @total_used_mass, 0 ].max
    end

  end

  # -----

  class SolidWoodEstimateGroupDef < AbstractEstimateWeightedGroupDef

    attr_accessor :total_volume, :total_used_volume

    def initialize
      super

      @total_volume = 0
      @total_used_volume = 0

    end

    # ---

    def create_group
      SolidWoodEstimateGroup.new(self)
    end

  end

  # -----

  class SheetGoodEstimateGroupDef < AbstractEstimateWeightedGroupDef

    attr_accessor :total_count, :total_area, :total_used_area

    def initialize
      super

      @total_count = 0
      @total_area = 0
      @total_used_area = 0

    end

    # ---

    def create_group
      SheetGoodEstimateGroup.new(self)
    end

  end

  # -----

  class DimensionalEstimateGroupDef < AbstractEstimateWeightedGroupDef

    attr_accessor :total_count, :total_length, :total_used_length

    def initialize
      super

      @total_count = 0
      @total_length = 0
      @total_used_length = 0

    end

    # ---

    def create_group
      DimensionalEstimateGroup.new(self)
    end

  end

  # -----

  class EdgeEstimateGroupDef < AbstractEstimateWeightedGroupDef

    attr_accessor :total_count, :total_length, :total_used_length

    def initialize
      super

      @total_count = 0
      @total_length = 0
      @total_used_length = 0

    end

    # ---

    def create_group
      EdgeEstimateGroup.new(self)
    end

  end

  # -----

  class HardwareEstimateGroupDef < AbstractEstimateWeightedGroupDef

    attr_accessor :total_count, :total_instance_count, :total_used_instance_count

    def initialize
      super

      @total_count = 0

      @total_instance_count = 0
      @total_used_instance_count = 0

    end

    # ---

    def create_group
      HardwareEstimateGroup.new(self)
    end

  end

  # -----

  class VeneerEstimateGroupDef < AbstractEstimateWeightedGroupDef

    attr_accessor :total_count, :total_area, :total_used_area

    def initialize
      super

      @total_count = 0
      @total_area = 0
      @total_used_area = 0

    end

    # ---

    def create_group
      VeneerEstimateGroup.new(self)
    end

  end

  # -----

  class CutEstimateGroupDef < AbstractEstimateGroupDef

    attr_accessor :total_count, :total_length

    def initialize
      super

      @total_count = 0
      @total_length = 0

    end

    # ---

    def create_group
      CutEstimateGroup.new(self)
    end

  end
end
