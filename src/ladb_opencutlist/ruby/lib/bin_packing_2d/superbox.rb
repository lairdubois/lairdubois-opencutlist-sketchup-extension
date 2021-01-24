module Ladb::OpenCutList::BinPacking2D

  #
  # Implements a Box that can contain stacked boxes.
  #
  class SuperBox < Box

    # Shape of the stacking, lengthwise.
    SL = 0
    # Shape of stacking, widthwise.
    SW = 1

    # The list of subboxes.
    attr_reader :sboxes

    # The maximal length for packing in a superbox.
    attr_reader :maxlength

    # The maximal width for packing in a superbox.
    attr_reader :maxwidth

    # The shape of this superbox.
    attr_reader :shape

    #
    # Initializes a new SuperBox.
    #
    def initialize(maxlength, maxwidth, saw_kerf)

      # Call super with a fake length/width
      super(1.0, 1.0, false, nil)

      # Reset fake length/width
      @length = 0
      @width = 0
      @saw_kerf = saw_kerf

      @maxlength = maxlength
      @maxwidth = maxwidth

      # Shape is currently unknown, assuming, but not important!
      @shape = SL

      @sboxes = []
    end

    #
    # Adds a first box to the superbox
    #
    def add_first_box(box)
      @sboxes << box
      # Check if box fits into @maxlength, @maxwidth!
      @length = box.length
      @width = box.width
      @rotatable = box.rotatable
      @rotated = false
      # Superbox has no shape yet, we could stack either way!
    end

    #
    # Stacks identical elements in boxes until maxlength reached.
    # Boxes passed in should all have the same width.
    # Returns the elements that could not be stacked.
    #
    def stack_length(boxes)
      surplus_boxes = []
      if @sboxes.size == 1
        @shape = SL
        until boxes.empty?
          box = boxes.shift
          if box.rotatable != @rotatable
            surplus_boxes << box
          elsif ((@width - box.width).abs <= EPS && @length + @saw_kerf + box.length <= @maxlength)
            @length = @length + @saw_kerf + box.length
            @sboxes << box
          elsif (box.rotatable && (@width - box.length).abs <= EPS && @length + @saw_kerf + box.width <= @maxlength)
            box.rotate
            @length = @length + @saw_kerf + box.length
            @sboxes << box
          else
            surplus_boxes << box
          end
        end
        @sboxes.sort_by!(&:length).reverse!
      else
        raise(Packing2DError, "Superbox length is empty, cannot stack!")
      end
      return surplus_boxes
    end

    #
    # Stacks identical elements in boxes until maxwidth is reached.
    # Boxes passed in should all have the same length.
    # Returns the elements that could not be stacked.
    #
    def stack_width(boxes)
      surplus_boxes = []
      # We have a first element in the superbox
      if @sboxes.size == 1
        @shape = SW
        until boxes.empty?
          box = boxes.shift
          #puts("next box to consider" + box.to_str)
          # Reject boxes than do not have the same rotatable
          if box.rotatable != @rotatable
            surplus_boxes << box
          elsif ((@length - box.length).abs <= EPS && @width + @saw_kerf + box.width <= @maxwidth)
            @width =  @width + @saw_kerf + box.width
            #puts("adding nr" + box.to_str)
            @sboxes << box
          elsif (box.rotatable && (@length - box.width).abs <= EPS && @width + @saw_kerf + box.length <= @maxwidth)
            box.rotate
            @width =  @width + @saw_kerf + box.width
            #puts("adding r " + box.to_str)
            @sboxes << box
          else
            surplus_boxes << box
          end
        end
        @sboxes.sort_by!(&:width).reverse!
      else
        raise(Packing2DError, "Superbox width is empty, cannot stack!")
      end
      return surplus_boxes
    end

=begin
    #
    # Reduces this superbox by one element, the last
    # and smallest.
    #
    def _reduce
      if @shape == SL
        if @sboxes.size > 1
          # Splat operator
          *@sboxes, last = @sboxes
          @length = @length - last.length - @saw_kerf
          return last, self
        else
          return @sboxes[0], nil
        end
      elsif @shape == SW
        if @sboxes.size > 1
          # Splat operator
          *@sboxes, last = @sboxes
          @width = @width - last.width - @saw_kerf
          return last, self
        else
          return @sboxes[0], nil
        end
      else
        raise(Packing2DError, "Trying to reduce a superbox with an unknown shape!")
      end
    end
=end

    #
    # Reduces this superbox by one element, the
    # first and largest.
    #
    def reduce
      if @shape == SL
        if @sboxes.size > 1
          # Splat operator
          first, *@sboxes = @sboxes
          @length = @length - first.length - @saw_kerf
          return first, self
        else
          return @sboxes[0], nil
        end
      elsif @shape == SW
        if @sboxes.size > 1
          # Splat operator
          first, *@sboxes = @sboxes
          @width = @width - first.width - @saw_kerf
          return first, self
        else
          return @sboxes[0], nil
        end
      else
        raise(Packing2DError, "Trying to reduce a superbox with an unknown shape!")
      end
    end

    def UNUSED_reduce
      if @shape == SL
        slice_size = (@sboxes.size/2.0).ceil
        groups = @sboxes.each_slice(slice_size).to_a
        first = groups[0]
        @sboxes = groups[1]
        if !@sboxes.nil? && @sboxes.size > 0
          @length = @sboxes.inject(0) { |sum, box| sum + box.length } + (@sboxes.size - 1)*@saw_kerf
          return first, self
        else
          return first, nil
        end
      elsif @shape == SW
        slice_size = (@sboxes.size/2.0).ceil
        groups = @sboxes.each_slice(slice_size).to_a
        first = groups[0]
        @sboxes = groups[1]
        if !@sboxes.nil? && @sboxes.size > 0
         @length = @sboxes.inject(0) { |sum, box| sum + box.length } + (@sboxes.size - 1)*@saw_kerf
         return first, self
        else
          return first, nil
        end
      else
        raise(Packing2DError, "Trying to reduce a superbox with an unknown shape!")
      end
    end

    #
    # Rotates the superbox by 90deg degree if option permits
    # and shape is still valid. Also rotates all contained boxes.
    #
    def rotate
      if @rotatable
        # TODO do we need to check for valid shape?
        #if (@width <= @maxlength && @length <= @maxwidth)
          @width, @length = [@length, @width]
          @rotated = !@rotated
          @sboxes.each(&:rotate)
          @shape = SL ? SW : SL
          return true
        #end
      end
      # on anything else!
      return false
    end

    #
    # Debugging!
    #
    def to_str
      s = "superbox shape=#{@shape}, x=#{@x}, y=#{@y}, length=#{@length}, width=#{@width}, "
      s += "count=#{@sboxes.size}, rotated=#{@rotated}/#{@rotatable}"
      return s
    end
  end
end
