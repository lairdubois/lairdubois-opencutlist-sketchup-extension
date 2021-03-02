module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class AbstractReportItem

    include HashableHelper

    attr_reader :total_mass, :total_cost

    def initialize(_def)
      @_def = _def

      @total_mass = _def.total_mass
      @total_cost = _def.total_cost

    end

  end

  class AbstractReportEntry < AbstractReportItem

    attr_reader :material_name, :material_display_name, :material_color, :material_type, :std_available, :std_dimension_stipped_name, :std_dimension, :std_thickness

    def initialize(_def)
      super(_def)

      @material_name = _def.cutlist_group.material_name
      @material_display_name = _def.cutlist_group.material_display_name
      @material_color = _def.cutlist_group.material_color
      @material_type = _def.cutlist_group.material_type
      @std_available = _def.cutlist_group.std_available
      @std_dimension_stipped_name = _def.cutlist_group.std_dimension_stipped_name
      @std_dimension = _def.cutlist_group.std_dimension
      @std_thickness = _def.cutlist_group.std_thickness

    end

  end

  # -----

  class SolidWoodReportEntry < AbstractReportEntry

    attr_reader :total_volume

    def initialize(_def)
      super(_def)

      @total_volume = _def.total_volume == 0 ? nil : DimensionUtils.instance.format_to_readable_volume(_def.total_volume, @material_type)

    end

  end

  # -----

  class SheetGoodReportEntry < AbstractReportEntry

    attr_reader :total_count, :total_area, :sheets

    def initialize(_def)
      super(_def)

      @total_count = _def.total_count
      @total_area = _def.total_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(_def.total_area)

      @sheets = _def.sheet_defs.map { |sheet_def| sheet_def.create_sheet }

    end

  end

  class SheetGoodReportEntrySheet < AbstractReportItem

    attr_reader :type, :length, :width, :count, :total_area

    def initialize(_def)
      super(_def)

      @type = _def.cuttingdiagram2d_summary_sheet.type
      @length = _def.cuttingdiagram2d_summary_sheet.length
      @width = _def.cuttingdiagram2d_summary_sheet.width
      @count = _def.cuttingdiagram2d_summary_sheet.count
      @total_area = _def.cuttingdiagram2d_summary_sheet.total_area

    end

  end

  # -----

  class DimensionalReportEntry < AbstractReportEntry

    attr_reader :total_count, :total_length, :bars

    def initialize(_def)
      super(_def)

      @total_count = _def.total_count
      @total_length = _def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_length)

      @bars = _def.bar_defs.map { |bar_def| bar_def.create_bar }

    end

  end

  class DimensionalReportEntryBar < AbstractReportItem

    attr_reader :type, :length, :count, :total_length

    def initialize(_def)
      super(_def)

      @type = _def.cuttingdiagram1d_summary_bar.type
      @length = _def.cuttingdiagram1d_summary_bar.length
      @count = _def.cuttingdiagram1d_summary_bar.count
      @total_length = _def.cuttingdiagram1d_summary_bar.total_length

    end

  end

  # -----

  class EdgeReportEntry < AbstractReportEntry

    attr_reader :total_length

    def initialize(_def)
      super(_def)

      @total_length = _def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_length)

    end

  end

  # -----

  class AccessoryReportEntry < AbstractReportEntry

    attr_reader :total_count

    def initialize(_def)
      super(_def)

      @total_count = _def.total_count

      @parts = _def.part_defs.map { |part_def| part_def.create_part }

    end

  end

  class AccessoryReportEntryPart < AbstractReportItem

    attr_reader :name, :count

    def initialize(_def)
      super(_def)

      @name = _def.cutlist_part.name
      @count = _def.cutlist_part.count

    end

  end

end
