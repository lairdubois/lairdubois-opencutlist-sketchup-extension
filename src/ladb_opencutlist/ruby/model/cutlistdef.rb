module Ladb::OpenCutList

  class CutlistDef

    attr_accessor :length_unit, :dir, :filename, :page_label, :max_number
    attr_reader :errors, :warnings, :tips, :used_labels, :material_usages, :group_defs

    def initialize(length_unit, dir, filename, page_label)
      @errors = []
      @warnings = []
      @tips = []
      @length_unit = length_unit
      @dir = dir
      @filename = filename
      @page_label = page_label
      @max_number = nil
      @used_labels = []
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

    def add_used_labels(used_labels)
      @used_labels += used_labels + (@used_labels & used_labels)
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

    def is_metric?
      @length_unit == Length::Millimeter || @length_unit == Length::Centimeter ||@length_unit == Length::Meter
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
