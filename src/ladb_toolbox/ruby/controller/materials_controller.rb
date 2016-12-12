require_relative 'controller'
require_relative '../model/material_attributes'

class MaterialsController < Controller

  def initialize(plugin)
    super(plugin, 'materials')
  end

  def setup_dialog_actions(dialog)

    # Setup toolbox dialog actions
    dialog.add_action_callback("ladb_materials_list") do |action_context, json_params|

      model = Sketchup.active_model
      materials = model.materials

      temp_dir = @plugin.temp_dir

      data = []
      materials.each { |material|

        thumbnail_file = File.join(temp_dir, "#{material.display_name}.png")
        material.write_thumbnail(thumbnail_file, 128)

        material_attributes = MaterialAttributes.new(material)

        data.push({
                      :id => material.entityID,
                      :name => material.display_name,
                      :thumbnail_file => thumbnail_file,
                      :color => '#' + material.color.to_i.to_s(16),
                      :attributes => {
                          :type => material_attributes.type,
                          :length_increase => material_attributes.length_increase,
                          :width_increase => material_attributes.width_increase,
                          :thickness_increase => material_attributes.thickness_increase,
                          :std_thicknesses => material_attributes.std_thicknesses
                      }
                  })
      }

      # Callback to JS
      execute_js_callback('onList', data)

    end

    dialog.add_action_callback("ladb_materials_update") do |action_context, json_params|

      params = JSON.parse(json_params)

      # Extract parameters
      material_name = params['material_name']
      length_increase = params['length_increase'].to_l
      width_increase = params['width_increase'].to_l
      thickness_increase = params['thickness_increase'].to_l

      # Fetch material
      model = Sketchup.active_model
      materials = model.materials
      material = materials[material_name]

      if material

        # Update attributes
        material_attributes = MaterialAttributes.new(material)
        material_attributes.length_increase = length_increase
        material_attributes.width_increase = width_increase
        material_attributes.thickness_increase = thickness_increase
        material_attributes.save_to_attributes

      end

    end

  end

end