module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/price_utils'
  require_relative '../../utils/unit_utils'

  class Packing

    include DefHelper
    include HashableHelper

    attr_reader :errors, :running, :cancelled, :solution

    def initialize(_def)
      @_def = _def

      @errors = _def.errors

      @running = _def.running
      @cancelled = _def.cancelled

      @solution = _def.solution_def.create_solution if _def.solution_def.is_a?(PackingSolutionDef)

    end

  end

  # -----

  class PackingSolution

    include DefHelper
    include HashableHelper

    attr_reader :options, :summary, :bins, :unplaced_parts

    def initialize(_def)
      @_def = _def

      @options = _def.options_def.create_options
      @summary = _def.summary_def.create_summary

      @bins = _def.bin_defs.map { |bin_def| bin_def.create_bin }

      @unplaced_part_infos = _def.unplaced_part_info_defs.map { |part_info_def| part_info_def.create_part_info }

    end

  end

  # -----

  class PackingOptions

    include DefHelper
    include HashableHelper

    attr_reader :problem_type, :spacing, :trimming, :hide_part_list, :part_drawing_type, :colored_part, :origin_corner

    def initialize(_def)
      @_def = _def

      @problem_type = _def.problem_type

      @spacing = _def.spacing.to_l.to_s
      @trimming = _def.trimming.to_l.to_s

      @hide_part_list = _def.hide_part_list
      @part_drawing_type = _def.part_drawing_type
      @colored_part = _def.colored_part
      @origin_corner = _def.origin_corner

    end

  end

  # -----

  class PackingSummary

    include DefHelper
    include HashableHelper

    attr_reader :time, :total_bin_count, :total_item_count, :total_efficiency, :total_leftover_count, :total_cut_count, :total_cut_length, :total_used_area, :total_used_area, :total_used_length, :total_used_cost, :total_used_item_count, :bin_types

    def initialize(_def)
      @_def = _def

      @time = _def.time
      @total_bin_count = _def.total_bin_count
      @total_item_count = _def.total_item_count
      @total_efficiency = _def.total_efficiency

      @total_leftover_count = _def.total_leftover_count
      @total_cut_count = _def.total_cut_count
      @total_cut_length = _def.total_cut_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_cut_length) : nil

      @total_used_count = _def.total_used_count
      @total_used_area = _def.total_used_area > 0 ? DimensionUtils.format_to_readable_area(_def.total_used_area) : nil
      @total_used_length = _def.total_used_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_used_length) : nil
      @total_used_cost = _def.total_used_cost > 0 ? PriceUtils.format_to_readable_price(_def.total_used_cost) : nil
      @total_used_item_count = _def.total_used_item_count

      @bin_types = _def.bin_type_defs.map { |bin_type_def| bin_type_def.create_summary_bin_type }

    end

  end

  # -----

  class PackingSummaryBinType

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :count, :length, :width, :used, :std_price, :total_area, :total_length, :total_item_count

    def initialize(_def)
      @_def = _def

      @type_id = _def.bin_type_def.id
      @type = _def.bin_type_def.type
      @count = _def.count > 0 ? _def.count : nil
      @length = _def.bin_type_def.length.to_l.to_s
      @width = _def.bin_type_def.width.to_l.to_s
      @used = _def.used

      @std_price = _def.std_price.nil? || _def.std_price[:val] == 0 ? nil : UnitUtils.format_readable(_def.std_price[:val], _def.std_price[:unit], 2, 2)

      @total_area = _def.total_area > 0 ? DimensionUtils.format_to_readable_area(_def.total_area) : nil
      @total_length = _def.total_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_length) : nil
      @total_cost = _def.total_cost > 0 ? PriceUtils.format_to_readable_price(_def.total_cost) : nil
      @total_item_count = _def.total_item_count

    end

  end

  # -----

  class PackingBin

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :length, :width, :count, :efficiency, :items, :leftovers, :cuts, :part_infos, :total_cut_length, :svg

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

      @total_cut_length = _def.total_cut_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_cut_length) : nil

      @svg = _def.svg

    end

  end


  # -----

  class Packingtem

    include DefHelper
    include HashableHelper

    attr_reader :x, :y, :angle, :mirror

    def initialize(_def)
      @_def = _def

      @x = _def.x.to_s
      @y = _def.y.to_s
      @angle = _def.angle
      @mirror = _def.mirror

    end

  end

  # -----

  class PackingLeftover

    include DefHelper
    include HashableHelper

    attr_reader :x, :y, :length, :width

    def initialize(_def)
      @_def = _def

      @x = _def.x.to_s
      @y = _def.y.to_s
      @length = _def.length
      @width = _def.width

    end

  end

  # -----

  class PackingCut

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

  class PackingPartInfo

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