module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/price_utils'
  require_relative '../../utils/unit_utils'

  class Packing < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :errors, :warnings,
                :running, :cancelled,
                :solution

    def initialize(_def)
      @_def = _def

      @errors = _def.errors
      @warnings = _def.warnings

      @running = _def.running
      @cancelled = _def.cancelled

      @solution = _def.solution_def.create_solution if _def.solution_def.is_a?(PackingSolutionDef)

    end

  end

  # -----

  class PackingSolution < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :options, :summary,
                :bins,
                :unplaced_part_infos

    def initialize(_def)
      @_def = _def

      @options = _def.options_def.create_options
      @summary = _def.summary_def.create_summary

      @bins = _def.bin_defs.map { |bin_def| bin_def.create_bin }

      @unplaced_part_infos = _def.unplaced_part_info_defs.map { |part_info_def| part_info_def.create_part_info }

    end

  end

  # -----

  class PackingOptions < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :problem_type,
                :spacing, :trimming,
                :items_formula, :hide_part_list, :part_drawing_type, :colorization, :origin_corner, :highlight_primary_cuts, :hide_edges_preview,
                :rectangleguillotine_cut_type, :rectangleguillotine_first_stage_orientation, :rectangleguillotine_number_of_stages, :rectangleguillotine_keep_length, :rectangleguillotine_keep_width,
                :irregular_allowed_rotations, :irregular_allow_mirroring

    def initialize(_def)
      @_def = _def

      @problem_type = _def.problem_type

      @spacing = DimensionUtils.str_add_units(_def.spacing.to_l.to_s)
      @trimming = DimensionUtils.str_add_units(_def.trimming.to_l.to_s)

      @items_formula = _def.items_formula
      @hide_part_list = _def.hide_part_list
      @part_drawing_type = _def.part_drawing_type
      @colorization = _def.colorization
      @origin_corner = _def.origin_corner
      @highlight_primary_cuts = _def.highlight_primary_cuts
      @hide_edges_preview = _def.hide_edges_preview

      @rectangleguillotine_cut_type = _def.rectangleguillotine_cut_type
      @rectangleguillotine_first_stage_orientation = _def.rectangleguillotine_first_stage_orientation
      @rectangleguillotine_number_of_stages = _def.rectangleguillotine_number_of_stages
      @rectangleguillotine_keep_length = _def.rectangleguillotine_keep_length.nil? ? nil : _def.rectangleguillotine_keep_length.to_l.to_s
      @rectangleguillotine_keep_width = _def.rectangleguillotine_keep_width.nil? ? nil : _def.rectangleguillotine_keep_width.to_l.to_s

      @irregular_allowed_rotations = _def.irregular_allowed_rotations
      @irregular_allow_mirroring = _def.irregular_allow_mirroring

    end

  end

  # -----

  class PackingSummary < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :time, :number_of_bins, :number_of_items, :efficiency,
                :number_of_leftovers, :number_of_leftovers_to_keep, :number_of_cuts,
                :cut_length, :cut_cost,
                :total_used_area, :total_used_area, :total_used_length, :total_used_cost, :total_used_item_count, :total_unused_item_count,
                :bin_type_stats

    def initialize(_def)
      @_def = _def

      @time = _def.time
      @number_of_bins = _def.number_of_bins
      @number_of_items = _def.number_of_items
      @efficiency = _def.efficiency

      @number_of_leftovers = _def.number_of_leftovers
      @number_of_leftovers_to_keep = _def.number_of_leftovers_to_keep
      @number_of_cuts = _def.number_of_cuts

      @cut_length = _def.cut_length > 0 ? DimensionUtils.format_to_readable_length(_def.cut_length) : nil
      @cut_cost = _def.cut_cost > 0 ? PriceUtils.format_to_readable_price(_def.cut_cost) : nil

      @total_used_count = _def.total_used_count
      @total_used_area = _def.total_used_area > 0 ? DimensionUtils.format_to_readable_area(_def.total_used_area) : nil
      @total_used_length = _def.total_used_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_used_length) : nil
      @total_used_cost = _def.total_used_cost > 0 ? PriceUtils.format_to_readable_price(_def.total_used_cost) : nil
      @total_used_item_count = _def.total_used_item_count
      @total_unused_item_count = _def.total_unused_item_count

      @bin_type_stats = _def.bin_type_stats_defs.map { |bin_type_stats_def| bin_type_stats_def.create_summary_bin_type_stats }

    end

  end

  # -----

  class PackingSummaryBinTypeStats < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :count, :length, :width, :used,
                :number_of_items,
                :std_price,
                :total_area, :total_length

    def initialize(_def)
      @_def = _def

      @type_id = _def.bin_type_def.id
      @type = _def.bin_type_def.type
      @count = _def.count > 0 ? _def.count : nil
      @length = _def.bin_type_def.length.to_l.to_s
      @width = _def.bin_type_def.width.to_l.to_s
      @used = _def.used

      @number_of_items = _def.number_of_items

      @std_price = _def.std_price.nil? || _def.std_price[:val] == 0 ? nil : UnitUtils.format_readable(_def.std_price[:val], _def.std_price[:unit], 2, 2)

      @total_area = _def.total_area > 0 ? DimensionUtils.format_to_readable_area(_def.total_area) : nil
      @total_length = _def.total_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_length) : nil
      @total_cost = _def.total_cost > 0 ? PriceUtils.format_to_readable_price(_def.total_cost) : nil

    end

  end

  # -----

  class PackingBin < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :length, :width,
                :count, :efficiency,
                :items, :leftovers, :cuts, :part_infos,
                :number_of_items, :number_of_leftovers, :number_of_leftovers_to_keep, :number_of_cuts,
                :cut_length, :cut_cost,
                :x_min, :x_max, :y_min, :y_max,
                :svg, :light_svg

    def initialize(_def)
      @_def = _def

      @type_id = _def.bin_type_def.id
      @type = _def.bin_type_def.type
      @length = _def.bin_type_def.length.to_l.to_s
      @width = _def.bin_type_def.width.to_l.to_s

      @count = _def.count
      @efficiency = _def.efficiency

      @items = _def.item_defs.map { |item_def| item_def.create_item }
      @leftovers = _def.leftover_defs.map { |leftover_def| leftover_def.create_leftover }
      @cuts = _def.cut_defs.map { |cut_def| cut_def.create_cut }
      @part_infos = _def.part_info_defs.map { |part_info_def| part_info_def.create_part_info }

      @number_of_items = _def.number_of_items
      @number_of_leftovers = _def.number_of_leftovers
      @number_of_leftovers_to_keep = _def.number_of_leftovers_to_keep
      @number_of_cuts = _def.number_of_cuts

      @cut_length = _def.cut_length > 0 ? DimensionUtils.format_to_readable_length(_def.cut_length) : nil
      @cut_cost = _def.cut_cost > 0 ? PriceUtils.format_to_readable_price(_def.cut_cost) : nil

      @x_min = _def.x_min> 0 ? DimensionUtils.format_to_readable_length(_def.x_min) : nil
      @x_max = _def.x_max> 0 ? DimensionUtils.format_to_readable_length(_def.x_max) : nil
      @y_min = _def.y_min > 0 ? DimensionUtils.format_to_readable_length(_def.y_min) : nil
      @y_max = _def.y_max > 0 ? DimensionUtils.format_to_readable_length(_def.y_max) : nil

      @svg = _def.svg
      @light_svg = _def.light_svg

    end

  end


  # -----

  class Packingtem < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :x, :y, :angle, :mirror,
                :label_offset

    def initialize(_def)
      @_def = _def

      @x = _def.x.to_s
      @y = _def.y.to_s
      @angle = _def.angle
      @mirror = _def.mirror

      @label_offset = _def.label_offset

    end

  end

  # -----

  class PackingLeftover < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :x, :y, :length, :width,
                :kept

    def initialize(_def)
      @_def = _def

      @x = _def.x.to_s
      @y = _def.y.to_s
      @length = _def.length
      @width = _def.width

      @kept = _def.kept

    end

  end

  # -----

  class PackingCut < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :depth, :x, :y, :length, :orientation

    def initialize(_def)
      @_def = _def

      @depth = _def.depth
      @x = _def.x.to_s
      @y = _def.y.to_s
      @length = _def.length
      @orientation = _def.orientation

    end

  end

  # -----

  class PackingPartInfo < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :part, :count

    def initialize(_def)
      @_def = _def

      @part = _def.part
      @count = _def.count

    end

  end

end