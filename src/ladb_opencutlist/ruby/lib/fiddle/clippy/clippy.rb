require_relative '../wrapper'

module Ladb::OpenCutList::Fiddle

  module Clippy
    extend Wrapper

    # https://angusj.com/clipper2/Docs/Units/Clipper/Types/ClipType.htm
    CLIP_TYPE_NO_CLIP = 0
    CLIP_TYPE_INTERSECTION = 1
    CLIP_TYPE_UNION = 2
    CLIP_TYPE_DIFFERENCE = 3
    CLIP_TYPE_XOR = 4

    # https://angusj.com/clipper2/Docs/Units/Clipper/Types/FillRule.htm
    FILL_TYPE_EVEN_ODD = 0
    FILL_TYPE_NON_ZERO = 1
    FILL_TYPE_POSITIVE = 2
    FILL_TYPE_NEGATIVE = 3

    # https://angusj.com/clipper2/Docs/Units/Clipper/Types/JoinType.htm
    JOIN_TYPE_SQUARE = 0
    JOIN_TYPE_BEVEL = 1
    JOIN_TYPE_ROUND = 2
    JOIN_TYPE_MITER = 3

    # https://angusj.com/clipper2/Docs/Units/Clipper/Types/EndType.htm
    END_TYPE_POLYGON = 0
    END_TYPE_JOINED = 1
    END_TYPE_BUTT = 2
    END_TYPE_SQUARE = 3
    END_TYPE_ROUND = 4

    # https://www.angusj.com/clipper2/Docs/Units/Clipper/Types/PointInPolygonResult.htm
    POINT_IN_POLYGON_RESULT_IS_ON = 0
    POINT_IN_POLYGON_RESULT_IS_INSIDE = 1
    POINT_IN_POLYGON_RESULT_IS_OUTSIDE = 2

    CPathsDSolution = struct [ 'double* closed_paths', 'double* open_paths', 'int error' ]
    CPolyTreeDSolution = struct [ 'double* polytree', 'double* open_paths', 'int error' ]

    def self._lib_name
      'Clippy'
    end

    def self._lib_c_functions
      [

        'CPathsDSolution* c_boolean_op(unsigned char, unsigned char, double*, double*, double*)',
        'CPolyTreeDSolution* c_boolean_op_polytree(unsigned char, unsigned char, double*, double*, double*)',

        'CPathsDSolution* c_inflate_paths(double*, double, unsigned char, unsigned char, double, double, int, int)',

        'int c_is_cpath_positive(double*)',
        'double c_get_cpath_area(double*)',

        'int c_is_point_on_polygon(double, double, double*)',
        'int c_is_mid_point_on_polygon(double, double, double, double, double*)',

        'void c_dispose_paths_solution(CPathsDSolution*)',
        'void c_dispose_polytree_solution(CPolyTreeDSolution*)',

        'char* c_version()'

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # -----

    def self.execute(
      clip_type:,
      fill_type: FILL_TYPE_NON_ZERO,
      closed_subjects:,
      open_subjects: [],
      clips: []
    )
      _load_lib

      solution_ptr = c_boolean_op(
        clip_type,
        fill_type,
        _rpaths_to_cpaths(closed_subjects),
        _rpaths_to_cpaths(open_subjects),
        _rpaths_to_cpaths(clips)
      )
      solution = CPathsDSolution.new(solution_ptr)

      closed_rpath, len = _cpaths_to_rpaths(solution.closed_paths)
      open_rpath, len = _cpaths_to_rpaths(solution.open_paths)

      c_dispose_paths_solution(solution_ptr)

      [ closed_rpath, open_rpath ]
    end

    def self.execute_union(
      closed_subjects: [],
      open_subjects: [],
      clips: []
    )
      self.execute(
        clip_type: CLIP_TYPE_UNION,
        fill_type: FILL_TYPE_NON_ZERO,
        closed_subjects: closed_subjects,
        open_subjects: open_subjects,
        clips: clips
      )
    end

    def self.execute_difference(
      closed_subjects: [],
      open_subjects: [],
      clips:
    )
      self.execute(
        clip_type: CLIP_TYPE_DIFFERENCE,
        fill_type: FILL_TYPE_NON_ZERO,
        closed_subjects: closed_subjects,
        open_subjects: open_subjects,
        clips: clips
      )
    end

    def self.execute_intersection(
      closed_subjects: [],
      open_subjects: [],
      clips:
    )
      self.execute(
        clip_type: CLIP_TYPE_INTERSECTION,
        fill_type: FILL_TYPE_NON_ZERO,
        closed_subjects: closed_subjects,
        open_subjects: open_subjects,
        clips: clips
      )
    end

    def self.execute_polytree(
      clip_type: CLIP_TYPE_UNION,
      fill_type: FILL_TYPE_NON_ZERO,
      closed_subjects:,
      open_subjects: [],
      clips: []
    )
      _load_lib

      solution_ptr = c_boolean_op_polytree(
        clip_type,
        fill_type,
        _rpaths_to_cpaths(closed_subjects),
        _rpaths_to_cpaths(open_subjects),
        _rpaths_to_cpaths(clips)
      )
      solution = CPolyTreeDSolution.new(solution_ptr)

      rpolytree, len = _cpolytree_to_rpolytree(solution.polytree)

      c_dispose_polytree_solution(solution_ptr)

      rpolytree
    end

    def self.inflate_paths(
      paths:,
      delta:,
      join_type: JOIN_TYPE_SQUARE,
      end_type: END_TYPE_POLYGON,
      miter_limit: 2.0,
      arc_tolerance: 1e6,
      preserve_collinear: false,
      reverse_solution: false
    )
      _load_lib

      solution_ptr = c_inflate_paths(
        _rpaths_to_cpaths(paths),
        delta,
        join_type,
        end_type,
        miter_limit,
        arc_tolerance,
        preserve_collinear ? 1 : 0,
        reverse_solution ? 1 : 0
      )
      solution = CPathsDSolution.new(solution_ptr)

      closed_rpaths, len = _cpaths_to_rpaths(solution.closed_paths)

      c_dispose_paths_solution(solution_ptr)

      closed_rpaths
    end

    def self.is_rpath_positive?(rpath)
      _load_lib
      return c_is_cpath_positive(_rpath_to_cpath(rpath)) == 1
    end

    def self.get_rpath_area(rpath)
      _load_lib
      return c_get_cpath_area(_rpath_to_cpath(rpath))
    end

    def self.is_point_on_polygon(x, y, rpath)
      _load_lib
      return c_is_point_on_polygon(x, y, _rpath_to_cpath(rpath)) == 1
    end

    def self.is_mid_point_on_polygon(x1, y1, x2, y2, rpath)
      _load_lib
      return c_is_mid_point_on_polygon(x1, y1, x2, y2, _rpath_to_cpath(rpath)) == 1
    end

    # -- Path manipulations --

    def self.reverse_rpath(rpath)
      rpath.each_slice(2).to_a.reverse.flatten(1)
    end

    def self.reverse_rpaths(rpaths)
      rpaths.map { |rpath| reverse_rpath(rpath) }
    end

    def self.similar_rpath?(rpath1, rpath2)
      return true if rpath1 == rpath2
      return true if rpath1.length == rpath2.length && (rpath1 - rpath2).empty?
      false
    end

    # Delete all paths from d_rpaths that are similar to s_rpaths
    def self.delete_rpaths_in(s_rpaths, d_rpaths)
      s_rpaths.delete_if { |s_rpath| d_rpaths.select { |d_rpath| Clippy.similar_rpath?(d_rpath, s_rpath) }.length > 0 }
    end

    # -- Path conversions --

    # Convert Array<Geom::Point3d> to Array<Integer> (x1, y1, x2, y2, ...)
    def self.points_to_rpath(points)
      points.flat_map { |point| [ point.x, point.y ] }
    end

    # Convert Array<Integer> (x1, y1, x2, y2, ...) to Array<Geom::Point3d>
    def self.rpath_to_points(rpath, z = 0.0)
      points = []
      rpath.each_slice(2) { |coord_x, coord_y| points << Geom::Point3d.new(coord_x, coord_y, z) } if rpath.is_a?(Array)
      points
    end

    # -- Polyshapes --

    # Convert PolyTree to Array<PolyShape>
    # PolyShape first path is outer others are holes
    def self.polytree_to_polyshapes(polytree)
      polyshapes = []
      stack = [ [ polytree, nil ] ]
      until stack.empty?
        current_node, current_polyshape = stack.pop
        if current_node.is_a?(PolyPath)
          if current_node.hole?
            current_polyshape.paths << current_node.path if current_polyshape && current_polyshape.paths.any?
          else
            current_polyshape = PolyShape.new([ current_node.path ])
            polyshapes << current_polyshape
          end
        end
        current_node.children.each do |child|
          stack.push([ child, current_polyshape ])
        end
      end
      polyshapes
    end

    private

    # --- Ruby to C

    def self._array_to_ptr_double(array)
      Fiddle::Pointer[array.pack('d*')]  # d* to write double-precision, native format (double)
    end

    def self._array_prepend_n_0_counter(array, period = 2)
      [ array.count / period, 0 ].concat(array)
    end

    # Returns Fiddle::Pointer
    def self._rpath_to_cpath(rpath)
      _array_to_ptr_double(_array_prepend_n_0_counter(rpath))
    end

    # Returns Fiddle::Pointer
    def self._rpaths_to_cpaths(rpaths)
      len = 2 ; rpaths.each { |rpath| len += 2 + rpath.length }   # .sum {...} incompatible with ruby < 2.4
      _array_to_ptr_double([ len, rpaths.length ].concat(rpaths.flat_map { |rpath| _array_prepend_n_0_counter(rpath) }))
    end

    # --- C to Ruby

    def self._ptr_double_to_array(ptr, cnt)
      ptr.to_str(Fiddle::SIZEOF_DOUBLE * cnt).unpack('d*') # d* to read double-precision, native format (double)
    end

    def self._ptr_double_offset(ptr, offset = 0)
      ptr + offset * Fiddle::SIZEOF_DOUBLE
    end

    # Returns Array<Integer>
    def self._cpath_to_rpath(cpath)
      n, zero = _ptr_double_to_array(cpath, 2)
      [ _ptr_double_to_array(_ptr_double_offset(cpath, 2), n * 2), 2 + n * 2 ] # Returns RPath and its data length
    end

    # Returns Array<Array<Integer>>
    def self._cpaths_to_rpaths(cpaths)
      l, n = _ptr_double_to_array(cpaths, 2)
      cur = 2
      rpaths = []
      n.to_i.times do
        rpath, len = _cpath_to_rpath(_ptr_double_offset(cpaths, cur))
        rpaths << rpath
        cur += len
      end
      [ rpaths, cur ] # Returns RPaths and cumulative data length
    end

    def self._cpolytree_to_rpolytree(cpolytree)
      l, c = _ptr_double_to_array(cpolytree, 2)
      cur = 2
      rpolypaths = []
      c.to_i.times do
        rpolypath, len = _read_cpolypath_to_rpolypath(_ptr_double_offset(cpolytree, cur))
        rpolypaths << rpolypath
        cur += len
      end
      [ PolyTree.new(rpolypaths), cur ] # Returns PolyTree and its data length
    end

    def self._read_cpolypath_to_rpolypath(cpolypath, level = 0)
      n, c = _ptr_double_to_array(cpolypath, 2)
      cur = 2
      rpath = _ptr_double_to_array(_ptr_double_offset(cpolypath, cur), n * 2)
      cur += n * 2
      rpolypaths = []
      c.to_i.times do
        rpolypath, len = _read_cpolypath_to_rpolypath(_ptr_double_offset(cpolypath, cur), level + 1)
        rpolypaths << rpolypath
        cur += len
      end
      [ PolyPath.new(rpath, level, rpolypaths), cur ] # Returns PolyPath and its data length
    end

    # -----

    PolyTree = Struct.new(:children)

    PolyPath = Struct.new(:path, :level, :children) do

      def hole?
        level.odd? # First level is 0
      end

    end

    PolyShape = Struct.new(:paths)

  end

end
