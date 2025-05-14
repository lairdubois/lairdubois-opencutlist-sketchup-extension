require_relative '../wrapper'

module Ladb::OpenCutList::Fiddle

  module Xly
    extend Wrapper

    def self._lib_name
      'Xly'
    end

    def self._lib_c_functions
      [

        'char* c_write_to_xlsx(char*)',

        'char* c_version()',

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.write_to_xlsx(input)
      _load_lib
      input_json = input.to_json
      JSON.parse(c_write_to_xlsx(input_json).to_s)
    end

  end

end
