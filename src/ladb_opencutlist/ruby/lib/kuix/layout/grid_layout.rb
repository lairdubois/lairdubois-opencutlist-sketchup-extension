module Ladb::OpenCutList::Kuix

  class GridLayout

    def initialize(num_cols = 1, num_rows = 1)
      @num_cols = num_cols
      @num_rows = num_rows
    end

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
      horizontal_gap = gap.horizontal * (@num_cols - 1)
      vertical_gap = gap.vertical * (@num_rows - 1)

      cell_width = (available_width - horizontal_gap) / @num_cols
      cell_height = (available_height - vertical_gap) / @num_rows

      col = 0
      row = 0
      prefered_cell_width = 0
      prefered_cell_height = 0

      # Loop on children
      widget = target.child
      until widget.nil?

        if layout
          widget.x = col * (cell_width + gap.horizontal)
          widget.y = row * (cell_height + gap.vertical)
          widget.width = cell_width
          widget.height = cell_height
          widget.do_layout
        else
          prefered_size = widget.get_prefered_size(available_width)
          prefered_cell_width = [ prefered_cell_width, prefered_size.width ].max
          prefered_cell_height = [ prefered_cell_height, prefered_size.width ].max
        end

        col += 1
        if col >= @num_cols
          col = 0
          row += 1
          if row >= @num_rows
            break
          end
        end

        widget = widget.next
      end

      unless layout
        size.set(
          insets.left + [ target.min_size.width, prefered_cell_width * @num_cols + horizontal_gap ].max + insets.right,
          insets.top + [ target.min_size.height, prefered_cell_height * @num_rows + vertical_gap ].max + insets.bottom
        )
      end

    end

  end

end