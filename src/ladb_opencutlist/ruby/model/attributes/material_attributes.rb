module Ladb::OpenCutList

  require 'securerandom'
  require_relative '../geom/size2d'
  require_relative '../geom/section'
  require_relative '../../utils/dimension_utils'

  class MaterialAttributes

    TYPE_UNKNOWN = 0
    TYPE_SOLID_WOOD = 1
    TYPE_SHEET_GOOD = 2
    TYPE_DIMENSIONAL = 3
    TYPE_EDGE = 4
    TYPE_ACCESSORY = 5

    NATIVES = {
        TYPE_UNKNOWN => {
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
            :volumic_mass => '',
        },
        TYPE_SOLID_WOOD => {
            :thickness => '0',
            :length_increase => { :metric => '50mm', :imperial => '1"' },
            :width_increase => { :metric => '5mm', :imperial => '1/8"' },
            :thickness_increase => { :metric => '5mm', :imperial => '1/8"' },
            :std_lengths => '',
            :std_widths => '',
            :std_thicknesses => { :metric => '18mm;27mm;35mm;45mm;64mm;80mm;100mm', :imperial => '1/2";3/4";1";1 1/4";1 1/2";1 3/4";2";2 1/2";3";3 1/2";4";4 1/2";5";5 1/2";6"' },
            :std_sections => '',
            :std_sizes => '',
            :grained => true,
            :edge_decremented => false,
            :volumic_mass => '',
        },
        TYPE_SHEET_GOOD => {
            :thickness => '0',
            :length_increase => '0',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_lengths => '',
            :std_widths => '',
            :std_thicknesses => { :metric => '5mm;8mm;10mm;12mm;15mm;16mm;18mm;19mm;22mm', :imperial => '1/4";1/2";5/8";3/4";1";1 1/8"' },
            :std_sections => '',
            :std_sizes => '',
            :grained => false,
            :edge_decremented => false,
            :volumic_mass => '',
        },
        TYPE_DIMENSIONAL => {
            :thickness => '0',
            :length_increase => { :metric => '50mm', :imperial => '1"' },
            :width_increase => '0',
            :thickness_increase => '0',
            :std_lengths => { :metric => '2400mm;6000mm;13000mm', :imperial => '6\';8\';10\';12\';14\';16\';18\';20\';22\';24\'' },
            :std_widths => '',
            :std_thicknesses => '',
            :std_sections => { :metric => '30mm x 40mm;40mm x 50mm', :imperial => '3/4" x 1 1/2";1 1/2" x 5 1/2";1 1/2" x 7 1/4"; 1 1/2" x 9 1/4"' },
            :std_sizes => '',
            :grained => false,
            :edge_decremented => false,
            :volumic_mass => '',
        },
        TYPE_EDGE => {
            :thickness => { :metric => '2mm', :imperial => '0.018"' },
            :length_increase => '0',
            :width_increase => '0',
            :thickness_increase => '0',
            :std_lengths => '',
            :std_widths => { :metric => '19mm;23mm;28mm;33mm;35mm;43mm', :imperial => '5/8";7/8";3/4";15/16";1 5/16";1 5/8";1 3/4"' },
            :std_thicknesses => '',
            :std_sections => '',
            :std_sizes => '',
            :grained => false,
            :edge_decremented => true,
            :volumic_mass => '',
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
            :volumic_mass => '',
        },
    }

    attr_accessor :uuid, :type, :thickness, :length_increase, :width_increase, :thickness_increase, :std_lengths, :std_widths, :std_thicknesses, :std_sections, :std_sizes, :grained, :edge_decremented, :volumic_mass
    attr_reader :material

    @@cached_uuids = {}
    @@used_uuids = []

    def initialize(material, force_unique_uuid = false)
      @material = material
      read_from_attributes(force_unique_uuid)
    end

    # -----

    def self.store_cached_uuid(material, uuid)
      @@cached_uuids.store("#{material.model.guid}|#{material.entityID}", uuid)
    end

    def self.fetch_cached_uuid(material)
      @@cached_uuids.fetch("#{material.model.guid}|#{material.entityID}", nil)
    end

    def self.delete_cached_uuid(material)
      @@cached_uuids.delete("#{material.model.guid}|#{material.entityID}")
    end

    def self.reset_used_uuids
      @@used_uuids.clear
    end

    def self.persist_cached_uuid_of(material)
      cached_uuid = fetch_cached_uuid(material)
      if cached_uuid
        material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', cached_uuid)
        MaterialAttributes.delete_cached_uuid(material)
      end
    end

    def self.valid_type(type)
      if type
        i_type = type.to_i
        if i_type < TYPE_UNKNOWN or i_type > TYPE_ACCESSORY
          return TYPE_UNKNOWN
        end
        i_type
      else
        TYPE_UNKNOWN
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
            a_value = [ type_order(material_a[:attributes][:type]) ]
            b_value = [ type_order(material_b[:attributes][:type]) ]
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

    def self.get_native_value(type, key)
      unless NATIVES[type].nil? || NATIVES[type][key].nil? || !(NATIVES[type][key].is_a?(Hash))
        if DimensionUtils.instance.model_unit_is_metric
          return NATIVES[type][key][:metric] unless NATIVES[type][key][:metric].nil?
        else
          return NATIVES[type][key][:imperial] unless NATIVES[type][key][:imperial].nil?
        end
      end
      NATIVES[type][key] unless NATIVES[type][key].is_a?(Hash)
    end

    # -----

    def uuid
      if @uuid.nil?

        # Generate a new UUID
        @uuid = SecureRandom.uuid

        # Cache new UUID
        MaterialAttributes.store_cached_uuid(@material, @uuid)

      end
      @uuid
    end

    def thickness
      case @type
      when TYPE_EDGE
        @thickness
      else
        MaterialAttributes.get_native_value(@type,:thickness)
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
          MaterialAttributes.get_native_value(@type,:length_increase)
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
          MaterialAttributes.get_native_value(@type,:width_increase)
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
          MaterialAttributes.get_native_value(@type,:thickness_increase)
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
        MaterialAttributes.get_native_value(@type,:std_lengths)
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
      a.sort_by! { |v| v.to_f }   # Force sort on true float value
      a
    end

    def std_widths
      case @type
      when TYPE_EDGE
        @std_widths
      else
        MaterialAttributes.get_native_value(@type,:std_widths)
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
      a.sort_by! { |v| v.to_f }   # Force sort on true float value
      a
    end

    def std_thicknesses
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD
          @std_thicknesses
        else
          MaterialAttributes.get_native_value(@type,:std_thicknesses)
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
      a.sort_by! { |v| v.to_f }   # Force sort on true float value
      a
    end

    def std_sections
      case @type
        when TYPE_DIMENSIONAL
          @std_sections
        else
          MaterialAttributes.get_native_value(@type,:std_sections)
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
          MaterialAttributes.get_native_value(@type,:@std_sizes)
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

        # Try to retrieve uuid from cached UUIDs
        @uuid = MaterialAttributes.fetch_cached_uuid(@material)

        if @uuid.nil?
          # Try to retrieve uuid from material's attributes
          @uuid = @material.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', nil)
        end

        unless @uuid.nil?
          if force_unique_uuid && @@used_uuids.include?(@uuid)
            @uuid = nil
          else
            @@used_uuids.push(@uuid)
          end
        end

        @type = MaterialAttributes.valid_type(Plugin.instance.get_attribute(@material, 'type', TYPE_UNKNOWN))
        @thickness = Plugin.instance.get_attribute(@material, 'thickness', MaterialAttributes.get_native_value(@type, :thickness))
        @length_increase = Plugin.instance.get_attribute(@material, 'length_increase', MaterialAttributes.get_native_value(@type, :length_increase))
        @width_increase = Plugin.instance.get_attribute(@material, 'width_increase', MaterialAttributes.get_native_value(@type, :width_increase))
        @thickness_increase = Plugin.instance.get_attribute(@material, 'thickness_increase', MaterialAttributes.get_native_value(@type, :thickness_increase))
        @std_lengths = Plugin.instance.get_attribute(@material, 'std_lengths', MaterialAttributes.get_native_value(@type, :std_lengths))
        @std_widths = Plugin.instance.get_attribute(@material, 'std_widths', MaterialAttributes.get_native_value(@type, :std_widths))
        @std_thicknesses = Plugin.instance.get_attribute(@material, 'std_thicknesses', MaterialAttributes.get_native_value(@type, :std_thicknesses))
        @std_sections = Plugin.instance.get_attribute(@material, 'std_sections', MaterialAttributes.get_native_value(@type, :std_sections))
        @std_sizes = Plugin.instance.get_attribute(@material, 'std_sizes', MaterialAttributes.get_native_value(@type, :std_sizes))
        @grained = Plugin.instance.get_attribute(@material, 'grained', MaterialAttributes.get_native_value(@type, :grained))
        @edge_decremented = Plugin.instance.get_attribute(@material, 'edge_decremented', MaterialAttributes.get_native_value(@type, :edge_decremented))
      else
        @type = TYPE_UNKNOWN
      end
    end

    def write_to_attributes
      if @material

        unless @uuid.nil?
          @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', @uuid)
          MaterialAttributes.delete_cached_uuid(@material)
        end

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
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'volumic_mass', @volumic_mass)
      end
    end

  end

end
