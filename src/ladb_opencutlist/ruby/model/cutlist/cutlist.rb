module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class Cutlist

    include HashableHelper

    attr_accessor :selection_only, :length_unit, :currency_symbol, :mass_unit_strippedname, :dir, :filename, :model_name, :page_label, :max_number, :instance_count, :ignored_instance_count, :solid_wood_material_count, :sheet_good_material_count, :dimensional_material_count, :edge_material_count, :hardware_material_count
    attr_reader :errors, :warnings, :tips, :used_tags, :material_usages, :groups

    def initialize(selection_only, length_unit, mass_unit_strippedname, currency_symbol, dir, filename, model_name, page_label, instance_count)
      @_obsolete = false
      @_observers = []

      @errors = []
      @warnings = []
      @tips = []
      @selection_only = selection_only
      @length_unit = length_unit
      @mass_unit_strippedname = mass_unit_strippedname
      @currency_symbol = currency_symbol
      @dir = dir
      @filename = filename
      @model_name = model_name
      @page_label = page_label
      @instance_count = instance_count
      @ignored_instance_count = 0
      @max_number = nil
      @used_tags = []
      @material_usages = []
      @groups = []

      @solid_wood_material_count = 0
      @sheet_good_material_count = 0
      @dimensional_material_count = 0
      @edge_material_count = 0
      @hardware_material_count = 0

    end

    # ---

    def invalidate
      @_obsolete = true
      _fire_invalidate_event
    end

    def obsolete?
      @_obsolete
    end

    # Errors

    def add_error(error)
      @errors.push(error)
    end

    # Warnings

    def add_warning(warning)
      @warnings.push(warning)
    end

    # Tips

    def add_tip(tip)
      @tips.push(tip)
    end

    # UsedLabels

    def add_used_tags(used_tags)
      @used_tags += used_tags - (@used_tags & used_tags)
    end

    # MaterialUsages

    def add_material_usages(material_usages)
      @material_usages += material_usages - (@material_usages & material_usages)
    end

    # Groups

    def add_group(group)
      @groups.push(group)
    end

    def get_group(id)
      @groups.each do |group|
        return group if group.id == id
      end
      nil
    end

    # Parts

    def get_part(id)
      get_real_parts([ id ]).first
    end

    def get_real_parts(ids = nil)
      parts = []
      @groups.each do |group|
        parts = parts + group.get_real_parts(ids)
      end
      parts
    end

    # ---

    def add_observer(observer)
      if observer.is_a? CutlistObserver
        @_observers.push(observer)
      else
        raise('Invalid CutlistObserver')
      end
    end

    def remove_observer(observer)
      @_observers.delete(observer)
    end

    private

    def _fire_invalidate_event
      @_observers.each do |observer|
        observer.onInvalidateCutlist(self)
      end
    end

  end

  class CutlistObserver

    def onInvalidateCutlist(cutlist)
    end

  end

end
