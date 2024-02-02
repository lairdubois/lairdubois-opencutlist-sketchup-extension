module Ladb::OpenCutList

  require_relative '../../utils/image_utils'

  class MaterialsUpdateWorker

    def initialize(material_data)

      @name = material_data.fetch('name')
      @display_name = material_data.fetch('display_name')
      @color = Sketchup::Color.new(material_data.fetch('color'))
      @texture_rotation = material_data.fetch('texture_rotation')
      @texture_file = material_data.fetch('texture_file')
      @texture_changed = material_data.fetch('texture_changed', false)
      @texture_width = material_data.fetch('texture_width')
      @texture_height = material_data.fetch('texture_height')

      attributes = material_data.fetch('attributes')
      @type = MaterialAttributes.valid_type(attributes.fetch('type'))
      @description = attributes.fetch('description', '')
      @url = attributes.fetch('url', '')
      @thickness = attributes.fetch('thickness')
      @length_increase = attributes.fetch('length_increase')
      @width_increase = attributes.fetch('width_increase')
      @thickness_increase = attributes.fetch('thickness_increase')
      @std_lengths = attributes.fetch('std_lengths')
      @std_widths = attributes.fetch('std_widths')
      @std_thicknesses = attributes.fetch('std_thicknesses')
      @std_sections = attributes.fetch('std_sections')
      @std_sizes = attributes.fetch('std_sizes')
      @grained = attributes.fetch('grained')
      @edge_decremented = attributes.fetch('edge_decremented')
      @raw_estimated = attributes.fetch('raw_estimated')
      @std_volumic_masses = attributes.fetch('std_volumic_masses')
      @std_prices = attributes.fetch('std_prices')

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Start model modification operation
      model.start_operation('OCL Material Update', true, false, true)

      # Fetch material
      materials = model.materials
      material = materials[@name]

      return { :errors => [ 'tab.materials.error.material_not_found' ] } unless material

      trigger_change_event = true

      # Sanitize display_name by removing tabs and line breaks
      @display_name = @display_name.delete("\t\r\n").strip

      # Update properties
      if @display_name != material.name

        material.name = materials.respond_to?(:unique_name) ? materials.unique_name(@display_name) : @display_name  # SU 2018+

        # In this case the event will be triggered by SU itself
        trigger_change_event = false

      end

      if @color.to_i != material.color.to_i

        material.color = @color

      end

      if @texture_changed || @texture_rotation > 0

        # Rotate texture
        ImageUtils.rotate(@texture_file, @texture_rotation) if @texture_rotation > 0 && @texture_file

        # Keep previous material color if colorized material
        if !@texture_changed && material.materialType == 2 # 2 = Sketchup::Material::MATERIAL_COLORIZED_TEXTURED
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

      unless material.texture.nil? || @texture_width.nil? || @texture_height.nil?

        texture_width = DimensionUtils.instance.d_to_ifloats(@texture_width).to_l
        texture_height = DimensionUtils.instance.d_to_ifloats(@texture_height).to_l

        # Set only if positive and not null dimensions
        if texture_width > 0 && texture_height > 0

          material.texture.size = [ texture_width, texture_height ]

          # In this case the event will be triggered by SU itself
          trigger_change_event = false

        end

      end

      # Update attributes
      material_attributes = MaterialAttributes.new(material)
      material_attributes.type = @type
      material_attributes.description = @description
      material_attributes.url = @url
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
      material_attributes.raw_estimated = @raw_estimated
      material_attributes.std_volumic_masses = @std_volumic_masses
      material_attributes.std_prices = @std_prices
      material_attributes.write_to_attributes

      # Trigger change event on materials observer if needed
      if trigger_change_event
        MaterialsObserver.instance.onMaterialChange(materials, material)
      end

      # Commit model modification operation
      model.commit_operation

    end

    # -----

  end

end