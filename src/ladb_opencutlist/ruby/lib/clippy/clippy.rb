require 'fiddle'
require 'fiddle/import'

module Ladb::OpenCutList

  module Clippy
    extend Fiddle::Importer

    FLOAT_TO_INT64_CONVERTER = 1e8

    @lib_loaded = false

    # -----

    def self.union(subjects, clips = [])
      _load_lib
      _clear
      _append_subjects(subjects)
      _append_clips(clips)
      _compute_union
      solution = _unpack_solution
      _clear
      solution
    end

    def self.difference(subjects, clips)
      _load_lib
      _clear
      _append_subjects(subjects)
      _append_clips(clips)
      _compute_difference
      solution = _unpack_solution
      _clear
      solution
    end

    def self.intersection(subjects, clips)
      _load_lib
      _clear
      _append_subjects(subjects)
      _append_clips(clips)
      _compute_intersection
      solution = _unpack_solution
      _clear
      solution
    end

    def self.is_rpath_positive?(rpath)
      _load_lib
      return c_is_cpath_positive(_rpath_to_cpath(rpath), rpath.length) == 1
    end

    def self.get_rpath_area(rpath)
      _load_lib
      return c_get_cpath_area(_rpath_to_cpath(rpath), rpath.length) / FLOAT_TO_INT64_CONVERTER / FLOAT_TO_INT64_CONVERTER
    end

    # -- Utils --

    # Convert Array<Geom::Point3d> to Array<Integer>
    def self.points_to_rpath(points)
      points.map { |point| [(point.x * FLOAT_TO_INT64_CONVERTER).to_i, (point.y * FLOAT_TO_INT64_CONVERTER).to_i ] }.flatten
    end

    # Convert Array<Integer> to Array<Geom::Point3d>
    def self.rpath_to_points(rpath, z = 0.0)
      points = []
      rpath.each_slice(2) { |coord_x, coord_y| points << Geom::Point3d.new(coord_x / FLOAT_TO_INT64_CONVERTER, coord_y / FLOAT_TO_INT64_CONVERTER, z) }
      points
    end

    private

    def self._load_lib
      return if @lib_loaded

      begin

        case Sketchup.platform
        when :platform_osx
          dlload File.join(__dir__, '../../../bin/osx/lib/libClippy.dylib')
        when :platform_win
          dlload File.join(__dir__, '../../../bin/x86/lib/Clippy.dll')
        end

        # Keep simple C syntax (without var names and void in args) to stay compatible with SketchUp 2017

        extern 'void c_clear_subjects()'
        extern 'void c_append_subject(int64_t*, size_t)'

        extern 'void c_clear_clips()'
        extern 'void c_append_clip(int64_t*, size_t)'

        extern 'void c_compute_union()'
        extern 'void c_compute_difference()'
        extern 'void c_compute_intersection()'

        extern 'void c_clear_solution()'
        extern 'size_t c_get_solution_len()'
        extern 'size_t c_get_solution_cpath_len_at(int)'
        extern 'int64_t* c_get_solution_cpath_at(int)'

        extern 'int c_is_cpath_positive(int64_t*, size_t)'
        extern 'double c_get_cpath_area(int64_t*, size_t)'

        extern 'void c_free_cpath(int64_t*)'

        @lib_loaded = true

      rescue Exception => e
        @lib_loaded = false
      end

    end

    # Returns Fiddle::Pointer
    def self._rpath_to_cpath(rpath)
      Fiddle::Pointer[rpath.pack('q*')]  # q* to read 64bits integers
    end

    # Returns Array<Integer>
    def self._cpath_to_rpath(cpath, len)
      cpath.to_str(len * Fiddle::SIZEOF_LONG_LONG * 2).unpack('q*')  # Fiddle::SIZEOF_LONG_LONG = sizeof(int64_t), q* to read 64bits integers
    end

    def self._clear
      c_clear_subjects
      c_clear_clips
      c_clear_solution
    end

    def self._append_subject(rpath)
      c_append_subject(_rpath_to_cpath(rpath), rpath.length)
    end

    def self._append_subjects(rpaths)
      rpaths.each do |rpath|
        _append_subject(rpath)
      end
    end

    def self._append_clip(rpath)
      c_append_clip(_rpath_to_cpath(rpath), rpath.length)
    end

    def self._append_clips(rpaths)
      rpaths.each do |rpath|
        _append_clip(rpath)
      end
    end

    def self._compute_union
      c_compute_union
    end

    def self._compute_difference
      c_compute_difference
    end

    def self._compute_intersection
      c_compute_intersection
    end

    def self._unpack_solution
      solution = []
      (0...c_get_solution_len).each do |index|

        # Retrieve the solution length (= number of cpath)
        cpath_len = c_get_solution_cpath_len_at(index)

        # Retrieve solution array pointer
        cpath = c_get_solution_cpath_at(index)

        # Unpack pointer data to Ruby Array<Integer>
        solution << _cpath_to_rpath(cpath, cpath_len)

        # Free pointer
        c_free_cpath(cpath)

      end
      solution
    end

  end
end
