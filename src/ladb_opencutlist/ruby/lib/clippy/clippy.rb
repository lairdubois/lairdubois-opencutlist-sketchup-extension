require 'fiddle'
require 'fiddle/import'

module Ladb::OpenCutList

  module Clippy
    extend Fiddle::Importer

    FLOAT_TO_INT64_CONVERTER = 1e12   # Clipper2 can have difficulties to union non squared polygon if > 1e6

    @lib_loaded = false

    # -----

    def self.compute_union(subjects, clips = [])
      _load_lib
      _clear
      _append_subjects(subjects)
      _append_clips(clips)
      _compute_union
      solution = _unpack_solution
      _clear
      solution
    end

    def self.compute_difference(subjects, clips)
      _load_lib
      _clear
      _append_subjects(subjects)
      _append_clips(clips)
      _compute_difference
      solution = _unpack_solution
      _clear
      solution
    end

    def self.compute_intersection(subjects, clips)
      _load_lib
      _clear
      _append_subjects(subjects)
      _append_clips(clips)
      _compute_intersection
      solution = _unpack_solution
      _clear
      solution
    end

    def self.compute_outers(subjects)
      _load_lib
      _clear
      _append_subjects(subjects)
      _compute_outers
      solution = _unpack_solution
      _clear
      solution
    end

    def self.compute_tree(subjects)
      _load_lib
      _clear
      _append_subjects(subjects)
      _compute_tree
      solution = _unpack_tree_solution
      _clear
      solution
    end

    def self.is_rpath_positive?(rpath)
      _load_lib
      return c_is_cpath_positive(_rpath_to_cpath(rpath)) == 1
    end

    def self.get_rpath_area(rpath)
      _load_lib
      return c_get_cpath_area(_rpath_to_cpath(rpath)) / FLOAT_TO_INT64_CONVERTER / FLOAT_TO_INT64_CONVERTER
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

    # -- Utils --

    # Convert Array<Geom::Point3d> to Array<Integer> (x1, y1, x2, y2, ...)
    def self.points_to_rpath(points)
      points.map { |point| [ (point.x * FLOAT_TO_INT64_CONVERTER).to_i, (point.y * FLOAT_TO_INT64_CONVERTER).to_i ] }.flatten
    end

    # Convert Array<Integer> (x1, y1, x2, y2, ...) to Array<Geom::Point3d>
    def self.rpath_to_points(rpath, z = 0.0)
      points = []
      rpath.each_slice(2) { |coord_x, coord_y| points << Geom::Point3d.new(coord_x / FLOAT_TO_INT64_CONVERTER, coord_y / FLOAT_TO_INT64_CONVERTER, z) }
      points
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
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
        extern 'void c_append_subject(int64_t*)'

        extern 'void c_clear_clips()'
        extern 'void c_append_clip(int64_t*)'

        extern 'void c_compute_union()'
        extern 'void c_compute_difference()'
        extern 'void c_compute_intersection()'
        extern 'void c_compute_outers()'
        extern 'void c_compute_tree()'

        extern 'void c_clear_solution()'
        extern 'int64_t* c_get_solution()'
        extern 'void c_clear_tree_solution()'
        extern 'int64_t* c_get_tree_solution()'

        extern 'int c_is_cpath_positive(int64_t*)'
        extern 'double c_get_cpath_area(int64_t*)'

        extern 'void c_dispose_array64(int64_t*)'

        extern 'char* c_version()'

        @lib_loaded = true

      rescue Exception => e
        puts "[#{File.basename(__FILE__)}:#{__LINE__}] : #{e.message}"
        @lib_loaded = false
      end

    end

    #
    # CPaths
    # |counter|path1|path2|...|pathC
    # |L, C   |     |     |...|
    #
    # L = Array length
    # C = Number of paths
    #
    # CPath
    # |counter|coord1|coord2|...|coordN
    # |N, 0   |x1, y1|x2, y2|...|xN, yN
    #
    # N = Number of coords
    #

    # --- Ruby to C

    def self._array_to_ptr_int64(array)
      Fiddle::Pointer[array.pack('q*')]  # q* to write 64-bit signed, native endian (int64_t)
    end

    def self._array_prepend_n_0_counter(array)
      [ array.count / 2, 0 ].concat(array)
    end

    # Returns Fiddle::Pointer
    def self._rpath_to_cpath(rpath)
      _array_to_ptr_int64(_array_prepend_n_0_counter(rpath))
    end

    # Returns Fiddle::Pointer
    def self._rpaths_to_cpaths(rpaths)
      len = 2 + rpaths.sum { |rpath| 2 + rpath.length }
      _array_to_ptr_int64([ len, rpaths.length ].concat(rpaths.map { |rpath| _array_prepend_n_0_counter(rpath) }.flatten(1)))
    end

    # --- C to Ruby

    def self._ptr_int64_to_array(ptr, cnt)
      ptr.to_str(Fiddle::SIZEOF_LONG_LONG * cnt).unpack('q*') # Fiddle::SIZEOF_LONG_LONG = sizeof(int64_t), q* to read 64-bit signed, native endian (int64_t)
    end

    def self._ptr_int64_offset(ptr, offset = 0)
      ptr + offset * Fiddle::SIZEOF_LONG_LONG
    end

    # Returns Array<Integer>
    def self._cpath_to_rpath(cpath)
      n, zero = _ptr_int64_to_array(cpath, 2)
      _ptr_int64_to_array(_ptr_int64_offset(cpath, 2), n * 2)
    end

    # Returns Array<Array<Integer>>
    def self._cpaths_to_rpaths(cpaths)
      len, n = _ptr_int64_to_array(cpaths, 2)
      rpaths = []
      cur = 2
      n.times do
        rpath = _cpath_to_rpath(_ptr_int64_offset(cpaths, cur))
        rpaths << rpath
        cur += 2 + rpath.length
      end
      rpaths
    end

    def self._cpolytree_to_rpolytree(cpolytree)
      l, c = _ptr_int64_to_array(cpolytree, 2)
      puts "POLYTREE len=#{l}, C=#{c}"
      rpolypaths = []
      cur = 2
      c.times do |i|
        rpolypath, len = _cpolypath_to_rpolypath(_ptr_int64_offset(cpolytree, cur))
        rpolypaths << rpolypath
        cur += len
      end
      { children: rpolypaths }
    end

    def self._cpolypath_to_rpolypath(cpolypath, level = 1)
      n, c = _ptr_int64_to_array(cpolypath, 2)
      puts "#{' '.rjust(level)}+ POLYPATH N=#{n}, C=#{c}, level=#{level}"
      cur = 2
      rpath = _ptr_int64_to_array(_ptr_int64_offset(cpolypath, cur), n * 2)
      puts "#{' '.rjust(level)}   ↳ path #{level.odd? ? '▪' : '▫︎'} = #{rpath[0,4]}..."
      rpath << rpath
      cur += n * 2
      rpolypaths = []
      c.times do |i|
        rpolypath, len = _cpolypath_to_rpolypath(_ptr_int64_offset(cpolypath, cur), level + 1)
        rpolypaths << rpolypath
        cur += len
      end
      [ { path: rpath, children: rpolypaths }, cur ]
    end

    # ---

    def self._clear
      c_clear_subjects
      c_clear_clips
      c_clear_solution
      c_clear_tree_solution
    end

    def self._append_subject(rpath)
      c_append_subject(_rpath_to_cpath(rpath))
    end

    def self._append_subjects(rpaths)
      rpaths.each do |rpath|
        _append_subject(rpath)
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

    def self._compute_union
      c_compute_union
    end

    def self._compute_difference
      c_compute_difference
    end

    def self._compute_intersection
      c_compute_intersection
    end

    def self._compute_outers
      c_compute_outers
    end

    def self._compute_tree
      c_compute_tree
    end

    def self._unpack_solution

      # Retrieve solution's pointer
      cpaths = c_get_solution

      # Convert to rpath
      rpaths = _cpaths_to_rpaths(cpaths)

      # Dispose pointer
      c_dispose_array64(cpaths)

      rpaths
    end

    def self._unpack_tree_solution

      # Retrieve solution's pointer
      cpolytree = c_get_tree_solution

      # Convert to rpath
      rpolytree = _cpolytree_to_rpolytree(cpolytree)

      # Dispose pointer
      c_dispose_array64(cpolytree)

      rpolytree
    end

  end
end
