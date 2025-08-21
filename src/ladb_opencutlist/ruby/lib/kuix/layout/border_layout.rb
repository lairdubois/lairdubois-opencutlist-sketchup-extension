module Ladb::OpenCutList::Kuix

  class BorderLayoutData

    CENTER = 0
    NORTH = 1
    EAST = 2
    WEST = 3
    SOUTH = 4

    attr_accessor :position

    def initialize(position)
      @position = position
    end

    # --

    def to_s
      "#{self.class.name} (position=#{@position})"
    end

  end

  class BorderLayout

    def initialize(horizontal_gap = 0, vertical_gap = 0)
      @horizontal_gap = horizontal_gap.to_i
      @vertical_gap = vertical_gap.to_i
    end

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

      top_height = 0
      right_width = 0
      bottom_height = 0
      left_width = 0
      center_width = 0
      center_height = 0

      north_entity = nil
      west_entity = nil
      east_entity = nil
      south_entity = nil
      center_entity = nil

      # Loop on children
      entity = target.child
      until entity.nil?
        if entity.visible?

          if entity.layout_data.is_a?(BorderLayoutData)

            case entity.layout_data.position
            when BorderLayoutData::NORTH
              north_entity = entity
            when BorderLayoutData::WEST
              west_entity = entity
            when BorderLayoutData::EAST
              east_entity = entity
            when BorderLayoutData::SOUTH
              south_entity = entity
            else
              if center_entity.nil?
                center_entity = entity
              end
            end

          elsif center_entity.nil?
            center_entity = entity
          end

        end
        entity = entity.next
      end

      # Compute gap values
      vertical_top_gap = (!north_entity.nil? && (!west_entity.nil? || !center_entity.nil? || !east_entity.nil? || !south_entity.nil?)) ? @vertical_gap : 0
      vertical_bottom_gap = (!south_entity.nil? && (!west_entity.nil? || !center_entity.nil? || !east_entity.nil?)) ? @vertical_gap : 0
      horizontal_left_gap = (!west_entity.nil? && (!center_entity.nil? || !east_entity.nil?)) ? @horizontal_gap : 0
      horizontal_right_gap = (!east_entity.nil? && (!center_entity.nil? || !west_entity.nil?)) ? @horizontal_gap : 0

      total_horizontal_gap = horizontal_left_gap + horizontal_right_gap
      total_vertical_gap = vertical_top_gap + vertical_bottom_gap

      # North
      if north_entity
        prefered_size = north_entity.get_preferred_size(available_width)
        center_width = prefered_size.width
        top_height = prefered_size.height
      end

      # West
      if west_entity
        prefered_size = west_entity.get_preferred_size(available_width - total_horizontal_gap)
        left_width = prefered_size.width
        center_height = prefered_size.height
      end

      # East
      if east_entity
        prefered_size = east_entity.get_preferred_size(available_width - left_width - total_horizontal_gap)
        right_width = prefered_size.width
        center_height = [ center_height, prefered_size.height].max
      end

      # South
      if south_entity
        prefered_size = south_entity.get_preferred_size(available_width)
        center_width = [ center_width, prefered_size.width ].max
        bottom_height = prefered_size.height
      end

      # Center
      if center_entity
        prefered_size = center_entity.get_preferred_size(available_width - left_width - right_width - total_horizontal_gap)
        center_width = [ center_width, prefered_size.width ].max
        center_height = [ center_height, prefered_size.height].max
      end

      if layout

        center_width = available_width - left_width - right_width - total_horizontal_gap
        center_height = available_height - top_height - bottom_height - total_vertical_gap

        # Center
        if center_entity
          center_entity.bounds.set!(
            left_width + horizontal_left_gap,
            top_height + vertical_top_gap,
            center_width,
            center_height
          )
          center_entity.do_layout
        end

        # North
        if north_entity
          north_entity.bounds.set!(
            0,
            0,
            available_width,
            top_height
          )
          north_entity.do_layout
        end

        # West
        if west_entity
          west_entity.bounds.set!(
            0,
            top_height + vertical_top_gap,
            left_width,
            center_height
          )
          west_entity.do_layout
        end

        # East
        if east_entity
          east_entity.bounds.set!(
            available_width - right_width,
            top_height + vertical_top_gap,
            right_width,
            center_height
          )
          east_entity.do_layout
        end

        # South
        if south_entity
          south_entity.bounds.set!(
            0,
            available_height - bottom_height,
            available_width,
            bottom_height
          )
          south_entity.do_layout
        end

      else
        size.set!(
          insets.left + [ target.min_size.width, left_width + center_width + right_width + total_horizontal_gap ].max + insets.right,
          insets.top + [ target.min_size.height, top_height + center_height + bottom_height + total_vertical_gap ].max + insets.bottom
        )
      end

    end

  end

end