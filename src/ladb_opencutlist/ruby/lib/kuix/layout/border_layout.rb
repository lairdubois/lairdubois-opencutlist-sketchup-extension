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

  end

  class BorderLayout

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

      gap = target.gap

      top_height = 0
      right_width = 0
      bottom_height = 0
      left_width = 0
      center_width = 0
      center_height = 0

      north_widget = nil
      west_widget = nil
      east_widget = nil
      south_widget = nil
      center_widget = nil

      # Loop on children
      widget = target.child
      until widget.nil?

        if widget.layout_data && widget.layout_data.is_a?(BorderLayoutData)

          case widget.layout_data.position
          when BorderLayoutData::NORTH
            north_widget = widget
          when BorderLayoutData::WEST
            west_widget = widget
          when BorderLayoutData::EAST
            east_widget = widget
          when BorderLayoutData::SOUTH
            south_widget = widget
          else
            center_widget = widget
          end

        elsif center_widget.nil?
          center_widget = widget
        end

        widget = widget.next
      end

      # Compute gap values
      vertical_top_gap = (!north_widget.nil? && (!west_widget.nil? || !center_widget.nil? || !east_widget.nil? || !south_widget.nil?)) ? gap.vertical : 0
      vertical_bottom_gap = (!south_widget.nil? && (!west_widget.nil? || !center_widget.nil? || !east_widget.nil?)) ? gap.vertical : 0
      horizontal_left_gap = (!west_widget.nil? && (!center_widget.nil? || !east_widget.nil?)) ? gap.horizontal : 0
      horizontal_right_gap = (!east_widget.nil? && (!center_widget.nil? || !west_widget.nil?)) ? gap.horizontal : 0

      vertical_gap = vertical_top_gap + vertical_bottom_gap
      horizontal_gap = horizontal_left_gap + horizontal_right_gap

      # North
      if north_widget
        prefered_size = north_widget.get_prefered_size(available_width)
        center_width = prefered_size.width
        top_height = prefered_size.height
      end

      # West
      if west_widget
        prefered_size = west_widget.get_prefered_size(available_width - horizontal_gap)
        left_width = prefered_size.width
        center_height = prefered_size.height
      end

      # East
      if east_widget
        prefered_size = east_widget.get_prefered_size(available_width - left_width - horizontal_gap)
        right_width = prefered_size.width
        center_height = [ center_height, prefered_size.height].max
      end

      # South
      if south_widget
        prefered_size = south_widget.get_prefered_size(available_width)
        center_width = [ center_width, prefered_size.width ].max
        bottom_height = prefered_size.height
      end

      # Center
      if center_widget
        prefered_size = center_widget.get_prefered_size(available_width - left_width - right_width - horizontal_gap)
        center_width = [ center_width, prefered_size.width ].max
        center_height = [ center_height, prefered_size.height].max
      end

      if layout

        center_width = available_width - left_width - right_width - horizontal_gap
        center_height = available_height - top_height - bottom_height - vertical_gap

        # Center
        if center_widget
          center_widget.x = left_width + horizontal_left_gap
          center_widget.y = top_height + vertical_top_gap
          center_widget.width = center_width
          center_widget.height = center_height
          center_widget.do_layout
        end

        # North
        if north_widget
          north_widget.x = 0
          north_widget.y = 0
          north_widget.width = available_width
          north_widget.height = top_height
          north_widget.do_layout
        end

        # West
        if west_widget
          west_widget.x = 0
          west_widget.y = top_height + vertical_top_gap
          west_widget.width = left_width
          west_widget.height = center_height
          west_widget.do_layout
        end

        # East
        if east_widget
          east_widget.x = available_width - right_width
          east_widget.y = top_height + vertical_top_gap
          east_widget.width = right_width
          east_widget.height = center_height
          east_widget.do_layout
        end

        # South
        if south_widget
          south_widget.x = 0
          south_widget.y = available_height - bottom_height
          south_widget.width = available_width
          south_widget.height = bottom_height
          south_widget.do_layout
        end

      else
        size.set(
          insets.left + [ target.min_size.width, left_width + center_width + right_width + horizontal_gap ].max + insets.right,
          insets.top + [ target.min_size.height, top_height + center_height + bottom_height + vertical_gap ].max + insets.bottom
        )
      end

    end

  end

end