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

    CMyStruct = struct [ 'char* msg', 'int* values', 'int error' ]
    CPathsDSolution = struct [ 'double* closed_paths', 'double* open_paths', 'int error' ]
    CPolyTreeDSolution = struct [ 'double* polytree', 'double* open_paths', 'int error' ]

    def self._lib_name
      'Clippy'
    end

    def self._lib_c_functions
      [

        'CPathsDSolution* c_boolean_op(uint8_t, uint8_t, double*, double*, double*)',
        'CPolyTreeDSolution* c_boolean_op_polytree(uint8_t, uint8_t, double*, double*, double*)',

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

    def self.doit
      _load_lib

      CMyStruct.malloc(Fiddle::RUBY_FREE) do |solution|

        puts "solution.class = #{solution.class}"

        c_doit(solution)

        values = solution.values.to_str(Fiddle::SIZEOF_INT * 2).unpack('l*')

        puts "solution.msg = #{solution.msg}"
        puts "solution.values = #{values}"
        puts "solution.error = #{solution.error}"

      end

    end

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

  end

end
