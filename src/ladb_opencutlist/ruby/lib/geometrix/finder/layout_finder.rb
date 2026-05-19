module Ladb::OpenCutList::Geometrix

  module LayoutFinder

    OVERLAP_THRESHOLD = 0.5

    def self.find_layout_debug(spacing = 0)

      require_relative '../../../utils/transformation_utils'

      grain_groups = {}

      fn_explore = lambda { |container, grain_group_container = nil, transformation = IDENTITY, path = []|

        case container
        when Sketchup::Model
          entities = container.active_entities
        when Sketchup::Group
          entities = container.entities
        when Sketchup::ComponentInstance
          entities = container.definition.entities
        else
          return
        end

        instance_attributes = Ladb::OpenCutList::InstanceAttributes.new(container)

        grain_group_container = container if instance_attributes.is_grain_group

        if entities.none? { |e| e.respond_to?(:definition) }

          return unless instance_attributes.is_grain_item

          grain_group = grain_groups[grain_group_container] ||= []
          grain_group << [ container, transformation, path ]

        else

          transformation *= container.transformation if container.respond_to?(:transformation)
          path += [ container ]

          entities.each { |e|
            fn_explore.call(e, grain_group_container, transformation, path)
          }

        end

      }

      fn_explore.call(Sketchup.active_model)

      grain_groups.each do |grain_group_container, items|
        puts "----"
        puts "#{grain_group_container.respond_to?(:name) ? grain_group_container.name : 'Global'}"
        puts " "
        items.group_by { |e, transformation, path|
          t = transformation * e.transformation
          x_axis = X_AXIS.transform(t).normalize
          y_axis = Y_AXIS.transform(t).normalize
          z_axis = Z_AXIS.transform(t).normalize
          [
            x_axis.to_a.map { |v| v.round(3) },
            y_axis.to_a.map { |v| v.round(3) },
            z_axis.to_a.map { |v| v.round(3) }
          ]
        }.each do |axes, items|
          puts "-> #{axes}"
          layout_def = find_layout(items.map { |e, transformation, path|

            t = transformation * e.transformation
            x_axis = X_AXIS.transform(t)
            y_axis = Y_AXIS.transform(t)
            z_axis = Z_AXIS.transform(t)
            at = Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis)
            ati = at.inverse

            # Ladb::OpenCutList::TransformationUtils.print(at)

            bounds = Geom::BoundingBox.new
            bounds.add(e.definition.entities.grep(Sketchup::Face).flat_map { |face| face.outer_loop.vertices.map(&:position) })

            min = bounds.min
            max = bounds.max
            v = min.vector_to(max)

            position = min.transform(t).transform(ati)
            position.z = 0
            vx = Geom::Vector3d.new(v.x, 0, 0).transform(ati)
            vy = Geom::Vector3d.new(0, v.y, 0).transform(ati)

            # Sketchup.active_model.active_entities.add_line(position, position + [ vx.length, vy.length ])

            BoxDef.new(position.x, position.y, vx.length, vy.length, data: (path + [e]).map { |e| e.name.empty? ? nil : e.name }.compact.join('/'))

          })

          puts layout_def.inspect

          boxes = layout(layout_def, spacing: spacing)

          puts "Boxes: #{boxes.size}"

          main_group = Sketchup.active_model.active_entities.add_group

          boxes.each_with_index do |box, i|
            puts "#{i}: #{box.x}, #{box.y}, #{box.width}, #{box.height}"

            box_group = main_group.entities.add_group
            box_group.name = box.id
            box_group.entities.add_face(
              [ box.x, box.y ],
              [ box.x + box.width, box.y ],
              [ box.x + box.width, box.y + box.height ],
              [ box.x, box.y + box.height ]
            )

          end

        end
        puts "----"
      end

      nil
    end

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
    # @param [Array<BoxDef>] boxes
    #
    # @return [LayoutDef]
    #
    def self.find_layout(boxes)
      nodes, direction = _build_node(boxes)
      return LayoutDef.new(nodes, direction)
    end

    def self.layout(layout_def, origin_x: 0, origin_y: 0, spacing: 0)
      return [] unless layout_def.is_a?(LayoutDef)

      preferred_width, preferred_height = _compute_preferred_size(layout_def.nodes, direction: layout_def.direction, spacing: spacing)

      _build_boxes(
        layout_def.nodes,
        origin_x: origin_x,
        origin_y: origin_y,
        available_width: preferred_width,
        available_height: preferred_height,
        direction: layout_def.direction,
        spacing: spacing
      )
    end

    # -----


    private

    # -- Find utils

    def self._split_into_rows(boxes)
      n = boxes.size
      parent = _create_uf(n)

      boxes.each_with_index do |bi, i|
        boxes.each_with_index do |bj, j|
          next if i >= j
          _uf_union(parent, i, j) if _intervals_overlap?(bi.y, bi.y_max, bj.y, bj.y_max)
        end
      end

      rows = _uf_groups(parent, boxes)
      # Sort rows from top to bottom
      rows.sort_by { |row| -row.map(&:y_max).max }
    end

    def self._split_into_columns(boxes)
      n = boxes.size
      parent = _create_uf(n)

      boxes.each_with_index do |bi, i|
        boxes.each_with_index do |bj, j|
          next if i >= j
          _uf_union(parent, i, j) if _intervals_overlap?(bi.x, bi.x_max, bj.x, bj.x_max)
        end
      end

      cols = _uf_groups(parent, boxes)
      # Sort columns from left to right
      cols.sort_by { |col| col.map(&:x).min }
    end

    def self._build_node(boxes, depth = 0)

      direction = :col

      # Split into lines
      rows = _split_into_rows(boxes)

      if rows.one?

        # Only one line: Split into columns
        cols = _split_into_columns(boxes)

        if cols.one?
          # Impossible to split further: return boxes
          nodes = boxes.one? ? boxes.first : boxes
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

    # -- Layout utils

    def self._compute_preferred_size(node, direction: :col, spacing: 0)
      if node.is_a?(BoxDef)
        [ node.width, node.height ]
      elsif node.is_a?(Array)
        child_direction = (direction == :col) ? :row : :col
        preferred_sizes = node.map { |child| _compute_preferred_size(child, direction: child_direction, spacing: spacing) }
        if direction == :col
          [ preferred_sizes.map(&:first).max, preferred_sizes.map(&:last).sum + spacing * (node.size - 1) ]
        else
          [ preferred_sizes.map(&:first).sum + spacing * (node.size - 1), preferred_sizes.map(&:last).max ]
        end
      else
        raise "Invalide node : #{node.inspect}"
      end
    end

    def self._build_boxes(node, origin_x:, origin_y:, available_width:, available_height:, direction: :col, spacing: 0, boxes: [])
      if node.is_a?(BoxDef)
        boxes << BoxDef.new(origin_x, origin_y + available_height - node.height, node.width, node.height, data: node.data)

      elsif node.is_a?(Array)
        child_direction = (direction == :col) ? :row : :col
        preferred_sizes = node.map { |child| _compute_preferred_size(child, direction: child_direction, spacing: spacing) }

        if direction == :col
          cursor_y = origin_y + available_height
          node.each_with_index do |child, i|
            _, child_h = preferred_sizes[i]
            cursor_y -= child_h
            _build_boxes(child,
                         origin_x: origin_x,
                         origin_y: cursor_y,
                         available_width: available_width,
                         available_height: child_h,
                         direction: child_direction,
                         spacing: spacing,
                         boxes: boxes
            )
            cursor_y -= spacing
          end
        else
          cursor_x = origin_x
          node.each_with_index do |child, i|
            child_w, _ = preferred_sizes[i]
            _build_boxes(child,
                         origin_x: cursor_x,
                         origin_y: origin_y,
                         available_width: child_w,
                         available_height: available_height,
                         direction: child_direction,
                         spacing: spacing,
                         boxes: boxes
            )
            cursor_x += child_w + spacing
          end
        end
      end

      boxes
    end

  end

  # -----

  class BoxDef

    attr_reader :x, :y, :width, :height,
                :data

    def initialize(x, y, width, height, data: nil)
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