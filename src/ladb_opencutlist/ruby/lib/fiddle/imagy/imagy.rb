require_relative '../wrapper'

module Ladb::OpenCutList::Fiddle

  module Imagy
    extend Wrapper

    def self._lib_name
      'Imagy'
    end

    def self._lib_c_functions
      [

        'int c_load(const char*)',
        'int c_write(const char*)',
        'void c_clear()',

        'int c_get_width()',
        'int c_get_height()',
        'int c_get_channels()',

        'void c_flip_horizontal()',
        'void c_flip_vertical()',

        'void c_rotate(int)',

        'char* c_version()'

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.load(filename)
      _load_lib
      return c_load(filename) == 1
    end

    def self.write(filename)
      _load_lib
      return c_write(filename) == 1
    end

    def self.clear!
      _load_lib
      c_clear
    end


    def self.get_width
      _load_lib
      c_get_width
    end

    def self.get_height
      _load_lib
      c_get_height
    end


    def self.flip_horizontal!
      _load_lib
      c_flip_horizontal
    end

    def self.flip_vertical!
      _load_lib
      c_flip_vertical
    end


    def self.rotate!(angle)
      _load_lib
      c_rotate(angle)
    end

  end

end
