module Ladb::OpenCutList::BinPacking2D

  #
  # Implements configuration options.
  #
  class Options
    attr_reader :debug, :optimization, :stacking_pref, :base_length, :base_width,
                :saw_kerf, :trimsize, :rotatable
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

    #
    # Sets debug mode to on/off.
    #
    def set_debug(debug)
      @debug = debug
    end

    #
    # Sets optimization level.
    #
    def set_optimization(optimization)
      @optimization = if (OPT_MEDIUM..OPT_ADVANCED).cover?(optimization)
          optimization
        else
          OPT_MEDIUM
        end
    end

    #
    # Sets the stacking preference.
    #
    def set_stacking_pref(stacking_pref)
      @stacking_pref = if (STACKING_NONE..STACKING_ALL).cover?(stacking_pref)
          stacking_pref
        else
          STACKING_NONE
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
      if [true, false].include?(rotatable)
        @rotatable = rotatable
      else
        @rotatable = false
      end
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
    def signature
      "#{@presort}/#{@score}/#{@split}/#{@stacking}/#{"%5.2f" % @saw_kerf}/#{"%5.2f" % @trimsize}"
    end

    #
    # Debugging!
    #
    def to_str
      "-> options\n" \
      "   optimization     = #{@optimization} => #{OPTIMIZATION[@optimization]}\n" \
      "   stacking_pref    = #{@stacking_pref} => #{STACKING[@stacking_pref]}\n" \
      "   computations     = #{get_computations(@optimization, @stacking_pref)}\n" \
      "   base_length      = #{@base_length}\n" \
      "   base_width       = #{@base_width}\n" \
      "   trimsize         = #{@trimsize}\n" \
      "   saw_kerf         = #{@saw_kerf}\n" \
      "   global rotatable = #{@rotatable}\n"
    end
  end
end
