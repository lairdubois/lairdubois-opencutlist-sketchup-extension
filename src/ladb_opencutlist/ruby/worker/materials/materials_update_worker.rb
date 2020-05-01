module Ladb::OpenCutList

  require_relative '../../utils/image_utils'

  class MaterialsUpdateWorker

    def initialize(material_data)
      @name = material_data['name']
      @display_name = material_data['display_name']
      @color = Sketchup::Color.new(material_data['color'])
      attributes = material_data['attributes']
      @texture_rotation = material_data['texture_rotation']
      @texture_file = material_data['texture_file']
      @texture_width = material_data['texture_width']
      @texture_height = material_data['texture_height']
      @texture_colorizable = material_data['texture_colorizable']
      @texture_colorized = material_data['texture_colorized']
      @type = MaterialAttributes.valid_type(attributes['type'])
      @thickness = attributes['thickness']
      @length_increase = attributes['length_increase']
      @width_increase = attributes['width_increase']
      @thickness_increase = attributes['thickness_increase']
      @std_lengths = attributes['std_lengths']
      @std_widths = attributes['std_widths']
      @std_thicknesses = attributes['std_thicknesses']
      @std_sections = attributes['std_sections']
      @std_sizes = attributes['std_sizes']
      @grained = attributes['grained']
      @edge_decremented = attributes['edge_decremented']
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Fetch material
      materials = model.materials
      material = materials[@name]

      return { :errors => [ 'tab.materials.error.material_not_found' ] } unless material

      trigger_change_event = true

      # Update properties
      if @display_name != material.name

        material.name = @display_name

        # In this case the event will be triggered by SU itself
        trigger_change_event = false

      end

      if @color.to_i != material.color.to_i

        material.color = @color

      end

      # Update texture
      unless @texture_file.nil?

        if @texture_rotation > 0 or (@texture_colorized and @texture_colorizable)

          # Rotate texture
          ImageUtils.rotate(@texture_file, @texture_rotation) if @texture_rotation > 0

          # Keep previous material color if colorized material
          if !@texture_colorized and material.materialType == 2 # 2 = Sketchup::Material::MATERIAL_COLORIZED_TEXTURED
            color = material.color
          else
            color = nil
          end

          # Set new texture to the material and re-apply previous color
          material.texture = @texture_file

          # Re-apply color if colorized material
          if color
            material.color = color
          end

          # In this case the event will be triggered by SU itself
          trigger_change_event = false

        end

        unless @texture_width.nil? or @texture_height.nil?

          material.texture.size = [ DimensionUtils.instance.dd_to_ifloats(@texture_width).to_l, DimensionUtils.instance.dd_to_ifloats(@texture_height).to_l ]

          # In this case the event will be triggered by SU itself
          trigger_change_event = false

        end

      end

        # Update attributes
        material_attributes = MaterialAttributes.new(material)
        material_attributes.type = @type
        material_attributes.thickness = @thickness
        material_attributes.length_increase = @length_increase
        material_attributes.width_increase = @width_increase
        material_attributes.thickness_increase = @thickness_increase
        material_attributes.std_lengths = @std_lengths
        material_attributes.std_widths = @std_widths
        material_attributes.std_thicknesses = @std_thicknesses
        material_attributes.std_sections = @std_sections
        material_attributes.std_sizes = @std_sizes
        material_attributes.grained = @grained
        material_attributes.edge_decremented = @edge_decremented
        material_attributes.write_to_attributes

      # Trigger change event on materials observer if needed
      if trigger_change_event
        MaterialsObserver.instance.onMaterialChange(materials, material)
      end

    end

    # -----

  end

end