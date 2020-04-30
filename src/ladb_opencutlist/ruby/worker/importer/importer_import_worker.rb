module Ladb::OpenCutList

  class ImporterImportWorker

    MATERIALS_PALETTE = %w(#4F78A7 #EF8E2C #DE545A #79B8B2 #5CA34D #ECCA48 #AE78A2 #FC9CA8 #9B755F #BAB0AC)

    def initialize(settings, parts)
      @remove_all = settings['remove_all']
      @keep_definitions_settings = settings['keep_definitions_settings']
      @keep_materials_settings = settings['keep_materials_settings']

      @parts = parts

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.importer.error.no_model' ] } unless model

      response = {
          :errors => [],
      }

      definitions = model.definitions
      materials = model.materials
      active_entities = model.active_entities

      # Start an operation
      model.start_operation('Importing Parts', true)

      # Remove all instances, definitions and materials if needed
      if @remove_all
        active_entities.clear!
        unless @keep_definitions_settings
          definitions.purge_unused
        end
        unless @keep_materials_settings
          materials.purge_unused
        end
      end

      offset_y = 0
      imported_part_count = 0
      imported_definition_names = {}
      material_palette_index = 0
      @parts.each do |part|

        next unless part[:errors].empty?

        # Retrieve or Create the definition
        definition = nil
        if @remove_all && @keep_definitions_settings

          # Check if definition name already used in import
          unless imported_definition_names.has_key?(part[:name])

            # Try to retrieve definition from list
            definition = definitions[part[:name]]

          end

          # Definition exists ? -> clear it
          if definition
            definition.entities.clear!
          end

        end

        definition = definitions.add(part[:name]) unless definition   # Add new definition if it doesn't exist
        entities = definition.entities

        # Flag definition name as imported (to avoid reuse)
        imported_definition_names[definition.name] = true

        # Create the base face
        face = entities.add_face([
                                     Geom::Point3d.new(0,             0,            0),
                                     Geom::Point3d.new(part[:length], 0,            0),
                                     Geom::Point3d.new(part[:length], part[:width], 0),
                                     Geom::Point3d.new(0,             part[:width], 0)
                                 ])

        # Extrude the part
        face.pushpull(-part[:thickness])

        # Retrieve material (or create it)
        material = nil
        unless part[:material].nil?
          material = materials[part[:material]]
          unless material
            material = materials.add(part[:material])
            material.color = MATERIALS_PALETTE[material_palette_index]
            material_palette_index = (material_palette_index + 1) % MATERIALS_PALETTE.length
          end
        end

        # Create definition instance(s)
        count = part[:count].nil? ? 1 : part[:count]
        for i in 0..count-1
          instance = active_entities.add_instance(definition, Geom::Transformation.new(Geom::Point3d.new(0, offset_y, i * part[:thickness])))
          instance.material = material if material
          imported_part_count += 1
        end

        # Set part attributes
        definition_attributes = DefinitionAttributes.new(definition)
        definition_attributes.orientation_locked_on_axis = true                 # Force part to be locked on its axis
        definition_attributes.labels = part[:labels] unless part[:labels].nil?  # Add labels if defined
        definition_attributes.write_to_attributes

        offset_y += part[:width]

      end

      # Purge extra definitions and materials if needed
      if @remove_all
        if @keep_definitions_settings
          definitions.purge_unused
        end
        if @keep_materials_settings
          materials.purge_unused
        end
      end

      # Commit operation
      if model.commit_operation

        # Cleanup data
        @parts = nil

        # Operation success -> send imported part count
        response[:imported_part_count] = imported_part_count

      else

        # Opetation failed
        response[:errors] << 'tab.importer.failed_to_import'

      end

      response
    end

    # -----

  end

end