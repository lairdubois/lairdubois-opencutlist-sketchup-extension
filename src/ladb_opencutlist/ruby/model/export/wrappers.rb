module Ladb::OpenCutList

  require_relative '../../utils/unit_utils'

  class Wrapper

    def export
      ''
    end

  end

  # -----

  class ValueWrapper < Wrapper

    def initialize(value, value_class = Object.class)
      @value = value
      @value_class = value_class
    end

    def method_missing(name, *args, &blk)
      result = @value.send(name, *args, &blk)
      result.is_a?(@value_class) ? self.class.new(result) : result
    end

    def to_s
      @value.to_s
    end

    def export
      @value
    end

  end

  # -----

  class NumericWrapper < ValueWrapper

    def initialize(value)
      super(value, Numeric.class)
    end

    def +(value)
      if value.is_a?(self.class) || value.is_a?(FloatWrapper) || value.is_a?(IntegerWrapper)
        self.class.new(self.to_f + value.to_f)
      elsif value.is_a?(Float) || value.is_a?(Integer)
        self.class.new(self.to_f + value)
      elsif value.is_a?(String)
        self.to_s + value
      end
    end

    def -(value)
      if value.is_a?(self.class) || value.is_a?(FloatWrapper) || value.is_a?(IntegerWrapper)
        self.class.new(self.to_f - value.to_f)
      elsif value.is_a?(Float) || value.is_a?(Integer)
        self.class.new(self.to_f - value)
      end
    end

    def *(value)
      if value.is_a?(self.class) || value.is_a?(FloatWrapper) || value.is_a?(IntegerWrapper)
        self.class.new(self.to_f * value.to_f)
      elsif value.is_a?(Float) || value.is_a?(Integer)
        self.class.new(self.to_f * value)
      end
    end

    def /(value)
      if value.is_a?(self.class) || value.is_a?(FloatWrapper) || value.is_a?(IntegerWrapper)
        self.class.new(self.to_f / value.to_f)
      elsif value.is_a?(Float) || value.is_a?(Integer)
        self.class.new(self.to_f / value)
      end
    end

    def to_i
      @value.to_i
    end

    def to_f
      @value.to_f
    end

  end

  # -----

  class IntegerWrapper < NumericWrapper

    def initialize(value)
      super(value.to_i)
    end

  end

  # -----

  class FloatWrapper < NumericWrapper

    def initialize(value)
      super(value.to_f)
    end

  end

  # -----

  class StringWrapper < ValueWrapper

    def initialize(value)
      super(value.to_s, String.class)
    end

  end

  # -----

  class ArrayWrapper < ValueWrapper

    def initialize(value)
      super(value, Array.class)
    end

    def to_s
      @value.join(',')
    end

    def export
      self.to_s
    end

  end

  # -----

  class LengthWrapper < FloatWrapper

    def initialize(value)
      if value.is_a?(Length)
        value = value.to_mm   # TODO : Convert to model unit
      end
      super(value)
    end

    def *(value)
      if value.is_a?(LengthWrapper)
        AreaWrapper.new(self.to_f * value.to_f)
      elsif value.is_a?(AreaWrapper)
        VolumeWrapper.new(self.to_f * value.to_f)
      else
        super
      end
    end

    def export
      return '' if @value == 0
      @value.to_i # TODO : format according to SketchUp formatter
    end

  end

  # -----

  class AreaWrapper < FloatWrapper

    def *(value)
      if value.is_a?(LengthWrapper)
        VolumeWrapper.new(self.to_f * value.to_f)
      else
        super
      end
    end

    def export
      return '' if @value == 0
      @value.to_i  # TODO : format according to SketchUp formatter
    end

  end

  # -----

  class VolumeWrapper < FloatWrapper

    def export
      return '' if @value == 0
      @value.to_i  # TODO : format according to SketchUp formatter
    end

  end

  # -----

  class EdgeWrapper < Wrapper

    attr_reader :material_name, :thickness, :width

    def initialize(material_name, std_dimensions)
      @material_name = StringWrapper.new(material_name)
      @std_dimensions = StringWrapper.new(std_dimensions)
    end

    def empty?
      @material_name.empty?
    end

    def to_s
      return '' if @material_name.empty?
      "#{@material_name.to_s} (#{@std_dimensions.to_s})"
    end

    def export
      self.to_s
    end

  end

end