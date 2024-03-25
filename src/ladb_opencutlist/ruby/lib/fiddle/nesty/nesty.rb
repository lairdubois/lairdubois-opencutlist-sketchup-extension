require_relative '../clipper_wrapper'

module Ladb::OpenCutList::Fiddle

  module Nesty
    extend ClipperWrapper

    def self._lib_name
      "Nesty"
    end

    def self._lib_c_functions
      [

        'char* c_version()'

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

  end

end
