require_relative '../clipper_wrapper'

module Ladb::OpenCutList::Fiddle

  module Packy
    extend ClipperWrapper

    @bin_defs_cache = {}
    @shape_defs_cache = {}

    def self._lib_name
      'Packy'
    end

    def self._lib_c_functions
      [

        'void c_clear()',

        'void c_append_bin_def(int, int, int64_t, int64_t, int)',
        'void c_append_shape_def(int, int, int, int64_t*)',

        'char* c_execute_rectangle(int64_t, int64_t)',
        'char* c_execute_rectangleguillotine(int64_t, int64_t)',
        'char* c_execute_irregular(int64_t, int64_t)',
        'char* c_execute_onedimensional(int64_t, int64_t)',

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

    def self.execute_rectangle(bin_defs, shape_defs, spacing, trimming)
      _load_lib
      _clear
      _append_bin_defs(bin_defs)
      _append_shape_defs(shape_defs)
      message = _execute_rectangle(spacing, trimming).to_s
      solution = _unpack_solution
      _clear
      [ solution, message ]
    end

    def self.execute_rectangleguillotine(bin_defs, shape_defs, spacing, trimming)
      _load_lib
      _clear
      _append_bin_defs(bin_defs)
      _append_shape_defs(shape_defs)
      message = _execute_rectangleguillotine(spacing, trimming).to_s
      solution = _unpack_solution
      _clear
      [ solution, message ]
    end

    def self.execute_irregular(bin_defs, shape_defs, spacing, trimming)
      _load_lib
      _clear
      _append_bin_defs(bin_defs)
      _append_shape_defs(shape_defs)
      message = _execute_irregular(spacing, trimming).to_s
      solution = _unpack_solution
      _clear
      [ solution, message ]
    end

    def self.execute_onedimensional(bin_defs, shape_defs, spacing, trimming)
      _load_lib
      _clear
      _append_bin_defs(bin_defs)
      _append_shape_defs(shape_defs)
      message = _execute_onedimensional(spacing, trimming).to_s
      solution = _unpack_solution
      _clear
      [ solution, message ]
    end

    private

    def self._clear
      c_clear
      @bin_defs_cache.clear
      @shape_defs_cache.clear
    end

    def self._append_bin_def(bin_def)
      @bin_defs_cache[bin_def.id] = bin_def
      c_append_bin_def(bin_def.id, bin_def.count, bin_def.length, bin_def.width, bin_def.type)
    end

    def self._append_bin_defs(bin_defs)
      bin_defs.each { |bin_def| _append_bin_def(bin_def) }
    end

    def self._append_shape_def(shape_def)
      @shape_defs_cache[shape_def.id] = shape_def
      c_append_shape_def(shape_def.id, shape_def.count, shape_def.rotations, _rpaths_to_cpaths(shape_def.paths))
    end

    def self._append_shape_defs(shape_defs)
      shape_defs.each { |shape_def| _append_shape_def(shape_def) }
    end

    def self._execute_rectangle(spacing, trimming)
      c_execute_rectangle(spacing, trimming)
    end

    def self._execute_rectangleguillotine(spacing, trimming)
      c_execute_rectangleguillotine(spacing, trimming)
    end

    def self._execute_irregular(spacing, trimming)
      c_execute_irregular(spacing, trimming)
    end

    def self._execute_onedimensional(spacing, trimming)
      c_execute_onedimensional(spacing, trimming)
    end

    def self._unpack_solution

      # Retrieve solution's pointer
      csolution = c_get_solution

      # Convert to rsolution
      rsolution, len = _csolution_to_rsolution(csolution)

      # Dispose pointer
      c_dispose_array64(csolution)

      rsolution
    end

    # -----

    def self._cshape_to_rshape(cshape)
      id, x, y, angle = _ptr_int64_to_array(cshape, 4)
      [ Shape.new(@shape_defs_cache[id], x, y, angle), 4 ] # Returns RShape and its data length
    end

    def self._cshapes_to_rshapes(cshapes)
      n = _ptr_int64_to_array(cshapes, 1)[0]
      cur = 1
      rshapes = []
      n.times do
        rshape, len = _cshape_to_rshape(_ptr_int64_offset(cshapes, cur))
        rshapes << rshape
        cur += len
      end
      [ rshapes, cur ] # Returns RShapes and cumulative data length
    end

    def self._ccut_to_rcut(ccut)
      depth, x1, y1, x2, y2 = _ptr_int64_to_array(ccut, 5)
      [ Cut.new(depth, x1, y1, x2, y2), 5 ] # Returns RCut and its data length
    end

    def self._ccuts_to_rcuts(ccuts)
      n = _ptr_int64_to_array(ccuts, 1)[0]
      cur = 1
      rcuts = []
      n.times do
        rcut, len = _ccut_to_rcut(_ptr_int64_offset(ccuts, cur))
        rcuts << rcut
        cur += len
      end
      [ rcuts, cur ] # Returns Rcuts and cumulative data length
    end

    def self._cbin_to_rbin(cbin)
      id = _ptr_int64_to_array(cbin, 1)[0]
      cur = 1
      shapes, len = _cshapes_to_rshapes(_ptr_int64_offset(cbin, cur))
      cur += len
      cuts, len = _ccuts_to_rcuts(_ptr_int64_offset(cbin, cur))
      cur += len
      [ Bin.new(@bin_defs_cache[id], shapes, cuts), cur ] # Returns RBin and its data length
    end

    def self._cbins_to_rbins(cbins)
      n = _ptr_int64_to_array(cbins, 1)[0]
      cur = 1
      rbins = []
      n.times do
        rbin, len = _cbin_to_rbin(_ptr_int64_offset(cbins, cur))
        rbins << rbin
        cur += len
      end
      [ rbins, cur ] # Returns RBins and cumulative data length
    end

    def self._csolution_to_rsolution(csolution)
      l = _ptr_int64_to_array(csolution, 1)
      cur = 1
      unused_bins, len = _cbins_to_rbins(_ptr_int64_offset(csolution, cur))
      cur += len
      packed_bins, len = _cbins_to_rbins(_ptr_int64_offset(csolution, cur))
      cur += len
      unplaced_shapes, len = _cshapes_to_rshapes(_ptr_int64_offset(csolution, cur))
      [ Solution.new(unused_bins, packed_bins, unplaced_shapes), cur ] # Returns RSolution and its data length
    end

    # -----

    BinDef = Struct.new(:id, :count, :length, :width, :type)  # length and with must be converted to int64
    ShapeDef = Struct.new(:id, :count, :rotations, :paths, :data)

    Solution = Struct.new(:unused_bins, :packed_bins, :unplaced_shapes)
    Bin = Struct.new(:def, :shapes, :cuts)
    Shape = Struct.new(:def, :x, :y, :angle)  # x, y are int64
    Cut = Struct.new(:depth, :x1, :y1, :x2, :y2)  # x1, y1, x2, y2 are int64

  end

end
