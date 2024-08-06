require_relative '../clipper_wrapper'

module Ladb::OpenCutList::Fiddle

  module Clippy
    extend ClipperWrapper

    CLIP_TYPE_NONE = 0
    CLIP_TYPE_INTERSECTION = 1
    CLIP_TYPE_UNION = 2
    CLIP_TYPE_DIFFERENCE = 3
    CLIP_TYPE_XOR = 4

    FILL_TYPE_EVEN_ODD = 0
    FILL_TYPE_NON_ZERO = 1
    FILL_TYPE_POSITIVE = 2
    FILL_TYPE_NEGATIVE = 3

    CPathsDSolution = struct [ 'double* closed_paths', 'double* open_paths', 'int error' ]
    CPolyTreeDSolution = struct [ 'double* polytree', 'double* open_paths', 'int error' ]

    def self._lib_name
      'Clippy'
    end

    def self._lib_c_functions
      [

        'CPathsDSolution* c_boolean_op(uint8_t clip_type, uint8_t fill_type, double* closed_paths, double* open_paths, double* clips)',
        'CPolyTreeDSolution* c_boolean_op_polytree(uint8_t clip_type, uint8_t fill_type, double* closed_paths, double* open_paths, double* clips)',

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

    def self.execute_union(closed_subjects: [], open_subjects: [], clips: [])
      self.execute(
        clip_type: CLIP_TYPE_UNION,
        fill_type: FILL_TYPE_NON_ZERO,
        closed_subjects: closed_subjects,
        open_subjects: open_subjects,
        clips: clips
      )
    end

    def self.execute_difference(closed_subjects: [], open_subjects: [], clips:)
      self.execute(
        clip_type: CLIP_TYPE_DIFFERENCE,
        fill_type: FILL_TYPE_NON_ZERO,
        closed_subjects: closed_subjects,
        open_subjects: open_subjects,
        clips: clips
      )
    end

    def self.execute_intersection(closed_subjects: [], open_subjects: [], clips:)
      self.execute(
        clip_type: CLIP_TYPE_INTERSECTION,
        fill_type: FILL_TYPE_NON_ZERO,
        closed_subjects: closed_subjects,
        open_subjects: open_subjects,
        clips: clips
      )
    end

    def self.execute_polytree(clip_type: CLIP_TYPE_UNION, fill_type: FILL_TYPE_NON_ZERO, closed_subjects:, open_subjects: [], clips: [])
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

    private

    def self._unpack_closed_paths_solution

      # Retrieve solution's pointer
      cpaths = c_get_closed_paths_solution

      # Convert to rpath
      rpaths, len = _cpaths_to_rpaths(cpaths)

      # Dispose pointer
      c_dispose_array_d(cpaths)

      rpaths
    end

    def self._unpack_open_paths_solution

      # Retrieve solution's pointer
      cpaths = c_get_open_paths_solution

      # Convert to rpath
      rpaths, len = _cpaths_to_rpaths(cpaths)

      # Dispose pointer
      c_dispose_array_d(cpaths)

      rpaths
    end

    def self._unpack_polytree_solution

      # Retrieve solution's pointer
      cpolytree = c_get_polytree_solution

      # Convert to rpath
      rpolytree, len = _cpolytree_to_rpolytree(cpolytree)

      # Dispose pointer
      c_dispose_array_d(cpolytree)

      rpolytree
    end

  end

end
