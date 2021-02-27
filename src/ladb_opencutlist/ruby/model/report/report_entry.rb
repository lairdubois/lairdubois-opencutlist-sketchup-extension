module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class AstractReportEntry

    include HashableHelper

    attr_reader :total_mass, :total_cost

    def initialize(entry_def)
      @_def = entry_def

      @material_name = entry_def.cutlist_group.material_name
      @material_display_name = entry_def.cutlist_group.material_display_name
      @material_color = entry_def.cutlist_group.material_color
      @material_type = entry_def.cutlist_group.material_type
      @std_available = entry_def.cutlist_group.std_available
      @std_dimension_stipped_name = entry_def.cutlist_group.std_dimension_stipped_name
      @std_dimension = entry_def.cutlist_group.std_dimension
      @std_thickness = entry_def.cutlist_group.std_thickness

      @total_mass = 0
      @total_cost = 0
    end

    # ---

  end

  class SolidWoodReportEntry < AstractReportEntry

    attr_reader :total_volume

    def initialize(entry_def)
      super(entry_def)

      @total_volume = entry_def.total_volume == 0 ? nil : DimensionUtils.instance.format_to_readable_volume(entry_def.total_volume, @material_type)
    end

    # ---

  end

  class SheetGoodReportEntry < AstractReportEntry

    attr_reader :total_count, :total_area

    def initialize(entry_def)
      super(entry_def)

      @total_count = entry_def.total_count
      @total_area = entry_def.total_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(entry_def.total_area)
    end

    # ---

  end

  class DimensionalReportEntry < AstractReportEntry

    attr_reader :total_count, :total_length

    def initialize(entry_def)
      super(entry_def)

      @total_count = entry_def.total_count
      @total_length = entry_def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(entry_def.total_length)
    end

    # ---

  end

  class EdgeReportEntry < AstractReportEntry

    attr_reader :total_length

    def initialize(entry_def)
      super(entry_def)

      @total_length = entry_def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(entry_def.total_length)
    end

    # ---

  end

  class AccessoryReportEntry < AstractReportEntry

    attr_reader :total_count

    def initialize(entry_def)
      super(entry_def)

      @total_count = entry_def.total_count
    end

    # ---

  end

end
