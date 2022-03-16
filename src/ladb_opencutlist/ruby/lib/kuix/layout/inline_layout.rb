module Ladb::OpenCutList::Kuix

  class InlineLayout

    def initialize(horizontal = true, gap = 0, anchor = nil)
      @horizontal = horizontal
      @gap = gap
      @anchor = anchor
    end

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

      child_defs = []

      # 1st Loop on children
      widget = target.child
      until widget.nil?
        if widget.visible?

          preferred_size = widget.get_prefered_size(available_width)
          child_defs.push({
                            :widget => widget,
                            :preferred_size => preferred_size
                          })

          if @horizontal
            content_bounds.size.width += preferred_size.width
            content_bounds.size.height = [ preferred_size.height, content_bounds.size.height ].max
          else
            content_bounds.size.width = [ preferred_size.width, content_bounds.size.width ].max
            content_bounds.size.height += preferred_size.height
          end

        end
        widget = widget.next
      end

      # Gap
      if child_defs.length > 1
        if @horizontal
          content_bounds.size.width += @gap * (child_defs.length - 1)
        else
          content_bounds.size.height += @gap * (child_defs.length - 1)
        end
      end

      # Anchor
      if @anchor
        if @anchor.is_right?
          content_bounds.origin.x = available_width - content_bounds.size.width
        elsif @anchor.is_vertical_center?
          content_bounds.origin.x = (available_width - content_bounds.size.width) / 2
        end
        if @anchor.is_bottom?
          content_bounds.origin.y = available_height - content_bounds.size.height
        elsif @anchor.is_horizontal_center?
          content_bounds.origin.y = (available_height - content_bounds.size.height) / 2
        end
      end

      if layout

        x = content_bounds.origin.x
        y = content_bounds.origin.y

        # Loop on precomputed child defs
        child_defs.each do |child_def|

          widget = child_def[:widget]
          preferred_size = child_def[:preferred_size]

          widget.bounds.set(
            x,
            y,
            @horizontal ? preferred_size.width : content_bounds.size.width,
            @horizontal ? content_bounds.size.height : preferred_size.height
          )
          widget.do_layout

          if @horizontal
            x += preferred_size.width + @gap
          else
            y += preferred_size.height + @gap
          end

        end

      else
        size.set(
          insets.left + [ target.min_size.width, content_bounds.size.width ].max + insets.right,
          insets.top + [ target.min_size.height, content_bounds.size.height ].max + insets.bottom
        )
      end
    end

  end

end