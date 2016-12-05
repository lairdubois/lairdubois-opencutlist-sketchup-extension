require_relative 'controller'

class MaterialsController < Controller

  def initialize(plugin)
    super(plugin)
  end

  def setup_dialog_actions(dialog)

    # Setup toolbox dialog actions
    dialog.add_action_callback("ladb_materials_list") do |action_context, json_params|

      model = Sketchup.active_model
      materials = model.materials

      output = []
      materials.each { |material|
        output.push(material.name);
      }

      json_data = output.to_json

      # Callback to JS
      dialog.execute_script("$('#ladb_tab_materials').ladbTabMaterials('onList', '#{json_data}')")

    end

  end

end