require_relative '../clipper_wrapper'

module Ladb::OpenCutList::Fiddle

  module Nesty
    extend ClipperWrapper

    def self._lib_name
      'Nesty'
    end

    def self._lib_c_functions
      [

        'void c_clear()',

        'void c_append_bin_def(int, int, int64_t, int64_t, int)',
        'void c_append_shape_def(int, int, int64_t*)',

        'char* c_execute_nesting(int64_t, int64_t)',

        'int64_t* c_get_solution()',

        'void c_dispose_array64(int64_t*)',

        'char* c_version()'

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.execute_nesting(bin_defs, shape_defs, spacing, trimming)
      _load_lib
      _clear
      _append_bin_defs(bin_defs)
      _append_shape_defs(shape_defs)
      message = _execute_nesting(spacing, trimming).to_s
      solution = _unpack_solution
      _clear
      [ solution, message ]
    end

    private

    def self._clear
      c_clear
    end

    def self._append_bin_def(bin_def)
      c_append_bin_def(bin_def.id, bin_def.count, bin_def.length, bin_def.width, bin_def.type)
    end

    def self._append_bin_defs(bin_defs)
      bin_defs.each { |bin_def| _append_bin_def(bin_def) }
    end

    def self._append_shape_def(shape_def)
      c_append_shape_def(shape_def.id, shape_def.count, _rpaths_to_cpaths(shape_def.paths))
    end

    def self._append_shape_defs(shape_defs)
      shape_defs.each { |shape_def| _append_shape_def(shape_def) }
    end

    def self._execute_nesting(spacing, trimming)
      c_execute_nesting(spacing, trimming)
    end

    def self._unpack_solution

      # Retrieve solution's pointer
      csolution = c_get_solution

      # Convert to rpath
      rsolution = _csolution_to_rsolution(csolution)

      # Dispose pointer
      c_dispose_array64(csolution)

      rsolution
    end

    # -----

    def self._cshape_to_rshape(cshape)
      id, x, y, rotation = _ptr_int64_to_array(cshape, 4)
      [ Shape.new(id, x, y, rotation), 4 ]
    end

    def self._cshapes_to_rshapes(cshapes)
      n = _ptr_int64_to_array(cshapes, 1)[0]
      cur = 1
      rshapes = []
      n.times do
        rshape, length = _cshape_to_rshape(_ptr_int64_offset(cshapes, cur))
        rshapes << rshape
        cur += length
      end
      [ rshapes, cur ]
    end

    def self._cbin_to_rbin(cbin)
      id = _ptr_int64_to_array(cbin, 1)[0]
      shapes, length = _cshapes_to_rshapes(_ptr_int64_offset(cbin, 1))
      [ Bin.new(id, shapes), 1 + length ]
    end

    def self._cbins_to_rbins(cbins)
      n = _ptr_int64_to_array(cbins, 1)[0]
      cur = 1
      rbins = []
      n.times do
        rbin, length = _cbin_to_rbin(_ptr_int64_offset(cbins, cur))
        rbins << rbin
        cur += length
      end
      [ rbins, cur ]
    end

    def self._csolution_to_rsolution(csolution)
      l = _ptr_int64_to_array(csolution, 1)
      cur = 1
      unused_bins, length = _cbins_to_rbins(_ptr_int64_offset(csolution, cur))
      cur += length
      packed_bins, length = _cbins_to_rbins(_ptr_int64_offset(csolution, cur))
      cur += length
      unplaced_shapes, length = _cshapes_to_rshapes(_ptr_int64_offset(csolution, cur))
      Solution.new(unused_bins, packed_bins, unplaced_shapes)
    end

    # -----

    BinDef = Struct.new(:id, :count, :length, :width, :type)
    ShapeDef = Struct.new(:id, :count, :paths, :data)

    Solution = Struct.new(:unused_bins, :packed_bins, :unplaced_shapes)
    Bin = Struct.new(:def, :shapes)
    Shape = Struct.new(:def, :x, :y, :rotation)

  end

end
