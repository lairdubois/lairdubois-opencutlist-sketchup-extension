module Ladb::OpenCutList

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
            :is_numeric => false,
            :data_type => DATA_TYPE_STRING
        },
        :count => {
            :align => 'center',
            :is_numeric => false,
            :data_type => DATA_TYPE_INTEGER
        },
        :length => {
            :align => 'right',
            :is_numeric => false,
            :data_type => DATA_TYPE_LENGTH
        },
        :width => {
            :align => 'right',
            :is_numeric => false,
            :data_type => DATA_TYPE_LENGTH
        },
        :thickness => {
            :align => 'right',
            :is_numeric => false,
            :data_type => DATA_TYPE_LENGTH
        },
        :material => {
            :align => 'left',
            :is_numeric => false,
            :data_type => DATA_TYPE_STRING
        },
        :labels => {
            :align => 'left',
            :is_numeric => false,
            :data_type => DATA_TYPE_STRING_ARRAY
        },
    }

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

      # Ask for open file path
      path = UI.openpanel(Plugin.instance.get_i18n_string('tab.importer.load.title'), '', "CSV|*.csv||")
      if path

        filename = File.basename(path)
        extname = File.extname(path)

        # Errors
        unless File.exist?(path)
          response[:errors] << 'tab.importer.error.file_not_found'
          return response
        end
        if extname.nil? || extname.downcase != '.csv'
          response[:errors] << 'tab.importer.error.no_csv_extension'
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
      encoding = settings['encoding']
      column_mapping = settings['column_mapping']   # { :field_name => COLUMN_INDEX, ... }

      model = Sketchup.active_model
      length_unit = model ? model.options["UnitsOptions"]["LengthUnit"] : nil

      response = {
          :warnings => [],
          :errors => [],
          :length_unit => length_unit,
      }

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

          # Convert col_sep
          case encoding.to_i
            when LOAD_OPTION_ENCODING_UTF16LE
              encoding = 'UTF-16LE'
            when LOAD_OPTION_ENCODING_UTF16BE
              encoding = 'UTF-16BE'
            else
              encoding = 'UTF-8'
          end

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
              if mapping

                column_info = mapping ? COLUMN_INFOS[mapping.to_sym] : nil
                if column_info

                  case column_info[:data_type]
                    when DATA_TYPE_INTEGER
                      begin
                        valid = !value.empty? && value.to_i > 0
                        value = value.to_i if valid
                      rescue => e
                        valid = false
                      end
                    when DATA_TYPE_LENGTH
                      begin
                        valid = !value.empty? && value.to_l > 0
                        value = value.to_l if valid
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
                      valid = true
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
          response[:errors] << 'tab.importer.error.failed_to_load_csv_file'
        end

      end

      response
    end

    def import_command(settings)

      response = {
          :errors => [],
      }

      model = Sketchup.active_model
      definitions = model.definitions
      materials = model.materials
      active_entities = model.active_entities

      # Start an operation
      model.start_operation('Create parts', true)

      offset_y = 0
      imported_part_count = 0
      @parts.each do |part|

        next unless part[:errors].empty?

        # Create the definition
        definition = definitions.add(part[:name])
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
            material.color = Sketchup::Color.new(rand(255), rand(255), rand(255))
          end
        end

        # Create definition instance(s)
        count = part[:count].nil? ? 1 : part[:count]
        for i in 0..count-1
          instance = active_entities.add_instance(definition, Geom::Transformation.new(Geom::Point3d.new(0, offset_y, i * part[:thickness])))
          instance.material = material if material
          imported_part_count += 1
        end

        offset_y += part[:width]

      end

      # Commit operation
      model.commit_operation

      response[:imported_part_count] = imported_part_count

      response
    end

  end

end