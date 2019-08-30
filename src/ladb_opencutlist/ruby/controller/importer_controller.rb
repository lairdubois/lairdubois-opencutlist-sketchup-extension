module Ladb::OpenCutList

  require_relative '../lib/rchardet'
  require_relative '../model/definition_attributes'

  class ImporterController < Controller

    LOAD_OPTION_COL_SEP_TAB = 0
    LOAD_OPTION_COL_SEP_COMMA = 1
    LOAD_OPTION_COL_SEP_SEMICOLON = 2

    LOAD_OPTION_ENCODING_UTF8 = 0
    LOAD_OPTION_ENCODING_UTF16LE = 1
    LOAD_OPTION_ENCODING_UTF16BE = 2

    DATA_TYPE_STRING = 0
    DATA_TYPE_INTEGER = 1
    DATA_TYPE_LENGTH = 2
    DATA_TYPE_STRING_ARRAY = 3

    COLUMN_INFOS = {
        :name => {
            :align => 'left',
            :data_type => DATA_TYPE_STRING
        },
        :count => {
            :align => 'center',
            :data_type => DATA_TYPE_INTEGER
        },
        :length => {
            :align => 'right',
            :data_type => DATA_TYPE_LENGTH
        },
        :width => {
            :align => 'right',
            :data_type => DATA_TYPE_LENGTH
        },
        :thickness => {
            :align => 'right',
            :data_type => DATA_TYPE_LENGTH
        },
        :material => {
            :align => 'left',
            :data_type => DATA_TYPE_STRING
        },
        :labels => {
            :align => 'left',
            :data_type => DATA_TYPE_STRING_ARRAY
        },
    }

    MATERIALS_PALETTE = %w(#4F78A7 #EF8E2C #DE545A #79B8B2 #5CA34D #ECCA48 #AE78A2 #FC9CA8 #9B755F #BAB0AC)

    def initialize()
      super('importer')
    end

    def setup_commands()

      # Setup opencutlist dialog actions
      Plugin.instance.register_command("importer_open") do
        open_command
      end
      Plugin.instance.register_command("importer_load") do |settings|
        load_command(settings)
      end
      Plugin.instance.register_command("importer_import") do |settings|
        import_command(settings)
      end

    end

    private

    # -- Commands --

    def open_command

      model = Sketchup.active_model
      length_unit = model ? model.options["UnitsOptions"]["LengthUnit"] : nil

      response = {
          :errors => [],
          :length_unit => length_unit,
      }

      # Check model
      unless model
        response[:errors] << 'tab.importer.error.no_model'
        return response
      end

      # Ask for open file path
      path = UI.openpanel(Plugin.instance.get_i18n_string('tab.importer.load.title'), '', "CSV|*.csv||")
      if path

        filename = File.basename(path)
        extname = File.extname(path)

        # Errors
        unless File.exist?(path)
          response[:errors] << [ 'tab.importer.error.file_not_found', { :filename => filename } ]
          return response
        end
        if extname.nil? || extname.downcase != '.csv'
          response[:errors] << [ 'tab.importer.error.no_csv_extension', { :filename => filename } ]
          return response
        end

        # Add file infos to response
        response[:path] = path.tr("\\", '/')  # Standardize path by replacing \ by /
        response[:filename] = filename

      end

      response
    end

    def load_command(settings)

      # Clear previously generated parts
      @parts = nil

      # Check settings
      path = settings['path']
      filename = settings['filename']
      with_headers = settings['with_headers']
      col_sep = settings['col_sep']
      column_mapping = settings['column_mapping']   # { :field_name => COLUMN_INDEX, ... }

      model = Sketchup.active_model

      response = {
          :warnings => [],
          :errors => [],
      }

      # Check model
      unless model
        response[:errors] << 'tab.importer.error.no_model'
        return response
      end

      # Add model infos to response
      response[:length_unit] = model.options["UnitsOptions"]["LengthUnit"]
      response[:model_is_empty] = model.active_entities.length == 0 && model.definitions.length == 0 && model.materials.length == 0

      if path

        begin

          # Convert col_sep
          case col_sep.to_i
            when LOAD_OPTION_COL_SEP_COMMA
              col_sep = ','
            when LOAD_OPTION_COL_SEP_SEMICOLON
              col_sep = ';'
            else
              col_sep = "\t"
          end

          # Try to detect file encoding with rchardet lib
          cd = CharDet.detect(File.read(path))
          encoding = cd['encoding']

          rows = CSV.read(path, {
              :encoding => encoding + ':utf-8',
              :headers => with_headers,
              :col_sep => col_sep
          })

          # Extract headers
          headers = with_headers ? rows.headers : nil

          # Columns
          column_count = rows.empty? ? 0 : rows[0].length
          columns = []

          for i in 0..column_count - 1
            mapping = column_mapping.key(i)
            column_info = mapping ? COLUMN_INFOS[mapping.to_sym] : nil
            columns[i] = {
                :header => with_headers ? headers[i] : nil,
                :mapping => mapping,
                :align => column_info ? column_info[:align] : 'left',
            }
          end

          # Parts
          parts = []
          importable_part_count = 0
          rows.each do |row|

            # Ignore header row if it exists
            next if row.is_a?(CSV::Row) && row.header_row?

            part = {
                :name => nil,
                :count => nil,
                :length => nil,
                :width => nil,
                :thickness => nil,
                :material => nil,
                :labels => nil,
                :errors => [],
                :warnings => [],
                :raw_values => []
            }

            i = 0
            row.each { |row_value|

              value = row.is_a?(CSV::Row) ? row_value[1] : row_value
              valid = false

              mapping = column_mapping.key(i)
              if value and mapping

                column_info = mapping ? COLUMN_INFOS[mapping.to_sym] : nil
                if column_info

                  case column_info[:data_type]
                    when DATA_TYPE_INTEGER
                      begin
                        integer_value = value.to_i
                        valid = !value.empty? && integer_value > 0
                        value = integer_value if valid
                      rescue => e
                        valid = false
                      end
                    when DATA_TYPE_LENGTH
                      begin
                        length_value = DimensionUtils.instance.dd_to_ifloats(value).to_l
                        valid = !value.empty? && length_value > 0
                        value = length_value if valid
                      rescue => e
                        valid = false
                      end
                    when DATA_TYPE_STRING_ARRAY
                      begin
                      value = value.split(',')
                      valid = true
                      rescue => e
                        valid = false
                      end
                    else
                      valid = !value.empty?
                  end

                end

                if valid
                  part.store(mapping.to_sym, value)
                end

              end

              part[:raw_values].push({
                  :mapped => !mapping.nil?,
                  :value => value,
                  :valid => valid
              })

              i += 1
            }

            # Errors
            if part[:name].nil?
              part[:errors] << 'tab.importer.error.invalid_name'
            end
            if part[:length].nil?
              part[:errors] << 'tab.importer.error.invalid_length'
            end
            if part[:width].nil?
              part[:errors] << 'tab.importer.error.invalid_width'
            end
            if part[:thickness].nil?
              part[:errors] << 'tab.importer.error.invalid_thickness'
            end

            # Warnings
            if part[:count].nil?
              part[:warnings] << 'tab.importer.warning.invalid_count'
            end
            if part[:material].nil?
              part[:warnings] << 'tab.importer.warning.invalid_material'
            end

            # Add part to list
            parts.push(part)

            # Increment importable part count if applicable
            importable_part_count += part[:count].nil? ? 1 : part[:count] if part[:errors].empty?

          end

          if importable_part_count == 0
            response[:errors] << 'tab.importer.error.no_importable_part'
          end

          # Populate response
          response[:path] = path
          response[:filename] = filename
          response[:columns] = columns
          response[:parts] = parts
          response[:importable_part_count] = importable_part_count

          # Keep generated parts
          @parts = parts

        rescue => e
          puts e.message
          puts e.backtrace
          response[:errors] << [ 'tab.importer.error.failed_to_load_csv_file', { :error => e.message } ]
        end

      end

      response
    end

    def import_command(settings)

      remove_all = settings['remove_all']
      keep_definitions_settings = settings['keep_definitions_settings']
      keep_materials_settings = settings['keep_materials_settings']

      response = {
          :errors => [],
      }

      model = Sketchup.active_model

      # Check model
      unless model
        response[:errors] << 'tab.importer.error.no_model'
        return response
      end

      definitions = model.definitions
      materials = model.materials
      active_entities = model.active_entities

      # Start an operation
      model.start_operation('Importing parts...', true)

      # Remove all instances, definitions and materials if needed
      if remove_all
        active_entities.clear!
        unless keep_definitions_settings
          definitions.purge_unused
        end
        unless keep_materials_settings
          materials.purge_unused
        end
      end

      offset_y = 0
      imported_part_count = 0
      material_palette_index = 0
      @parts.each do |part|

        next unless part[:errors].empty?

        # Retrieve or Create the definition
        definition = nil
        if remove_all && keep_definitions_settings

          # Try to retrieve definition from list
          definition = definitions[part[:name]]

          # Definition exists ? -> clear it
          if definition
            definition.entities.clear!
          end

        end

        definition = definitions.add(part[:name]) unless definition   # Add new definition it it doesn't exist
        entities = definition.entities

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

        # Add labels if exists
        unless part[:labels].nil?
          definition_attributes = DefinitionAttributes.new(definition)
          definition_attributes.labels = part[:labels]
          definition_attributes.write_to_attributes
        end

        offset_y += part[:width]

        # Purge extra definitions and materials if needed
        if remove_all
          if keep_definitions_settings
            definitions.purge_unused
          end
          if keep_materials_settings
            materials.purge_unused
          end
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

  end

end