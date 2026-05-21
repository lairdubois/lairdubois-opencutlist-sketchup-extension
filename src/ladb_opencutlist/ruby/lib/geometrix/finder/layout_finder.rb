module Ladb::OpenCutList::Geometrix

  module LayoutFinder

    OVERLAP_THRESHOLD = 0.5

    # Detection of the layout of boxes in nested rows/columns.
    #
    # Strategy: First, the ROWS (overlapping horizontal bands Y) are detected.
    # Then, within each row, the boxes are sorted from top to bottom.
    # If a "row" contains columns of different sizes, they are recursively grouped.
    #
    # Y
    # ^
    # |
    # +------------------+
    # |        A         |
    # +---+--------------+
    # | B |              |
    # +---+       D      +
    # | C |              |
    # +---+--------------+--> X
    #
    #
    # Input: BoxDefs (x, y = bottom-left corner (y upwards), width, height = dimensions)
    # Output: LayoutDef (direction = :row, nodes = [ "A", [ ["B", "C"], "D" ] ])
    #
    # @param [Array<BoxDef>] box_defs
    #
    # @return [LayoutDef]
    #
    def self.find_layout(box_defs)
      nodes, direction = _build_node(box_defs)
      return LayoutDef.new(nodes, direction)
    end

    # Iterate on the BoxDefs of a layout.
    #
    # @param [LayoutDef] layout_def
    #
    # @yield [BoxDef]
    #
    def self.iterate_on_box_defs(layout_def, &block)
      _iterate_on_nodes(layout_def.nodes, &block)
    end

    # Arrange boxes in a grid.
    # The grid is defined by the layout_def.
    #
    # @param [LayoutDef] layout_def
    # @param [Float] origin_x
    # @param [Float] origin_y
    # @param [Float] spacing
    #
    # @return [preferred_width, preferred_height, Array<BoxDef>]
    #
    def self.layout(layout_def, origin_x: 0, origin_y: 0, spacing: 0)
      return [] unless layout_def.is_a?(LayoutDef)

      preferred_width, preferred_height = _compute_preferred_size(layout_def.nodes, direction: layout_def.direction, spacing: spacing)
      box_defs = _build_box_defs(
        layout_def.nodes,
        origin_x: origin_x,
        origin_y: origin_y,
        available_width: preferred_width,
        available_height: preferred_height,
        direction: layout_def.direction,
        spacing: spacing
      )

      [ preferred_width, preferred_height, box_defs ]
    end

    # -----

    private

    # -- Find utils

    def self._split_into_rows(box_defs)
      n = box_defs.size
      parent = _create_uf(n)

      box_defs.each_with_index do |bi, i|
        box_defs.each_with_index do |bj, j|
          next if i >= j
          _uf_union(parent, i, j) if _intervals_overlap?(bi.y, bi.y_max, bj.y, bj.y_max)
        end
      end

      rows = _uf_groups(parent, box_defs)
      # Sort rows from top to bottom
      rows.sort_by { |row| -row.map(&:y_max).max }
    end

    def self._split_into_columns(box_defs)
      n = box_defs.size
      parent = _create_uf(n)

      box_defs.each_with_index do |bi, i|
        box_defs.each_with_index do |bj, j|
          next if i >= j
          _uf_union(parent, i, j) if _intervals_overlap?(bi.x, bi.x_max, bj.x, bj.x_max)
        end
      end

      cols = _uf_groups(parent, box_defs)
      # Sort columns from left to right
      cols.sort_by { |col| col.map(&:x).min }
    end

    def self._build_node(box_defs, depth = 0)

      direction = :col

      # Split into lines
      rows = _split_into_rows(box_defs)

      if rows.one?

        # Only one line: Split into columns
        cols = _split_into_columns(box_defs)

        if cols.one?
          # Impossible to split further: return boxes
          nodes = box_defs.one? ? box_defs.first : box_defs
        else

          direction = :row

          # Recursion on each column
          col_nodes = cols.map { |col| nodes, _ = _build_node(col, depth + 1); nodes }
          nodes = col_nodes.one? ? col_nodes.first : col_nodes
        end

      else

        # Several lines: Recursion on each line
        row_nodes = rows.map { |row| nodes, _ = _build_node(row, depth + 1); nodes }
        nodes = row_nodes.one? ? row_nodes.first : row_nodes

      end

      [ nodes, direction ]
    end

    # Returns true if two intervals [ a0, a1 ] et [ b0, b1 ] overlap
    # at least `threshold` * min(a1 - a0, b1 - b0)
    def self._intervals_overlap?(a0, a1, b0, b1, threshold: OVERLAP_THRESHOLD)
      overlap = [ a1, b1 ].min - [ a0, b0 ].max
      min_len = [ a1 - a0, b1 - b0 ].min
      overlap > threshold * min_len
    end

    def self._create_uf(n)
      Array.new(n) { |i| i }
    end

    def self._uf_find(parent, i)
      parent[i] = _uf_find(parent, parent[i]) if parent[i] != i
      parent[i]
    end

    def self._uf_union(parent, a, b)
      ra, rb = _uf_find(parent, a), _uf_find(parent, b)
      parent[ra] = rb unless ra == rb
    end

    def self._uf_groups(parent, items)
      groups = Hash.new { |h, k| h[k] = [] }
      items.each_with_index { |item, i| groups[_uf_find(parent, i)] << item }
      groups.values
    end

    # -- Iterate utils

    def self._iterate_on_nodes(node, &block)
      if node.is_a?(BoxDef)
        block.call(node)
      elsif node.is_a?(Array)
        node.each { |child| _iterate_on_nodes(child, &block) }
      else
        raise "Invalide node : #{node.inspect}"
      end
    end

    # -- Layout utils

    def self._compute_preferred_size(node, direction: :col, spacing: 0)
      if node.is_a?(BoxDef)
        [ node.width, node.height ]
      elsif node.is_a?(Array)
        child_direction = (direction == :col) ? :row : :col
        preferred_sizes = node.map { |child| _compute_preferred_size(child, direction: child_direction, spacing: spacing) }
        if direction == :col
          [ preferred_sizes.map(&:first).max, preferred_sizes.map(&:last).inject(0) { |sum, height| sum + height } + spacing * (node.size - 1) ]
        else
          [ preferred_sizes.map(&:first).inject(0) { |sum, width| sum + width } + spacing * (node.size - 1), preferred_sizes.map(&:last).max ]
        end
      else
        raise "Invalide node : #{node.inspect}"
      end
    end

    def self._build_box_defs(node, origin_x:, origin_y:, available_width:, available_height:, direction: :col, spacing: 0, box_defs: [])
      if node.is_a?(BoxDef)
        box_defs << BoxDef.new(origin_x, origin_y + available_height - node.height, node.width, node.height, data: node.data)

      elsif node.is_a?(Array)
        child_direction = (direction == :col) ? :row : :col
        preferred_sizes = node.map { |child| _compute_preferred_size(child, direction: child_direction, spacing: spacing) }

        if direction == :col
          cursor_y = origin_y + available_height
          node.each_with_index do |child, i|
            _, child_h = preferred_sizes[i]
            cursor_y -= child_h
            _build_box_defs(child,
                            origin_x: origin_x,
                            origin_y: cursor_y,
                            available_width: available_width,
                            available_height: child_h,
                            direction: child_direction,
                            spacing: spacing,
                            box_defs: box_defs
            )
            cursor_y -= spacing
          end
        else
          cursor_x = origin_x
          node.each_with_index do |child, i|
            child_w, _ = preferred_sizes[i]
            _build_box_defs(child,
                            origin_x: cursor_x,
                            origin_y: origin_y,
                            available_width: child_w,
                            available_height: available_height,
                            direction: child_direction,
                            spacing: spacing,
                            box_defs: box_defs
            )
            cursor_x += child_w + spacing
          end
        end
      end

      box_defs
    end

  end

  # -----

  class BoxDef

    attr_accessor :x, :y, :width, :height,
                  :data

    def initialize(x = 0, y = 0, width = 0, height = 0, data: nil)
      @x = x
      @y = y
      @width = width
      @height = height
      @data = data
    end

    def x_max
      @x + @width
    end

    def y_max
      @y + @height
    end

    def inspect
      @data.inspect
    end

  end

  class LayoutDef

    attr_reader :nodes,
                :direction

    def initialize(nodes, direction)
      @nodes = nodes
      @direction = direction
    end

    def inspect
      "#{self.class.name}\n" +
      " Direction=#{@direction}\n" +
      " Nodes=#{@nodes.inspect}"
    end

  end

end