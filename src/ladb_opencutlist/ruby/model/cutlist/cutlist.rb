module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/hashable_helper'

  class Cutlist < DataContainer

    include HashableHelper

    attr_accessor :dir, :filename, :model_name, :model_description, :model_active_path, :page_name, :page_description, :max_number, :is_entity_selection, :length_unit, :currency_symbol, :mass_unit_strippedname, :instance_count, :ignored_instance_count, :solid_wood_material_count, :sheet_good_material_count, :dimensional_material_count, :edge_material_count, :hardware_material_count, :veneer_material_count
    attr_reader :errors, :warnings, :tips, :used_tags, :material_usages, :groups

    def initialize(dir, filename, model_name, model_description, model_active_path, page_name, page_description, is_entity_selection, length_unit, mass_unit_strippedname, currency_symbol, instance_count)
      @_obsolete = false
      @_observers = []

      @errors = []
      @warnings = []
      @tips = []
      @dir = dir
      @filename = filename
      @model_name = model_name
      @model_description = model_description
      @model_active_path = model_active_path
      @page_name = page_name
      @page_description = page_description
      @is_entity_selection = is_entity_selection
      @length_unit = length_unit
      @mass_unit_strippedname = mass_unit_strippedname
      @currency_symbol = currency_symbol
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
      @veneer_material_count = 0

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
      @groups.find { |group| group.id == id }
    end

    # Parts

    def get_part(id, real: true)
      get_parts([ id ], nil, real: real).first
    end

    def get_parts(ids = nil, material_types_filter = nil, real: true)
      parts = []
      @groups.each do |group|
        next if material_types_filter && !material_types_filter.include?(group.def.material_attributes.type)
        parts = parts + group.get_parts(ids, real: real)
      end
      parts
    end

    # ---

    def add_observer(observer)
      throw 'Invalid CutlistObserver' unless observer.is_a?(CutlistObserverHelper)
      @_observers.push(observer)
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

  module CutlistObserverHelper

    def onInvalidateCutlist(cutlist)
    end

  end

end
