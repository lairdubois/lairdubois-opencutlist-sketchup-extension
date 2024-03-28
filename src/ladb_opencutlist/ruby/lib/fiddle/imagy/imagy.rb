require_relative '../wrapper'

module Ladb::OpenCutList::Fiddle

  module Imagy
    extend Wrapper

    def self._lib_name
      'Imagy'
    end

    def self._lib_c_functions
      [

        'int c_read(const char* filename)',
        'int c_write(const char* filename)',
        'void c_clear(void)',

        'int c_get_width(void)',
        'int c_get_height(void)',

        'void c_flip_x(void)',
        'void c_flip_y(void)',

        'void c_rotate_left(void)',
        'void c_rotate_right(void)',

        'char* c_version()'

      ]
    end

    # -- Debug --

    def self.version
      _load_lib
      c_version.to_s
    end

    # --

    def self.read(filename)
      _load_lib
      return c_read(filename) == 1
    end

    def self.write(filename)
      _load_lib
      return c_write(filename) == 1
    end

    def self.clear
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


    def self.flip_x!
      _load_lib
      c_flip_x
    end

    def self.flip_y!
      _load_lib
      c_flip_y
    end


    def self.rotate_left!
      _load_lib
      c_rotate_left
    end

    def self.rotate_right!
      _load_lib
      c_rotate_right
    end

  end

end
