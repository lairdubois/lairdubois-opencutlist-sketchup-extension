require_relative '../clipper_wrapper'

module Ladb::OpenCutList::Fiddle

  module Clippy
    extend ClipperWrapper

    def self._lib_name
      "Clippy"
    end

    def self._lib_c_functions
      [

        'void c_clear_subjects()',
        'void c_append_open_subject(int64_t*)',
        'void c_append_closed_subject(int64_t*)',

        'void c_clear_clips()',
        'void c_append_clip(int64_t*)',

        'void c_execute_union()',
        'void c_execute_difference()',
        'void c_execute_intersection()',
        'void c_execute_polytree()',

        'void c_clear_paths_solution()',
        'int64_t* c_get_closed_paths_solution()',
        'int64_t* c_get_open_paths_solution()',
        'void c_clear_polytree_solution()',
        'int64_t* c_get_polytree_solution()',

        'int c_is_cpath_positive(int64_t*)',
        'double c_get_cpath_area(int64_t*)',

        'void c_dispose_array64(int64_t*)',

        'char* c_version()'

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # -----

    def self.execute_union(closed_subjects, open_subjects = [], clips = [])
      _load_lib
      _clear
      _append_closed_subjects(closed_subjects)
      _append_open_subjects(open_subjects)
      _append_clips(clips)
      _execute_union
      closed_paths_solution = _unpack_closed_paths_solution
      open_paths_solution = _unpack_open_paths_solution
      _clear
      [ closed_paths_solution, open_paths_solution ]
    end

    def self.execute_difference(closed_subjects, open_subjects, clips)
      _load_lib
      _clear
      _append_closed_subjects(closed_subjects)
      _append_open_subjects(open_subjects)
      _append_clips(clips)
      _execute_difference
      closed_paths_solution = _unpack_closed_paths_solution
      open_paths_solution = _unpack_open_paths_solution
      _clear
      [ closed_paths_solution, open_paths_solution ]
    end

    def self.execute_intersection(closed_subjects, open_subjects, clips)
      _load_lib
      _clear
      _append_closed_subjects(closed_subjects)
      _append_open_subjects(open_subjects)
      _append_clips(clips)
      _execute_intersection
      closed_paths_solution = _unpack_closed_paths_solution
      open_paths_solution = _unpack_open_paths_solution
      _clear
      [ closed_paths_solution, open_paths_solution ]
    end

    def self.execute_polytree(closed_subjects, open_subjects = [])
      _load_lib
      _clear
      _append_closed_subjects(closed_subjects)
      _append_open_subjects(open_subjects)
      _execute_polytree
      solution = _unpack_polytree_solution
      _clear
      solution
    end

    def self.is_rpath_positive?(rpath)
      _load_lib
      return c_is_cpath_positive(_rpath_to_cpath(rpath)) == 1
    end

    def self.get_rpath_area(rpath)
      _load_lib
      return c_get_cpath_area(_rpath_to_cpath(rpath)) / ClipperWrapper::FLOAT_TO_INT64_CONVERTER / ClipperWrapper::FLOAT_TO_INT64_CONVERTER
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

    def self._clear
      c_clear_subjects
      c_clear_clips
      c_clear_paths_solution
      c_clear_polytree_solution
    end

    def self._append_closed_subject(rpath)
      c_append_closed_subject(_rpath_to_cpath(rpath))
    end

    def self._append_closed_subjects(rpaths)
      rpaths.each do |rpath|
        _append_closed_subject(rpath)
      end
    end

    def self._append_open_subject(rpath)
      c_append_open_subject(_rpath_to_cpath(rpath))
    end

    def self._append_open_subjects(rpaths)
      rpaths.each do |rpath|
        _append_open_subject(rpath)
      end
    end

    def self._append_clip(rpath)
      c_append_clip(_rpath_to_cpath(rpath))
    end

    def self._append_clips(rpaths)
      rpaths.each do |rpath|
        _append_clip(rpath)
      end
    end

    def self._execute_union
      c_execute_union
    end

    def self._execute_difference
      c_execute_difference
    end

    def self._execute_intersection
      c_execute_intersection
    end

    def self._execute_polytree
      c_execute_polytree
    end

    def self._unpack_closed_paths_solution

      # Retrieve solution's pointer
      cpaths = c_get_closed_paths_solution

      # Convert to rpath
      rpaths = _cpaths_to_rpaths(cpaths)

      # Dispose pointer
      c_dispose_array64(cpaths)

      rpaths
    end

    def self._unpack_open_paths_solution

      # Retrieve solution's pointer
      cpaths = c_get_open_paths_solution

      # Convert to rpath
      rpaths = _cpaths_to_rpaths(cpaths)

      # Dispose pointer
      c_dispose_array64(cpaths)

      rpaths
    end

    def self._unpack_polytree_solution

      # Retrieve solution's pointer
      cpolytree = c_get_polytree_solution

      # Convert to rpath
      rpolytree = _cpolytree_to_rpolytree(cpolytree)

      # Dispose pointer
      c_dispose_array64(cpolytree)

      rpolytree
    end

  end

end
