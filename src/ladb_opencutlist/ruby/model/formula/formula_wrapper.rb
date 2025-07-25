module Ladb::OpenCutList

  require_relative '../../utils/unit_utils'
  require_relative '../../utils/path_utils'
  require_relative '../../model/attributes/material_attributes'

  class FormulaWrapper

    def export
      ''
    end

    private

    def _raise_no_method_error(method_name)
      raise NoMethodError, "undefined method `#{method_name}' for #{self.class}"
    end

  end

  # -----

  class ValueFormulaWrapper < FormulaWrapper

    def initialize(value, value_class = Object)
      @value = value
      @value_class = value_class
    end

    def method_missing(name, *args, &blk)
      result = @value.send(name, *args, &blk)
      result.is_a?(@value_class) ? self.class.new(result) : result
    end

    def coerce(something)
      [ self, something ]
    end

    def to_s
      @value.to_s
    end

    def export
      @value
    end

  end

  # -----

  class NumericFormulaWrapper < ValueFormulaWrapper

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

  class IntegerFormulaWrapper < NumericFormulaWrapper

    def initialize(value)
      super(value.to_i)
    end

  end

  # -----

  class FloatFormulaWrapper < NumericFormulaWrapper

    def initialize(value)
      super(value.to_f)
    end

  end

  # -----

  class StringFormulaWrapper < ValueFormulaWrapper

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

  class ArrayFormulaWrapper < ValueFormulaWrapper

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

  class ColorFormulaWrapper < ValueFormulaWrapper

    def initialize(value)
      super(value, Sketchup::Color)
    end

    # -- Privatisation

    def alpha=(*args)
      _raise_no_method_error(__method__)
    end

    def blue=(*args)
      _raise_no_method_error(__method__)
    end

    def green=(*args)
      _raise_no_method_error(__method__)
    end

    def red=(*args)
      _raise_no_method_error(__method__)
    end

    # -----

    def export
      self.to_s
    end

  end

  # -----

  class EntityFormulaWrapper < ValueFormulaWrapper

    def initialize(value, value_class = Sketchup::Entity)
      super
    end

    # -- Privatisation

    def add_observer(*args)
      _raise_no_method_error(__method__)
    end

    def remove_observer(*args)
      _raise_no_method_error(__method__)
    end

    def attribute_dictionaries
      _raise_no_method_error(__method__)
    end

    def attribute_dictionary(*args)
      _raise_no_method_error(__method__)
    end

    def set_attribute(*args)
      _raise_no_method_error(__method__)
    end

    def delete_attribute(*args)
      _raise_no_method_error(__method__)
    end

    def model
      _raise_no_method_error(__method__)
    end

    def parent
      _raise_no_method_error(__method__)
    end

  end

  class DrawingElementFormulaWrapper < EntityFormulaWrapper

    def initialize(value, value_class = Sketchup::DrawingElement)
      super
    end

    # -- Privatisation

    def hidden=(*args)
      _raise_no_method_error(__method__)
    end

    def visible=(*args)
      _raise_no_method_error(__method__)
    end

    def layer=(*args)
      _raise_no_method_error(__method__)
    end

    def material=(*args)
      _raise_no_method_error(__method__)
    end

    def cast_shadows=(*args)
      _raise_no_method_error(__method__)
    end

    def receives_shadows=(*args)
      _raise_no_method_error(__method__)
    end

    def erase!
      _raise_no_method_error(__method__)
    end

  end

  class ComponentDefinitionFormulaWrapper < DrawingElementFormulaWrapper

    def initialize(value)
      super(value, Sketchup::ComponentDefinition)
    end

    # -- Privatisation

    def name=(name)
      _raise_no_method_error(__method__)
    end

    def description=(description)
      _raise_no_method_error(__method__)
    end

    def thumbnail_camera=(*args)
      _raise_no_method_error(__method__)
    end

    def entities
      _raise_no_method_error(__method__)
    end

    def instances
      _raise_no_method_error(__method__)
    end

    def add_classification(*args)
      _raise_no_method_error(__method__)
    end

    def remove_classification(*args)
      _raise_no_method_error(__method__)
    end

    def set_classification_value(*args)
      _raise_no_method_error(__method__)
    end

    def save_as(*args)
      _raise_no_method_error(__method__)
    end

    def save_copy(*args)
      _raise_no_method_error(__method__)
    end

    def save_thumbnail(*args)
      _raise_no_method_error(__method__)
    end

    # -----

    def get_dc_attribute(key)
      @value.get_attribute('dynamic_attributes', key.to_s.downcase) # DC attribute names are always stored lower case.
    end

    def export
      return '' if @value.nil?
      self.name
    end

  end

  class ComponentInstanceFormulaWrapper < DrawingElementFormulaWrapper

    def initialize(value, path = [])
      super(value, Sketchup::ComponentInstance)
      @path = path
    end

    private def _local_position
      ta = transformation.to_a
      Geom::Point3d.new(ta[12], ta[13], ta[14])
    end

    def local_x
      LengthFormulaWrapper.new(_local_position.x, true, true)
    end

    def local_y
      LengthFormulaWrapper.new(_local_position.y, true, true)
    end

    def local_z
      LengthFormulaWrapper.new(_local_position.z, true, true)
    end

    private def _world_position
      ORIGIN.transform(PathUtils.get_transformation(@path, IDENTITY))
    end

    def world_x
      LengthFormulaWrapper.new(_world_position.x, true, true)
    end

    def world_y
      LengthFormulaWrapper.new(_world_position.y, true, true)
    end

    def world_z
      LengthFormulaWrapper.new(_world_position.z, true, true)
    end

    # -- Privatisation

    def name=(*args)
      _raise_no_method_error(__method__)
    end

    def definition=(*args)
      _raise_no_method_error(__method__)
    end

    def glue_to=(*args)
      _raise_no_method_error(__method__)
    end

    def locked=(*args)
      _raise_no_method_error(__method__)
    end

    def transformation=(*args)
      _raise_no_method_error(__method__)
    end

    def make_unique(*args)
      _raise_no_method_error(__method__)
    end

    def explode(*args)
      _raise_no_method_error(__method__)
    end

    def split(*args)
      _raise_no_method_error(__method__)
    end

    def trim(*args)
      _raise_no_method_error(__method__)
    end

    def union(*args)
      _raise_no_method_error(__method__)
    end

    def substract(*args)
      _raise_no_method_error(__method__)
    end

    def intersect(*args)
      _raise_no_method_error(__method__)
    end

    def outer_shell(*args)
      _raise_no_method_error(__method__)
    end

    def show_differences(*args)
      _raise_no_method_error(__method__)
    end

    def move!(*args)
      _raise_no_method_error(__method__)
    end

    def transform!(*args)
      _raise_no_method_error(__method__)
    end

    # -----

    def get_dc_attribute(key)
      @value.get_attribute('dynamic_attributes', key)
    end

    def export
      return '' if @value.nil?
      self.name
    end

  end

  # -----

  class LengthFormulaWrapper < FloatFormulaWrapper

    def initialize(value, output_to_model_unit = true, output_zero = false)
      value = value.to_f if value.is_a?(Length)
      super(value)
      @output_to_model_unit = output_to_model_unit
      @output_zero = output_zero
    end

    def *(value)
      if value.is_a?(LengthFormulaWrapper)
        AreaFormulaWrapper.new(self.to_f * value.to_f)
      elsif value.is_a?(AreaFormulaWrapper)
        VolumeFormulaWrapper.new(self.to_f * value.to_f)
      else
        super
      end
    end

    def to_s
      return '' if @value == 0 && !@output_zero
      return DimensionUtils.format_to_readable_length(@value) unless @output_to_model_unit
      @value.to_l.to_s.gsub(/^~ /, '')  # Remove ~ character if it exists
    end

    def export
      self.to_s
    end

  end

  # -----

  class AreaFormulaWrapper < FloatFormulaWrapper

    def *(value)
      if value.is_a?(LengthFormulaWrapper)
        VolumeFormulaWrapper.new(self.to_f * value.to_f)
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
      DimensionUtils.format_to_readable_area(@value)
    end

    def export
      self.to_s
    end

  end

  # -----

  class VolumeFormulaWrapper < FloatFormulaWrapper

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
      DimensionUtils.format_to_readable_volume(@value)
    end

    def export
      self.to_s
    end

  end

  # -----

  class PathFormulaWrapper < ArrayFormulaWrapper

    def to_s
      return '' unless @value.is_a?(Array)
      @value.join('/')
    end

  end

  # -----

  class BatchFormulaWrapper < FormulaWrapper

    attr_reader :position, :count

    def initialize(position, count)
      @position = IntegerFormulaWrapper.new(position)
      @count = IntegerFormulaWrapper.new(count)
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

  class MaterialTypeFormulaWrapper < ValueFormulaWrapper

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
      PLUGIN.get_i18n_string("tab.materials.type_#{@value}")
    end

    def export
      self.to_s
    end

  end

  class MaterialFormulaWrapper < FormulaWrapper

    attr_reader :name, :color, :type, :description, :url
    attr_reader :std_dimension, :std_thickness, :std_width

    def initialize(material, group_def)

      @material = material
      @group_def = group_def

      @name = StringFormulaWrapper.new(material.nil? ? nil : material.display_name)
      @color = ColorFormulaWrapper.new(material.nil? ? nil : material.color)

      @type = MaterialTypeFormulaWrapper.new(group_def.nil? ? MaterialAttributes::TYPE_UNKNOWN : group_def.material_attributes.type)
      @description = StringFormulaWrapper.new(group_def.nil? ? nil : group_def.material_attributes.description)
      @url = StringFormulaWrapper.new(group_def.nil? ? nil : group_def.material_attributes.url)

      @std_dimension = StringFormulaWrapper.new(group_def ? group_def.std_dimension : nil)
      @std_thickness = LengthFormulaWrapper.new(group_def ? group_def.std_thickness : nil)
      @std_width = LengthFormulaWrapper.new(group_def ? group_def.std_width : nil)

    end

    def empty?
      @material.nil?
    end

    def grained?
      return false if @group_def.nil? || @group_def.material_attributes.nil?
      @group_def.material_attributes.grained
    end

    def to_s
      return PLUGIN.get_i18n_string('tab.cutlist.material_undefined') if empty?
      name.to_s
    end

    def export
      self.to_s
    end

  end

  class EdgeFormulaWrapper < MaterialFormulaWrapper

    # BC for old edge wrapper
    alias_method :material_name, :name
    alias_method :material_color, :color

    def to_s
      return '' if empty?
      "#{super} (#{std_thickness.to_s} x #{std_width.to_s})"
    end

  end

  class VeneerFormulaWrapper < MaterialFormulaWrapper

    # BC for old veneer wrapper
    alias_method :material_name, :name
    alias_method :material_color, :color

    def to_s
      return '' if empty?
      "#{super} (#{std_thickness.to_s})"
    end

  end

end