module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'

  class Cuttingdiagram2d

    include DefHelper
    include HashableHelper

    attr_reader :errors, :warnings, :tips, :unplaced_parts, :options, :summary, :sheets

    def initialize(_def)
      @_def = _def

      @errors = _def.errors
      @warnings = _def.warnings
      @tips = _def.tips

      @unplaced_parts = _def.unplaced_part_defs.values.map { |sheet_def| sheet_def.create_listed_part }.sort_by { |part| [ part.def._sorter ] }
      @options = _def.options_def.create_options
      @summary = _def.summary_def.create_summary
      @sheets = _def.sheet_defs.values.map { |sheet_def| sheet_def.create_sheet }.sort_by { |sheet| [ -sheet.type, -sheet.efficiency, -sheet.count ] }

    end

  end

  # -----

  class Cuttingdiagram2dOptions

    include DefHelper
    include HashableHelper

    attr_reader :px_saw_kerf, :saw_kerf, :trimming, :sheet_folding, :hide_part_list, :full_width_diagram, :hide_cross, :wrap_length

    def initialize(_def)
      @_def = _def

      @px_saw_kerf = _def.px_saw_kerf
      @saw_kerf = _def.saw_kerf.to_l.to_s
      @trimming = _def.trimming.to_l.to_s
      @optimization = _def.optimization
      @stacking = _def.stacking
      @sheet_folding = _def.sheet_folding
      @hide_part_list = _def.hide_part_list
      @full_width_diagram = _def.full_width_diagram
      @hide_cross = _def.hide_cross
      @origin_corner = _def.origin_corner
      @highlight_primary_cuts = _def.highlight_primary_cuts

    end

  end

  # -----

  class Cuttingdiagram2dSummary

    include DefHelper
    include HashableHelper

    attr_reader :total_used_count, :total_used_length, :total_used_part_count, :sheets

    def initialize(_def)
      @_def = _def

      @total_used_count = _def.total_used_count
      @total_used_area = DimensionUtils.instance.format_to_readable_area(_def.total_used_area)
      @total_used_part_count = _def.total_used_part_count

      @sheets = _def.sheet_defs.values.map { |sheet_def| sheet_def.create_summary_sheet }.sort_by { |sheet| [ -sheet.type ] }

    end

  end

  # -----

  class Cuttingdiagram2dSummarySheet

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :count, :length, :width, :total_area, :total_part_count, :is_used

    def initialize(_def)
      @_def = _def

      @type_id = _def.type_id
      @type = _def.type
      @count = _def.count
      @length = _def.length.to_l.to_s
      @width = _def.width.to_l.to_s
      @total_area = DimensionUtils.instance.format_to_readable_area(_def.total_area)
      @total_part_count = _def.total_part_count
      @is_used = _def.is_used

    end

  end

  class Cuttingdiagram2dSheet

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :count, :px_length, :px_width, :length, :width, :efficiency, :total_length_cuts

    def initialize(_def)
      @_def = _def

      @type_id = _def.type_id
      @type = _def.type
      @count = _def.count
      @px_length = _def.px_length
      @px_width = _def.px_width
      @length = _def.length.to_l.to_s
      @width = _def.width.to_l.to_s
      @efficiency = _def.efficiency
      @total_length_cuts = DimensionUtils.instance.format_to_readable_length(_def.total_length_cuts)

      @parts = _def.part_defs.map { |part_def| part_def.create_part }
      @grouped_parts = _def.grouped_part_defs.values.map { |part_def| part_def.create_listed_part }.sort_by { |part| [ part.def._sorter ] }
      @cuts = _def.cut_defs.map { |cut_def| cut_def.create_cut }
      @leftovers = _def.leftover_defs.map { |cut_def| cut_def.create_leftover }

    end

  end

  # -----

  class Cuttingdiagram2dPart

    include DefHelper
    include HashableHelper

    attr_reader :id, :number, :name, :cutting_length, :cutting_width

    def initialize(_def)
      @_def = _def

      @id = _def.cutlist_part.id
      @number = _def.cutlist_part.number
      @name = _def.cutlist_part.name
      @cutting_length = _def.cutlist_part.cutting_length
      @cutting_width = _def.cutlist_part.cutting_width
      @edge_count = _def.cutlist_part.edge_count
      @edge_material_names = _def.cutlist_part.edge_material_names
      @edge_std_dimensions = _def.cutlist_part.edge_std_dimensions
      @tags = _def.cutlist_part.tags

      @px_x = _def.px_x
      @px_y = _def.px_y
      @px_length = _def.px_length
      @px_width = _def.px_width
      @rotated = _def.rotated

    end

  end

  class Cuttingdiagram2dListedPart

    include DefHelper
    include HashableHelper

    attr_reader :id, :number, :saved_number, :name, :length, :width, :cutting_length, :cutting_width, :count

    def initialize(_def)
      @_def = _def

      @id = _def.cutlist_part.id
      @number = _def.cutlist_part.number
      @saved_number = _def.cutlist_part.saved_number
      @name = _def.cutlist_part.name
      @length = _def.cutlist_part.length
      @width = _def.cutlist_part.width
      @cutting_length = _def.cutlist_part.cutting_length
      @cutting_width = _def.cutlist_part.cutting_width
      @edge_count = _def.cutlist_part.edge_count
      @edge_pattern = _def.cutlist_part.edge_pattern
      @edge_decrements = _def.cutlist_part.edge_decrements

      @count = _def.count

    end

  end

  # -----

  class Cuttingdiagram2dLeftover

    include DefHelper
    include HashableHelper

    attr_reader :x, :length

    def initialize(_def)
      @_def = _def

      @px_x = _def.px_x
      @px_y = _def.px_y
      @px_length = _def.px_length
      @px_width = _def.px_width
      @length = _def.length.to_l.to_s
      @width = _def.width.to_l.to_s

    end

  end

  # -----

  class Cuttingdiagram2dCut

    include DefHelper
    include HashableHelper

    attr_reader :px_x, :px_y, :px_length, :x, :y, :is_horizontal, :is_through, :is_final

    def initialize(_def)
      @_def = _def

      @px_x = _def.px_x
      @px_y = _def.px_y
      @px_length = _def.px_length
      @x = _def.x.to_l.to_s
      @y = _def.y.to_l.to_s
      @is_horizontal = _def.is_horizontal
      @is_through = _def.is_through
      @is_final = _def.is_final

    end

  end

end
