require 'fiddle'
require 'fiddle/import'

module Ladb::OpenCutList
  module Clippy
    extend Fiddle::Importer

    FLOAT_TO_INT64_CONVERTER = 1e16

    case Sketchup.platform
    when :platform_osx
      dlload File.join(__dir__, '../../../bin/osx/lib/libClippy.dylib')
    when :platform_win
      dlload File.join(__dir__, '../../../bin/x86/lib/Clippy.dll')
    end

    extern 'void c_clear_subjects(void)'
    extern 'void c_append_subject(int64_t* cpath, size_t len)'

    extern 'void c_clear_clips(void)'
    extern 'void c_append_clip(int64_t* cpath, size_t len)'

    extern 'size_t c_compute_union(void)'
    extern 'size_t c_compute_difference(void)'
    extern 'size_t c_compute_intersection(void)'

    extern 'void c_clear_solution(void)'
    extern 'size_t c_get_solution_len(void)'
    extern 'size_t c_get_solution_cpath_len_at(int index)'
    extern 'int64_t* c_get_solution_cpath_at(int index)'

    extern 'int c_is_cpath_positive(int64_t *cpath, size_t len)'
    extern 'double c_get_cpath_area(int64_t *cpath, size_t len)'

    extern 'void c_free_cpath(int64_t *cpath)'

    def self.union(subjects, clips)
      _clear
      _append_subjects(subjects)
      _append_clips(clips)
      solution = _compute_union
      _clear
      solution
    end

    def self.difference(subjects, clips)
      _clear
      _append_subjects(subjects)
      _append_clips(clips)
      solution = _compute_difference
      _clear
      solution
    end

    def self.intersaction(subjects, clips)
      _clear
      _append_subjects(subjects)
      _append_clips(clips)
      solution = _compute_intersection
      _clear
      solution
    end

    def self.is_path_positive?(path)
      return c_is_cpath_positive(_pack_path(path), path.length) == 1
    end

    def self.get_path_area(path)
      return c_get_cpath_area(_pack_path(path), path.length) / (FLOAT_TO_INT64_CONVERTER**2)
    end

    # -- Utils --

    # Convert Array<Geom::Point3d> to Array<Integer>
    def self.points_to_path(points)
      points.map { |point| [(point.x * FLOAT_TO_INT64_CONVERTER).to_i, (point.y * FLOAT_TO_INT64_CONVERTER).to_i ] }.flatten
    end

    # Convert Array<Integer> to Array<Geom::Point3d>
    def self.path_to_points(path, z = 0.0)
      points = []
      path.each_slice(2) { |coord_a, coord_b| points << Geom::Point3d.new(coord_a / FLOAT_TO_INT64_CONVERTER, coord_b / FLOAT_TO_INT64_CONVERTER, z) }
      points
    end

    private

    def self._pack_path(path)
      Fiddle::Pointer[path.pack('q*')]
    end

    def self._clear
      c_clear_subjects
      c_clear_clips
      c_clear_solution
    end

    def self._append_subject(path)
      c_append_subject(_pack_path(path), path.length)
    end

    def self._append_subjects(paths)
      paths.each do |path|
        _append_subject(path)
      end
    end

    def self._append_clip(path)
      c_append_clip(_pack_path(path), path.length)
    end

    def self._append_clips(paths)
      paths.each do |path|
        _append_clip(path)
      end
    end

    def self._compute_union
      c_compute_union
      _unpack_solution
    end

    def self._compute_difference
      c_compute_difference
      _unpack_solution
    end

    def self._compute_intersection
      c_compute_intersection
      _unpack_solution
    end

    def self._unpack_solution
      solution = []
      (0...c_get_solution_len).each do |index|

        # Retrieve the solution length (= number of cpath)
        path_len = c_get_solution_cpath_len_at(index)

        # Retrieve solution array pointer
        path_ptr = c_get_solution_cpath_at(index)

        # Unpack pointer data to Ruby Array<Integer> (q* to read 64bits integers)
        solution << path_ptr.to_str(path_len * Fiddle::SIZEOF_LONG_LONG * 2).unpack('q*')  # Fiddle::SIZEOF_LONG_LONG = sizeof(int64_t)

        # Free pointer
        c_free_cpath(path_ptr)

      end
      solution
    end

  end
end
