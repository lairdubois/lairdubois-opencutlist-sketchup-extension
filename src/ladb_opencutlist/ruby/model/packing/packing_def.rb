module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative 'packing'

  class PackingDef < DataContainer

    attr_reader :group, :errors, :running, :cancelled, :solution_def

    def initialize(group: nil, errors: [], running: false, cancelled: false, solution_def: nil)
      @group = group

      @errors = errors

      @running = running
      @cancelled = cancelled

      @solution_def = solution_def

    end

    # ---

    def create_packing
      Packing.new(self)
    end

  end

  # -----

  class PackingSolutionDef < DataContainer

    attr_reader :options_def, :summary_def, :bin_defs, :unplaced_part_info_defs

    def initialize(options_def:, summary_def:, bin_defs:)

      @options_def = options_def
      @summary_def = summary_def

      @bin_defs = bin_defs

      # Computed

      @unplaced_part_info_defs = []

    end

    # ---

    def create_solution
      PackingSolution.new(self)
    end

  end

  # -----

  class PackingOptionsDef < DataContainer

    attr_reader :problem_type, :spacing, :trimming, :items_formula, :hide_part_list, :part_drawing_type, :colorization, :origin_corner

    def initialize(problem_type:, spacing:, trimming:, items_formula:, hide_part_list:, part_drawing_type:, colorization:, origin_corner:)

      @problem_type = problem_type

      @spacing = spacing
      @trimming = trimming

      @items_formula = items_formula
      @hide_part_list = hide_part_list
      @part_drawing_type = part_drawing_type
      @colorization = colorization
      @origin_corner = origin_corner

    end

    # ---

    def create_options
      PackingOptions.new(self)
    end

  end

  # -----

  class PackingSummaryDef < DataContainer

    attr_reader :time, :total_bin_count, :total_item_count, :total_efficiency, :bin_type_defs
    attr_accessor :total_leftover_count, :total_cut_count, :total_cut_length, :total_used_count, :total_used_area, :total_used_length, :total_used_cost, :total_used_item_count

    def initialize(time:, total_bin_count:, total_item_count:, total_efficiency:, bin_type_defs:)

      @time = time
      @total_bin_count = total_bin_count
      @total_item_count = total_item_count
      @total_efficiency = total_efficiency

      @bin_type_defs = bin_type_defs

      # Computed

      @total_leftover_count = 0
      @total_cut_count = 0
      @total_cut_length = 0

      @total_used_count = 0
      @total_used_area = 0
      @total_used_length = 0
      @total_used_cost = 0
      @total_used_item_count = 0

    end

    # ---

    def create_summary
      PackingSummary.new(self)
    end

  end

  # -----

  class PackingSummaryBinTypeDef < DataContainer

    attr_reader :bin_type_def, :count, :used, :std_price, :total_area, :total_length, :total_cost, :total_item_count

    def initialize(bin_type_def:, count:, used:, total_item_count: 0)

      @bin_type_def = bin_type_def
      @count = count
      @used = used

      @std_price = bin_type_def.std_price

      @total_area = bin_type_def.length * bin_type_def.width * count
      @total_length = bin_type_def.length * count
      @total_cost = @used ? bin_type_def.cost * count : 0
      @total_item_count = total_item_count

    end

    # ---

    def create_summary_bin_type
      PackingSummaryBinType.new(self)
    end

  end

  # -----

  class PackingBinDef < DataContainer

    attr_reader :bin_type_def, :count, :efficiency, :item_defs, :leftover_defs, :cut_defs, :part_info_defs, :total_cut_length, :x_max, :y_max
    attr_accessor :svg, :light_svg

    def initialize(bin_type_def:, count:, efficiency:, item_defs:, leftover_defs:, cut_defs:, part_info_defs:, total_cut_length:, x_max:, y_max:)

      @bin_type_def = bin_type_def

      @count = count
      @efficiency = efficiency

      @item_defs = item_defs
      @leftover_defs = leftover_defs
      @cut_defs = cut_defs
      @part_info_defs = part_info_defs

      @total_cut_length = total_cut_length

      @x_max = x_max
      @y_max = y_max

      # Computed

      @svg = ''
      @light_svg = ''

    end

    # ---

    def create_bin
      PackingBin.new(self)
    end

  end

  # -----

  class PackingItemDef < DataContainer

    attr_reader :item_type_def, :instance_info, :x, :y, :angle, :mirror

    def initialize(item_type_def:, instance_info:, x:, y:, angle:, mirror:)

      @item_type_def = item_type_def
      @instance_info = instance_info

      @x = x
      @y = y
      @angle = angle
      @mirror = mirror

    end

    # ---

    def create_item
      Packingtem.new(self)
    end

  end

  # -----

  class PackingLeftoverDef < DataContainer

    attr_reader :x, :y, :length, :width

    def initialize(x:, y:, length:, width:)

      @x = x
      @y = y
      @length = length
      @width = width

    end

    # ---

    def create_leftover
      PackingLeftover.new(self)
    end

  end

  # -----

  class PackingCutDef < DataContainer

    attr_reader :depth, :x, :y, :length, :orientation

    def initialize(depth:, x:, y:, length:, orientation:)

      @depth = depth
      @x = x
      @y = y
      @length = length
      @orientation = orientation

    end

    def vertical?
      @orientation == 'vertical'
    end

    def horizontal?
      @orientation == 'horizontal'
    end

    # ---

    def create_cut
      PackingCut.new(self)
    end

  end

  # -----

  class PackingPartInfoDef < DataContainer

    attr_reader :_sorter, :part, :count

    def initialize(part:, count:)

      @_sorter = part.number.to_i > 0 ? part.number.to_i : part.number.rjust(4)  # Use a special "_sorter" property because number could be a letter. In this case, rjust it.

      @part = part
      @count = count

    end

    # ---

    def create_part_info
      PackingPartInfo.new(self)
    end

  end

end