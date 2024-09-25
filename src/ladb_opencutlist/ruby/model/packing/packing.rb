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

    attr_reader :time, :number_of_bins, :number_of_different_bins, :cost, :number_of_items, :profit, :efficiency

    def initialize(_def)
      @_def = _def

      @time = _def.time
      @number_of_bins = _def.number_of_bins
      @number_of_different_bins = _def.number_of_different_bins
      @cost = _def.cost
      @profit = _def.profit
      @number_of_items = _def.number_of_items
      @profit = _def.profit
      @efficiency = _def.efficiency

    end

  end

  # -----

  class PackingBin

    include DefHelper
    include HashableHelper

    attr_reader :copies, :efficiency, :items, :cuts, :svg, :total_cut_length

    def initialize(_def)
      @_def = _def

      @type = _def.bin_type_def.type
      @length = _def.bin_type_def.length.to_l.to_s
      @width = _def.bin_type_def.width.to_l.to_s

      @copies = _def.copies
      @efficiency = _def.efficiency

      @items = _def.item_defs.map { |item_def| item_def.create_item }
      @cuts = _def.cut_defs.map { |cut_def| cut_def.create_cut }

      @svg = _def.svg
      @total_cut_length = DimensionUtils.format_to_readable_length(_def.total_cut_length)

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

end