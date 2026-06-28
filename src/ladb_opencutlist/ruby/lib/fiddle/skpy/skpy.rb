require_relative '../wrapper'

module Ladb::OpenCutList::Fiddle

  module Skpy
    extend Wrapper

    def self._lib_name
      'Skpy'
    end

    def self._lib_c_functions
      [

        'char* c_get_skp_version_info(char*)',

        'char* c_version()'

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.get_skp_version_info(input)
      _load_lib
      input_json = input.to_json
      JSON.parse(c_get_skp_version_info(input_json).to_s)
    end

  end

end
