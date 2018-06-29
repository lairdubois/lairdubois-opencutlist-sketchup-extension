module Ladb::OpenCutList::BinPacking2D
  
  class SuperBox < Box

    attr_accessor :boxes, :saw_kerf, :all_elements_same_dimensions
    
    def initialize(length, width, saw_kerf, data = nil)
      super(length, width, data)
      @saw_kerf = saw_kerf

      @boxes = []
      @box_length = nil
      @box_width = nil
      @all_elements_same_dimensions = false
      @stack_is_horizontal = true
      @has_internal_rotation = false
      
    end

    def is_horizontal?
      return @stack_is_horizontal
    end
    
    def has_internal_rotation?
      return @has_internal_rotation
    end
    
    # should call this clone
    def copy
      sbox = self.clone
      sbox.boxes = []
      sbox.all_elements_same_dimensions = @all_elements_same_dimensions
      @boxes.each { |box| sbox.boxes << box.copy }
      return sbox
    end
    
    def all_same?
      return @all_elements_same_dimensions
    end
    
    # Stack box horizontally. The container box is the bounding
    # box of the contained boxes in @sboxes
    #
    def stack_length(box)
      @length += @saw_kerf if @length > 0
      @length += box.length
      if @box_length.nil?
        @box_length = box.length
        @all_elements_same_dimensions = true
      elsif @box_length == box.length
        @all_elements_same_dimensions = true
      else
        @all_elements_same_dimensions = false
      end
      
      @boxes << box
      @stack_is_horizontal = true
    end

    # Stack box vertically. The container box is the bounding
    # box of the contained boxes in @sboxes
    #
    def stack_width(box)
      @width += @saw_kerf if @width > 0
      @width += box.width
      if @box_width.nil?
        @box_width = box.width
        @all_elements_same_dimensions = true
      elsif @box_width == box.width
        @all_elements_same_dimensions = true
      else
        @all_elements_same_dimensions = false
      end
      
      @boxes << box
      @stack_is_horizontal = false
    end
    
    def rotate
      @width, @length = [@length, @width]
      @is_rotated = !@is_rotated      
      @boxes.each do |box|
        box.rotate
      end      
      return self
    end
    
    # Rotate the elements internally, we assume that the caller
    # has checked that the material is rotatable
    #
    def internal_rotate() 
      if @all_elements_same_dimensions
        @boxes.each do |box|
          box.rotate
        end
        if @stack_is_horizontal
          @length = @boxes[0].length*@boxes.length() + (@boxes.length() - 1)*@saw_kerf
          @width = @boxes[0].width
        else
          @length = @boxes[0].length
          @width = @boxes[0].width*@boxes.length() + (@boxes.length() - 1)*@saw_kerf
        end
        @has_internal_rotation = true
      end
    end
    
    def internally_rotated_dimensions()
      if @all_elements_same_dimensions
        if @stack_is_horizontal
          length = @boxes[0].width*@boxes.length() + (@boxes.length() - 1)*@saw_kerf
          width = @boxes[0].length
        else
          length = @boxes[0].width
          width = @boxes[0].length*@boxes.length() + (@boxes.length() - 1)*@saw_kerf
        end
        return length, width
      end
    end

    # Reduce the size of a supergroup. If it contains more than
    # 2 elements, remove just the last one. 
    # When called, we know that we are a a superbox, no need to check
    #
    # UNUSED FOR NOW!!
    def reduce_supergroup(saw_kerf)
      boxes = []
      if @boxes.length() > 2
        *@boxes, last = @boxes
        if @stack_is_horizontal
          @length = @length - last.length - saw_kerf
        else
          @width = @width - last.width - saw_kerf
        end
        boxes.unshift(last)
        boxes.unshift(self) # we are still a valid superbox
      else
        @boxes.each do |box|
          boxes.unshift(box)
        end
      end
      return boxes
    end

  end
end
