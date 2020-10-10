module Ladb::OpenCutList

  require 'securerandom'
  require_relative '../geom/size2d'
  require_relative '../geom/section'
  require_relative '../../utils/dimension_utils'

  class MaterialAttributes

    TYPE_UNKNOW = 0
    TYPE_SOLID_WOOD = 1
    TYPE_SHEET_GOOD = 2
    TYPE_DIMENSIONAL = 3
    TYPE_EDGE = 4
    TYPE_ACCESSORY = 5

    DEFAULTS = {
        TYPE_UNKNOW => {
            :thickness => '0',
            :length_increase => '0',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_lengths => '',
            :std_widths => '',
            :std_thicknesses => '',
            :std_sections => '',
            :std_sizes => '',
            :grained => false,
            :edge_decremented => false,
        },
        TYPE_SOLID_WOOD => {
            :thickness => '0',
            :length_increase => '50mm',
            :width_increase => '5mm',
            :thickness_increase => '5mm',
            :std_lengths => '',
            :std_widths => '',
            :std_thicknesses => '18mm;27mm;35mm;45mm;64mm;80mm;100mm',
            :std_sections => '',
            :std_sizes => '',
            :grained => true,
            :edge_decremented => false,
        },
        TYPE_SHEET_GOOD => {
            :thickness => '0',
            :length_increase => '0',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_lengths => '',
            :std_widths => '',
            :std_thicknesses => '5mm;8mm;10mm;15mm;18mm;22mm',
            :std_sections => '',
            :std_sizes => '',
            :grained => false,
            :edge_decremented => false,
        },
        TYPE_DIMENSIONAL => {
            :thickness => '0',
            :length_increase => '50mm',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_lengths => '2400mm',
            :std_widths => '',
            :std_thicknesses => '',
            :std_sections => '30mm x 40mm;40mm x 50mm',
            :std_sizes => '',
            :grained => false,
            :edge_decremented => false,
        },
        TYPE_EDGE => {
            :thickness => '2mm',
            :length_increase => '50mm',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_lengths => '',
            :std_widths => '23mm;33mm;43mm',
            :std_thicknesses => '',
            :std_sections => '',
            :std_sizes => '',
            :grained => false,
            :edge_decremented => true,
        },
        TYPE_ACCESSORY => {
            :thickness => '0',
            :length_increase => '0',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_lengths => '',
            :std_widths => '',
            :std_thicknesses => '',
            :std_sections => '',
            :std_sizes => '',
            :grained => false,
            :edge_decremented => false,
        },
    }

    attr_accessor :uuid, :type, :thickness, :length_increase, :width_increase, :thickness_increase, :std_lengths, :std_widths, :std_thicknesses, :std_sections, :std_sizes, :grained, :edge_decremented
    attr_reader :material

    @@used_uuids = []

    def initialize(material, force_unique_uuid = false)
      @material = material
      read_from_attributes(force_unique_uuid)
    end

    # -----

    def self.reset_used_uuids
      @@used_uuids.clear
    end

    def self.valid_type(type)
      if type
        i_type = type.to_i
        if i_type < TYPE_UNKNOW or i_type > TYPE_ACCESSORY
          TYPE_UNKNOW
        end
        i_type
      else
        TYPE_UNKNOW
      end
    end

    def self.material_order(material_a, material_b, strategy)
      a_values = []
      b_values = []
      if strategy
        properties = strategy.split('>')
        properties.each { |property|
          if property.length < 1
            next
          end
          asc = true
          if property.start_with?('-')
            asc = false
            property.slice!(0)
          end
          case property
          when 'type'
            a_value = [ self.type_order(material_a[:attributes][:type]) ]
            b_value = [ self.type_order(material_b[:attributes][:type]) ]
          when 'name'
            a_value = [ material_a[:display_name] ]
            b_value = [ material_b[:display_name] ]
          else
            next
          end
          if asc
            a_values.concat(a_value)
            b_values.concat(b_value)
          else
            a_values.concat(b_value)
            b_values.concat(a_value)
          end
        }
      end
      a_values <=> b_values
    end

    def self.type_order(type)
      case type
        when TYPE_SOLID_WOOD
          1
        when TYPE_SHEET_GOOD
          2
        when TYPE_DIMENSIONAL
          3
        when TYPE_EDGE
          4
        when TYPE_ACCESSORY
          5
        else
          99
      end
    end

    # -----

    def thickness
      case @type
      when TYPE_EDGE
        @thickness
      else
        get_default(:thickness)
      end
    end

    def l_thickness
      DimensionUtils.instance.d_to_ifloats(thickness).to_l
    end

    def length_increase
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD, TYPE_DIMENSIONAL, TYPE_EDGE
          @length_increase
        else
          get_default(:length_increase)
      end
    end

    def l_length_increase
      DimensionUtils.instance.d_to_ifloats(length_increase).to_l
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
      DimensionUtils.instance.d_to_ifloats(width_increase).to_l
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
      DimensionUtils.instance.d_to_ifloats(thickness_increase).to_l
    end

    def std_lengths
      case @type
      when TYPE_DIMENSIONAL
        @std_lengths
      else
        get_default(:std_lengths)
      end
    end

    def append_std_length(std_length)
      @std_lengths = @std_lengths.empty? ? std_length : [ @std_lengths, std_length].join(';')
    end

    def l_std_lengths
      a = []
      @std_lengths.split(';').each { |std_length|
        a << DimensionUtils.instance.d_to_ifloats(std_length).to_l
      }
      a.sort!
      a
    end

    def std_widths
      case @type
      when TYPE_EDGE
        @std_widths
      else
        get_default(:std_widths)
      end
    end

    def append_std_width(std_width)
      @std_widths = @std_widths.empty? ? std_width : [ @std_widths, std_width].join(';')
    end

    def l_std_widths
      a = []
      @std_widths.split(';').each { |std_width|
        a << DimensionUtils.instance.d_to_ifloats(std_width).to_l
      }
      a.sort!
      a
    end

    def std_thicknesses
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD
          @std_thicknesses
        else
          get_default(:std_thicknesses)
      end
    end

    def append_std_thickness(std_thickness)
      @std_thicknesses = @std_thicknesses.empty? ? std_thickness : [ @std_thicknesses, std_thickness].join(';')
    end

    def l_std_thicknesses
      a = []
      @std_thicknesses.split(';').each { |std_thickness|
        a << DimensionUtils.instance.d_to_ifloats(std_thickness).to_l
      }
      a.sort!
      a
    end

    def std_sections
      case @type
        when TYPE_DIMENSIONAL
          @std_sections
        else
          get_default(:std_sections)
      end
    end

    def append_std_section(std_section)
      @std_sections = @std_sections.empty? ? std_section : [ @std_sections, std_section].join(';')
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

    def read_from_attributes(force_unique_uuid = false)
      if @material

        # Special case for UUID that must be truely unique in the session
        uuid = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', nil)
        if uuid.nil? or (force_unique_uuid and @@used_uuids.include?(uuid))

          # Generate a new UUID
          uuid = SecureRandom.uuid

          # Store the new uuid to material attributes
          @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', uuid)

        end
        @@used_uuids.push(uuid)
        @uuid = uuid

        @type = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'type', TYPE_UNKNOW)
        @thickness = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness', get_default(:thickness))
        @length_increase = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'length_increase', get_default(:length_increase))
        @width_increase = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'width_increase', get_default(:width_increase))
        @thickness_increase = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_increase', get_default(:thickness_increase))
        @std_lengths = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_lengths', get_default(:std_lengths))
        @std_widths = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_widths', get_default(:std_widths))
        @std_thicknesses = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_thicknesses', get_default(:std_thicknesses))
        @std_sections = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_sections', get_default(:std_sections))
        @std_sizes = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_sizes', get_default(:std_sizes))
        @grained = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'grained', get_default(:grained))
        @edge_decremented = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'edge_decremented', get_default(:edge_decremented))
      else
        @type = TYPE_UNKNOW
      end
    end

    def write_to_attributes
      if @material
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', @uuid)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'type', @type)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness', DimensionUtils.instance.str_add_units(@thickness))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'length_increase', DimensionUtils.instance.str_add_units(@length_increase))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'width_increase', DimensionUtils.instance.str_add_units(@width_increase))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_increase', DimensionUtils.instance.str_add_units(@thickness_increase))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_lengths', DimensionUtils.instance.d_add_units(@std_lengths))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_widths', DimensionUtils.instance.d_add_units(@std_widths))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_thicknesses', DimensionUtils.instance.d_add_units(@std_thicknesses))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_sections', DimensionUtils.instance.dxd_add_units(@std_sections))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_sizes', DimensionUtils.instance.dxd_add_units(@std_sizes))
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'grained', @grained)
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'edge_decremented', @edge_decremented)
      end
    end

    def get_default(key)
      DEFAULTS[@type][key] unless DEFAULTS[@type].nil?
    end

  end

end