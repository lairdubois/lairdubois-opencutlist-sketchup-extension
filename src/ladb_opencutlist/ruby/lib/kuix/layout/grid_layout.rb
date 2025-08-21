module Ladb::OpenCutList::Kuix

  class GridLayoutData

    attr_accessor :col_span

    def initialize(col_span = 1)
      @col_span = [col_span.to_i, 1 ].max
    end

  end

  class GridLayout

    def initialize(num_cols = 1, num_rows = 1, horizontal_gap = 0, vertical_gap = 0)
      @num_cols = [ num_cols.to_i, 1 ].max
      @num_rows = [ num_rows.to_i, 1 ].max
      @horizontal_gap = horizontal_gap.to_i
      @vertical_gap = vertical_gap.to_i
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

      total_horizontal_gap = @horizontal_gap * (@num_cols - 1)
      total_vertical_gap = @vertical_gap * (@num_rows - 1)

      cell_width = (available_width - total_horizontal_gap) / @num_cols
      cell_height = (available_height - total_vertical_gap) / @num_rows

      col = 0
      row = 0
      preferred_cell_width = 0
      preferred_cell_height = 0

      # Loop on children
      entity = target.child
      until entity.nil?
        if entity.visible?

          if entity.layout_data && entity.layout_data.is_a?(GridLayoutData)
            col_span = [ entity.layout_data.col_span, @num_cols - col ].min
          else
            col_span = 1
          end

          if layout
            entity.bounds.set!(
              col * (cell_width + @horizontal_gap),
              row * (cell_height + @vertical_gap),
              cell_width * col_span + @horizontal_gap * (col_span - 1),
              cell_height
            )
            entity.do_layout
          else
            preferred_size = entity.get_preferred_size(available_width)
            preferred_cell_width = [ preferred_cell_width, preferred_size.width ].max
            preferred_cell_height = [ preferred_cell_height, preferred_size.height ].max
          end

          col += col_span
          if col >= @num_cols
            col = 0
            row += 1
            if row >= @num_rows
              break
            end
          end

        end
        entity = entity.next
      end

      unless layout
        size.set!(
          insets.left + [ target.min_size.width, preferred_cell_width * @num_cols + total_horizontal_gap ].max + insets.right,
          insets.top + [ target.min_size.height, preferred_cell_height * @num_rows + total_vertical_gap ].max + insets.bottom
        )
      end

    end

  end

end