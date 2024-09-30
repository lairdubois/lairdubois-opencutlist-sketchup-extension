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

    attr_reader :problem_type, :spacing, :trimming, :hide_part_list, :part_drawing_type

    def initialize(problem_type, spacing, trimming, hide_part_list, part_drawing_type)

      @problem_type = problem_type

      @spacing = spacing
      @trimming = trimming

      @hide_part_list = hide_part_list
      @part_drawing_type = part_drawing_type

    end

    # ---

    def create_options
      PackingOptions.new(self)
    end

  end

  # -----

  class PackingSummaryDef

    attr_reader :time, :total_bin_count, :total_item_count, :total_efficiency, :bin_type_defs
    attr_accessor :total_leftover_count, :total_cut_count, :total_cut_length, :total_used_count, :total_used_area, :total_used_length, :total_used_item_count

    def initialize(time, total_bin_count, total_item_count, total_efficiency)

      @time = time
      @total_bin_count = total_bin_count
      @total_item_count = total_item_count
      @total_efficiency = total_efficiency

      # Computed

      @total_leftover_count = 0
      @total_cut_count = 0
      @total_cut_length = 0

      @total_used_count = 0
      @total_used_area = 0
      @total_used_length = 0
      @total_used_item_count = 0

      @bin_type_defs = []

    end

    # ---

    def create_summary
      PackingSummary.new(self)
    end

  end

  # -----

  class PackingSummaryBinTypeDef

    attr_reader :bin_type_def, :count, :used, :total_area, :total_length, :total_item_count

    def initialize(bin_type_def, count, used, total_item_count = 0)

      @bin_type_def = bin_type_def
      @count = count
      @used = used

      @total_area = bin_type_def.length * bin_type_def.width * count
      @total_length = bin_type_def.length * count
      @total_item_count = total_item_count

    end

    # ---

    def create_summary_bin_type
      PackingSummaryBinType.new(self)
    end

  end

  # -----

  class PackingBinDef

    attr_reader :bin_type_def, :count, :efficiency, :item_defs, :leftover_defs, :cut_defs, :part_defs
    attr_accessor :svg, :total_cut_length, :parts

    def initialize(bin_type_def, count, efficiency, item_defs, leftover_defs, cut_defs, part_defs)

      @bin_type_def = bin_type_def

      @count = count
      @efficiency = efficiency

      @item_defs = item_defs
      @leftover_defs = leftover_defs
      @cut_defs = cut_defs
      @part_defs = part_defs

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

  class PackingLeftoverDef

    attr_reader :x, :y, :length, :width

    def initialize(x, y, length, width)

      @x = x
      @y = y
      @length = length
      @width = width

    end

    # ---

    def create_cut
      PackingLeftover.new(self)
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

  # -----

  class PackingBinPartDef

    attr_reader :_sorter, :part, :count

    def initialize(part, count)

      @_sorter = part.number.to_i > 0 ? part.number.to_i : part.number.rjust(4)  # Use a special "_sorter" property because number could be a letter. In this case, rjust it.

      @part = part
      @count = count

    end

    # ---

    def create_bin_part
      PackingBinPart.new(self)
    end

  end

end