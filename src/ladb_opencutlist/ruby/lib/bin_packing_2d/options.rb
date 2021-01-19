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

    def initialize
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

    def set_debug(debug)
      @debug = debug
    end

    def set_optimization(optimization)
      @optimization = optimization
    end

    def set_stacking_pref(stacking_pref)
      @stacking_pref = stacking_pref
    end

    def set_base_length(base_length)
      @base_length = base_length
    end

    def set_base_width(base_width)
      @base_width = base_width
    end

    def set_rotatable(rotatable)
      @rotatable = rotatable
    end

    def set_saw_kerf(saw_kerf)
      @saw_kerf = saw_kerf
    end

    def set_trimsize(trimsize)
      @trimsize = trimsize
    end
    #
    # Make a signature string of the options.
    #
    def signature
      return "#{@presort}/#{@score}/#{@split}/#{@stacking}/#{'%5.3f' % @saw_kerf}/#{'%5.3f' % @trimsize}"
    end

    #
    # Get number of packings for this option setup.
    #
    def get_computations(optimization, stacking_pref)
      case optimization
      when OPT_LIGHT
        if stacking_pref <= STACKING_WIDTH
          return 16
        else
          return 48
        end
      when OPT_ADVANCED
        if stacking_pref <= STACKING_WIDTH
          return 216
        else
          return 648
        end
      else
        return 0
      end
    end

    #
    # Debugging!
    #
    def to_str
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
