module Ladb
  module Toolbox
    class MaterialsObserver < Sketchup::MaterialsObserver

      @plugin

      def initialize(plugin)
        @plugin = plugin
      end

      def onMaterialAdd(materials, material)
        puts "onMaterialAdd: #{material}"
      end

      def onMaterialRemove(materials, material)
        puts "onMaterialRemove: #{material}"
      end

      def onMaterialChange(materials, material)
        puts "onMaterialChange: #{material}"
      end

    end
  end
end