module Ladb
  module Toolbox
    class CutlistDef

      attr_accessor :is_metric, :dir, :filename, :page_label, :max_number
      attr_reader :errors, :warnings, :tips, :material_usages, :group_defs

      def initialize(is_metric, dir, filename, page_label)
        @errors = []
        @warnings = []
        @tips = []
        @is_metric = is_metric
        @dir = dir
        @filename = filename
        @page_label = page_label
        @max_number = nil
        @material_usages = {}
        @group_defs = {}
      end

      def add_error(error)
        @errors.push(error)
      end

      def add_warning(warning)
        @warnings.push(warning)
      end

      def add_tip(tip)
        @tips.push(tip)
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

      def include_number?(number)
        @group_defs.each { |key, group_def|
          if group_def.include_number? number
            return true
          end
        }
        false
      end

    end
  end
end
