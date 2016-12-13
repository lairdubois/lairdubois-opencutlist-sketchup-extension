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

      data = {
          :errors => [],
          :warnings => [],
          :materials => []
      }
      materials.each { |material|

        thumbnail_file = File.join(temp_dir, "#{material.display_name}.png")
        material.write_thumbnail(thumbnail_file, 128)

        material_attributes = MaterialAttributes.new(material)

        data[:materials].push({
                      :id => material.entityID,
                      :name => material.name,
                      :display_name => material.display_name,
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

      # Errors
      if materials.count == 0
        data[:errors].push('Votre modèle ne contient aucune matière.')
      end

      # Sort materials by type ASC, display_name ASC
      data[:materials].sort_by! { |v| [MaterialAttributes.type_order(v[:attributes][:type]), v[:display_name]] }

      # Callback to JS
      execute_js_callback('onList', data)

    end

    dialog.add_action_callback("ladb_materials_update") do |action_context, json_params|

      params = JSON.parse(json_params)

      # Extract parameters
      name = params['name']
      display_name = params['display_name']

      attributes = params['attributes']
      type = MaterialAttributes.valid_type(attributes['type'])
      length_increase = attributes['length_increase']
      width_increase = attributes['width_increase']
      thickness_increase = attributes['thickness_increase']
      std_thicknesses = attributes['std_thicknesses']

      # Fetch material
      model = Sketchup.active_model
      materials = model.materials
      material = materials[name]

      if material

        # Update properties
        material.name = display_name

        # Update attributes
        material_attributes = MaterialAttributes.new(material)
        material_attributes.type = type
        material_attributes.length_increase = length_increase
        material_attributes.width_increase = width_increase
        material_attributes.thickness_increase = thickness_increase
        material_attributes.std_thicknesses = std_thicknesses
        material_attributes.write_to_attributes

      end

    end

  end

end