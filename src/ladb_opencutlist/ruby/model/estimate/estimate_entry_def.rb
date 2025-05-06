module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative 'estimate_entry'

  class AbstractEstimateItemDef < DataContainer

    attr_accessor :parent_def, :total_cost, :total_used_cost

    def initialize(parent_def)

      @parent_def = parent_def

      @total_cost = 0
      @total_used_cost = 0

    end

  end

  class AbstractEstimateWeightedItemDef < AbstractEstimateItemDef

    attr_accessor :total_mass, :total_used_mass

    def initialize(parent_def)
      super

      @total_mass = 0
      @total_used_mass = 0

    end

  end

  class AbstractEstimateWeightedEntryDef < AbstractEstimateWeightedItemDef

    attr_reader :cutlist_group
    attr_accessor :raw_estimated, :multiplier_coefficient, :errors

    def initialize(parent_def, cutlist_group)
      super(parent_def)

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

  class SolidWoodEstimateEntryDef < AbstractEstimateWeightedEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_volume, :total_used_volume

    def initialize(parent_def, cutlist_group)
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

  class SheetGoodEstimateEntryDef < AbstractEstimateWeightedEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_area, :total_used_area
    attr_reader :bin_defs

    def initialize(parent_def, cutlist_group)
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

  class SheetGoodEstimateEntryBinDef < AbstractEstimateWeightedItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_area, :total_used_area
    attr_reader :type, :length, :width

    def initialize(parent_def, bin_type_def)
      super(parent_def)

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

  class DimensionalEstimateEntryDef < AbstractEstimateWeightedEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_length, :total_used_length
    attr_reader :bin_defs

    def initialize(parent_def, cutlist_group)
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

  class DimensionalEstimateEntryBarDef < AbstractEstimateWeightedItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_length, :total_used_length
    attr_reader :type, :length

    def initialize(parent_def, bin_type_def)
      super(parent_def)

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

  class EdgeEstimateEntryDef < AbstractEstimateWeightedEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_length, :total_used_length
    attr_reader :bin_defs

    def initialize(parent_def, cutlist_group)
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

  class EdgeEstimateEntryBarDef < AbstractEstimateWeightedItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_length, :total_used_length
    attr_reader :type, :length

    def initialize(parent_def, bin_type_def)
      super(parent_def)

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

  class HardwareEstimateEntryDef < AbstractEstimateWeightedEntryDef

    attr_accessor :total_count, :total_instance_count, :total_used_instance_count
    attr_reader :part_defs

    def initialize(parent_def, cutlist_group)
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

  class HardwareEstimateEntryPartDef < AbstractEstimateWeightedItemDef

    attr_accessor :mass, :price, :total_instance_count, :total_used_instance_count
    attr_reader :cutlist_part

    def initialize(parent_def, cutlist_part)
      super(parent_def)

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

  class VeneerEstimateEntryDef < AbstractEstimateWeightedEntryDef

    attr_accessor :std_volumic_mass, :std_price, :total_count, :total_area, :total_used_area
    attr_reader :bin_defs

    def initialize(parent_def, cutlist_group)
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

  class VeneerEstimateEntryBinDef < AbstractEstimateWeightedItemDef

    attr_accessor :std_volumic_mass, :std_price, :count, :total_area, :total_used_area
    attr_reader :type, :length, :width

    def initialize(parent_def, bin_type_def)
      super(parent_def)

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

  # -----

  class CutEstimateEntryDef < AbstractEstimateItemDef

    attr_reader :cutlist_group, :bin_defs
    attr_accessor :std_price, :total_count, :total_length

    def initialize(parent_def, cutlist_group)
      super(parent_def)

      @cutlist_group = cutlist_group

      @std_price = nil

      @total_count = 0
      @total_length = 0

      @bin_defs = {}

    end

    # ---

    def create_entry
      CutEstimateEntry.new(self)
    end

  end

  class CutEstimateEntryBinDef < AbstractEstimateItemDef

    attr_accessor :std_price, :count, :total_length
    attr_reader :type, :length, :width

    def initialize(parent_def, bin_type_def)
      super(parent_def)

      @std_price = nil

      @type = bin_type_def.type
      @length = bin_type_def.length
      @width = bin_type_def.width

      @count = 0
      @total_length = 0

    end

    # ---

    def create_bin
      CutEstimateEntryBin.new(self)
    end

  end

end
