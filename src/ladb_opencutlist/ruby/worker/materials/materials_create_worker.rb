module Ladb::OpenCutList

  require_relative '../../utils/color_utils'

  class MaterialsCreateWorker

    def initialize(

                   name: ,
                   color: ,
                   attributes: {}

    )

      @name = name
      @color = ColorUtils.color_create(color)

      @type = MaterialAttributes.valid_type(attributes.fetch('type', MaterialAttributes::TYPE_UNKNOWN))
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
      @multiplier_coefficient = attributes.fetch('multiplier_coefficient')
      @std_volumic_masses = attributes.fetch('std_volumic_masses')
      @std_prices = attributes.fetch('std_prices')

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Start model modification operation
      model.start_operation('OCL Material Create', true, false, true)

      materials = model.materials
      material = materials.add(@name)
      material.color = @color

      # Set attributes
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
      material_attributes.multiplier_coefficient = @multiplier_coefficient
      material_attributes.std_volumic_masses = @std_volumic_masses
      material_attributes.std_prices = @std_prices
      material_attributes.write_to_attributes

      # Commit model modification operation
      model.commit_operation

      {
          :id => material.entityID,
      }
    end

    # -----

  end

end