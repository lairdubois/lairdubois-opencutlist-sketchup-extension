module Ladb::OpenCutList

  require_relative '../../tool/smart_paint_tool'

  class MaterialsSmartPaintWorker

    def initialize(

                   tab_name_to_show_on_quit: nil,

                   name:

    )

      @tab_name_to_show_on_quit = tab_name_to_show_on_quit

      @name = name

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Fetch material
      materials = model.materials
      material = materials[@name]

      return { :errors => [ 'tab.materials.error.material_not_found' ] } unless material

      # Select Smart Paint Tool
      model.select_tool(SmartPaintTool.new(
        tab_name_to_show_on_quit: @tab_name_to_show_on_quit,
        material: material
      ))

      # Focus SketchUp
      Sketchup.focus if Sketchup.respond_to?(:focus)

      { :success => true }
    end

    # -----

  end

end