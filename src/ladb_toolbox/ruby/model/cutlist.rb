module Ladb
  module Toolbox
    class Cutlist

      attr_accessor :filename, :page_label
      attr_reader :errors, :warnings, :material_usages, :group_defs

      def initialize(filename, page_label)
        @errors = []
        @warnings = []
        @filename = filename
        @page_label = page_label
        @material_usages = {}
        @group_defs = {}
      end

      def add_error(error)
        @errors.push(error)
      end

      def add_warning(warning)
        @warnings.push(warning)
      end

      def set_material_usage(key, material_usage)
        @material_usages[key] = material_usage
      end

      def get_material_usage(key)
        if @material_usages.has_key? key
          return @material_usages[key]
        end
        nil
      end

      def set_group_def(key, group_def)
        @group_defs[key] = group_def
      end

      def get_group_def(key)
        if @group_defs.has_key? key
          return @group_defs[key]
        end
        nil
      end

    end
  end
end
