module Ladb::OpenCutList

  require_relative '../../utils/unit_utils'
  require_relative '../../model/attributes/material_attributes'

  class Wrapper

    def export
      ''
    end

  end

  # -----

  class ValueWrapper < Wrapper

    def initialize(value, value_class = Object)
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
      if value.is_a?(String)
        self.to_s + value
      elsif value.respond_to?(:to_f)
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

    def ==(value)
      if value.respond_to?(:to_f)
        self.to_f == value.to_f
      end
    end

    def >(value)
      if value.respond_to?(:to_f)
        self.to_f > value.to_f
      end
    end

    def >=(value)
      if value.respond_to?(:to_f)
        self.to_f >= value.to_f
      end
    end

    def <(value)
      if value.respond_to?(:to_f)
        self.to_f < value.to_f
      end
    end

    def <=(value)
      if value.respond_to?(:to_f)
        self.to_f <= value.to_f
      end
    end

    def to_mm
      @value.to_mm.round(6)    # Returns the float representation of the value converted from inches to milimeters
    end

    def to_cm
      @value.to_cm.round(6)    # Returns the float representation of the value converted from inches to centimeters
    end

    def to_m
      @value.to_m.round(6)     # Returns the float representation of the value converted from inches to meters
    end

    def to_km
      @value.to_km.round(6)    # Returns the float representation of the value converted from inches to kilometers
    end

    def to_inch
      @value.to_inch.round(6)  # Returns the float representation of the value converted from inches to inches
    end

    def to_feet
      @value.to_feet.round(6)  # Returns the float representation of the value converted from inches to feet
    end

    def to_mile
      @value.to_mile.round(6)  # Returns the float representation of the value converted from inches to miles
    end

    def to_yard
      @value.to_yard.round(6)  # Returns the float representation of the value converted from inches to yards
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

    def ==(value)
      @value == value
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

  class ColorWrapper < ValueWrapper

    def initialize(value)
      super(value, Sketchup::Color)
    end

    def export
      self.to_s
    end

  end

  # -----

  class LengthWrapper < FloatWrapper

    def initialize(value, output_to_model_unit = true)
      if value.is_a?(Length)
        value = value.to_f
      end
      super(value)
      @output_to_model_unit = output_to_model_unit
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
      return DimensionUtils.instance.format_to_readable_length(@value) unless @output_to_model_unit
      @value.to_l.to_s.gsub(/^~ /, '')  # Remove ~ character if it exists
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

    def to_mm2
      @value.to_mm.to_mm.round(6)      # Returns the float representation of the value converted from inches to milimeters²
    end

    def to_cm2
      @value.to_cm.to_cm.round(6)      # Returns the float representation of the value converted from inches to centimeters²
    end

    def to_m2
      @value.to_m.to_m.round(6)        # Returns the float representation of the value converted from inches to meters²
    end

    def to_km2
      @value.to_km.to_km.round(6)      # Returns the float representation of the value converted from inches to kilometers²
    end

    def to_inch2
      @value.to_inch.to_inch.round(6)  # Returns the float representation of the value converted from inches to inches²
    end

    def to_feet2
      @value.to_feet.to_feet.round(6)  # Returns the float representation of the value converted from inches to feet²
    end

    def to_mile2
      @value.to_mile.to_mile.round(6)  # Returns the float representation of the value converted from inches to miles²
    end

    def to_yard2
      @value.to_inch.to_inch.round(6)  # Returns the float representation of the value converted from inches to yards²
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

    def to_mm3
      @value.to_mm.to_mm.to_mm.round(6)         # Returns the float representation of the value converted from inches to milimeters³
    end

    def to_cm3
      @value.to_cm.to_cm.to_cm.round(6)         # Returns the float representation of the value converted from inches to centimeters³
    end

    def to_m3
      @value.to_m.to_m.to_m.round(6)            # Returns the float representation of the value converted from inches to meters³
    end

    def to_km3
      @value.to_km.to_km.to_km.round(6)         # Returns the float representation of the value converted from inches to kilometers³
    end

    def to_inch3
      @value.to_inch.to_inch.to_inch.round(6)   # Returns the float representation of the value converted from inches to inches³
    end

    def to_feet3
      @value.to_feet.to_feet.to_feet.round(6)   # Returns the float representation of the value converted from inches to feet³
    end

    def to_mile3
      @value.to_mile.to_mile.to_mile.round(6)   # Returns the float representation of the value converted from inches to miles³
    end

    def to_yard3
      @value.to_yard.to_yard.to_yard.round(6)   # Returns the float representation of the value converted from inches to yards³
    end

    def to_fbm
      (to_inch3 / 144.0).round(6)               # Returns the float representation of the value converted from inches to board feet
    end

    def to_s
      return '' if @value == 0
      DimensionUtils.instance.format_to_readable_volume(@value)
    end

    def export
      self.to_s
    end

  end

  # -----

  class PathWrapper < ArrayWrapper

    def to_s
      return '' unless @value.is_a?(Array)
      @value.join('/')
    end

  end

  # -----

  class MaterialTypeWrapper < ValueWrapper

    def initialize(value)
      super(value, Integer)
    end

    def is_solid_wood?
      @value == MaterialAttributes::TYPE_SOLID_WOOD
    end

    def is_sheet_good?
      @value == MaterialAttributes::TYPE_SHEET_GOOD
    end

    def is_dimensional?
      @value == MaterialAttributes::TYPE_DIMENSIONAL
    end

    def is_hardware?
      @value == MaterialAttributes::TYPE_HARDWARE
    end

    def is_edge?
      @value == MaterialAttributes::TYPE_EDGE
    end

    def is_veneer?
      @value == MaterialAttributes::TYPE_VENEER
    end

    def to_i
      @value
    end

    def to_s
      Plugin.instance.get_i18n_string("tab.materials.type_#{@value}")
    end

    def export
      self.to_s
    end

  end

  # -----

  class BatchWrapper < Wrapper

    attr_reader :position, :count

    def initialize(position, count)
      @position = IntegerWrapper.new(position)
      @count = IntegerWrapper.new(count)
    end

    def +(value)
      if value.is_a?(String)
        self.to_s + value
      end
    end

    def to_s
      "#{@position.to_s }/#{@count.to_s}"
    end

    def export
      self.to_s
    end

  end

  # -----

  class EdgeWrapper < Wrapper

    attr_reader :material_name, :material_color, :std_thickness, :std_width

    def initialize(material_name, material_color, std_thickness, std_width)
      @material_name = StringWrapper.new(material_name)
      @material_color = ColorWrapper.new(material_color)
      @std_thickness = LengthWrapper.new(std_thickness)
      @std_width = LengthWrapper.new(std_width)
    end

    def empty?
      @material_name.empty?
    end

    def to_s
      return '' if @material_name.empty?
      "#{@material_name.to_s} (#{@std_thickness.to_s} x #{@std_width.to_s})"
    end

    def export
      self.to_s
    end

  end

  # -----

  class VeneerWrapper < Wrapper

    attr_reader :material_name, :material_color, :std_thickness

    def initialize(material_name, material_color, std_thickness)
      @material_name = StringWrapper.new(material_name)
      @material_color = ColorWrapper.new(material_color)
      @std_thickness = LengthWrapper.new(std_thickness)
    end

    def empty?
      @material_name.empty?
    end

    def to_s
      return '' if @material_name.empty?
      "#{@material_name.to_s} (#{@std_thickness.to_s})"
    end

    def export
      self.to_s
    end

  end

end