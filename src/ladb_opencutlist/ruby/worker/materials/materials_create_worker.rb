module Ladb::OpenCutList

  class MaterialsCreateWorker

    def initialize(material_data)
      @name = material_data['name']
      @color = Sketchup::Color.new(material_data['color'])
      attributes = material_data['attributes']
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

      materials = model.materials
      material = materials.add(@name)
      material.color = @color

      # Set attributes
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

      {
          :id => material.entityID,
      }
    end

    # -----

  end

end