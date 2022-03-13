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
      @gap = Gap.new(horizontal_gap, vertical_gap)
    end

    def measure_prefered_size(target, prefered_width, size)
      _compute(target, prefered_width, size, false)
    end

    def do_layout(target)
      _compute(target, target.bounds.width, nil, true)
    end

    # -- Internals --

    def _compute(target, preferred_width, size, layout)

      insets = target.get_insets
      available_width = preferred_width - insets.left - insets.right
      available_height = target.bounds.height - insets.top - insets.bottom

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
            if center_widget.nil?
              center_widget = widget
            end
          end

        elsif center_widget.nil?
          center_widget = widget
        end

        widget = widget.next
      end

      # Compute gap values
      vertical_top_gap = (!north_widget.nil? && (!west_widget.nil? || !center_widget.nil? || !east_widget.nil? || !south_widget.nil?)) ? @gap.vertical : 0
      vertical_bottom_gap = (!south_widget.nil? && (!west_widget.nil? || !center_widget.nil? || !east_widget.nil?)) ? @gap.vertical : 0
      horizontal_left_gap = (!west_widget.nil? && (!center_widget.nil? || !east_widget.nil?)) ? @gap.horizontal : 0
      horizontal_right_gap = (!east_widget.nil? && (!center_widget.nil? || !west_widget.nil?)) ? @gap.horizontal : 0

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
          center_widget.bounds.set(
            left_width + horizontal_left_gap,
            top_height + vertical_top_gap,
            center_width,
            center_height
          )
          center_widget.do_layout
        end

        # North
        if north_widget
          north_widget.bounds.set(
            0,
            0,
            available_width,
            top_height
          )
          north_widget.do_layout
        end

        # West
        if west_widget
          west_widget.bounds.set(
            0,
            top_height + vertical_top_gap,
            left_width,
            center_height
          )
          west_widget.do_layout
        end

        # East
        if east_widget
          east_widget.bounds.set(
            available_width - right_width,
            top_height + vertical_top_gap,
            right_width,
            center_height
          )
          east_widget.do_layout
        end

        # South
        if south_widget
          south_widget.bounds.set(
            0,
            available_height - bottom_height,
            available_width,
            bottom_height
          )
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