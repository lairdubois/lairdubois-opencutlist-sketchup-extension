module Ladb::OpenCutList

  class MaterialsObserver < Sketchup::MaterialsObserver

    def onMaterialAdd(materials, material)
      # puts "onMaterialAdd: #{material}"
      Plugin.trigger_event('on_material_add', { :material_name => material.name })
    end

    def onMaterialRemove(materials, material)
      # puts "onMaterialRemove: #{material}"
      Plugin.trigger_event('on_material_remove', nil)
    end

    def onMaterialChange(materials, material)
      # puts "onMaterialChange: #{material}"
      Plugin.trigger_event('on_material_change', { :material_name => material.name })
    end

  end

end