module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/mass_utils'
  require_relative '../../utils/price_utils'

  class AbstractReportGroup

    include HashableHelper

    attr_accessor :mass_ratio, :cost_ratio
    attr_reader :material_type, :total_mass, :total_cost, :entries

    def initialize(_def, material_type)
      @_def = _def

      @material_type = material_type

      @total_mass = _def.total_mass == 0 ? nil : MassUtils.instance.format_to_readable_mass(_def.total_mass)
      @total_used_mass = _def.total_used_mass == 0 ? nil : MassUtils.instance.format_to_readable_mass(_def.total_used_mass)
      @total_unused_mass = _def.total_unused_mass == 0 ? nil : MassUtils.instance.format_to_readable_mass(_def.total_unused_mass)

      @total_cost = _def.total_cost == 0 ? nil : PriceUtils.instance.format_to_readable_price(_def.total_cost)
      @total_used_cost = _def.total_used_cost == 0 ? nil : PriceUtils.instance.format_to_readable_price(_def.total_used_cost)
      @total_unused_cost = _def.total_unused_cost == 0 ? nil : PriceUtils.instance.format_to_readable_price(_def.total_unused_cost)

      @mass_ratio = 0
      @cost_ratio = 0

      @entries = _def.entry_defs.map { |entry_def| entry_def.create_entry }

    end

  end

  # -----

  class SolidWoodReportGroup < AbstractReportGroup

    attr_reader :total_volume, :total_used_volume

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_SOLID_WOOD)

      @total_volume = _def.total_volume == 0 ? nil : DimensionUtils.instance.format_to_readable_volume(_def.total_volume, @material_type)
      @total_used_volume = _def.total_used_volume == 0 ? nil : DimensionUtils.instance.format_to_readable_volume(_def.total_used_volume, @material_type)

    end

  end

  # -----

  class SheetGoodReportGroup < AbstractReportGroup

    attr_reader :total_count, :total_area, :total_used_area

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_SHEET_GOOD)

      @total_count = _def.total_count == 0 ? nil : _def.total_count
      @total_area = _def.total_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(_def.total_area)
      @total_used_area = _def.total_used_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(_def.total_used_area)

    end

  end

  # -----

  class DimensionalReportGroup < AbstractReportGroup

    attr_reader :total_count, :total_length, :total_used_length

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_DIMENSIONAL)

      @total_count = _def.total_count == 0 ? nil : _def.total_count
      @total_length = _def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_length)
      @total_used_length = _def.total_used_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_used_length)

    end

  end

  # -----

  class EdgeReportGroup < AbstractReportGroup

    attr_reader :total_count, :total_length, :total_used_length

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_EDGE)

      @total_count = _def.total_count == 0 ? nil : _def.total_count
      @total_length = _def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_length)
      @total_used_length = _def.total_used_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_used_length)

    end

  end

  # -----

  class HardwareReportGroup < AbstractReportGroup

    attr_reader :total_count, :total_instance_count, :total_used_instance_count

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_HARDWARE)

      @total_count = _def.total_count

      @total_instance_count = _def.total_instance_count
      @total_used_instance_count = _def.total_used_instance_count

    end

  end

  # -----

  class VeneerReportGroup < AbstractReportGroup

    attr_reader :total_count, :total_area, :total_used_area

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_VENEER)

      @total_count = _def.total_count == 0 ? nil : _def.total_count
      @total_area = _def.total_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(_def.total_area)
      @total_used_area = _def.total_used_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(_def.total_used_area)

    end

  end

end
