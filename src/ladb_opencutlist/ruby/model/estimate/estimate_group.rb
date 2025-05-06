module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/mass_utils'
  require_relative '../../utils/price_utils'

  class AbstractEstimateGroup < DataContainer

    include HashableHelper

    attr_accessor :cost_ratio
    attr_reader :type, :total_cost, :entries

    def initialize(_def, type)
      @_def = _def

      @type = type

      @total_cost = _def.total_cost == 0 ? nil : PriceUtils.format_to_readable_price(_def.total_cost)
      @total_used_cost = _def.total_used_cost == 0 ? nil : PriceUtils.format_to_readable_price(_def.total_used_cost)
      @total_unused_cost = _def.total_unused_cost == 0 ? nil : PriceUtils.format_to_readable_price(_def.total_unused_cost)

      @cost_ratio = 0

      @entries = _def.entry_defs.map { |entry_def| entry_def.create_entry }

    end

  end

  class AbstractEstimateWeightedGroup < AbstractEstimateGroup

    include HashableHelper

    attr_accessor :mass_ratio
    attr_reader :total_mass

    def initialize(_def, type)
      super

      @total_mass = _def.total_mass == 0 ? nil : MassUtils.format_to_readable_mass(_def.total_mass)
      @total_used_mass = _def.total_used_mass == 0 ? nil : MassUtils.format_to_readable_mass(_def.total_used_mass)
      @total_unused_mass = _def.total_unused_mass == 0 ? nil : MassUtils.format_to_readable_mass(_def.total_unused_mass)

      @mass_ratio = 0

    end

  end

  # -----

  class SolidWoodEstimateGroup < AbstractEstimateWeightedGroup

    attr_reader :total_volume, :total_used_volume

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_SOLID_WOOD)

      @total_volume = _def.total_volume == 0 ? nil : DimensionUtils.format_to_readable_volume(_def.total_volume, @material_type)
      @total_used_volume = _def.total_used_volume == 0 ? nil : DimensionUtils.format_to_readable_volume(_def.total_used_volume, @material_type)

    end

  end

  # -----

  class SheetGoodEstimateGroup < AbstractEstimateWeightedGroup

    attr_reader :total_count, :total_area, :total_used_area

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_SHEET_GOOD)

      @total_count = _def.total_count == 0 ? nil : _def.total_count
      @total_area = _def.total_area == 0 ? nil : DimensionUtils.format_to_readable_area(_def.total_area)
      @total_used_area = _def.total_used_area == 0 ? nil : DimensionUtils.format_to_readable_area(_def.total_used_area)

    end

  end

  # -----

  class DimensionalEstimateGroup < AbstractEstimateWeightedGroup

    attr_reader :total_count, :total_length, :total_used_length

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_DIMENSIONAL)

      @total_count = _def.total_count == 0 ? nil : _def.total_count
      @total_length = _def.total_length == 0 ? nil : DimensionUtils.format_to_readable_length(_def.total_length)
      @total_used_length = _def.total_used_length == 0 ? nil : DimensionUtils.format_to_readable_length(_def.total_used_length)

    end

  end

  # -----

  class EdgeEstimateGroup < AbstractEstimateWeightedGroup

    attr_reader :total_count, :total_length, :total_used_length

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_EDGE)

      @total_count = _def.total_count == 0 ? nil : _def.total_count
      @total_length = _def.total_length == 0 ? nil : DimensionUtils.format_to_readable_length(_def.total_length)
      @total_used_length = _def.total_used_length == 0 ? nil : DimensionUtils.format_to_readable_length(_def.total_used_length)

    end

  end

  # -----

  class HardwareEstimateGroup < AbstractEstimateWeightedGroup

    attr_reader :total_count, :total_instance_count, :total_used_instance_count

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_HARDWARE)

      @total_count = _def.total_count

      @total_instance_count = _def.total_instance_count
      @total_used_instance_count = _def.total_used_instance_count

    end

  end

  # -----

  class VeneerEstimateGroup < AbstractEstimateWeightedGroup

    attr_reader :total_count, :total_area, :total_used_area

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_VENEER)

      @total_count = _def.total_count == 0 ? nil : _def.total_count
      @total_area = _def.total_area == 0 ? nil : DimensionUtils.format_to_readable_area(_def.total_area)
      @total_used_area = _def.total_used_area == 0 ? nil : DimensionUtils.format_to_readable_area(_def.total_used_area)

    end

  end

  # -----

  class CutEstimateGroup < AbstractEstimateGroup

    attr_reader :total_length

    def initialize(_def)
      super(_def, -1)

      @total_count = _def.total_count == 0 ? nil : _def.total_count
      @total_length = _def.total_length == 0 ? nil : DimensionUtils.format_to_readable_length(_def.total_length)

    end

  end

end
