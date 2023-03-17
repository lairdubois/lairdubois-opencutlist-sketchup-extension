module Ladb::OpenCutList::Kuix

  class Size3d

    attr_accessor :width, :height, :thickness

    def initialize(width = 0, height = 0, thickness = 0)
      set!(width, height, thickness)
    end

    def set!(width = 0, height = 0, thickness = 0)
      @width = width >= 0 ? width : 0               # Force width to be positive
      @height = height >= 0 ? height : 0            # Force height to be positive
      @thickness = thickness >= 0 ? thickness : 0   # Force thickness to be positive
    end

    def set_all!(value = 0)
      set!(value, value, value)
    end

    def copy!(size)
      set!(size.width, size.height, size.thickness)
    end

    # -- Tests --

    def is_empty?
      @width == 0 || @height == 0 || @thickness == 0
    end

    # --

    def to_s
      "#{self.class.name} (width=#{@width}, height=#{@height}, thickness=#{@thickness})"
    end

  end

end