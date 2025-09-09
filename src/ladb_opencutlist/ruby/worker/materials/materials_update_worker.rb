module Ladb::OpenCutList

  require_relative '../../utils/color_utils'

  class MaterialsUpdateWorker

    def initialize(

                   name: ,
                   display_name: ,
                   color: ,
                   description: '',
                   url: '',
                   type: MaterialAttributes::TYPE_UNKNOWN,

                   thickness: nil,
                   length_increase: nil,
                   width_increase: nil,
                   thickness_increase: nil,
                   std_sections: nil,
                   std_lengths: nil,
                   std_widths: nil,
                   std_thicknesses: nil,
                   std_sizes: nil,
                   grained: nil,
                   edge_decremented: nil,
                   raw_estimated: nil,
                   multiplier_coefficient: nil,
                   std_volumic_masses: nil,
                   std_prices: nil,
                   std_cut_prices: nil,

                   texture_file: nil,
                   texture_changed: false,
                   texture_rotation: nil,
                   texture_width: nil,
                   texture_height: nil

    )

      @name = name
      @display_name = display_name
      @color = ColorUtils.color_create(color)
      @description = description
      @url = url
      @type = MaterialAttributes.valid_type(type)

      @texture_file = texture_file
      @texture_changed = texture_changed
      @texture_rotation = texture_rotation.to_i
      @texture_width = texture_width
      @texture_height = texture_height

      @thickness = thickness
      @length_increase = length_increase
      @width_increase = width_increase
      @thickness_increase = thickness_increase
      @std_sections = std_sections
      @std_lengths = std_lengths
      @std_widths = std_widths
      @std_thicknesses = std_thicknesses
      @std_sizes = std_sizes
      @grained = grained
      @edge_decremented = edge_decremented
      @raw_estimated = raw_estimated
      @multiplier_coefficient = multiplier_coefficient
      @std_volumic_masses = std_volumic_masses
      @std_prices = std_prices
      @std_cut_prices = std_cut_prices

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Start a model modification operation
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

      if @color.nil?
        case material.materialType
        when Sketchup::Material::MATERIAL_COLORIZED_TEXTURED
          material.color = nil
          # SketchUp 2025 workaround (https://forums.sketchup.com/t/how-to-reset-colorized-textured-material-color-on-su-2025/331827/2)
          material.color = material.color
          material.color = nil
        when Sketchup::Material::MATERIAL_SOLID
          @color = Sketchup::Color.new('#ffffff')
        end
      end

      if !@color.nil? && @color.to_i != material.color.to_i

        material.color = @color

      end

      if @texture_changed || @texture_rotation > 0

        # Rotate texture
        if @texture_rotation > 0 && @texture_file

          require_relative '../../lib/fiddle/imagy/imagy'

          if Fiddle::Imagy.load(@texture_file)
            Fiddle::Imagy.rotate!(@texture_rotation)
            Fiddle::Imagy.write(@texture_file)
            Fiddle::Imagy.clear!
          end

        end

        # Keep previous material color if colorized material
        if !@texture_changed && material.materialType == Sketchup::Material::MATERIAL_COLORIZED_TEXTURED
          color = material.color
        else
          color = nil
        end

        # Set a new texture to the material and re-apply the previous color
        material.texture = @texture_file

        # Re-apply color if colorized material
        material.color = color if color

        # In this case SU itself will trigger the event
        trigger_change_event = false

      end

      unless material.texture.nil? || @texture_width.nil? || @texture_height.nil?

        texture_width = DimensionUtils.d_to_ifloats(@texture_width).to_l
        texture_height = DimensionUtils.d_to_ifloats(@texture_height).to_l

        # Set only if positive and not null dimensions
        if texture_width > 0 && texture_height > 0

          material.texture.size = [ texture_width, texture_height ]

          # In this case SU itself will trigger the event
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
      material_attributes.std_sections = @std_sections
      material_attributes.std_lengths = @std_lengths
      material_attributes.std_widths = @std_widths
      material_attributes.std_thicknesses = @std_thicknesses
      material_attributes.std_sizes = @std_sizes
      material_attributes.grained = @grained
      material_attributes.edge_decremented = @edge_decremented
      material_attributes.raw_estimated = @raw_estimated
      material_attributes.multiplier_coefficient = @multiplier_coefficient
      material_attributes.std_volumic_masses = @std_volumic_masses
      material_attributes.std_prices = @std_prices
      material_attributes.std_cut_prices = @std_cut_prices
      material_attributes.write_to_attributes

      # Trigger change event on the materials observer if needed
      PLUGIN.app_observer.materials_observer.onMaterialChange(materials, material) if trigger_change_event

      # Commit model modification operation
      model.commit_operation

    end

    # -----

  end

end