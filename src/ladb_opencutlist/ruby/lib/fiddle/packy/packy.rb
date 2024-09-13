require_relative '../clipper_wrapper'

module Ladb::OpenCutList::Fiddle

  module Packy
    extend ClipperWrapper

    PROBLEM_TYPE_RECTANGLE = 'rectangle'
    PROBLEM_TYPE_RECTANGLEGUILLOTINE = 'rectangleguillotine'
    PROBLEM_TYPE_IRREGULAR = 'irregular'
    PROBLEM_TYPE_ONEDIMENSIONAL = 'onedimensional'

    @bin_defs_cache = {}
    @item_defs_cache = {}

    def self._lib_name
      'Packy'
    end

    def self._lib_c_functions
      [

        'void c_optimize_start(char*)',
        'char* c_optimize_advance()',
        'void c_optimize_cancel()',

        'char* c_version()',

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.optimize_start(input)
      _load_lib
      c_optimize_start(input.to_json)
    end

    def self.optimize_advance
      _load_lib
      output = JSON.parse(c_optimize_advance.to_s)
      return output
    end

    def self.optimize_cancel
      c_optimize_cancel if loaded?
    end

    # -----

    BinDef = Struct.new(:length, :width, :type)
    ItemDef = Struct.new(:projection_def, :data, :color)

    Bin = Struct.new(:def, :copies, :items, :cuts)
    Item = Struct.new(:def, :x, :y, :angle, :mirror)
    Cut = Struct.new(:depth, :x, :y, :length, :orientation)

  end

end
