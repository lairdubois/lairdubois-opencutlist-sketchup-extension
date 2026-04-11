require 'json'
require_relative '../wrapper'

module Ladb::OpenCutList::Fiddle

  module Packy
    extend Wrapper

    PROBLEM_TYPE_RECTANGLE = 'rectangle'.freeze
    PROBLEM_TYPE_RECTANGLEGUILLOTINE = 'rectangleguillotine'.freeze
    PROBLEM_TYPE_IRREGULAR = 'irregular'.freeze
    PROBLEM_TYPE_ONEDIMENSIONAL = 'onedimensional'.freeze

    OPTIMIZATION_MODE_AUTO = 'auto'.freeze
    OPTIMIZATION_MODE_ANYTIME = 'anytime'.freeze
    OPTIMIZATION_MODE_NOT_ANYTIME = 'not-anytime'.freeze
    OPTIMIZATION_MODE_NOT_ANYTIME_DETERMINISTIC = 'not-anytime-deterministic'.freeze
    OPTIMIZATION_MODE_NOT_ANYTIME_SEQUENTIAL = 'not-anytime-sequential'.freeze

    OBJECTIVE_AUTO = 'auto'.freeze
    OBJECTIVE_BIN_PACKING = 'bin-packing'.freeze
    OBJECTIVE_BIN_PACKING_WITH_LEFTOVERS = 'bin-packing-with-leftovers'.freeze
    OBJECTIVE_VARIABLE_SIZED_BIN_PACKING = 'variable-sized-bin-packing'.freeze
    OBJECTIVE_KNAPSACK = 'knapsack'.freeze

    RECTANGLEGUILLOTINE_CUT_TYPE_NON_EXACT = 'non-exact'.freeze
    RECTANGLEGUILLOTINE_CUT_TYPE_EXACT = 'exact'.freeze
    RECTANGLEGUILLOTINE_CUT_HOMOGENOUS = 'homogenous'.freeze

    @cached_outputs = {}
    @running_input_md5 = nil

    def self._lib_name
      'Packy'
    end

    def self._lib_c_functions
      [

        'char* c_optimize_start(char*)',
        'char* c_optimize_advance(int)',
        'char* c_optimize_cancel(int)',
        'char* c_optimize_cancel_all()',

        'char* c_version()',

      ]
    end

    def self.unload
      @cached_outputs = {}
      super
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.optimize_start(input, no_cache = false)
      _load_lib
      input_json = input.to_json
      input_md5 = Digest::MD5.hexdigest(input_json)
      if !no_cache && @cached_outputs.key?(input_md5)
        return @cached_outputs[input_md5].merge({ cached: true })
      end
      @running_input_md5 = input_md5
      JSON.parse(c_optimize_start(input_json).to_s)
    end

    def self.optimize_advance(run_id = 0)
      _load_lib
      output = JSON.parse(c_optimize_advance(run_id).to_s)
      if !@running_input_md5.nil? && !output['running'] && !output['cancelled'] && !output['error']
        @cached_outputs[@running_input_md5] = output
        @running_input_md5 = nil
      end
      output
    end

    def self.optimize_cancel(run_id = 0)
      return {} unless loaded?
      JSON.parse(c_optimize_cancel(run_id).to_s)
    end

    def self.optimize_cancel_all
      return {} unless loaded?
      JSON.parse(c_optimize_cancel_all.to_s)
    end

  end

end
