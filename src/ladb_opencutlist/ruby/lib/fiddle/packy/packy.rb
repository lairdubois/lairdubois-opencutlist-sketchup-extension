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

    # -----

    BinDef = Struct.new(:length, :width, :type)
    ItemDef = Struct.new(:projection_def, :data)

    Solution = Struct.new(:unused_bins, :packed_bins, :unplaced_items)
    Bin = Struct.new(:def, :copies, :items, :cuts)
    Item = Struct.new(:def, :x, :y, :angle)
    Cut = Struct.new(:depth, :x, :y, :length, :orientation)

    # -----

    class Input

      attr_reader :problem_type,
                  :parameters,
                  :instance

      def initialize(problem_type)
        @problem_type = problem_type
        @parameters = InputParameters.new
        @instance = Instance.new
      end

    end

    class InputParameters

    end

    class Instance

      attr_reader :parameters,
                  :bin_types,
                  :item_types

      def initialize
        @parameters = InstanceParameters.new
        @bin_types = []
        @item_types = []
      end

    end

    class InstanceParameters

      def initialize
      end

    end

    class BinType

      attr_accessor :copies,
                    :length,
                    :width,

      def initialize
        @copies = 1
        @length = -1
        @width = -1
      end

    end

    class ItemType

      attr_accessor :copies

      def initialize
        @copies = 1
      end

    end

    class OnedimensionalItemType < ItemType

      attr_accessor :length

      def initialize
        super
        @length = -1
      end

    end

    class RectangleItemType < ItemType

      attr_accessor :length,
                    :width

      def initialize
        super
        @length = -1
        @width = -1
      end

    end

    class IrregularItemType < ItemType

      attr_reader :shapes,
                  :allowed_rotations

      def initialize
        super
        @shapes = []
        @allowed_rotations = []
      end

    end

    class IrregularShape

      attr_reader :vertices

      def initialize
        @vertices = []
      end

    end

    class IrregularItemShape < IrregularShape

      attr_reader :holes

      def initialize
        super
        @holes = []
      end

    end

  end

end
