module Ladb::OpenCutList::Kuix

  class StaticLayoutData

    attr_accessor :x, :y, :width, :height

    def initialize(x = 0, y = 0, width = -1, height = -1)
      @x = x
      @y = y
      @width = width
      @height = height
    end

    def to_s
      "#{self.class.name} (x=#{@x}, y=#{@y}, width=#{@width}, height=#{@height})"
    end

  end

  class StaticLayout

    def measure_prefered_size(target, prefered_width, size)
      _measure(target, prefered_width, size, false)
    end

    def do_layout(target)
      _measure(target, target.width, nil, true)
    end

    # -- Internals --

    def _measure(target, preferred_width, size, layout)

      insets = target.get_insets
      available_width = preferred_width - insets.left - insets.right
      available_height = target.height - insets.top - insets.bottom

      content_metrics = Metrics.new

      widget = target.child
      until widget.nil?

        preferred_size = widget.get_prefered_size(available_width)

        if widget.layout_data && widget.layout_data.is_a?(StaticLayoutData)
          widget_x = widget.layout_data.x
          widget_y = widget.layout_data.y
          if widget.layout_data.width < 0
            widget_width = preferred_size.width
          else
            widget_width = [ widget.layout_data.width, preferred_size.width ].max
          end
          if widget.layout_data.height < 0
            widget_height = preferred_size.height
          else
            widget_height = [ widget.layout_data.height, preferred_size.height ].max
          end
        else
          widget_x = 0
          widget_y = 0
          widget_width = preferred_size.width
          widget_height = preferred_size.height
        end

        if layout
          widget.x = widget_x
          widget.y = widget_y
          widget.width = widget_width
          widget.height = widget_height
          widget.do_layout
        end

        content_metrics.add(widget_x, widget_y, widget_width, widget_height)

        widget = widget.next
      end

      unless layout
        size.set(
          insets.left + [ target.min_size.width, content_metrics.width ].max + insets.right,
          insets.top + [ target.min_size.height, content_metrics.height ].max + insets.bottom
        )
      end

    end

  end

end