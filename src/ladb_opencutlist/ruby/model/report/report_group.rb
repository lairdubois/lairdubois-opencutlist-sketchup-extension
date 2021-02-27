module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class AstractReportGroup

    include HashableHelper

    attr_reader :material_type, :total_mass, :total_cost, :entries

    def initialize(group_def, material_type)
      @_def = group_def

      @material_type = material_type
      @total_mass = group_def.total_mass
      @total_cost = group_def.total_cost

      @entries = []
      group_def.entry_defs.each do |entry_def|
        @entries.push(entry_def.create_entry)
      end
    end

  end

  class SolidWoodReportGroup < AstractReportGroup

    attr_reader :total_volume

    def initialize(group_def)
      super(group_def, MaterialAttributes::TYPE_SOLID_WOOD)

      @total_volume = group_def.total_volume == 0 ? nil : DimensionUtils.instance.format_to_readable_volume(group_def.total_volume, @material_type)
    end

    # ---

  end

  class SheetGoodReportGroup < AstractReportGroup

    attr_reader :total_area

    def initialize(group_def)
      super(group_def, MaterialAttributes::TYPE_SHEET_GOOD)

      @total_count = group_def.total_count
      @total_area = group_def.total_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(group_def.total_area)
    end

    # ---

  end

  class DimensionalReportGroup < AstractReportGroup

    attr_reader :total_length

    def initialize(group_def)
      super(group_def, MaterialAttributes::TYPE_DIMENSIONAL)

      @total_count = group_def.total_count
      @total_length = group_def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(group_def.total_length)
    end

    # ---

  end

  class EdgeReportGroup < AstractReportGroup

    attr_reader :total_length

    def initialize(group_def)
      super(group_def, MaterialAttributes::TYPE_EDGE)

      @total_length = group_def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(group_def.total_length)
    end

    # ---

  end

  class AccessoryReportGroup < AstractReportGroup

    attr_reader :total_count

    def initialize(group_def)
      super(group_def, MaterialAttributes::TYPE_ACCESSORY)

      @total_count = group_def.total_count
    end

    # ---

  end

end
