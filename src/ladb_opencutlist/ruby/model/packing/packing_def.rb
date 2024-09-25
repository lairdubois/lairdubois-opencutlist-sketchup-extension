module Ladb::OpenCutList

  require_relative 'packing'

  class PackingDef

    attr_accessor :options_def, :summary_def, :bin_defs

    def initialize(options_def, summary_def, bin_defs)

      @options_def = options_def
      @summary_def = summary_def

      @bin_defs = bin_defs

    end

    # ---

    def create_packing
      Packing.new(self)
    end

  end

  # -----

  class PackingOptionsDef

    attr_reader :problem_type, :spacing, :trimming

    def initialize(problem_type, spacing, trimming)

      @problem_type = problem_type

      @spacing = spacing
      @trimming = trimming

    end

    # ---

    def create_options
      PackingOptions.new(self)
    end

  end

  # -----

  class PackingSummaryDef

    attr_reader :time, :number_of_bins, :number_of_different_bins, :cost, :number_of_items, :profit, :efficiency
    attr_accessor :total_cut_length

    def initialize(time, number_of_bins, number_of_different_bins, cost, number_of_items, profit, efficiency)

      @time = time
      @number_of_bins = number_of_bins
      @number_of_different_bins = number_of_different_bins
      @cost = cost
      @number_of_items = number_of_items
      @profit = profit
      @efficiency = efficiency

      # Computed

      @total_cut_length = 0

    end

    # ---

    def create_summary
      PackingSummary.new(self)
    end

  end

  # -----

  class PackingBinDef

    attr_reader :bin_type_def, :copies, :efficiency, :item_defs, :cut_defs
    attr_accessor :svg, :total_cut_length

    def initialize(bin_type_def, copies, efficiency, item_defs, cut_defs)

      @bin_type_def = bin_type_def

      @copies = copies
      @efficiency = efficiency

      @item_defs = item_defs
      @cut_defs = cut_defs

      # Computed

      @svg = ''

      @total_cut_length = 0

    end

    # ---

    def create_bin
      PackingBin.new(self)
    end

  end

  # -----

  class PackingItemDef

    attr_reader :item_type_def, :x, :y, :angle, :mirror

    def initialize(item_type_def, x, y, angle, mirror)

      @item_type_def = item_type_def

      @x = x
      @y = y
      @angle = angle
      @mirror = mirror

    end

    # ---

    def create_item
      PackingItem.new(self)
    end

  end

  # -----

  class PackingCutDef

    attr_reader :depth, :x, :y, :length, :orientation

    def initialize(depth, x, y, length, orientation)

      @depth = depth
      @x = x
      @y = y
      @length = length
      @orientation = orientation

    end

    # ---

    def create_cut
      PackingCut.new(self)
    end

  end

end