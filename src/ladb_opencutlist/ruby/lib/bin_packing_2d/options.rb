# frozen_string_literal: true

module Ladb::OpenCutList::BinPacking2D
  #
  # Implements configuration options.
  #
  class Options
    attr_reader :debug, :optimization, :stacking_pref, :base_length, :base_width,
                :saw_kerf, :trimsize, :rotatable, :min_length, :min_width
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
      @min_length = @saw_kerf
      @min_width = @saw_kerf
      # Used internally by algorithm.
      @presort = 0
      @score = 0
      @split = 0
      @stacking = 0
    end

    #
    # Set debug mode to on/off.
    #
    def set_debug(debug)
      @debug = debug
    end

    #
    # Set optimization level.
    #
    def set_optimization(optimization)
      @optimization = if (OPT_MEDIUM..OPT_ADVANCED).cover?(optimization)
                        optimization
                      else
                        OPT_MEDIUM
                      end
    end

    #
    # Set the stacking preference.
    #
    def set_stacking_pref(stacking_pref)
      @stacking_pref = if (STACKING_NONE..STACKING_ALL).cover?(stacking_pref)
                         stacking_pref
                       else
                         STACKING_NONE
                       end
    end

    #
    # Set the base length of infinite Bin.
    #
    def set_base_length(base_length)
      @base_length = base_length
    end

    #
    # Set the base width of infinite Bin.
    #
    def set_base_width(base_width)
      @base_width = base_width
    end

    #
    # Set global property rotatable = no grain.
    #
    def set_rotatable(rotatable)
      @rotatable = if [true, false].include?(rotatable)
                     rotatable
                   else
                     true
                   end
    end

    #
    # Set saw kerf width.
    #
    def set_saw_kerf(saw_kerf)
      @saw_kerf = saw_kerf
    end

    #
    # Set trim size around bin (symmetrical).
    #
    def set_trimsize(trimsize)
      @trimsize = trimsize
    end

    #
    # Set the keep parameter.
    #
    def set_keep(min_length, min_width)
      @min_length = min_length
      @min_width = min_width
    end

    #
    # Return a signature string of the options.
    #
    def signature
      "#{@presort}/#{@score}/#{@split}/#{@stacking}/#{format('%5.2f', @saw_kerf)}/#{format('%5.2f', @trimsize)}"
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
      s + "   global rotatable = #{@rotatable}\n"
    end
  end
end
