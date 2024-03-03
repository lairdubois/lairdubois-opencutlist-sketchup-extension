require 'fiddle'
require 'fiddle/import'

module Ladb::OpenCutList

  module Clippy
    extend Fiddle::Importer

    FLOAT_TO_INT64_CONVERTER = 1e8

    @lib_loaded = false

    def self.loaded?
      @lib_loaded
    end

    def self.available?
      _load_lib
      loaded?
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

    def self.polytree_to_polyshapes(polytree)
      polyshapes = []
      stack = [ polytree ]
      until stack.empty?
        current = stack.pop
        current.children.each { |child| stack.push(child) }
        if current.is_a?(PolyPath)
          if current.hole?
            if polyshapes.last && !polyshapes.last.paths.empty?
              polyshapes.last.paths << current.path
            end
          else
            polyshapes << PolyShape.new([ current.path ])
          end
        end
      end
      polyshapes
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

    private

    def self._load_lib
      return if @lib_loaded

      begin

        case Sketchup.platform
        when :platform_osx
          lib_dir = File.join(PLUGIN_DIR,'bin', 'osx', 'lib')
          lib_file = 'libClippy.dylib'
        when :platform_win
          lib_dir = File.join(PLUGIN_DIR,'bin', 'win', 'lib')
          lib_file = 'Clippy.dll'
        else
          raise "Invalid platform : #{Sketchup.platform}"
        end

        lib_path = File.join(lib_dir, lib_file)

        raise "CLippy lib not found : #{lib_path}" unless File.exist?(lib_path)

        begin

          # Load lib (from default extension path)
          dlload(lib_path)

        rescue Fiddle::DLError => e

          # Fiddle lib loader seems to have troubles with non-ASCII encoded path :(
          # Workaround : Try to copy and load lib file from temp folder

          tmp_lib_path = File.join(Dir.tmpdir, lib_file)

          # Copy lib
          FileUtils.copy_file(lib_path, tmp_lib_path)

          # Load lib
          dlload(tmp_lib_path)

        end

        # Keep simple C syntax (without var names and void in args) to stay compatible with SketchUp 2017

        extern 'void c_clear_subjects()'
        extern 'void c_append_open_subject(int64_t*)'
        extern 'void c_append_closed_subject(int64_t*)'

        extern 'void c_clear_clips()'
        extern 'void c_append_clip(int64_t*)'

        extern 'void c_execute_union()'
        extern 'void c_execute_difference()'
        extern 'void c_execute_intersection()'
        extern 'void c_execute_polytree()'

        extern 'void c_clear_paths_solution()'
        extern 'int64_t* c_get_closed_paths_solution()'
        extern 'int64_t* c_get_open_paths_solution()'
        extern 'void c_clear_polytree_solution()'
        extern 'int64_t* c_get_polytree_solution()'

        extern 'int c_is_cpath_positive(int64_t*)'
        extern 'double c_get_cpath_area(int64_t*)'

        extern 'void c_dispose_array64(int64_t*)'

        extern 'char* c_version()'

        @lib_loaded = true

      rescue Exception => e
        Plugin.instance.dump_exception(e, true, Sketchup.platform == :platform_win ? "To resolve this issue, try installing the Microsoft Visual C++ Redistributable available here :\nhttps://aka.ms/vs/17/release/vc_redist.x64.exe" : nil)
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
      l, n = _ptr_int64_to_array(cpaths, 2)
      cur = 2
      rpaths = []
      n.times do
        rpath = _cpath_to_rpath(_ptr_int64_offset(cpaths, cur))
        rpaths << rpath
        cur += 2 + rpath.length
      end
      rpaths
    end

    def self._cpolytree_to_rpolytree(cpolytree)
      l, c = _ptr_int64_to_array(cpolytree, 2)
      cur = 2
      rpolypaths = []
      c.times do
        rpolypath, len = _read_cpolypath_to_rpolypath(_ptr_int64_offset(cpolytree, cur))
        rpolypaths << rpolypath
        cur += len
      end
      PolyTree.new(rpolypaths)
    end

    def self._read_cpolypath_to_rpolypath(cpolypath, level = 0)
      n, c = _ptr_int64_to_array(cpolypath, 2)
      cur = 2
      rpath = _ptr_int64_to_array(_ptr_int64_offset(cpolypath, cur), n * 2)
      cur += n * 2
      rpolypaths = []
      c.times do
        rpolypath, len = _read_cpolypath_to_rpolypath(_ptr_int64_offset(cpolypath, cur), level + 1)
        rpolypaths << rpolypath
        cur += len
      end
      [ PolyPath.new(rpath, level, rpolypaths), cur ] # Returns PolyPath and its data length
    end

    # ---

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
