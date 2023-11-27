module Ladb::OpenCutList

  require_relative 'cuttingdiagram2d'

  class Cuttingdiagram2dDef

    attr_accessor :group, :errors, :warnings, :tips, :unplaced_part_defs, :options_def, :summary_def, :sheet_defs, :to_keep_leftover_defs, :projection_defs

    def initialize(group, errors = [])
      @group = group

      @errors = errors
      @warnings = []
      @tips = []

      @unplaced_part_defs = {}
      @options_def = Cuttingdiagram2dOptionsDef.new
      @summary_def = Cuttingdiagram2dSummaryDef.new
      @sheet_defs = {}
      @to_keep_leftover_defs = {}

      @projection_defs = {} # Key = part ID

    end

    # ---

    def create_cuttingdiagram2d
      Cuttingdiagram2d.new(self)
    end

  end

  # -----

  class Cuttingdiagram2dOptionsDef

    attr_accessor :grained, :px_saw_kerf, :saw_kerf, :trimming, :optimization, :stacking, :keep_length, :keep_width, :sheet_folding, :hide_part_list, :part_drawing_type, :use_names, :full_width_diagram, :hide_cross, :origin_corner, :highlight_primary_cuts, :hide_edges_preview

    def initialize

      @grained = false
      @px_saw_kerf = 0
      @saw_kerf = 0
      @trimming = 0
      @optimization = 0
      @stacking = 0
      @keep_length = 0
      @keep_width = 0
      @sheet_folding = false
      @hide_part_list = false
      @part_drawing_type = 0
      @use_names = false
      @full_width_diagram = false
      @hide_cross = false
      @origin_corner = 0
      @highlight_primary_cuts = false
      @hide_edges_preview = true

    end

    # ---

    def create_options
      Cuttingdiagram2dOptions.new(self)
    end

  end

  # -----

  class Cuttingdiagram2dSummaryDef

    attr_accessor :total_used_count, :total_used_area, :total_used_part_count, :total_cut_count, :total_cut_length, :overall_efficiency
    attr_reader :sheet_defs

    def initialize

      @total_used_count = 0
      @total_used_area = 0
      @total_used_part_count = 0

      @total_cut_count = 0
      @total_cut_length = 0

      @overall_efficiency = 0

      @sheet_defs = {}

    end

    # ---

    def create_summary
      Cuttingdiagram2dSummary.new(self)
    end

  end

  # -----

  class Cuttingdiagram2dSummarySheetDef

    attr_accessor :type_id, :type, :count, :length, :width, :total_area, :total_part_count, :is_used

    def initialize

      @type_id = 0
      @type = 0
      @count = 0
      @length = 0
      @width = 0
      @total_area = 0
      @total_part_count = 0
      @is_used = false

    end

    # ---

    def create_summary_sheet
      Cuttingdiagram2dSummarySheet.new(self)
    end

  end

  class Cuttingdiagram2dSheetDef

    attr_accessor :type_id, :type, :count, :length, :width, :px_length, :px_width, :efficiency, :total_cut_length
    attr_reader :part_defs, :grouped_part_defs, :cut_defs, :leftover_defs

    def initialize

      @type_id = 0
      @type = 0
      @count = 0
      @length = 0
      @width = 0
      @px_length = 0
      @px_width = 0
      @efficiency = 0
      @total_cut_length = 0

      @part_defs = []
      @grouped_part_defs = {}
      @cut_defs = []
      @leftover_defs = []

    end

    # ---

    def create_sheet
      Cuttingdiagram2dSheet.new(self)
    end

  end

  # -----

  class Cuttingdiagram2dPartDef

    attr_accessor :px_x, :px_y, :px_x_offset, :px_y_offset, :px_length, :px_width, :rotated
    attr_reader :cutlist_part

    def initialize(cutlist_part)
      @cutlist_part = cutlist_part

      @px_x = 0
      @px_y = 0
      @px_x_offset = 0
      @px_y_offset = 0
      @px_length = 0
      @px_width = 0
      @rotated = false

    end

    # ---

    def create_part
      Cuttingdiagram2dPart.new(self)
    end

  end

  class Cuttingdiagram2dListedPartDef

    attr_accessor :_sorter, :count
    attr_reader :cutlist_part

    def initialize(cutlist_part)
      @cutlist_part = cutlist_part

      @_sorter = cutlist_part.number.to_i > 0 ? cutlist_part.number.to_i : cutlist_part.number.rjust(4)  # Use a special "_sorter" property because number could be a letter. In this case, rjust it.

      @count = 0

    end

    # ---

    def create_listed_part
      Cuttingdiagram2dListedPart.new(self)
    end

  end

  # -----

  class Cuttingdiagram2dLeftoverDef

    attr_accessor :px_x, :px_y, :px_length, :px_width, :length, :width, :to_keep

    def initialize

      @px_x = 0
      @px_y = 0
      @px_length = 0
      @px_width = 0
      @length = 0
      @width = 0
      @to_keep = false

    end

    # ---

    def create_leftover
      Cuttingdiagram2dLeftover.new(self)
    end

  end

  # -----

  class Cuttingdiagram2dListedLeftoverDef

    attr_accessor :leftover_def, :sheet_def, :count

    def initialize

      @leftover_def = leftover_def
      @sheet_def = sheet_def

      @count = 0

    end

    def length
      @leftover_def.length
    end

    def width
      @leftover_def.width
    end

    def area
      length * width
    end

    # ---

    def create_listed_leftover
      Cuttingdiagram2dListedLeftover.new(self)
    end

  end

  # -----

  class Cuttingdiagram2dCutDef

    attr_accessor :px_x, :px_y, :px_length, :x, :y, :length, :is_horizontal, :is_internal_through, :is_trimming, :is_bounding

    def initialize

      @px_x = 0
      @px_y = 0
      @px_length = 0
      @x = 0
      @y = 0
      @length = 0
      @is_horizontal = false
      @is_internal_through = false
      @is_trimming = false
      @is_bounding = false

    end

    # ---

    def create_cut
      Cuttingdiagram2dCut.new(self)
    end

  end

end
