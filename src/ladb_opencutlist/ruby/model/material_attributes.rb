module Ladb::OpenCutList

  require_relative '../model/section'

  class MaterialAttributes

    TYPE_UNKNOW = 0
    TYPE_SOLID_WOOD = 1
    TYPE_SHEET_GOOD = 2
    TYPE_BAR = 3

    DEFAULTS = {
        TYPE_UNKNOW => {
            :length_increase => '0',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_thicknesses => '',
            :std_sections => ''
        },
        TYPE_SOLID_WOOD => {
            :length_increase => '50mm',
            :width_increase => '5mm',
            :thickness_increase => '5mm',
            :std_thicknesses => '18mm;27mm;35mm;45mm;64mm;80mm;100mm',
            :std_sections => ''
        },
        TYPE_SHEET_GOOD => {
            :length_increase => '10mm',
            :width_increase => '10mm',
            :thickness_increase => '0',
            :std_thicknesses => '5mm;15mm;18mm;22mm',
            :std_sections => ''
        },
        TYPE_BAR => {
            :length_increase => '50mm',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_thicknesses => '',
            :std_sections => '30mmx40mm;40mmx50mm'
        },
    }

    attr_accessor :type, :length_increase, :width_increase, :thickness_increase, :std_thicknesses, :std_sections
    attr_reader :material

    def initialize(material)
      @material = material
      @type = TYPE_UNKNOW
      @length_increase = get_default(:length_increase)
      @width_increase = get_default(:width_increase)
      @thickness_increase = get_default(:thickness_increase)
      @std_thicknesses = get_default(:std_thicknesses)
      @std_sections = get_default(:std_sections)
      read_from_attributes
    end

    # -----

    def self.valid_type(type)
      if type
        i_type = type.to_i
        if i_type < TYPE_UNKNOW or i_type > TYPE_BAR
          TYPE_UNKNOW
        end
        i_type
      else
        TYPE_UNKNOW
      end
    end

    def self.type_order(type)
      case type
        when TYPE_SOLID_WOOD
          1
        when TYPE_SHEET_GOOD
          2
        when TYPE_BAR
          3
        else
          99
      end
    end

    # -----

    def length_increase
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD, TYPE_BAR
          @length_increase
        else
          get_default(:length_increase)
      end
    end

    def l_length_increase
      length_increase.to_l
    end

    def width_increase
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD
          @width_increase
        else
          get_default(:width_increase)
      end
    end

    def l_width_increase
      width_increase.to_l
    end

    def thickness_increase
      case @type
        when TYPE_SOLID_WOOD
          @thickness_increase
        else
          get_default(:thickness_increase)
      end
    end

    def l_thickness_increase
      thickness_increase.to_l
    end

    def std_thicknesses
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD
          @std_thicknesses
        else
          get_default(:std_thicknesses)
      end
    end

    def l_std_thicknesses
      a = []
      @std_thicknesses.split(';').each { |std_thickness|
        a.push((std_thickness).to_l)
      }
      a.sort!
      a
    end

    def std_sections
      case @type
        when TYPE_BAR
          @std_sections
        else
          get_default(:std_sections)
      end
    end

    def l_std_sections
      a = []
      @std_sections.split(';').each { |std_section|
        a.push(Section.new(std_section))
      }
      a
    end

    # -----

    def read_from_attributes
      if @material
        @type = Plugin.get_attribute(@material, 'type', TYPE_UNKNOW)
        @length_increase = Plugin.get_attribute(@material, 'length_increase', get_default(:length_increase))
        @width_increase = Plugin.get_attribute(@material, 'width_increase', get_default(:width_increase))
        @thickness_increase = Plugin.get_attribute(@material, 'thickness_increase', get_default(:thickness_increase))
        @std_thicknesses = Plugin.get_attribute(@material, 'std_thicknesses', get_default(:std_thicknesses))
        @std_sections = Plugin.get_attribute(@material, 'std_sections', get_default(:std_sections))
      end
    end

    def write_to_attributes
      if @material
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'type', @type)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'length_increase', @length_increase)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'width_increase', @width_increase)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_increase', @thickness_increase)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_thicknesses', @std_thicknesses)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_sections', @std_sections)
      end
    end

    def get_default(key)
      DEFAULTS[@type][key]
    end

  end

end