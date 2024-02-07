module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../helper/pixel_converter_helper'

  class Cuttingdiagram2d

    include DefHelper
    include HashableHelper
    include PixelConverterHelper

    attr_reader :errors, :warnings, :tips, :unplaced_parts, :options, :summary, :sheets, :to_keep_leftovers, :projections

    def initialize(_def)
      @_def = _def

      @errors = _def.errors
      @warnings = _def.warnings
      @tips = _def.tips

      @unplaced_parts = _def.unplaced_part_defs.values.map { |part_def| part_def.create_listed_part }.sort_by { |part| [ part.def._sorter ] }
      @options = _def.options_def.create_options
      @summary = _def.summary_def.create_summary
      @sheets = _def.sheet_defs.values.map { |sheet_def| sheet_def.create_sheet }.sort_by { |sheet| [ -sheet.type, -sheet.efficiency, -sheet.count ] }
      @to_keep_leftovers = _def.to_keep_leftover_defs.values.map { |leftover_def| leftover_def.create_listed_leftover }.sort_by { |leftover| [ -leftover.def.area, -leftover.def.length ] }

      @projections = _def.projection_defs.map { |part_id, projection_def| [ part_id, projection_def.layer_defs.map { |layer_def| { :depth => layer_def.depth, :path => "#{layer_def.poly_defs.map { |poly_def| "M #{poly_def.points.map { |point| "#{_to_px(point.x).round(2)},#{-_to_px(point.y).round(2)}" }.join(' L ')} Z" }.join(' ')}" } } ] }.to_h
      
    end

  end

  # -----

  class Cuttingdiagram2dOptions

    include DefHelper
    include HashableHelper

    attr_reader :px_saw_kerf, :saw_kerf, :trimming, :optimization, :stacking, :keep_length, :keep_width, :sheet_folding, :hide_part_list, :part_drawing_type, :use_names, :full_width_diagram, :hide_cross, :origin_corner, :highlight_primary_cuts, :hide_edges_preview

    def initialize(_def)
      @_def = _def

      @px_saw_kerf = _def.px_saw_kerf
      @saw_kerf = _def.saw_kerf.to_l.to_s
      @trimming = _def.trimming.to_l.to_s
      @optimization = _def.optimization
      @stacking = _def.stacking
      @keep_length = _def.keep_length.to_l.to_s
      @keep_width = _def.keep_width.to_l.to_s
      @sheet_folding = _def.sheet_folding
      @hide_part_list = _def.hide_part_list
      @part_drawing_type = _def.part_drawing_type
      @use_names = _def.use_names
      @full_width_diagram = _def.full_width_diagram
      @hide_cross = _def.hide_cross
      @origin_corner = _def.origin_corner
      @highlight_primary_cuts = _def.highlight_primary_cuts
      @hide_edges_preview = _def.hide_edges_preview

    end

  end

  # -----

  class Cuttingdiagram2dSummary

    include DefHelper
    include HashableHelper

    attr_reader :total_used_count, :total_used_length, :total_used_part_count, :total_cut_count, :total_cut_length, :overall_efficiency, :sheets

    def initialize(_def)
      @_def = _def

      @total_used_count = _def.total_used_count
      @total_used_area = DimensionUtils.instance.format_to_readable_area(_def.total_used_area)
      @total_used_part_count = _def.total_used_part_count

      @total_cut_count = _def.total_cut_count
      @total_cut_length = DimensionUtils.instance.format_to_readable_length(_def.total_cut_length)

      @overall_efficiency = _def.overall_efficiency

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

    attr_reader :type_id, :type, :count, :px_length, :px_width, :length, :width, :efficiency, :total_cut_length, :parts, :grouped_parts, :cuts, :leftovers

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
      @total_cut_length = DimensionUtils.instance.format_to_readable_length(_def.total_cut_length)

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

    attr_reader :id, :number, :name, :cutting_length, :cutting_width, :edge_count, :edge_material_names, :edge_material_colors, :edge_std_dimensions, :face_count, :face_material_names, :face_material_colors, :face_std_dimensions, :px_x, :px_y, :px_x_offset, :px_y_offset, :px_length, :px_width, :rotated

    def initialize(_def)
      @_def = _def

      @id = _def.cutlist_part.id
      @number = _def.cutlist_part.number
      @name = _def.cutlist_part.name
      @cutting_length = _def.cutlist_part.cutting_length
      @cutting_width = _def.cutlist_part.cutting_width
      @edge_count = _def.cutlist_part.edge_count
      @edge_material_names = _def.cutlist_part.edge_material_names
      @edge_material_colors = _def.cutlist_part.edge_material_colors
      @edge_std_dimensions = _def.cutlist_part.edge_std_dimensions
      @face_count = _def.cutlist_part.face_count
      @face_material_names = _def.cutlist_part.face_material_names
      @face_material_colors = _def.cutlist_part.face_material_colors
      @face_std_dimensions = _def.cutlist_part.face_std_dimensions

      @px_x = _def.px_x
      @px_y = _def.px_y
      @px_x_offset = _def.px_x_offset
      @px_y_offset = _def.px_y_offset
      @px_length = _def.px_length
      @px_width = _def.px_width
      @rotated = _def.rotated

    end

  end

  class Cuttingdiagram2dListedPart

    include DefHelper
    include HashableHelper

    attr_reader :id, :number, :saved_number, :name, :description, :length, :width, :cutting_length, :cutting_width, :edge_cutting_length, :edge_cutting_width, :length_increase, :width_increase, :length_increased, :width_increased, :count, :tags, :flipped, :thickness_layer_count, :edge_count, :edge_pattern, :edge_material_names, :edge_material_colors, :edge_std_dimensions, :edge_decrements, :edge_entity_ids, :face_count, :face_pattern, :face_material_names, :face_material_colors, :face_std_dimensions, :face_decrements, :face_entity_ids

    def initialize(_def)
      @_def = _def

      @id = _def.cutlist_part.id
      @number = _def.cutlist_part.number
      @saved_number = _def.cutlist_part.saved_number
      @name = _def.cutlist_part.name
      @description = _def.cutlist_part.description
      @length = _def.cutlist_part.length
      @width = _def.cutlist_part.width
      @cutting_length = _def.cutlist_part.cutting_length
      @cutting_width = _def.cutlist_part.cutting_width
      @edge_cutting_length = _def.cutlist_part.edge_cutting_length
      @edge_cutting_width = _def.cutlist_part.edge_cutting_width
      @length_increase = _def.cutlist_part.length_increase
      @width_increase = _def.cutlist_part.width_increase
      @length_increased = _def.cutlist_part.length_increased
      @width_increased = _def.cutlist_part.width_increased
      @count = _def.count
      @tags = _def.cutlist_part.tags
      @flipped = _def.cutlist_part.flipped
      @thickness_layer_count = _def.cutlist_part.thickness_layer_count
      @edge_count = _def.cutlist_part.edge_count
      @edge_pattern = _def.cutlist_part.edge_pattern
      @edge_material_names = _def.cutlist_part.edge_material_names
      @edge_material_colors = _def.cutlist_part.edge_material_colors
      @edge_std_dimensions = _def.cutlist_part.edge_std_dimensions
      @edge_decrements = _def.cutlist_part.edge_decrements
      @edge_entity_ids = _def.cutlist_part.edge_entity_ids
      @face_count = _def.cutlist_part.face_count
      @face_pattern = _def.cutlist_part.face_pattern
      @face_material_names = _def.cutlist_part.face_material_names
      @face_material_colors = _def.cutlist_part.face_material_colors
      @face_std_dimensions = _def.cutlist_part.face_std_dimensions
      @face_decrements = _def.cutlist_part.face_decrements
      @face_entity_ids = _def.cutlist_part.face_entity_ids

    end

  end

  # -----

  class Cuttingdiagram2dLeftover

    include DefHelper
    include HashableHelper

    attr_reader :px_x, :px_y, :px_length, :px_width, :length, :width, :to_keep

    def initialize(_def)
      @_def = _def

      @px_x = _def.px_x
      @px_y = _def.px_y
      @px_length = _def.px_length
      @px_width = _def.px_width
      @length = _def.length.to_l.to_s
      @width = _def.width.to_l.to_s
      @to_keep = _def.to_keep

    end

  end

  # -----

  class Cuttingdiagram2dListedLeftover

    include DefHelper
    include HashableHelper

    attr_reader :length, :width, :area, :count

    def initialize(_def)
      @_def = _def

      @length = _def.length.to_l.to_s
      @width = _def.width.to_l.to_s
      @area = DimensionUtils.instance.format_to_readable_area(_def.area)

      @count = _def.count * _def.sheet_def.count

    end

  end

  # -----

  class Cuttingdiagram2dCut

    include DefHelper
    include HashableHelper

    attr_reader :px_x, :px_y, :px_length, :x, :y, :is_horizontal, :is_internal_through, :is_trimming, :is_bounding

    def initialize(_def)
      @_def = _def

      @px_x = _def.px_x
      @px_y = _def.px_y
      @px_length = _def.px_length
      @x = _def.x.to_l.to_s
      @y = _def.y.to_l.to_s
      @is_horizontal = _def.is_horizontal
      @is_internal_through = _def.is_internal_through
      @is_trimming = _def.is_trimming
      @is_bounding = _def.is_bounding

    end

  end

end
