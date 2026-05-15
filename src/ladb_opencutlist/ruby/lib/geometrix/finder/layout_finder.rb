module Ladb::OpenCutList::Geometrix

  module LayoutFinder

    OVERLAP_THRESHOLD = 0.5

    def self.find_layout_debug
      Sketchup.active_model.active_entities.group_by(&:layer)
              .each do |layer, entities|
        next if layer.name == 'layer0'
        puts "----"
        puts "#{layer.name}"
        puts find_layout(entities.map { |e| BoxDef.new(e.bounds.min.x, e.bounds.min.y, e.bounds.width, e.bounds.height, id: e.name) }).inspect
        puts "----"
      end
      nil
    end

    # Detection of the layout of boxes in nested rows/columns.
    #
    # Strategy: First, the ROWS (overlapping horizontal bands Y) are detected.
    # Then, within each row, the boxes are sorted from top to bottom.
    # If a "row" contains columns of different sizes,
    # they are recursively grouped.
    #
    # +------------------+
    # |        A         |
    # +---+--------------+
    # | B |              |
    # +---+       D      +
    # | C |              |
    # +---+--------------+
    #
    # Input: BoxDefs (x, y = bottom-left corner (y upwards), width, height = dimensions)
    # Output: LayoutDef (direction = AXIS, nodes = [ "A", [ ["B", "C"], "D" ] ])
    #
    # @param [Array<BoxDef>] boxes
    #
    # @return [LayoutDef]
    #
    def self.find_layout(boxes)
      nodes, direction = _build_node(boxes)
      return LayoutDef.new(nodes, direction)
    end

    # -----

    private

    def self._split_into_rows(boxes)
      n = boxes.size
      parent = _make_uf(n)

      boxes.each_with_index do |bi, i|
        boxes.each_with_index do |bj, j|
          next if i >= j
          if _intervals_overlap?(bi.y, bi.y_max, bj.y, bj.y_max)
            _uf_union(parent, i, j)
          end
        end
      end

      rows = _uf_groups(parent, boxes)
      # Sort rows from top to bottom
      rows.sort_by { |row| -row.map(&:y_max).max }
    end

    def self._split_into_columns(boxes)
      n = boxes.size
      parent = _make_uf(n)

      boxes.each_with_index do |bi, i|
        boxes.each_with_index do |bj, j|
          next if i >= j
          if _intervals_overlap?(bi.x, bi.x_max, bj.x, bj.x_max)
            _uf_union(parent, i, j)
          end
        end
      end

      cols = _uf_groups(parent, boxes)
      # Sort columns from left to right
      cols.sort_by { |col| col.map(&:x).min }
    end

    def self._build_node(boxes, depth = 0)

      direction = Y_AXIS

      # Split into lines
      rows = _split_into_rows(boxes)

      if rows.one?

        # Only one line: Split into columns
        cols = _split_into_columns(boxes)

        if cols.one?
          # Impossible to split further: return boxes
          nodes = boxes.one? ? boxes.first : boxes
        else

          direction = X_AXIS

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
      overlap = [a1, b1].min - [a0, b0].max
      min_len = [a1 - a0, b1 - b0].min
      overlap > threshold * min_len
    end

    def self._make_uf(n)
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

  end

  # -----

  class BoxDef

    attr_reader :id, :x, :y, :width, :height

    def initialize(x, y, width, height, id: nil)
      @x = x
      @y = y
      @width = width
      @height = height
      @id = id
    end

    def x_max
      @x + @width
    end

    def y_max
      @y + @height
    end

    def inspect
      @id.to_s
    end

  end

  class LayoutDef

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