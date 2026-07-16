module Ladb::OpenCutList::Geometrix

  require_relative '../utils/distance_utils'

  module PointFinder

    # Finds the centroid of the given points: the arithmetic mean of their
    # X, Y and Z coordinates. For a polygon it matches the vertex average,
    # not the area-weighted center of mass.
    #
    # @param [Array<Geom::Point3d>] points
    #
    # @return [Geom::Point3d|nil]
    #
    def self.find_centroid(points)
      return nil unless points.is_a?(Array)
      return nil if points.empty?

      sum_x = 0
      sum_y = 0
      sum_z = 0

      # Iterate over each point to add its coordinates.
      points.each do |point|
        sum_x += point.x
        sum_y += point.y
        sum_z += point.z
      end

      num_points = points.length

      # Centroid
      Geom::Point3d.new(
        sum_x.to_f / num_points,
        sum_y.to_f / num_points,
        sum_z.to_f / num_points
      )
    end

    # Finds the pole of inaccessibility: the interior point farthest from all
    # boundaries (outer loop and holes). Equivalent to the center of the
    # largest inscribed circle.
    #  Input points are only considered as 2D points. Z of the first point is propagated to the result.
    #
    # Based on: Mapbox Polylabel (https://github.com/mapbox/polylabel)
    # Complexity: O(n * log(1/epsilon) * log(n))
    #
    # @param [Array<Geom::Point3d>] points the outer loop
    # @param [Array<Array<Geom::Point3d>>] holes optional hole loops
    # @param [Float] precision epsilon factor relative to the initial cell size
    #
    # @return [Geom::Point3d|nil]
    #
    def self.find_pole_of_inaccessibility(points, holes = [], precision = 0.001)
      return nil unless points.is_a?(Array)
      return nil if points.empty?

      z = points.first.z
      loops = [ points ] + holes

      x_min, x_max = points.map(&:x).minmax
      y_min, y_max = points.map(&:y).minmax

      width = x_max - x_min
      height = y_max - y_min
      cell_size = [ width, height ].min

      return Geom::Point3d.new(x_min, y_min, z) if cell_size == 0

      # A cell covers a square of side 2*half centred on (x, y).
      # dist = signed distance from center to the nearest boundary segment:
      #        positive if inside the shape, negative if outside.
      # max  = maximum achievable dist for any point in this cell
      #      = dist + half * sqrt(2)  (distance to the farthest corner).

      # Max-heap ordered on CellDef#max: explore the most-promising cells first.
      queue = []

      # Seed with a grid of cells covering the full bounding box.
      h = cell_size / 2.0
      x = x_min
      while x < x_max
        y = y_min
        while y < y_max
          _heap_push(queue, _make_cell(loops, x + h, y + h, h))
          y += cell_size
        end
        x += cell_size
      end

      # Initialize the best candidate with the bounding-box centroid.
      best = _make_cell(loops, (x_min + x_max) / 2.0, (y_min + y_max) / 2.0, 0.0)

      # Stop refining when no cell can beat the best by more than epsilon.
      epsilon = cell_size * precision

      until queue.empty?
        cell = _heap_pop(queue)

        best = cell if cell.dist > best.dist

        # Prune: this cell cannot improve on the current best.
        next if cell.max - best.dist <= epsilon

        # Subdivide into 4 quadrants and enqueue each.
        h = cell.half / 2.0
        _heap_push(queue, _make_cell(loops, cell.x - h, cell.y - h, h))
        _heap_push(queue, _make_cell(loops, cell.x + h, cell.y - h, h))
        _heap_push(queue, _make_cell(loops, cell.x - h, cell.y + h, h))
        _heap_push(queue, _make_cell(loops, cell.x + h, cell.y + h, h))
      end

      Geom::Point3d.new(best.x, best.y, z)
    end

    # -----

    CellDef = Struct.new(:x, :y, :half, :dist, :max)

    # -----

    private

    # Builds a cell and computes its signed distance to the boundary.
    #
    # @param [Array<Array<Geom::Point3d>>] loops
    # @param [Float] x
    # @param [Float] y
    # @param [Float] half
    #
    # @return [CellDef]
    #
    def self._make_cell(loops, x, y, half)
      dist = DistanceUtils.signed_distance_to_boundary(loops, x, y)
      CellDef.new(x, y, half, dist, dist + half * SQRT2)
    end

    # Pushes a cell onto the binary max-heap (ordered on CellDef#max).
    #
    # @param [Array<CellDef>] heap
    # @param [CellDef] cell
    #
    def self._heap_push(heap, cell)
      heap << cell
      i = heap.length - 1
      while i > 0
        parent = (i - 1) / 2
        break if heap[parent].max >= heap[i].max
        heap[parent], heap[i] = heap[i], heap[parent]
        i = parent
      end
    end

    # Pops the cell with the highest CellDef#max from the binary max-heap.
    #
    # @param [Array<CellDef>] heap
    #
    # @return [CellDef]
    #
    def self._heap_pop(heap)
      top = heap[0]
      last = heap.pop
      unless heap.empty?
        heap[0] = last
        i = 0
        length = heap.length
        loop do
          left = 2 * i + 1
          right = left + 1
          largest = i
          largest = left if left < length && heap[left].max > heap[largest].max
          largest = right if right < length && heap[right].max > heap[largest].max
          break if largest == i
          heap[largest], heap[i] = heap[i], heap[largest]
          i = largest
        end
      end
      top
    end

  end

end