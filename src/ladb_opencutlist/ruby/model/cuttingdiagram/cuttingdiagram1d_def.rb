module Ladb::OpenCutList

  require_relative 'cuttingdiagram1d'

  class Cuttingdiagram1dDef

    attr_accessor :group, :errors, :warnings, :tips, :unplaced_part_defs, :options_def, :summary_def, :bar_defs, :projection_defs

    def initialize(group, errors = [])
      @group = group

      @errors = errors
      @warnings = []
      @tips = []

      @unplaced_part_defs = {}
      @options_def = Cuttingdiagram1dOptionsDef.new
      @summary_def = Cuttingdiagram1dSummaryDef.new
      @bar_defs = {}

      @projection_defs = {} # Key = part ID

    end

    # ---

    def create_cuttingdiagram1d
      Cuttingdiagram1d.new(self)
    end

  end

  # -----

  class Cuttingdiagram1dOptionsDef

    attr_accessor :px_saw_kerf, :saw_kerf, :trimming, :bar_folding, :hide_part_list, :part_drawing_type, :use_names, :full_width_diagram, :hide_cross, :origin_corner, :wrap_length

    def initialize

      @px_saw_kerf = 0
      @saw_kerf = 0
      @trimming = 0
      @bar_folding = false
      @hide_part_list = false
      @part_drawing_type = 0
      @use_names = false
      @full_width_diagram = false
      @hide_cross = false
      @origin_corner = 0
      @wrap_length = false

    end

    # ---

    def create_options
      Cuttingdiagram1dOptions.new(self)
    end

  end

  # -----

  class Cuttingdiagram1dSummaryDef

    attr_accessor :total_used_count, :total_used_length, :total_used_part_count, :total_cut_count, :total_cut_length, :overall_efficiency
    attr_reader :bar_defs

    def initialize

      @total_used_count = 0
      @total_used_length = 0
      @total_used_part_count = 0

      @total_cut_count = 0
      @total_cut_length = 0

      @overall_efficiency = 0

      @bar_defs = {}

    end

    # ---

    def create_summary
      Cuttingdiagram1dSummary.new(self)
    end

  end

  # -----

  class Cuttingdiagram1dSummaryBarDef

    attr_accessor :type_id, :type, :count, :length, :width, :total_length, :total_part_count, :is_used

    def initialize

      @type_id = 0
      @type = 0
      @count = 0
      @length = 0
      @total_length = 0
      @total_part_count = 0
      @is_used = false

    end

    # ---

    def create_summary_bar
      Cuttingdiagram1dSummaryBar.new(self)
    end

  end

  class Cuttingdiagram1dBarDef

    attr_accessor :type_id, :type, :count, :length, :width, :px_length, :px_width, :efficiency, :total_cut_length, :leftover_def
    attr_reader :slice_defs, :part_defs, :grouped_part_defs, :cut_defs

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

      @slice_defs = []
      @part_defs = []
      @grouped_part_defs = {}
      @cut_defs = []

      @leftover_def = nil

    end

    # ---

    def create_bar
      Cuttingdiagram1dBar.new(self)
    end

  end

  # -----

  class Cuttingdiagram1dSliceDef

    attr_accessor :index, :px_x, :px_length

    def initialize
      @index = nil
      @px_x = 0
      @px_length = 0
    end

    # ---

    def create_slice
      Cuttingdiagram1dSlice.new(self)
    end

  end

  # -----

  class Cuttingdiagram1dPartDef

    attr_accessor :px_x, :px_x_offset, :px_length
    attr_reader :cutlist_part, :slice_defs

    def initialize(cutlist_part)
      @cutlist_part = cutlist_part

      @px_x = 0
      @px_x_offset = 0
      @px_length = 0

      @slice_defs = []

    end

    # ---

    def create_part
      Cuttingdiagram1dPart.new(self)
    end

  end

  class Cuttingdiagram1dListedPartDef

    attr_accessor :_sorter, :count
    attr_reader :cutlist_part

    def initialize(cutlist_part)
      @cutlist_part = cutlist_part

      @_sorter = cutlist_part.number.to_i > 0 ? cutlist_part.number.to_i : cutlist_part.number.rjust(4)  # Use a special "_sorter" property because number could be a letter. In this case, rjust it.

      @count = 0

    end

    # ---

    def create_listed_part
      Cuttingdiagram1dListedPart.new(self)
    end

  end

  # -----

  class Cuttingdiagram1dLeftoverDef

    attr_accessor :px_x, :px_length, :length
    attr_reader :slice_defs

    def initialize

      @px_x = 0
      @px_length = 0
      @length = 0

      @slice_defs = []

    end

    # ---

    def create_leftover
      Cuttingdiagram1dLeftover.new(self)
    end

  end

  # -----

  class Cuttingdiagram1dCutDef

    attr_accessor :px_x, :x
    attr_reader :slice_defs

    def initialize

      @px_x = 0
      @x = 0

      @slice_defs = []

    end

    # ---

    def create_cut
      Cuttingdiagram1dCut.new(self)
    end

  end

end
