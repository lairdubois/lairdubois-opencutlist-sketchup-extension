module Ladb::OpenCutList::Kuix

  class Widget

    attr_accessor :id
    attr_accessor :x, :y, :width, :height
    attr_reader :margin, :border, :padding, :gap
    attr_reader :min_size
    attr_accessor :background_color, :border_color, :color
    attr_accessor :parent, :child, :last_child, :next, :previous
    attr_accessor :layout, :layout_data

    def initialize(id = nil)

      @id = id

      @x = 0
      @y = 0
      @width = 0
      @height = 0

      @margin = Inset.new
      @border = Inset.new
      @padding = Inset.new
      @gap = Gap.new

      @min_size = Size.new

      @background_color = nil
      @border_color = nil
      @color = nil

      @parent = nil
      @child = nil
      @last_child = nil

      @next = nil
      @previous = nil

      @invalidated = true

      @layout = nil
      @layout_data = nil

    end

    def to_s
      "#{self.class.name} (id=#{@id}, x=#{x}, y=#{y}, width=#{width}, height=#{height})"
    end

    # --

    def get_insets
      Inset.new(
        @margin.top + @border.top + @padding.top,
        @margin.right + @border.right + @padding.right,
        @margin.bottom + @border.bottom + @padding.bottom,
        @margin.left + @border.left + @padding.left
      )
    end

    def get_prefered_size(prefered_width)
      size = Size.new
      if @layout
        @layout.measure_prefered_size(self, prefered_width, size)
      else
        insets = self.get_insets
        size.set(
          insets.left + @min_size.width + insets.right,
          insets.top + @min_size.height + insets.bottom
        )
      end
      size
    end

    # -- DOM --

    # Append given widget to self and returns self
    def append(widget)

      # Remove widget from previous parent
      if widget.parent
        widget.remove
      end

      # Append widget to linked list
      widget.parent = self
      @last_child.next = widget if @last_child
      widget.previous = @last_child
      @child = widget unless @child
      @last_child = widget

      # Invalidate self
      invalidate

      # Returns self
      self
    end

    # Remove self widget from its parent and returns parent
    def remove
      return unless @parent
      if @parent.child == self
        @parent.child = @next
      end
      if @parent.last_child == self
        @parent.last_child = @previous
      end
      unless @previous.nil?
        @previous.next = @next
      end
      unless @next.nil?
        @next.previous = @previous
        @next = nil
      end
      @previous = nil
      parent = @parent
      @parent = nil
      parent.invalidate
      parent
    end

    def remove_all
      unless @child
        widget = @child
        until widget.nil?
          widget.next = widget.previous = widget.parent = null
          widget = widget.next
        end
        @child = nil
        @last_child = nil
        invalidate
      end
    end

    # -- Layout --

    def invalidate
      @invalidated = true
      if @parent && !@parent.is_invalidated?
        @parent.invalidate
      end
    end

    def is_invalidated?
      @invalidated
    end

    def do_layout
      if @layout
        @layout.do_layout(self)
      end
      @invalidated = false
    end

    # -- Render --

    def paint(graphics)

      graphics.translate(@x + @margin.left, @y + @margin.top)
      paint_border(graphics)

      graphics.translate(@border.left, @border.top)
      paint_background(graphics)

      graphics.translate(@padding.left, @padding.top)
      paint_content(graphics)

      graphics.translate(-@x - @margin.left - @border.left - @padding.left, -@y - @margin.top - @border.top - @padding.top)
      paint_sibling(graphics)

    end

    def paint_border(graphics)
      if @border_color

        width = @width - @margin.left - @margin.right
        height = @height - @margin.top - @margin.bottom

        graphics.set_drawing_color(@border_color)
        graphics.draw_rect(0, 0, width - @border.right, @border.top)
        graphics.draw_rect(0 + width - @border.right, 0, @border.right, height - @border.bottom)
        graphics.draw_rect(0 + @border.left, 0 + height - @border.bottom, width - @border.left, @border.bottom)
        graphics.draw_rect(0, 0 + @border.top, @border.left, height - @border.top)
      end
    end

    def paint_background(graphics)
      if @background_color

        width = @width - @margin.left - @border.left - @margin.right - @border.right
        height = @height - @margin.top - @border.top - @margin.bottom - @border.bottom

        graphics.draw_rect(0, 0, width, height, @background_color)
      end
    end

    def paint_content(graphics)
      if @child
        @child.paint(graphics)
      end
    end

    def paint_sibling(graphics)
      if @next
        @next.paint(graphics)
      end
    end

  end

end