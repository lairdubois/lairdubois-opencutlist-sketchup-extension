module Ladb
  module Toolbox
    class GroupDef

      attr_accessor :material_name, :material_type, :part_count, :raw_thickness, :raw_thickness_available, :max_number
      attr_reader :id, :part_defs

      def initialize(id)
        @id = id
        @material_name = ''
        @material_type = MaterialAttributes::TYPE_UNKNOW
        @raw_thickness = 0
        @max_number = nil
        @part_count = 0
        @part_defs = {}
      end

      def set_part_def(key, part_def)
        @part_defs.store(key, part_def)
      end

      def get_part_def(key)
        if @part_defs.has_key? key
          return @part_defs[key]
        end
        nil
      end

      def include_number?(number)
        @part_defs.each { |key, part_def|
          if part_def.number == number
            return true
          end
        }
        false
      end

    end
  end
end