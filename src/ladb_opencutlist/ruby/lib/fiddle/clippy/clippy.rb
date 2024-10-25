require_relative '../clipper_wrapper'

module Ladb::OpenCutList::Fiddle

  module Clippy
    extend ClipperWrapper

    # https://angusj.com/clipper2/Docs/Units/Clipper/Types/ClipType.htm
    CLIP_TYPE_NONE = 0
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

    def self.execute(clip_type:, fill_type: FILL_TYPE_NON_ZERO, closed_subjects:, open_subjects: [], clips: [])
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

  end

end
