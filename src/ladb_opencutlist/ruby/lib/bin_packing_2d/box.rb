module Ladb::OpenCutList::BinPacking2D

  #
  # Implements an element to pack into a Bin.
  #
  class Box

    # Position of this Box inside the enclosing Bin.
    attr_reader :x, :y

    # Length this Box.
    attr_reader :length

    # Width of this Box.
    attr_reader :width

    # True if this Box can be rotated.
    attr_reader :rotatable

    # True if this Box has been rotated by 90 deg. from its original orientation.
    attr_reader :rotated

    # Reference to an external object. This value is kept during optimization.
    attr_reader :data

    #
    # Initializes a new Box, ensure that it has a length and width > 0.
    #
    def initialize(length, width, rotatable, data)
      @x = 0
      @y = 0
      @length = length * 1.0
      @width = width * 1.0

      raise(Packing2DError, "Trying to initialize a box with zero or negative length/width!") if @length <= 0.0 || @width <= 0.0

      @rotatable = rotatable
      @rotated = false
      @data = data
    end

    #
    # Sets rotated when copied.
    #
    def set_rotated
      @rotated = true
    end

    #
    # Returns true if the Box was rotated.
    #
    def rotated?
      return @rotated
    end

    #
    # Rotates the Box by 90 deg. if option permits.
    #
    def rotate
      if @rotatable
        # Only rotate if length and width are different, otherwise does not
        # make sense.
        if (@length - @width).abs > EPS
          @width, @length = [@length, @width]
          @rotated = !@rotated
        end
      end
    end

    #
    # Sets the position of this Box inside a Bin when placed into a Leftover by Packer.
    #
    def set_position(x, y)
      @x = x
      @y = y
      raise(Packing2DError, "Trying to initialize a box with negative x or y!") if @x < 0.0 || @y < 0.0
    end

    #
    # Checks if this Box would fit into a rectangle given by length and width.
    #
    def fits_into?(length, width)
      # EPS tolerance because of conversion from mm to decimal inches!
      return true if length - @length >= -EPS && width - @width >= -EPS
      return true if @rotatable && width - @length >= -EPS && length - @width >= -EPS
      false
    end

    #
    # Returns true if this Box fits into given Leftover. The top level
    # Leftover of a Bin has already been trimmed, if trimming option is set.
    #
    def fits_into_leftover?(leftover)
      return false if leftover.nil?

      fits_into?(leftover.length, leftover.width)
    end

    #
    # Returns the area of this Box.
    #
    def area
      @length * @width
    end

    #
    # Returns true if this Box is equal to another Box.
    #
    def equal?(other)
      return true if other.nil?

      return true if (@length - other.length).abs <= EPS && (@width - other.width).abs <= EPS

      return true if @rotatable && (@length - other.width).abs <= EPS && (@width - other.length).abs <= EPS

      false
    end

    #
    # Return true if this Box is "very" different from another Box, e.g. 10% difference in both directions.
    #
    def different?(box)
      return true if box.nil?

      return true if (@length - box.length).abs > box.length * DIFF_PERCENTAGE_BOX || (@width - box.width).abs > box.width * DIFF_PERCENTAGE_BOX

      return true if @rotatable && ((@length - box.width).abs >= box.length * DIFF_PERCENTAGE_BOX || (@width - box.length).abs >= box.width * DIFF_PERCENTAGE_BOX)

      false
    end

    #
    # Debugging!
    #
    def to_str
      "box : #{"%5d" % object_id} [#{"%9.2f" % @x}, #{"%9.2f" % @y}, " \
      "#{"%9.2f" % @length}, #{"%9.2f" % @width}], " \
      "rotated = #{@rotated}[rotatable=#{@rotatable}]"
    end

    #
    # Debugging!
    #
    def to_octave
      "rectangle(\"Position\", [#{@x},#{@y},#{@length},#{@width}], " \
      "\"Facecolor\", blue); # box"
    end
  end
end
