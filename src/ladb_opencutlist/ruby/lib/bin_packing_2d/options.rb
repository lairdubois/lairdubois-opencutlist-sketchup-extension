module Ladb::OpenCutList::BinPacking2D

  #
  # Implements configuration options.
  #
  class Options

    attr_accessor :debug
    attr_accessor :optimization, :stacking_pref
    attr_accessor :base_length, :base_width
    attr_accessor :saw_kerf, :trimsize, :rotatable
    attr_accessor :presort, :stacking, :score, :split

    def initialize
      @debug = debug
      @optimization = 0
      @stacking_pref = 0

      # Bin configuration options.
      #@rotatable = false
      @saw_kerf = 0
      @trimsize = 0

      # Used internally by algorithm
      @presort = 0
      @score = 0
      @split = 0
      @stacking = 0
    end

    #
    # Returns true if a standard bin has been setup.
    #
    def std_bin_exists?
      return (@base_length - 2 * @trimsize) > EPS &&
        (@base_width - 2 * @trimsize) > EPS
    end

    def signature
      return "#{@presort}/#{@score}/#{@split}/#{@stacking}/#{'%5.3f' % @saw_kerf}/#{'%5.3f' % @trimsize}"
    end

    def get_computations(optimization, stacking_pref)
      case optimization
      when OPT_LIGHT
        if stacking_pref <= STACKING_WIDTH
          return 16
        else
          return 48
        end
      when OPT_MEDIUM
        if stacking_pref <= STACKING_WIDTH
          return 72
        else
          return 216
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
