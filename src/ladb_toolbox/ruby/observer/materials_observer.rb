module Ladb
  module Toolbox
    class MaterialsObserver < Sketchup::MaterialsObserver

      @plugin

      def initialize(plugin)
        @plugin = plugin
      end

      def onMaterialAdd(materials, material)
        # puts "onMaterialAdd: #{material}"
        @plugin.trigger_event('on_material_add', { :material_name => material.name })
      end

      def onMaterialRemove(materials, material)
        # puts "onMaterialRemove: #{material}"
        @plugin.trigger_event('on_material_remove', nil)
      end

      def onMaterialChange(materials, material)
        # puts "onMaterialChange: #{material}"
        @plugin.trigger_event('on_material_change', { :material_name => material.name })
      end

    end
  end
end