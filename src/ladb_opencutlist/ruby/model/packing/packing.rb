module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'

  class Packing

    include DefHelper
    include HashableHelper

    attr_reader :options, :summary, :bins

    def initialize(_def)
      @_def = _def

      @options = _def.options_def.create_options
      @summary = _def.summary_def.create_summary

      @bins = _def.bin_defs.map { |bin_def| bin_def.create_bin }

    end

  end

  # -----

  class PackingOptions

    include DefHelper
    include HashableHelper

    attr_reader :problem_type, :spacing, :trimming

    def initialize(_def)
      @_def = _def

      @problem_type = _def.problem_type

      @spacing = _def.spacing.to_l.to_s
      @trimming = _def.trimming.to_l.to_s

    end

  end

  # -----

  class PackingSummary

    include DefHelper
    include HashableHelper

    attr_reader :time, :total_bin_count, :total_item_count, :total_efficiency, :total_cut_count, :total_cut_length, :total_used_area, :total_used_area, :total_used_length, :total_used_item_count, :bin_types

    def initialize(_def)
      @_def = _def

      @time = _def.time
      @total_bin_count = _def.total_bin_count
      @total_item_count = _def.total_item_count
      @total_efficiency = _def.total_efficiency

      @total_cut_count = _def.total_cut_count
      @total_cut_length = _def.total_cut_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_cut_length) : nil

      @total_used_count = _def.total_used_count
      @total_used_area = _def.total_used_area > 0 ? DimensionUtils.format_to_readable_area(_def.total_used_area) : nil
      @total_used_length = _def.total_used_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_used_length) : nil
      @total_used_item_count = _def.total_used_item_count

      @bin_types = _def.bin_type_defs.map { |bin_type_def| bin_type_def.create_summary_bin_type }

    end

  end

  # -----

  class PackingSummaryBinType

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :count, :length, :width, :used, :total_area, :total_length, :total_item_count

    def initialize(_def)
      @_def = _def

      @type_id = _def.bin_type_def.id
      @type = _def.bin_type_def.type
      @count = _def.count
      @length = _def.bin_type_def.length.to_l.to_s
      @width = _def.bin_type_def.width.to_l.to_s
      @used = _def.used

      @total_area = _def.total_area > 0 ? DimensionUtils.format_to_readable_area(_def.total_area) : nil
      @total_length = _def.total_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_length) : nil
      @total_item_count = _def.total_item_count

    end

  end

  # -----

  class PackingBin

    include DefHelper
    include HashableHelper

    attr_reader :type_id, :type, :length, :width, :count, :efficiency, :items, :cuts, :parts, :svg, :total_cut_length

    def initialize(_def)
      @_def = _def

      @type_id = _def.bin_type_def.id
      @type = _def.bin_type_def.type
      @length = _def.bin_type_def.length.to_l.to_s
      @width = _def.bin_type_def.width.to_l.to_s

      @count = _def.count
      @efficiency = _def.efficiency

      @items = _def.item_defs.map { |item_def| item_def.create_item }
      @cuts = _def.cut_defs.map { |cut_def| cut_def.create_cut }
      @parts = _def.part_defs.map { |part_def| part_def.create_bin_part }

      @svg = _def.svg
      @total_cut_length = _def.total_cut_length > 0 ? DimensionUtils.format_to_readable_length(_def.total_cut_length) : nil

    end

  end


  # -----

  class PackingItem

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

  class PackingBinPart

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