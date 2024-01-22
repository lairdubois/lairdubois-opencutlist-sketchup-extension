module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../helper/pixel_converter_helper'

  class Cuttingdiagram1d

    include DefHelper
    include HashableHelper
    include PixelConverterHelper

    attr_reader :errors, :warnings, :tips, :unplaced_parts, :options, :summary, :bars, :projections

    def initialize(_def)
      @_def = _def

      @errors = _def.errors
      @warnings = _def.warnings
      @tips = _def.tips

      @unplaced_parts = _def.unplaced_part_defs.values.map { |bar_def| bar_def.create_listed_part }.sort_by { |part| [ part.def._sorter ] }
      @options = _def.options_def.create_options
      @summary = _def.summary_def.create_summary
      @bars = _def.bar_defs.values.map { |bar_def| bar_def.create_bar }.sort_by { |bar| [ -bar.type, -bar.efficiency, -bar.count ] }

      @projections = _def.projection_defs.map { |part_id, projection_def| [ part_id, projection_def.layer_defs.map { |layer_def| { :depth => layer_def.depth, :path => "#{layer_def.poly_defs.map { |poly_def| "M #{poly_def.points.map { |point| "#{_to_px(point.x).round(2)},#{-_to_px(point.y.round(2))}" }.join(' L ')} Z" }.join(' ')}" } } ] }.to_h

    end

  end

  # -----

  class Cuttingdiagram1dOptions

    include DefHelper
    include HashableHelper

    attr_reader :px_saw_kerf, :saw_kerf, :trimming, :bar_folding, :hide_part_list, :part_drawing_type, :use_names, :full_width_diagram, :hide_cross, :origin_corner, :wrap_length

    def initialize(_def)
      @_def = _def

      @px_saw_kerf = _def.px_saw_kerf
      @saw_kerf = _def.saw_kerf.to_l.to_s
      @trimming = _def.trimming.to_l.to_s
      @bar_folding = _def.bar_folding
      @hide_part_list = _def.hide_part_list
      @part_drawing_type = _def.part_drawing_type
      @use_names = _def.use_names
      @full_width_diagram = _def.full_width_diagram
      @hide_cross = _def.hide_cross
      @origin_corner = _def.origin_corner
      @wrap_length = _def.wrap_length

    end

  end

  # -----

  class Cuttingdiagram1dSummary

    include DefHelper
    include HashableHelper

    attr_reader :total_used_count, :total_used_length, :total_used_part_count, :total_cut_count, :total_cut_length, :overall_efficiency, :bars

    def initialize(_def)
      @_def = _def

      @total_used_count = _def.total_used_count
      @total_used_length = DimensionUtils.instance.format_to_readable_length(_def.total_used_length)
      @total_used_part_count = _def.total_used_part_count

      @total_cut_count = _def.total_cut_count
      @total_cut_length = DimensionUtils.instance.format_to_readable_length(_def.total_cut_length)

      @overall_efficiency = _def.overall_efficiency

      @bars = _def.bar_defs.values.map { |bar_def| bar_def.create_summary_bar }.sort_by { |bar| [ -bar.type ] }

    end

  end

  # -----

  class Cuttingdiagram1dSummaryBar

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :count, :length, :total_length, :total_part_count, :is_used

    def initialize(_def)
      @_def = _def

      @type_id = _def.type_id
      @type = _def.type
      @count = _def.count
      @length = DimensionUtils.instance.format_to_readable_length(_def.length)
      @total_length = DimensionUtils.instance.format_to_readable_length(_def.total_length)
      @total_part_count = _def.total_part_count
      @is_used = _def.is_used

    end

  end

  class Cuttingdiagram1dBar

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :count, :px_length, :px_width, :length, :width, :efficiency, :total_cut_length, :slices, :parts, :grouped_parts, :cuts, :leftover

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

      @slices = _def.slice_defs.map { |slice_def| slice_def.create_slice }
      @parts = _def.part_defs.map { |part_def| part_def.create_part }
      @grouped_parts = _def.grouped_part_defs.values.map { |part_def| part_def.create_listed_part }.sort_by { |part| [ part.def._sorter ] }
      @cuts = _def.cut_defs.map { |cut_def| cut_def.create_cut }

      @leftover = _def.leftover_def.create_leftover

    end

  end

  # -----

  class Cuttingdiagram1dSlice

    include DefHelper
    include HashableHelper

    attr_reader :index, :px_x, :px_length

    def initialize(_def)
      @_def = _def

      @index = _def.index
      @px_x = _def.px_x
      @px_length = _def.px_length

    end

  end

  # -----

  class Cuttingdiagram1dPart

    include DefHelper
    include HashableHelper

    attr_reader :id, :number, :saved_number, :name, :cutting_length, :px_x, :px_x_offset, :px_length, :slices

    def initialize(_def)
      @_def = _def

      @id = _def.cutlist_part.id
      @number = _def.cutlist_part.number
      @name = _def.cutlist_part.name
      @cutting_length = _def.cutlist_part.cutting_length

      @px_x = _def.px_x
      @px_x_offset = _def.px_x_offset
      @px_length = _def.px_length

      @slices = _def.slice_defs.map { |slide_def| slide_def.create_slice }

    end

  end

  class Cuttingdiagram1dListedPart

    include DefHelper
    include HashableHelper

    attr_reader :id, :number, :saved_number, :name, :description, :length, :cutting_length, :length_increase, :length_increased, :count, :tags

    def initialize(_def)
      @_def = _def

      @id = _def.cutlist_part.id
      @number = _def.cutlist_part.number
      @saved_number = _def.cutlist_part.saved_number
      @name = _def.cutlist_part.name
      @description = _def.cutlist_part.description
      @length = _def.cutlist_part.length
      @cutting_length = _def.cutlist_part.cutting_length
      @length_increase = _def.cutlist_part.length_increase
      @length_increased = _def.cutlist_part.length_increased
      @count = _def.count
      @tags = _def.cutlist_part.tags
      @flipped = _def.cutlist_part.flipped

    end

  end

  # -----

  class Cuttingdiagram1dLeftover

    include DefHelper
    include HashableHelper

    attr_reader :px_x, :px_length, :length, :slices

    def initialize(_def)
      @_def = _def

      @px_x = _def.px_x
      @px_length = _def.px_length
      @length = _def.length.to_l.to_s

      @slices = _def.slice_defs.map { |slide_def| slide_def.create_slice }

    end

  end

  # -----

  class Cuttingdiagram1dCut

    include DefHelper
    include HashableHelper

    attr_reader :px_x, :x, :slices

    def initialize(_def)
      @_def = _def

      @px_x = _def.px_x
      @x = _def.x

      @slices = _def.slice_defs.map { |slide_def| slide_def.create_slice }

    end

  end

end
