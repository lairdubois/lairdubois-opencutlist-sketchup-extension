module Ladb::OpenCutList::Kuix

  class InlineLayout

    def initialize(horizontal = true, gap = 0, anchor = nil)
      @horizontal = horizontal
      @gap = gap.to_i
      @anchor = anchor
    end

    def measure_preferred_size(target, prefered_width, size)
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

      content_bounds = Bounds2d.new

      child_defs = []

      # 1st Loop on children
      entity = target.child
      until entity.nil?
        if entity.visible?

          preferred_size = entity.get_preferred_size(available_width)
          child_defs.push({
                            :entity => entity,
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
        entity = entity.next
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
        if @anchor.right?
          content_bounds.origin.x = available_width - content_bounds.size.width
        elsif @anchor.vertical_center?
          content_bounds.origin.x = (available_width - content_bounds.size.width) / 2
        end
        if @anchor.bottom?
          content_bounds.origin.y = available_height - content_bounds.size.height
        elsif @anchor.horizontal_center?
          content_bounds.origin.y = (available_height - content_bounds.size.height) / 2
        end
      end

      if layout

        x = content_bounds.origin.x
        y = content_bounds.origin.y

        # Loop on precomputed child defs
        child_defs.each do |child_def|

          entity = child_def[:entity]
          preferred_size = child_def[:preferred_size]

          entity.bounds.set!(
            x,
            y,
            @horizontal ? preferred_size.width : content_bounds.size.width,
            @horizontal ? content_bounds.size.height : preferred_size.height
          )
          entity.do_layout

          if @horizontal
            x += preferred_size.width + @gap
          else
            y += preferred_size.height + @gap
          end

        end

      else
        size.set!(
          insets.left + [ target.min_size.width, content_bounds.size.width ].max + insets.right,
          insets.top + [ target.min_size.height, content_bounds.size.height ].max + insets.bottom
        )
      end
    end

  end

end