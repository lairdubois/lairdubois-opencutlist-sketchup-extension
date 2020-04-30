module Ladb::OpenCutList

  require 'singleton'

  class MaterialsObserver < Sketchup::MaterialsObserver

    include Singleton

    ON_MATERIAL_ADD = 'on_material_add'.freeze
    ON_MATERIAL_REMOVE = 'on_material_remove'.freeze
    ON_MATERIAL_CHANGE = 'on_material_change'.freeze
    ON_MATERIAL_SET_CURRENT = 'on_material_set_current'.freeze

    def onMaterialAdd(materials, material)
      # puts "onMaterialAdd: #{material}"
      Plugin.instance.trigger_event(ON_MATERIAL_ADD, { :material_name => material.name })
    end

    def onMaterialRemove(materials, material)
      # puts "onMaterialRemove: #{material}"
      Plugin.instance.trigger_event(ON_MATERIAL_REMOVE, nil)
    end

    def onMaterialChange(materials, material)
      # puts "onMaterialChange: #{material}"
      Plugin.instance.trigger_event(ON_MATERIAL_CHANGE, { :material_name => material.name })
    end

    def onMaterialSetCurrent(materials, material)
      # puts "onMaterialSetCurrent: #{material}"
      Plugin.instance.trigger_event(ON_MATERIAL_SET_CURRENT, { :material_name => material.name })
    end

  end

end