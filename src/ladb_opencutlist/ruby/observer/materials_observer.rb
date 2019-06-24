module Ladb::OpenCutList

  require 'singleton'

  class MaterialsObserver < Sketchup::MaterialsObserver

    include Singleton

    def onMaterialAdd(materials, material)
      # puts "onMaterialAdd: #{material}"
      Plugin.instance.trigger_event('on_material_add', { :material_name => material.name })
    end

    def onMaterialRemove(materials, material)
      # puts "onMaterialRemove: #{material}"
      Plugin.instance.trigger_event('on_material_remove', nil)
    end

    def onMaterialChange(materials, material)
      puts "onMaterialChange: #{material}"
      Plugin.instance.trigger_event('on_material_change', { :material_name => material.name })
    end

  end

end