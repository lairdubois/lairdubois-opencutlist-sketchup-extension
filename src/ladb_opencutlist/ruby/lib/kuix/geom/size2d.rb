module Ladb::OpenCutList::Kuix

  class Size2d

    attr_accessor :width, :height

    def initialize(width = 0, height = 0)
      set!(width, height)
    end

    def set!(width = 0, height = 0)
      @width = width >= 0 ? width : 0       # Force width to be positive
      @height = height >= 0 ? height : 0    # Force height to be positive
      self
    end

    def set_all!(value = 0)
      set!(value, value)
    end

    def copy!(size)
      set!(
        size.respond_to?(:width) ? size.width : 0,
        size.respond_to?(:height) ? size.height : 0
      )
    end

    # -- Tests --

    def is_empty?
      @width == 0 || @height == 0
    end

    # --

    def to_s
      "#{self.class.name} (width=#{@width}, height=#{@height})"
    end

  end

end