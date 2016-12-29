module Ladb
  module Toolbox
    class MaterialAttributes

      ATTRIBUTE_DICTIONARY = 'ladb_toolbox'

      TYPE_UNKNOW = 0
      TYPE_HARDWOOD = 1
      TYPE_PLYWOOD = 2

      DEFAULTS = {
          TYPE_UNKNOW => {
              :length_increase => '0',
              :width_increase => '0',
              :thickness_increase => '0',
              :std_thicknesses => ''
          },
          TYPE_HARDWOOD => {
              :length_increase => '50mm',
              :width_increase => '5mm',
              :thickness_increase => '5mm',
              :std_thicknesses => '18mm;27mm;35mm;45mm;64mm;80mm;100mm'
          },
          TYPE_PLYWOOD => {
              :length_increase => '10mm',
              :width_increase => '10mm',
              :thickness_increase => '0',
              :std_thicknesses => '5mm;15mm;18mm;22mm'
          },
      }

      attr_accessor :type, :length_increase, :width_increase, :thickness_increase, :std_thicknesses
      attr_reader :material

      def initialize(material)
        @material = material
        @type = TYPE_UNKNOW
        @length_increase = get_default(:length_increase)
        @width_increase = get_default(:width_increase)
        @thickness_increase = get_default(:thickness_increase)
        @std_thicknesses = get_default(:std_thicknesses)
        read_from_attributes
      end

      # -----

      def self.valid_type(type)
        if type
          i_type = type.to_i
          if i_type < TYPE_UNKNOW or i_type > TYPE_PLYWOOD
            TYPE_UNKNOW
          end
          i_type
        else
          TYPE_UNKNOW
        end
      end

      def self.type_order(type)
        case type
          when TYPE_HARDWOOD
            1
          when TYPE_PLYWOOD
            2
          else
            99
        end
      end

      # -----

      def length_increase
        case @type
          when TYPE_HARDWOOD, TYPE_PLYWOOD
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
          when TYPE_HARDWOOD, TYPE_PLYWOOD
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
          when TYPE_HARDWOOD
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
          when TYPE_HARDWOOD, TYPE_PLYWOOD
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
        a
      end

      # -----

      def read_from_attributes
        if @material
          @type = @material.get_attribute(ATTRIBUTE_DICTIONARY, 'type', TYPE_UNKNOW)
          @length_increase = @material.get_attribute(ATTRIBUTE_DICTIONARY, 'length_increase', get_default(:length_increase))
          @width_increase = @material.get_attribute(ATTRIBUTE_DICTIONARY, 'width_increase', get_default(:width_increase))
          @thickness_increase = @material.get_attribute(ATTRIBUTE_DICTIONARY, 'thickness_increase', get_default(:thickness_increase))
          @std_thicknesses = @material.get_attribute(ATTRIBUTE_DICTIONARY, 'std_thicknesses', get_default(:std_thicknesses))
        end
      end

      def write_to_attributes
        if @material
          @material.set_attribute(ATTRIBUTE_DICTIONARY, 'type', @type)
          @material.set_attribute(ATTRIBUTE_DICTIONARY, 'length_increase', @length_increase)
          @material.set_attribute(ATTRIBUTE_DICTIONARY, 'width_increase', @width_increase)
          @material.set_attribute(ATTRIBUTE_DICTIONARY, 'thickness_increase', @thickness_increase)
          @material.set_attribute(ATTRIBUTE_DICTIONARY, 'std_thicknesses', @std_thicknesses)
        end
      end

      def get_default(key)
        DEFAULTS[@type][key]
      end

    end
  end
end