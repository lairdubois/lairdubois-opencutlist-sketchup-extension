module Ladb::OpenCutList

  require 'json'
  require 'securerandom'
  require_relative '../geom/size2d'
  require_relative '../geom/section'
  require_relative '../../utils/unit_utils'
  require_relative '../../utils/dimension_utils'

  class MaterialAttributes

    TYPE_UNKNOWN = 0
    TYPE_SOLID_WOOD = 1
    TYPE_SHEET_GOOD = 2
    TYPE_DIMENSIONAL = 3
    TYPE_EDGE = 4
    TYPE_HARDWARE = 5
    TYPE_VENEER = 6

    DEFAULTS_DICTIONARY = 'materials_material_attributes'.freeze

    attr_accessor :uuid, :type, :thickness, :length_increase, :width_increase, :thickness_increase, :std_lengths, :std_widths, :std_thicknesses, :std_sections, :std_sizes, :grained, :edge_decremented, :volumic_mass, :std_prices
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
        if i_type < TYPE_UNKNOWN || i_type > TYPE_VENEER
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
        when TYPE_HARDWARE
          6
        when TYPE_VENEER
          5
        else
          99
      end
    end

    def self.is_virtual?(value)
      if value.is_a?(MaterialAttributes)
        type = value.type
      elsif value.is_a?(Sketchup::Material)
        type = MaterialAttributes.new(value).type
      elsif value.is_a?(Integer)
        type = value
      else
        return false
      end
      type == TYPE_EDGE || type == TYPE_VENEER
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
      when TYPE_EDGE, TYPE_VENEER
        @thickness
      else
        Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['thickness']
      end
    end

    def l_thickness
      DimensionUtils.instance.d_to_ifloats(thickness).to_l
    end

    def length_increase
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD, TYPE_DIMENSIONAL, TYPE_EDGE, TYPE_VENEER
          @length_increase
        else
          Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['length_increase']
      end
    end

    def l_length_increase
      DimensionUtils.instance.d_to_ifloats(length_increase).to_l
    end

    def width_increase
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD, TYPE_VENEER
          @width_increase
        else
          Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['width_increase']
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
          Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['thickness_increase']
      end
    end

    def l_thickness_increase
      DimensionUtils.instance.d_to_ifloats(thickness_increase).to_l
    end

    def std_lengths
      case @type
      when TYPE_DIMENSIONAL, TYPE_EDGE
        @std_lengths
      else
        Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['std_lengths']
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
        Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['std_widths']
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
          Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['std_thicknesses']
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
          Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['std_sections']
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
        when TYPE_SHEET_GOOD, TYPE_VENEER
          @std_sizes
        else
          Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['std_sizes']
      end
    end

    def l_std_sizes
      a = []
      @std_sizes.split(';').each { |std_size|
        a << Size2d.new(DimensionUtils.instance.dxd_to_ifloats(std_size))
      }
      a
    end

    def volumic_mass
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD, TYPE_DIMENSIONAL, TYPE_EDGE, TYPE_VENEER
          @volumic_mass
        else
          Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['volumic_mass']
      end
    end

    def h_volumic_mass
      unit, val = UnitUtils.split_unit_and_value(@volumic_mass)
      { :unit => unit, :val => val }
    end

    def std_prices
      case @type
        when TYPE_SOLID_WOOD, TYPE_SHEET_GOOD, TYPE_DIMENSIONAL, TYPE_EDGE, TYPE_VENEER
          @std_prices
        else
          Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)['std_prices']
      end
    end

    def h_std_prices

      # Returns an array like [ { :unit => STRING_UNIT, :val => FLOAT }, { :unit => STRING_UNIT, :val => FLOAT , :dim => [ LENGTH or SIZE, ... ]}, ... ]

      # Setup return array with default value first
      std_prices = [ { unit: nil, :val => 0.0 } ]

      if @std_prices.is_a?(Array)
        @std_prices.each do |std_price|

          if std_price['dim'].nil?
            unit, val = UnitUtils.split_unit_and_value(std_price['val'])
            std_prices[0][:unit] = unit
            std_prices[0][:val] = val
          elsif !std_price['dim'].is_a?(String)
            next
          else
            dim = []
            a = std_price['dim'].split(';')
            a.each { |d|
              unless d.nil?
                if d.index('x').nil?
                  dim << d.to_f.to_l
                else
                  dim << Size2d.new(d.split('x').map { |l| l.to_f })
                end
              end
            }
            if dim.length > 0
              unit, val = UnitUtils.split_unit_and_value(std_price['val'])
              std_prices << { :unit => unit, :val => val, :dim => dim }
            end
          end

        end
      end

      std_prices
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

        defaults = Plugin.instance.get_app_defaults(DEFAULTS_DICTIONARY, @type)

        @type = MaterialAttributes.valid_type(Plugin.instance.get_attribute(@material, 'type', TYPE_UNKNOWN))
        @thickness = Plugin.instance.get_attribute(@material, 'thickness', defaults['thickness'])
        @length_increase = Plugin.instance.get_attribute(@material, 'length_increase', defaults['length_increase'])
        @width_increase = Plugin.instance.get_attribute(@material, 'width_increase', defaults['width_increase'])
        @thickness_increase = Plugin.instance.get_attribute(@material, 'thickness_increase', defaults['thickness_increase'])
        @std_lengths = Plugin.instance.get_attribute(@material, 'std_lengths', defaults['std_lengths'])
        @std_widths = Plugin.instance.get_attribute(@material, 'std_widths', defaults['std_widths'])
        @std_thicknesses = Plugin.instance.get_attribute(@material, 'std_thicknesses', defaults['std_thicknesses'])
        @std_sections = Plugin.instance.get_attribute(@material, 'std_sections', defaults['std_sections'])
        @std_sizes = Plugin.instance.get_attribute(@material, 'std_sizes', defaults['std_sizes'])
        @grained = Plugin.instance.get_attribute(@material, 'grained', defaults['grained'])
        @edge_decremented = Plugin.instance.get_attribute(@material, 'edge_decremented', defaults['edge_decremented'])
        @volumic_mass = Plugin.instance.get_attribute(@material, 'volumic_mass', defaults['volumic_mass'])
        @std_prices = Plugin.instance.get_attribute(@material, 'std_prices', defaults['std_prices'])
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
        @material.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'std_prices', @std_prices.to_json)
      end
    end

  end

end
