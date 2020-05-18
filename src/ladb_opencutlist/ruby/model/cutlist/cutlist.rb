module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class Cutlist

    include HashableHelper

    attr_accessor :selection_only, :length_unit, :dir, :filename, :page_label, :max_number, :instance_count, :ignored_instance_count
    attr_reader :errors, :warnings, :tips, :used_labels, :material_usages, :groups

    def initialize(selection_only, length_unit, dir, filename, page_label, instance_count)
      @_obsolete = false
      @_observers = []

      @errors = []
      @warnings = []
      @tips = []
      @selection_only = selection_only
      @length_unit = length_unit
      @dir = dir
      @filename = filename
      @page_label = page_label
      @instance_count = instance_count
      @ignored_instance_count = 0
      @max_number = nil
      @used_labels = []
      @material_usages = []
      @groups = []
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

    def add_used_labels(used_labels)
      @used_labels += used_labels - (@used_labels & used_labels)
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
