module Ladb::OpenCutList

  class Flip3d

    attr_accessor :x, :y, :z

    def initialize(x = false, y = false, z = false)
      @x = x
      @y = y
      @z = z
    end

    # -----

    def flipped_axis?(axis)
      case axis
        when X_AXIS
          @x
        when Y_AXIS
          @y
        when Z_AXIS
          @z
        else
          raise 'Invalid axis'
      end
    end

    def flipped?
      @x || @y || @z
    end

    # -----

    def to_s
      'Flip3d(' + @x.to_s + ', ' + @y.to_s + ', ' + @z.to_s + ')'
    end

  end

end
