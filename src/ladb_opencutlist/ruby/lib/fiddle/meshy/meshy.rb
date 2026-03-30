require_relative '../wrapper'

module Ladb::OpenCutList::Fiddle

  module Meshy
    extend Wrapper

    def self._lib_name
      'Meshy'
    end

    def self._lib_c_functions
      [

        'char* c_operate(char*)',

        'char* c_version()'

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.operate(input)
      _load_lib
      input_json = input.to_json
      JSON.parse(c_operate(input_json).to_s)
    end

  end

end
