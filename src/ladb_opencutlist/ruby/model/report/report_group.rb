module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/mass_utils'
  require_relative '../../utils/price_utils'

  class AbstractReportGroup

    include HashableHelper

    attr_reader :material_type, :total_mass, :total_cost, :entries

    def initialize(_def, material_type)
      @_def = _def

      @material_type = material_type
      @total_mass = _def.total_mass == 0 ? nil : MassUtils.instance.format_to_readable_mass(_def.total_mass)
      @total_cost = _def.total_cost == 0 ? nil : PriceUtils.instance.format_to_readable_price(_def.total_cost)

      @entries = _def.entry_defs.map { |entry_def| entry_def.create_entry }

    end

  end

  # -----

  class SolidWoodReportGroup < AbstractReportGroup

    attr_reader :total_volume

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_SOLID_WOOD)

      @total_volume = _def.total_volume == 0 ? nil : DimensionUtils.instance.format_to_readable_volume(_def.total_volume, @material_type)

    end

  end

  # -----

  class SheetGoodReportGroup < AbstractReportGroup

    attr_reader :total_area

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_SHEET_GOOD)

      @total_count = _def.total_count
      @total_area = _def.total_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(_def.total_area)

    end

  end

  # -----

  class DimensionalReportGroup < AbstractReportGroup

    attr_reader :total_length

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_DIMENSIONAL)

      @total_count = _def.total_count
      @total_length = _def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_length)

    end

  end

  # -----

  class EdgeReportGroup < AbstractReportGroup

    attr_reader :total_length

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_EDGE)

      @total_length = _def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_length)

    end

  end

  # -----

  class HardwareReportGroup < AbstractReportGroup

    attr_reader :total_count

    def initialize(_def)
      super(_def, MaterialAttributes::TYPE_HARDWARE)

      @total_count = _def.total_count

    end

  end

end
