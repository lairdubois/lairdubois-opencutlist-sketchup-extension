module Ladb::OpenCutList::BinPacking2D

  #
  # Implements an element to pack into a Bin.
  #
  class Box

    # Position of the box inside the enclosing bin.
    attr_reader :x, :y

    # Length this box.
    attr_reader :length

    # Width of this box.
    attr_reader :width

    # True if this box can be rotated.
    attr_reader :rotatable

    # True if this box has been rotated by 90 deg. from its original orientation.
    attr_reader :rotated

    # Reference to an external object. This value is kept during optimization.
    attr_reader :data

    #
    # Initializes a new Box, ensure that it has a length and width > 0.
    #
    def initialize(length, width, rotatable, data)
      @x = 0
      @y = 0

      @length = length*1.0
      @width = width*1.0

      @rotatable = rotatable
      @rotated = false

      if @length <= 0.0 || @width <= 0.0
        raise(Packing2DError, "Trying to initialize a box with zero or negative length/width!")
      end

      @data = data
    end

    #
    # Returns true if the box was rotated.
    #
    def rotated?
      return @rotated
    end

    #
    # Rotates the box by 90 deg. if option permits.
    #
    def rotate
      if @rotatable
        # TODO dangerous comparaison with float numbers
        if @length < @width || @length > @width
          @width, @length = [@length, @width]
          @rotated = !@rotated
        end
      end
    end

    #
    # Sets the position of this box inside a Bin when
    # placed into a Leftover by Packer.
    #
    def set_position(x, y)
      @x = x
      @y = y
    end

    #
    # Checks if this box would fit into the given leftover.
    # The top level leftover of a bin has already been trimmed.
    #
    def fits_into?(length, width)
      # EPS tolerance because of decimal inches!
      if length - @length >= -EPS && width - @width >= -EPS
        return true
      elsif @rotatable && width - @length >= -EPS && length - @width >= -EPS
        return true
      end
      return false
    end

    #
    # Returns true if this box fits into given leftover.
    #
    def fits_into_leftover?(leftover)
      if leftover.nil?
        return false
      end
      return fits_into?(leftover.length, leftover.width)
    end

    #
    # Returns the area of this box.
    #
    def area
      return @length * @width
    end

    #
    # Returns true if this box is equal to box.
    #
    def equal?(box)
      return true if box.nil?
      if (@length - box.length).abs <= EPS && (@width - box.width).abs <= EPS
        return true
      elsif @rotatable && (@length - box.width).abs <= EPS && (@width - box.length).abs <= EPS
        return true
      end
      return false
    end

    #
    # Returns true if at least one of the dimensions of the two
    # boxes are equal.
    #
    def equal_one_dimension?(box)
      return true if box.nil?
      if (@length - box.length).abs <= EPS || (@width - box.width).abs <= EPS
        return true
      elsif @rotatable && ((@length - box.width).abs < EPS || (@width - box.length).abs <= EPS)
        return true
      end
      return false
    end

    #
    # Debugging!
    #
    def to_str
      s = "box : #{'%5d' % object_id} [#{'%9.2f' % @x}, #{'%9.2f' % @y}, #{'%9.2f' % @length}, #{'%9.2f' % @width}], "
      s += "rotated = #{@rotated}/#{@rotatable}" #, data = #{@data}"
      return s
    end

    def to_octave
      return "rectangle(\"Position\", [#{@x},#{@y},#{@length},#{@width}], \"Facecolor\", blue); # box"
    end
  end
end
