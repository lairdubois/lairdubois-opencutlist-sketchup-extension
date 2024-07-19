require_relative '../clipper_wrapper'

module Ladb::OpenCutList::Fiddle

  module Packy
    extend ClipperWrapper

    @bin_defs_cache = {}
    @item_defs_cache = {}

    def self._lib_name
      'Packy'
    end

    def self._lib_c_functions
      [

        'void c_clear()',

        'void c_append_bin_def(int, int, double, double, int)',
        'void c_append_item_def(int, int, int, double*)',

        'char* c_execute_rectangle(char*, double, double, int)',
        'char* c_execute_rectangleguillotine(char*, char*, char*, double, double, int)',
        'char* c_execute_irregular(char*, double, double, int)',
        'char* c_execute_onedimensional(char*, double, double, int)',

        'double* c_get_solution()',

        'void c_dispose_array_d(double*)',

        'char* c_version()'

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.execute_rectangle(bin_defs, item_defs, objective, spacing, trimming, verbosity_level)
      _load_lib
      _clear
      _append_bin_defs(bin_defs)
      _append_item_defs(item_defs)
      message = _execute_rectangle(objective, spacing, trimming, verbosity_level).to_s
      solution = _unpack_solution
      _clear
      [ solution, message ]
    end

    def self.execute_rectangleguillotine(bin_defs, item_defs, objective, cut_type, first_stage_orientation, spacing, trimming, verbosity_level)
      _load_lib
      _clear
      _append_bin_defs(bin_defs)
      _append_item_defs(item_defs)
      message = _execute_rectangleguillotine(objective, cut_type, first_stage_orientation, spacing, trimming, verbosity_level).to_s
      solution = _unpack_solution
      _clear
      [ solution, message ]
    end

    def self.execute_irregular(bin_defs, item_defs, objective, spacing, trimming, verbosity_level)
      _load_lib
      _clear
      _append_bin_defs(bin_defs)
      _append_item_defs(item_defs)
      message = _execute_irregular(objective, spacing, trimming, verbosity_level).to_s
      solution = _unpack_solution
      _clear
      [ solution, message ]
    end

    def self.execute_onedimensional(bin_defs, item_defs, objective, spacing, trimming, verbosity_level)
      _load_lib
      _clear
      _append_bin_defs(bin_defs)
      _append_item_defs(item_defs)
      message = _execute_onedimensional(objective, spacing, trimming, verbosity_level).to_s
      solution = _unpack_solution
      _clear
      [ solution, message ]
    end

    private

    def self._clear
      c_clear
      @bin_defs_cache.clear
      @item_defs_cache.clear
    end

    def self._append_bin_def(bin_def)
      @bin_defs_cache[bin_def.id] = bin_def
      c_append_bin_def(bin_def.id, bin_def.count, bin_def.length, bin_def.width, bin_def.type)
    end

    def self._append_bin_defs(bin_defs)
      bin_defs.each { |bin_def| _append_bin_def(bin_def) }
    end

    def self._append_item_def(item_def)
      @item_defs_cache[item_def.id] = item_def
      c_append_item_def(item_def.id, item_def.count, item_def.rotations, _rpaths_to_cpaths(item_def.paths))
    end

    def self._append_item_defs(item_defs)
      item_defs.each { |item_def| _append_item_def(item_def) }
    end

    def self._execute_rectangle(objective, spacing, trimming, verbosity_level)
      c_execute_rectangle(objective, spacing, trimming, verbosity_level)
    end

    def self._execute_rectangleguillotine(objective, cut_type, first_stage_orientation, spacing, trimming, verbosity_level)
      c_execute_rectangleguillotine(objective, cut_type, first_stage_orientation, spacing, trimming, verbosity_level)
    end

    def self._execute_irregular(objective, spacing, trimming, verbosity_level)
      c_execute_irregular(objective, spacing, trimming, verbosity_level)
    end

    def self._execute_onedimensional(objective, spacing, trimming, verbosity_level)
      c_execute_onedimensional(objective, spacing, trimming, verbosity_level)
    end

    def self._unpack_solution

      # Retrieve solution's pointer
      csolution = c_get_solution

      # Convert to rsolution
      rsolution, len = _csolution_to_rsolution(csolution)

      # Dispose pointer
      c_dispose_array_d(csolution)

      rsolution
    end

    # -----

    def self._citem_to_ritem(citem)
      id, x, y, angle = _ptr_double_to_array(citem, 4)
      [ Item.new(@item_defs_cache[id.to_i], x, y, angle), 4 ] # Returns RItem and its data length
    end

    def self._citems_to_ritems(citems)
      n = _ptr_double_to_array(citems, 1)[0]
      cur = 1
      ritems = []
      n.to_i.times do
        ritem, len = _citem_to_ritem(_ptr_double_offset(citems, cur))
        ritems << ritem
        cur += len
      end
      [ ritems, cur ] # Returns RItems and cumulative data length
    end

    def self._ccut_to_rcut(ccut)
      depth, x1, y1, x2, y2 = _ptr_double_to_array(ccut, 5)
      [ Cut.new(depth, x1, y1, x2, y2), 5 ] # Returns RCut and its data length
    end

    def self._ccuts_to_rcuts(ccuts)
      n = _ptr_double_to_array(ccuts, 1)[0]
      cur = 1
      rcuts = []
      n.to_i.times do
        rcut, len = _ccut_to_rcut(_ptr_double_offset(ccuts, cur))
        rcuts << rcut
        cur += len
      end
      [ rcuts, cur ] # Returns Rcuts and cumulative data length
    end

    def self._cbin_to_rbin(cbin)
      id = _ptr_double_to_array(cbin, 1)[0]
      cur = 1
      items, len = _citems_to_ritems(_ptr_double_offset(cbin, cur))
      cur += len
      cuts, len = _ccuts_to_rcuts(_ptr_double_offset(cbin, cur))
      cur += len
      [ Bin.new(@bin_defs_cache[id.to_i], items, cuts), cur ] # Returns RBin and its data length
    end

    def self._cbins_to_rbins(cbins)
      n = _ptr_double_to_array(cbins, 1)[0]
      cur = 1
      rbins = []
      n.to_i.times do
        rbin, len = _cbin_to_rbin(_ptr_double_offset(cbins, cur))
        rbins << rbin
        cur += len
      end
      [ rbins, cur ] # Returns RBins and cumulative data length
    end

    def self._csolution_to_rsolution(csolution)
      l = _ptr_double_to_array(csolution, 1)
      cur = 1
      unused_bins, len = _cbins_to_rbins(_ptr_double_offset(csolution, cur))
      cur += len
      packed_bins, len = _cbins_to_rbins(_ptr_double_offset(csolution, cur))
      cur += len
      unplaced_items, len = _citems_to_ritems(_ptr_double_offset(csolution, cur))
      [ Solution.new(unused_bins, packed_bins, unplaced_items), cur ] # Returns RSolution and its data length
    end

    # -----

    BinDef = Struct.new(:id, :count, :length, :width, :type)  # length and with must be converted to int64
    ItemDef = Struct.new(:id, :count, :rotations, :paths, :data)

    Solution = Struct.new(:unused_bins, :packed_bins, :unplaced_items)
    Bin = Struct.new(:def, :items, :cuts)
    Item = Struct.new(:def, :x, :y, :angle)  # x, y are int64
    Cut = Struct.new(:depth, :x1, :y1, :x2, :y2)  # x1, y1, x2, y2 are int64

  end

end
