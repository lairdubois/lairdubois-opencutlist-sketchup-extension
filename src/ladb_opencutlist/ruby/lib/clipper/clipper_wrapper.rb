require 'fiddle'
require 'fiddle/import'

module Ladb::OpenCutList

  module ClipperWrapper
    include Fiddle::Importer

    FLOAT_TO_INT64_CONVERTER = 1e8

    @lib_loaded = false

    def loaded?
      @lib_loaded
    end

    def available?
      _load_lib
      loaded?
    end

    # ---

    # Convert Array<Geom::Point3d> to Array<Integer> (x1, y1, x2, y2, ...)
    def points_to_rpath(points)
      points.map { |point| [ (point.x * FLOAT_TO_INT64_CONVERTER).to_i, (point.y * FLOAT_TO_INT64_CONVERTER).to_i ] }.flatten
    end

    # Convert Array<Integer> (x1, y1, x2, y2, ...) to Array<Geom::Point3d>
    def rpath_to_points(rpath, z = 0.0)
      points = []
      rpath.each_slice(2) { |coord_x, coord_y| points << Geom::Point3d.new(coord_x / FLOAT_TO_INT64_CONVERTER, coord_y / FLOAT_TO_INT64_CONVERTER, z) }
      points
    end

    # ---

    # Convert PolyTree to Array<PolyShape>
    def polytree_to_polyshapes(polytree)
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

    protected

    def _lib_name
      'NoName'
    end

    def _lib_c_functions
      []
    end

    def _load_lib
      return if @lib_loaded

      begin

        case Sketchup.platform
        when :platform_osx
          lib_dir = File.join(PLUGIN_DIR,'bin', 'osx', 'lib')
          lib_file = "lib#{_lib_name}.dylib"
        when :platform_win
          lib_dir = File.join(PLUGIN_DIR,'bin', 'win', 'lib')
          lib_file = "#{_lib_name}.dll"
        else
          raise "Invalid platform : #{Sketchup.platform}"
        end

        lib_path = File.join(lib_dir, lib_file)

        raise "'#{_lib_name}' lib not found : #{lib_path}" unless File.exist?(lib_path)

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
        _lib_c_functions.each do |function|
          extern function
        end

        @lib_loaded = true

      rescue Exception => e
        PLUGIN.dump_exception(e, true, Sketchup.platform == :platform_win ? "To resolve this issue, try installing the Microsoft Visual C++ Redistributable available here :\nhttps://aka.ms/vs/17/release/vc_redist.x64.exe" : nil)
        @lib_loaded = false
      end

    end

    # --- Ruby to C

    def _array_to_ptr_int64(array)
      Fiddle::Pointer[array.pack('q*')]  # q* to write 64-bit signed, native endian (int64_t)
    end

    def _array_prepend_n_0_counter(array)
      [ array.count / 2, 0 ].concat(array)
    end

    # Returns Fiddle::Pointer
    def _rpath_to_cpath(rpath)
      _array_to_ptr_int64(_array_prepend_n_0_counter(rpath))
    end

    # Returns Fiddle::Pointer
    def _rpaths_to_cpaths(rpaths)
      len = 2 + rpaths.sum { |rpath| 2 + rpath.length }
      _array_to_ptr_int64([ len, rpaths.length ].concat(rpaths.map { |rpath| _array_prepend_n_0_counter(rpath) }.flatten(1)))
    end

    # --- C to Ruby

    def _ptr_int64_to_array(ptr, cnt)
      ptr.to_str(Fiddle::SIZEOF_LONG_LONG * cnt).unpack('q*') # Fiddle::SIZEOF_LONG_LONG = sizeof(int64_t), q* to read 64-bit signed, native endian (int64_t)
    end

    def _ptr_int64_offset(ptr, offset = 0)
      ptr + offset * Fiddle::SIZEOF_LONG_LONG
    end

    # Returns Array<Integer>
    def _cpath_to_rpath(cpath)
      n, zero = _ptr_int64_to_array(cpath, 2)
      _ptr_int64_to_array(_ptr_int64_offset(cpath, 2), n * 2)
    end

    # Returns Array<Array<Integer>>
    def _cpaths_to_rpaths(cpaths)
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

    def _cpolytree_to_rpolytree(cpolytree)
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

    def _read_cpolypath_to_rpolypath(cpolypath, level = 0)
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
