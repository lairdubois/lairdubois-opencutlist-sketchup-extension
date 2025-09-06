module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative 'packing'

  class PackingDef < DataContainer

    attr_reader :group,
                :errors, :warnings,
                :running, :cancelled,
                :solution_def,
                :cached

    def initialize(group: nil,
                   errors: [],
                   warnings: [],
                   running: false, cancelled: false,
                   solution_def: nil,
                   cached: false)
      @group = group

      @errors = errors
      @warnings = warnings

      @running = running
      @cancelled = cancelled

      @solution_def = solution_def

      @cached = cached

    end

    # ---

    def create_packing
      Packing.new(self)
    end

  end

  # -----

  class PackingSolutionDef < DataContainer

    attr_reader :options_def, :summary_def,
                :unused_part_info_defs,
                :bin_defs

    def initialize(options_def:, summary_def:,
                   unused_part_info_defs:,
                   bin_defs:)

      @options_def = options_def
      @summary_def = summary_def

      @unused_part_info_defs = unused_part_info_defs

      @bin_defs = bin_defs

    end

    # ---

    def create_solution
      PackingSolution.new(self)
    end

  end

  # -----

  class PackingOptionsDef < DataContainer

    attr_reader :problem_type, :objective, :optimization_mode,
                :spacing, :trimming,
                :items_formula, :hide_part_list, :part_drawing_type, :colorization, :origin_corner, :highlight_primary_cuts, :hide_edges_preview,
                :rectangleguillotine_cut_type, :rectangleguillotine_first_stage_orientation, :rectangleguillotine_number_of_stages, :rectangleguillotine_keep_length, :rectangleguillotine_keep_width,
                :irregular_allowed_rotations, :irregular_allow_mirroring

    def initialize(problem_type:, objective:, optimization_mode:,
                   spacing:, trimming:,
                   items_formula:, hide_part_list:, part_drawing_type:, colorization:, origin_corner:, highlight_primary_cuts:, hide_edges_preview:,
                   rectangleguillotine_cut_type:, rectangleguillotine_first_stage_orientation:, rectangleguillotine_number_of_stages:, rectangleguillotine_keep_length:, rectangleguillotine_keep_width:,
                   irregular_allowed_rotations:, irregular_allow_mirroring:)

      @problem_type = problem_type
      @objective = objective
      @optimization_mode = optimization_mode

      @spacing = spacing
      @trimming = trimming

      @items_formula = items_formula
      @hide_part_list = hide_part_list
      @part_drawing_type = part_drawing_type
      @colorization = colorization
      @origin_corner = origin_corner
      @highlight_primary_cuts = highlight_primary_cuts
      @hide_edges_preview = hide_edges_preview

      @rectangleguillotine_cut_type = rectangleguillotine_cut_type
      @rectangleguillotine_first_stage_orientation = rectangleguillotine_first_stage_orientation
      @rectangleguillotine_number_of_stages = rectangleguillotine_number_of_stages
      @rectangleguillotine_keep_length = rectangleguillotine_keep_length
      @rectangleguillotine_keep_width = rectangleguillotine_keep_width

      @irregular_allowed_rotations = irregular_allowed_rotations
      @irregular_allow_mirroring = irregular_allow_mirroring

    end

    # ---

    def create_options
      PackingOptions.new(self)
    end

  end

  # -----

  class PackingSummaryDef < DataContainer

    attr_reader :time, :number_of_bins, :number_of_items, :efficiency,
                :bin_type_stats_defs
    attr_accessor :number_of_leftovers, :number_of_leftovers_to_keep, :number_of_cuts,
                  :cut_length, :cut_cost,
                  :total_used_count, :total_used_area, :total_used_length, :total_used_cost, :total_used_item_count, :total_unused_item_count, :total_usable_item_count

    def initialize(time:, number_of_bins:, number_of_items:, efficiency:,
                   bin_type_stats_defs:)

      @time = time
      @number_of_bins = number_of_bins
      @number_of_items = number_of_items
      @efficiency = efficiency

      @bin_type_stats_defs = bin_type_stats_defs

      # Computed

      @number_of_leftovers = 0
      @number_of_leftovers_to_keep = 0
      @number_of_cuts = 0

      @cut_length = 0
      @cut_cost = 0

      @total_used_count = 0
      @total_used_area = 0
      @total_used_length = 0
      @total_used_cost = 0
      @total_used_item_count = 0
      @total_unused_item_count = 0
      @total_usable_item_count = 0

    end

    # ---

    def create_summary
      PackingSummary.new(self)
    end

  end

  # -----

  class PackingSummaryBinTypeStatsDef < DataContainer

    attr_reader :bin_type_def, :count, :used,
                :number_of_items,
                :std_price,
                :total_area, :total_length, :total_cost

    def initialize(bin_type_def:, count:, used:,
                   number_of_items: 0)

      @bin_type_def = bin_type_def
      @count = count
      @used = used

      @number_of_items = number_of_items

      @std_price = bin_type_def.std_price

      @total_area = bin_type_def.length * bin_type_def.width * count
      @total_length = bin_type_def.length * count
      @total_cost = @used ? bin_type_def.cost * count : 0

    end

    # ---

    def create_summary_bin_type_stats
      PackingSummaryBinTypeStats.new(self)
    end

  end

  # -----

  BIN_TYPE_STD    = 0
  BIN_TYPE_SCRAP  = 1

  class PackingBinTypeDef < DataContainer

    attr_reader :id,
                :length, :width,
                :cost,
                :std_price,
                :std_cut_price,
                :type

    def initialize(id:,
                   length:, width:,
                   count:,
                   cost:,
                   std_price:,
                   std_cut_price:,
                   type: BIN_TYPE_STD)

      @id = id
      @length = length
      @width = width
      @count = count
      @cost = cost
      @std_price = std_price
      @std_cut_price = std_cut_price
      @type = type

    end

  end

  # -----

  class PackingBinDef < DataContainer

    attr_reader :bin_type_def,
                :count, :efficiency,
                :item_defs, :leftover_defs, :cut_defs, :part_info_defs,
                :number_of_items, :number_of_leftovers, :number_of_leftovers_to_keep, :number_of_cuts,
                :cut_length,
                :x_min, :x_max, :y_min, :y_max
    attr_accessor :cut_cost,
                  :svg, :light_svg

    def initialize(bin_type_def:,
                   count:, efficiency:,
                   item_defs:, leftover_defs:, cut_defs:, part_info_defs:,
                   number_of_items:, number_of_leftovers:, number_of_leftovers_to_keep:, number_of_cuts:,
                   cut_length:,
                   x_min:, x_max:, y_min:, y_max:)

      @bin_type_def = bin_type_def

      @count = count
      @efficiency = efficiency

      @item_defs = item_defs
      @leftover_defs = leftover_defs
      @cut_defs = cut_defs
      @part_info_defs = part_info_defs

      @number_of_items = number_of_items
      @number_of_leftovers = number_of_leftovers
      @number_of_leftovers_to_keep = number_of_leftovers_to_keep
      @number_of_cuts = number_of_cuts

      @cut_length = cut_length

      @x_min = x_min
      @x_max = x_max
      @y_min = y_min
      @y_max = y_max

      # Computed

      @cut_cost = 0

      @svg = ''
      @light_svg = ''

    end

    # ---

    def create_bin
      PackingBin.new(self)
    end

  end

  # -----

  class PackingItemTypeDef < DataContainer

    attr_reader :length, :width,
                :count,
                :part,
                :projection_def,
                :color,
                :boxed

    def initialize(length:, width:,
                   count:,
                   part:,
                   projection_def:,
                   color:,
                   boxed:)

      @length = length
      @width = width
      @count = count
      @part = part
      @projection_def = projection_def
      @color = color
      @boxed = boxed

    end

  end

  # -----

  class PackingItemDef < DataContainer

    attr_reader :item_type_def, :instance_info,
                :x, :y, :angle, :mirror,
                :label_offset

    def initialize(item_type_def:, instance_info:,
                   x:, y:, angle:, mirror:,
                   label_offset:)

      @item_type_def = item_type_def
      @instance_info = instance_info

      @x = x
      @y = y
      @angle = angle
      @mirror = mirror

      # Label offset (relative to the bounding box center, without transformations)
      @label_offset = label_offset

    end

    # ---

    def create_item
      Packingtem.new(self)
    end

  end

  # -----

  class PackingLeftoverDef < DataContainer

    attr_reader :x, :y, :length, :width,
                :kept

    def initialize(x:, y:, length:, width:, kept:)

      @x = x
      @y = y
      @length = length
      @width = width

      @kept = kept

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

    attr_reader :_sorter,
                :part, :count,
                :usable

    def initialize(part:, count:,
                   usable: true)

      @_sorter = part.number.to_i > 0 ? part.number.to_i : part.number.rjust(4)  # Use a special "_sorter" property because number could be a letter. In this case, rjust it.

      @part = part
      @count = count

      @usable = usable

    end

    # ---

    def create_part_info
      PackingPartInfo.new(self)
    end

  end

end