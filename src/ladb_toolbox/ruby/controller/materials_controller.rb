require_relative 'controller'

class MaterialsController < Controller

  def initialize(plugin)
    super(plugin, 'materials')
  end

  def setup_dialog_actions(dialog)

    # Setup toolbox dialog actions
    dialog.add_action_callback("ladb_materials_list") do |action_context, json_params|

      model = Sketchup.active_model
      materials = model.materials

      data = []
      materials.each { |material|
        data.push(material.name)
      }

      # Callback to JS
      execute_js_callback('onList', data)

    end

  end

end