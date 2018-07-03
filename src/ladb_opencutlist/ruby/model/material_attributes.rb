﻿module Ladb::OpenCutList

  require 'securerandom'
  require_relative '../model/section'
  require_relative '../model/size2d'
  require_relative '../utils/dimension_utils'

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
            :std_sections => '',
            :std_sizes => '',
            :grained => false,
        },
        TYPE_SOLID_WOOD => {
            :length_increase => '50mm',
            :width_increase => '5mm',
            :thickness_increase => '5mm',
            :std_thicknesses => '18mm;27mm;35mm;45mm;64mm;80mm;100mm',
            :std_sections => '',
            :std_sizes => '',
            :grained => true,
        },
        TYPE_SHEET_GOOD => {
            :length_increase => '0',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_thicknesses => '5mm;8mm;10mm;15mm;18mm;22mm',
            :std_sections => '',
            :std_sizes => '',
            :grained => false,
        },
        TYPE_BAR => {
            :length_increase => '50mm',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_thicknesses => '',
            :std_sections => '30mm x 40mm;40mm x 50mm',
            :std_sizes => '',
            :grained => false,
        },
    }

    attr_accessor :uuid, :type, :length_increase, :width_increase, :thickness_increase, :std_thicknesses, :std_sections, :std_sizes, :grained
    attr_reader :material

    def initialize(material)
      @material = material
      @uuid = nil
      @type = TYPE_UNKNOW
      @length_increase = get_default(:length_increase)
      @width_increase = get_default(:width_increase)
      @thickness_increase = get_default(:thickness_increase)
      @std_thicknesses = get_default(:std_thicknesses)
      @std_sections = get_default(:std_sections)
      @std_sizes = get_default(:@std_sizes)
      @grained = get_default(:@grained)

      # Reload properties from attributes
      read_from_attributes

      # Init uuid if undefined
      if @uuid.nil?
        @uuid = SecureRandom.uuid
        unless material.nil?
          @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', @uuid)
        end
      end

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
      DimensionUtils.instance.dd_to_ifloats(length_increase).to_l
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
      DimensionUtils.instance.dd_to_ifloats(width_increase).to_l
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
      DimensionUtils.instance.dd_to_ifloats(thickness_increase).to_l
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
        a << DimensionUtils.instance.dd_to_ifloats(std_thickness).to_l
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
        a << Section.new(DimensionUtils.instance.dxd_to_ifloats(std_section))
      }
      a
    end

    def std_sizes
      case @type
        when TYPE_SHEET_GOOD
          @std_sizes
        else
          get_default(:@std_sizes)
      end
    end

    def l_std_sizes
      a = []
      @std_sizes.split(';').each { |std_size|
        a << Size2d.new(DimensionUtils.instance.dxd_to_ifloats(std_size))
      }
      a
    end

    # -----

    def read_from_attributes
      if @material
        @uuid = Plugin.instance.get_attribute(@material, 'uuid', nil)
        @type = Plugin.instance.get_attribute(@material, 'type', TYPE_UNKNOW)
        @length_increase = Plugin.instance.get_attribute(@material, 'length_increase', get_default(:length_increase))
        @width_increase = Plugin.instance.get_attribute(@material, 'width_increase', get_default(:width_increase))
        @thickness_increase = Plugin.instance.get_attribute(@material, 'thickness_increase', get_default(:thickness_increase))
        @std_thicknesses = Plugin.instance.get_attribute(@material, 'std_thicknesses', get_default(:std_thicknesses))
        @std_sections = Plugin.instance.get_attribute(@material, 'std_sections', get_default(:std_sections))
        @std_sizes = Plugin.instance.get_attribute(@material, 'std_sizes', get_default(:std_sizes))
        @grained = Plugin.instance.get_attribute(@material, 'grained', get_default(:grained))
      end
    end

    def write_to_attributes
      if @material
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', uuid)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'type', @type)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'length_increase', DimensionUtils.instance.str_add_units(@length_increase))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'width_increase', DimensionUtils.instance.str_add_units(@width_increase))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_increase', DimensionUtils.instance.str_add_units(@thickness_increase))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_thicknesses', DimensionUtils.instance.dd_add_units(@std_thicknesses))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_sections', DimensionUtils.instance.dxd_add_units(@std_sections))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_sizes', DimensionUtils.instance.dxd_add_units(@std_sizes))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'grained', @grained)
      end
    end

    def get_default(key)
      DEFAULTS[@type][key]
    end

  end

end