module Ladb::OpenCutList::Kuix

  class StaticLayoutData

    attr_accessor :x, :y, :width, :height, :anchor

    def initialize(x = 0, y = 0, width = -1, height = -1, anchor = nil)
      @x = x
      @y = y
      @width = width
      @height = height
      @anchor = anchor
    end

    # --

    def to_s
      "#{self.class.name} (x=#{@x}, y=#{@y}, width=#{@width}, height=#{@height})"
    end

  end

  class StaticLayout

    def measure_prefered_size(target, prefered_width, size)
      _compute(target, prefered_width, size, false)
    end

    def do_layout(target)
      _compute(target, target.bounds.width, nil, true)
    end

    # -- Internals --

    def _compute(target, preferred_width, size, layout)

      insets = target.insets
      available_width = preferred_width - insets.left - insets.right
      available_height = target.bounds.height - insets.top - insets.bottom

      content_bounds = Bounds.new

      widget = target.child
      until widget.nil?
        if widget.visible?

          preferred_size = widget.get_prefered_size(available_width)
          widget_bounds = Bounds.new

          if widget.layout_data && widget.layout_data.is_a?(StaticLayoutData)

            # X
            if widget.layout_data.x.is_a?(Float)
              widget_bounds.origin.x = available_width * widget.layout_data.x
            else
              widget_bounds.origin.x = widget.layout_data.x
            end

            # Y
            if widget.layout_data.y.is_a?(Float)
              widget_bounds.origin.y = available_height * widget.layout_data.y
            else
              widget_bounds.origin.y = widget.layout_data.y
            end

            # Width
            if widget.layout_data.width < 0
              widget_bounds.size.width = preferred_size.width
            elsif widget.layout_data.width.is_a?(Float)
              widget_bounds.size.width = available_width * widget.layout_data.width
            else
              widget_bounds.size.width = [ widget.layout_data.width, preferred_size.width ].max
            end

            # Height
            if widget.layout_data.height < 0
              widget_bounds.size.height = preferred_size.height
            elsif widget.layout_data.height.is_a?(Float)
              widget_bounds.size.height = available_height * widget.layout_data.height
            else
              widget_bounds.size.height = [ widget.layout_data.height, preferred_size.height ].max
            end

            # Anchor
            if widget.layout_data.anchor
              if widget.layout_data.anchor.is_right?
                widget_bounds.origin.x -= widget_bounds.size.width
              elsif widget.layout_data.anchor.is_vertical_center?
                widget_bounds.origin.x -= widget_bounds.size.width / 2
              end
              if widget.layout_data.anchor.is_bottom?
                widget_bounds.origin.y -= widget_bounds.size.height
              elsif widget.layout_data.anchor.is_horizontal_center?
                widget_bounds.origin.y -= widget_bounds.size.height / 2
              end
            end

          else
            widget_bounds.origin.x = 0
            widget_bounds.origin.y = 0
            widget_bounds.size.width = preferred_size.width
            widget_bounds.size.height = preferred_size.height
          end

          if layout
            widget.bounds.copy(widget_bounds)
            widget.do_layout
          end

          content_bounds.union(widget_bounds)

        end
        widget = widget.next
      end

      unless layout
        size.set(
          insets.left + [ target.min_size.width, content_bounds.width ].max + insets.right,
          insets.top + [ target.min_size.height, content_bounds.height ].max + insets.bottom
        )
      end

    end

  end

end