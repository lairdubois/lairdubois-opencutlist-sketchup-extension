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

  class StaticLayoutDataWithSnap < StaticLayoutData

    attr_accessor :snap_position

    def initialize(snap_position, width = -1, height = -1, anchor = nil)
      super(0, 0, width, height, anchor)

      @snap_position = snap_position

    end

  end

  class StaticLayout

    def measure_preferred_size(target, preferred_width, size)
      _compute(target, preferred_width, size, false)
    end

    def do_layout(target)
      _compute(target, target.bounds.width, nil, true)
    end

    # -- Internals --

    def _compute(target, preferred_width, size, layout)

      insets = target.insets
      available_width = preferred_width - insets.left - insets.right
      available_height = target.bounds.height - insets.top - insets.bottom

      content_bounds = Bounds2d.new unless layout

      # Loop on children
      entity = target.child
      until entity.nil?
        if entity.visible?

          preferred_size = entity.get_preferred_size(available_width)
          entity_bounds = Bounds2d.new

          if entity.layout_data.is_a?(StaticLayoutData)

            if entity.layout_data.is_a?(StaticLayoutDataWithSnap)

              model = Sketchup.active_model
              entity_bounds.origin.copy!(model.active_view.screen_coords(entity.layout_data.snap_position)) unless model.nil?

            else

              # X
              if entity.layout_data.x.is_a?(Float) && entity.layout_data.x <= 1.0
                entity_bounds.origin.x = available_width * entity.layout_data.x
              else
                entity_bounds.origin.x = entity.layout_data.x
              end

              # Y
              if entity.layout_data.y.is_a?(Float) && entity.layout_data.y <= 1.0
                entity_bounds.origin.y = available_height * entity.layout_data.y
              else
                entity_bounds.origin.y = entity.layout_data.y
              end

            end

            # Width
            if entity.layout_data.width < 0
              entity_bounds.size.width = preferred_size.width
            elsif entity.layout_data.width.is_a?(Float) && entity.layout_data.width <= 1.0
              entity_bounds.size.width = available_width * entity.layout_data.width
            else
              entity_bounds.size.width = [ entity.layout_data.width, preferred_size.width ].max
            end

            # Height
            if entity.layout_data.height < 0
              entity_bounds.size.height = preferred_size.height
            elsif entity.layout_data.height.is_a?(Float) && entity.layout_data.height <= 1.0
              entity_bounds.size.height = available_height * entity.layout_data.height
            else
              entity_bounds.size.height = [ entity.layout_data.height, preferred_size.height ].max
            end

            # Anchor
            if entity.layout_data.anchor
              if entity.layout_data.anchor.right?
                entity_bounds.origin.x -= entity_bounds.size.width
              elsif entity.layout_data.anchor.vertical_center?
                entity_bounds.origin.x -= entity_bounds.size.width / 2
              end
              if entity.layout_data.anchor.bottom?
                entity_bounds.origin.y -= entity_bounds.size.height
              elsif entity.layout_data.anchor.horizontal_center?
                entity_bounds.origin.y -= entity_bounds.size.height / 2
              end
            end

          else
            entity_bounds.origin.x = 0
            entity_bounds.origin.y = 0
            entity_bounds.size.width = preferred_size.width
            entity_bounds.size.height = preferred_size.height
          end

          if layout
            entity.bounds.copy!(entity_bounds)
            entity.do_layout
          else
            content_bounds.union!(entity_bounds)
          end

        end
        entity = entity.next
      end

      unless layout
        size.set!(
          insets.left + [ target.min_size.width, content_bounds.width ].max + insets.right,
          insets.top + [ target.min_size.height, content_bounds.height ].max + insets.bottom
        )
      end

    end

  end

end