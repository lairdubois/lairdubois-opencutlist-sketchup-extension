module Ladb::OpenCutList::Fiddle

  require_relative 'wrapper'

  module ClipperWrapper
    include Wrapper

    # ---

    # Convert Array<Geom::Point3d> to Array<Integer> (x1, y1, x2, y2, ...)
    def points_to_rpath(points)
      points.flat_map { |point| [ point.x, point.y ] }
    end

    # Convert Array<Integer> (x1, y1, x2, y2, ...) to Array<Geom::Point3d>
    def rpath_to_points(rpath, z = 0.0)
      points = []
      rpath.each_slice(2) { |coord_x, coord_y| points << Geom::Point3d.new(coord_x, coord_y, z) } if rpath.is_a?(Array)
      points
    end

    # ---

    # Convert PolyTree to Array<PolyShape>
    # PolyShape first path is outer others are holes
    def polytree_to_polyshapes(polytree)
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

    protected

    # --- Ruby to C

    def _array_to_ptr_double(array)
      Fiddle::Pointer[array.pack('d*')]  # d* to write double-precision, native format (double)
    end

    def _array_prepend_n_0_counter(array, period = 2)
      [ array.count / period, 0 ].concat(array)
    end

    # Returns Fiddle::Pointer
    def _rpath_to_cpath(rpath)
      _array_to_ptr_double(_array_prepend_n_0_counter(rpath))
    end

    # Returns Fiddle::Pointer
    def _rpaths_to_cpaths(rpaths)
      len = 2 ; rpaths.each { |rpath| len += 2 + rpath.length }   # .sum {...} incompatible with ruby < 2.4
      _array_to_ptr_double([ len, rpaths.length ].concat(rpaths.flat_map { |rpath| _array_prepend_n_0_counter(rpath) }))
    end

    # --- C to Ruby

    def _ptr_double_to_array(ptr, cnt)
      ptr.to_str(Fiddle::SIZEOF_DOUBLE * cnt).unpack('d*') # d* to read double-precision, native format (double)
    end

    def _ptr_double_offset(ptr, offset = 0)
      ptr + offset * Fiddle::SIZEOF_DOUBLE
    end

    # Returns Array<Integer>
    def _cpath_to_rpath(cpath)
      n, zero = _ptr_double_to_array(cpath, 2)
      [ _ptr_double_to_array(_ptr_double_offset(cpath, 2), n * 2), 2 + n * 2 ] # Returns RPath and its data length
    end

    # Returns Array<Array<Integer>>
    def _cpaths_to_rpaths(cpaths)
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

    def _cpolytree_to_rpolytree(cpolytree)
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

    def _read_cpolypath_to_rpolypath(cpolypath, level = 0)
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
