module Ladb::OpenCutList::BinPacking2D

  #
  # Implements configuration options.
  #
  class Options

    attr_reader :debug
    attr_reader :optimization, :stacking_pref
    attr_reader :base_length, :base_width
    attr_reader :saw_kerf, :trimsize, :rotatable
    attr_accessor :presort, :stacking, :score, :split

    def initialize()
      @debug = debug

      # General algorithm options.
      @optimization = 0
      @stacking_pref = 0
      @base_length = 0
      @base_width = 0
      # Bin configuration options.
      @rotatable = false
      @saw_kerf = 0
      @trimsize = 0

      # Used internally by algorithm.
      @presort = 0
      @score = 0
      @split = 0
      @stacking = 0
    end

    #
    # Sets debug mode to on.
    #
    def set_debug(debug)
      @debug = debug
    end

    #
    # Sets optimization level.
    #
    def set_optimization(optimization)
      if (OPT_MEDIUM..OPT_ADVANCED).include?(optimization)
        @optimization = optimization
      else
        @optimization = OPT_MEDIUM
      end
    end

    #
    # Sets the stacking preference.
    #
    def set_stacking_pref(stacking_pref)
      if (STACKING_NONE..STACKING_ALL).include?(stacking_pref)
        @stacking_pref = stacking_pref
      else
        @stacking_pref = STACKING_NONE
      end
    end

    #
    # Sets the base length of infinite Bin.
    #
    def set_base_length(base_length)
      @base_length = base_length
    end

    #
    # Sets the base width of infinite Bin.
    #
    def set_base_width(base_width)
      @base_width = base_width
    end

    #
    # Sets global property rotatable = no grain.
    #
    def set_rotatable(rotatable)
      @rotatable = rotatable
    end

    #
    # Sets saw kerf width.
    #
    def set_saw_kerf(saw_kerf)
      @saw_kerf = saw_kerf
    end

    #
    # Sets trim size around bin (symmetrical).
    #
    def set_trimsize(trimsize)
      @trimsize = trimsize
    end

    #
    # Makes a signature string of the options.
    #
    def signature()
      return "#{@presort}/#{@score}/#{@split}/#{@stacking}/#{'%5.3f' % @saw_kerf}/#{'%5.3f' % @trimsize}"
    end

    #
    # Gets number of packings for this option setup.
    #
    def get_computations(optimization, stacking_pref)
      case optimization
      when OPT_MEDIUM
        if stacking_pref <= STACKING_WIDTH
          return 64
        else
          return 192
        end
      when OPT_ADVANCED
        if stacking_pref <= STACKING_WIDTH
          return 384
        else
          return 1152
        end
      else
        return 0
      end
    end

    #
    # Debugging!
    #
    def to_str()
      s = "-> options\n"
      s += "   optimization     = #{@optimization} => #{OPTIMIZATION[@optimization]}\n"
      s += "   stacking_pref    = #{@stacking_pref} => #{STACKING[@stacking_pref]}\n"
      s += "   computations     = #{get_computations(@optimization, @stacking_pref)}\n"
      s += "   base_length      = #{@base_length}\n"
      s += "   base_width       = #{@base_width}\n"
      s += "   trimsize         = #{@trimsize}\n"
      s += "   saw_kerf         = #{@saw_kerf}\n"
      s += "   global rotatable = #{@rotatable}\n"
      return s
    end
  end

end
