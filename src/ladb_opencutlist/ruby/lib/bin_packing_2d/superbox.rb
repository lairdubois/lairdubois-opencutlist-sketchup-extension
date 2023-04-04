# frozen_string_literal: true

module Ladb::OpenCutList::BinPacking2D
  #
  # Implements a SuperBox that can contain stacked Boxes.
  #
  class SuperBox < Box
    # Shape of the stacking, lengthwise.
    SHAPE_LENGTH = 0
    # Shape of stacking, width-wise.
    SHAPE_WIDTH = 1

    # The list of Boxes in a SuperBox.
    attr_reader :sboxes

    # The maximal length for packing in a SuperBox.
    attr_reader :maxlength

    # The maximal width for packing in a SuperBox.
    attr_reader :maxwidth

    # The shape of this Superbox.
    attr_reader :shape

    # Unbreakable if the SuperBox should not be broken.
    attr_reader :unbreakable

    #
    # Initializes a new SuperBox.
    #
    def initialize(maxlength, maxwidth, saw_kerf)
      # Call super with a fake length/width
      super(1.0, 1.0, false, nil, nil)

      # Reset fake length/width
      @length = 0
      @width = 0
      @saw_kerf = saw_kerf
      @unbreakable = false
      @maxlength = maxlength
      @maxwidth = maxwidth

      # Shape is currently unknown, assuming, but not important!
      @shape = SHAPE_LENGTH
      @sboxes = []
    end

    #
    # Make this superbox unbreakable, meaning it will not
    # be further decomposed during packing.
    #
    def make_unbreakable
      @unbreakable = true
    end

    #
    # Add a first Box to the SuperBox.
    #
    def add_first_box(box)
      @sboxes << box
      # Check if box fits into @maxlength, @maxwidth!
      # This is done in packer.
      @length = box.length
      @width = box.width
      @rotatable = box.rotatable
      @rotated = false
      # Superbox has no shape yet, we could still stack either way!
    end

    #
    # Stack identical elements in boxes until maxlength reached.
    # Boxes passed in should all have the same width.
    # Returns the elements that could not be stacked.
    #
    def stack_length(boxes)
      # Only superbox with size 1 can have other boxes stacked onto it!
      raise(Packing2DError, 'SuperBox length is empty, cannot stack!') unless @sboxes.size == 1

      surplus_boxes = []
      @shape = SHAPE_LENGTH
      until boxes.empty?
        box = boxes.shift
        if box.rotatable == @rotatable && (@width - box.width).abs <= EPS &&
           @length + @saw_kerf + box.length <= @maxlength
          @length = @length + @saw_kerf + box.length
          @sboxes << box
        elsif box.rotatable == @rotatable && box.rotatable && (@width - box.length).abs <= EPS &&
              @length + @saw_kerf + box.width <= @maxlength
          box.rotate
          @length = @length + @saw_kerf + box.length
          @sboxes << box
        else
          surplus_boxes << box
        end
      end
      surplus_boxes
    end

    #
    # Stack identical elements in boxes until maxwidth is reached.
    # Boxes passed in should all have the same length.
    # Returns the elements that could not be stacked.
    #
    def stack_width(boxes)
      # Only superbox with size 1 can have other boxes stacked onto it!
      raise(Packing2DError, 'Superbox width is empty, cannot stack!') unless @sboxes.size == 1

      surplus_boxes = []
      # We have a first element in the superbox
      @shape = SHAPE_WIDTH
      until boxes.empty?
        box = boxes.shift
        # Reject boxes than do not have the same rotatable
        if box.rotatable == @rotatable && (@length - box.length).abs <= EPS &&
           @width + @saw_kerf + box.width <= @maxwidth
          @width = @width + @saw_kerf + box.width
          @sboxes << box
        elsif box.rotatable == @rotatable && box.rotatable && (@length - box.width).abs <= EPS &&
              @width + @saw_kerf + box.length <= @maxwidth
          box.rotate
          @width = @width + @saw_kerf + box.width
          @sboxes << box
        else
          surplus_boxes << box
        end
      end
      surplus_boxes
    end

    #
    # Reduce this SuperBox by one element, the first and largest.
    #
    def reduce
      case @shape
      when SHAPE_LENGTH
        return @sboxes[0], nil unless @sboxes.size > 1

        # Splat operator
        first, *@sboxes = @sboxes
        @length = @length - first.length - @saw_kerf
        return first, self
      when SHAPE_WIDTH
        return @sboxes[0], nil unless @sboxes.size > 1

        # Splat operator
        first, *@sboxes = @sboxes
        @width = @width - first.width - @saw_kerf
        return first, self
      else
        raise(Packing2DError, 'Trying to reduce a superbox with an unknown shape!')
      end
    end

    #
    # Rotate the SuperBox by 90 degree if option permits
    # and shape is still valid. Also rotates all contained boxes.
    #
    def rotate
      if @rotatable
        # Checking for valid shape is done in leftover.score()
        @width, @length = [@length, @width]
        @rotated = !@rotated
        @sboxes.each(&:rotate)
        @shape = SHAPE_LENGTH ? SHAPE_WIDTH : SHAPE_LENGTH
        return true
      end
      # on anything else!
      false
    end

    #
    # Debugging!
    #
    def to_str
      "superbox shape=#{@shape}, x=#{@x}, y=#{@y}, length=#{@length}, " \
        "width=#{@width}, count=#{@sboxes.size}, rotated=#{@rotated}/#{@rotatable}"
    end
  end
end
