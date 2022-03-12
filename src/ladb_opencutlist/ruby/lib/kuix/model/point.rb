module Ladb::OpenCutList::Kuix

  class Point

    attr_accessor :x, :y

    def initialize(x = 0, y = 0)
      set(x, y)
    end

    def set(x = 0, y = 0)
      @x = x
      @y = y
    end

    def to_s
      "#{self.class.name} (x=#{@x}, y=#{@y})"
    end

  end

end