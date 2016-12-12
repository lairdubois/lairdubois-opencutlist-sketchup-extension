class MaterialAttributes

  ATTRIBUTE_DICTIONARY = 'ladb_toolbox'

  TYPE_UNKNOW = 0
  TYPE_HARDWOOD = 1
  TYPE_PLYWOOD = 2

  DEFAULTS = {
      TYPE_UNKNOW => {
          :length_increase => 0,
          :width_increase => 0,
          :thickness_increase => 0,
          :std_thicknesses => ''
      },
      TYPE_HARDWOOD => {
          :length_increase => 50,
          :width_increase => 5,
          :thickness_increase => 5,
          :std_thicknesses => '18;27;35;45;64;80;100'
      },
      TYPE_PLYWOOD => {
          :length_increase => 10,
          :width_increase => 10,
          :thickness_increase => 0,
          :std_thicknesses => '5;15;18;22'
      },
  }

  attr_accessor :type, :length_increase, :width_increase, :thickness_increase, :std_thicknesses
  attr_reader :material

  def initialize(material)
    @material = material
    load_from_attributes
  end

  def load_from_attributes
    @type = material.get_attribute(ATTRIBUTE_DICTIONARY, 'type', TYPE_UNKNOW)
    @length_increase = material.get_attribute(ATTRIBUTE_DICTIONARY, 'length_increase', get_default(:length_increase))
    @width_increase = material.get_attribute(ATTRIBUTE_DICTIONARY, 'width_increase', get_default(:width_increase))
    @thickness_increase = material.get_attribute(ATTRIBUTE_DICTIONARY, 'thickness_increase', get_default(:thickness_increase))
    @std_thicknesses = material.get_attribute(ATTRIBUTE_DICTIONARY, 'std_thicknesses', get_default(:std_thicknesses))
  end

  def save_to_attributes
    material.set_attribute(ATTRIBUTE_DICTIONARY, 'type', @type)
    material.set_attribute(ATTRIBUTE_DICTIONARY, 'length_increase', @length_increase)
    material.set_attribute(ATTRIBUTE_DICTIONARY, 'width_increase', @width_increase)
    material.set_attribute(ATTRIBUTE_DICTIONARY, 'thickness_increase', @thickness_increase)
    material.set_attribute(ATTRIBUTE_DICTIONARY, 'std_thicknesses', @std_thicknesses)
  end

  def get_default(key)
    DEFAULTS[@type][key]
  end

end