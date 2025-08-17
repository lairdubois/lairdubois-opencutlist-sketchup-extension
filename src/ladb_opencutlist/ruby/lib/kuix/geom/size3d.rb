module Ladb::OpenCutList::Kuix

  class Size3d

    attr_accessor :width, :height, :depth

    def initialize(width = 0, height = 0, depth = 0)
      set!(width, height, depth)
    end

    def set!(width = 0, height = 0, depth = 0)
      @width = width >= 0 ? width : 0               # Force width to be positive
      @height = height >= 0 ? height : 0            # Force height to be positive
      @depth = depth >= 0 ? depth : 0               # Force depth to be positive
      self
    end

    def set_all!(value = 0)
      set!(value, value, value)
    end

    def copy!(size)
      set!(
        size.respond_to?(:width) ? size.width : 0,
        size.respond_to?(:height) ? size.height : 0,
        size.respond_to?(:depth) ? size.depth : 0
      )
    end

    # -- Tests --

    def is_empty?
      @width == 0 || @height == 0 || @depth == 0
    end

    # --

    def to_s
      "#{self.class.name} (width=#{@width}, height=#{@height}, depth=#{@depth})"
    end

  end

end