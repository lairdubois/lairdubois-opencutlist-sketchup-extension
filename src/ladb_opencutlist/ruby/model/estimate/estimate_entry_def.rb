module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative 'estimate_entry'

  class AbstractEstimateItemDef < DataContainer

    attr_accessor :total_mass, :total_used_mass, :total_cost, :total_used_cost

    def initialize

      @total_mass = 0
      @total_used_mass = 0

      @total_cost = 0
      @total_used_cost = 0

    end

  end

  class AbstractEstimateEntryDef < AbstractEstimateItemDef

    attr_accessor :cutlist_group, :raw_estimated, :multiplier_coefficient, :errors

    def initialize(cutlist_group)
      super()

      @cutlist_group = cutlist_group

      @errors = []

      @raw_estimated = true
      @multiplier_coefficient = 1.0

    end

    # ---

    def create_entry
      raise 'Abstract method : Override it'
    end

  end

  # -----

  class SolidWoodEstimateEntryDef < AbstractEstimateEntryDef

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
      SolidWoodEstimateEntry.new(self)
    end

  end

  # -----

  class SheetGoodEstimateEntryDef < AbstractEstimateEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_area, :total_used_area
    attr_reader :bin_defs

    def initialize(cutlist_group)
      super

      @std_volumic_mass = nil
      @std_price = nil

      @total_count = 0
      @total_area = 0
      @total_used_area = 0

      @bin_defs = {}

    end

    # ---

    def create_entry
      SheetGoodEstimateEntry.new(self)
    end

  end

  class SheetGoodEstimateEntryBinDef < AbstractEstimateItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_area, :total_used_area
    attr_reader :type, :length, :width

    def initialize(bin_type_def)
      super()

      @std_volumic_mass = nil
      @std_price = nil

      @type = bin_type_def.type
      @length = bin_type_def.length
      @width = bin_type_def.width

      @count = 0
      @total_area = 0
      @total_used_area = 0

    end

    # ---

    def create_bin
      SheetGoodEstimateEntryBin.new(self)
    end

  end

  # -----

  class DimensionalEstimateEntryDef < AbstractEstimateEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_length, :total_used_length
    attr_reader :bin_defs

    def initialize(cutlist_group)
      super

      @std_volumic_mass = nil
      @std_price = nil

      @total_count = 0
      @total_length = 0
      @total_used_length = 0

      @bin_defs = {}

    end

    # ---

    def create_entry
      DimensionalEstimateEntry.new(self)
    end

  end

  class DimensionalEstimateEntryBarDef < AbstractEstimateItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_length, :total_used_length
    attr_reader :type, :length

    def initialize(bin_type_def)
      super()

      @std_volumic_mass = nil
      @std_price = nil

      @type = bin_type_def.type
      @length = bin_type_def.length

      @count = 0
      @total_length = 0
      @total_used_length = 0

    end

    # ---

    def create_bin
      DimensionalEstimateEntryBin.new(self)
    end

  end

  # -----

  class EdgeEstimateEntryDef < AbstractEstimateEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_length, :total_used_length
    attr_reader :bin_defs

    def initialize(cutlist_group)
      super

      @std_volumic_mass = nil
      @std_price = nil

      @total_count = 0
      @total_length = 0
      @total_used_length = 0

      @bin_defs = {}

    end

    # ---

    def create_entry
      EdgeEstimateEntry.new(self)
    end

  end

  class EdgeEstimateEntryBarDef < AbstractEstimateItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_length, :total_used_length
    attr_reader :type, :length

    def initialize(bin_type_def)
      super()

      @std_volumic_mass = nil
      @std_price = nil

      @type = bin_type_def.type
      @length = bin_type_def.length

      @count = 0
      @total_length = 0
      @total_used_length = 0

    end

    # ---

    def create_bin
      EdgeEstimateEntryBin.new(self)
    end

  end

  # -----

  class HardwareEstimateEntryDef < AbstractEstimateEntryDef

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
      HardwareEstimateEntry.new(self)
    end

  end

  class HardwareEstimateEntryPartDef < AbstractEstimateItemDef

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
      HardwareEstimateEntryPart.new(self)
    end

  end

  # -----

  class VeneerEstimateEntryDef < AbstractEstimateEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_area, :total_used_area
    attr_reader :bin_defs

    def initialize(cutlist_group)
      super

      @std_volumic_mass = nil
      @std_price = nil

      @total_count = 0
      @total_area = 0
      @total_used_area = 0

      @bin_defs = {}

    end

    # ---

    def create_entry
      VeneerEstimateEntry.new(self)
    end

  end

  class VeneerEstimateEntryBinDef < AbstractEstimateItemDef

    attr_accessor :std_volumic_mass, :std_price, :std_volumic_mass, :std_price, :count, :total_area, :total_used_area
    attr_reader :type, :length, :width

    def initialize(bin_type_def)
      super()

      @std_volumic_mass = nil
      @std_price = nil

      @type = bin_type_def.type
      @length = bin_type_def.length
      @width = bin_type_def.width

      @count = 0
      @total_area = 0
      @total_used_area = 0

    end

    # ---

    def create_bin
      VeneerEstimateEntryBin.new(self)
    end

  end

end
