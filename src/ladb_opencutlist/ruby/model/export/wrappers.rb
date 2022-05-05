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

    def coerce(something)
      [self, something]
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
      super(value, Numeric)
    end

    def +(value)
      if value.respond_to?(:to_f)
        self.class.new(self.to_f + value.to_f)
      end
    end

    def -(value)
      if value.respond_to?(:to_f)
        self.class.new(self.to_f - value.to_f)
      end
    end

    def *(value)
      if value.respond_to?(:to_f)
        self.class.new(self.to_f * value.to_f)
      end
    end

    def /(value)
      if value.respond_to?(:to_f)
        self.class.new(self.to_f / value.to_f)
      end
    end

    def to_i
      @value.to_i
    end

    def to_f
      @value.to_f
    end

    def to_str
      self.to_s
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
      super(value.to_s, String)
    end

    def to_str
      @value.to_str
    end

  end

  # -----

  class ArrayWrapper < ValueWrapper

    def initialize(value)
      super(value, Array)
    end

    def to_ary
      @value.to_ary
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
        value = value.to_f
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

    def to_s
      return '' if @value == 0
      @value.to_l.to_s
    end

    def export
      self.to_s
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

    def to_s
      return '' if @value == 0
      DimensionUtils.instance.format_to_readable_area(@value)
    end

    def export
      self.to_s
    end

  end

  # -----

  class VolumeWrapper < FloatWrapper

    def to_s
      return '' if @value == 0
      DimensionUtils.instance.format_to_readable_volume(@value)
    end

    def export
      self.to_s
    end

  end

  # -----

  class EdgeWrapper < Wrapper

    attr_reader :material_name, :std_dimensions

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