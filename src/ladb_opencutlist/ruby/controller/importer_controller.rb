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

      response = {
          :errors => [],
          :open_path => ''
      }

      # Fetch component instances in given entities
      model = Sketchup.active_model
      dir, filename = File.split(model ? model.path : '')

      # Ask for open file path
      csv_path = UI.openpanel(Plugin.instance.get_i18n_string('tab.importer.load.title'), dir, "CSV|*.csv||")
      if csv_path

        # Add load_path to response
        response[:csv_path] = csv_path.tr("\\", '/')  # Standardize path by replacing \ by /

      end

      response
    end

    def load_command(settings)

      # Check settings
      csv_path = settings['csv_path']
      with_headers = settings['with_headers']
      col_sep = settings['col_sep']
      encoding = settings['encoding']
      column_mapping = settings['column_mapping']   # { :field_name => COLUMN_INDEX, ... }

      response = {
          :warnings => [],
          :errors => [],
          :csv_path => csv_path
      }

      if csv_path

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

        rows = CSV.read(csv_path, {
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
        rows.each do |row|
          next if row.header_row?

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
          row.to_hash.each { |k, v|

            value = v
            valid = false

            mapping = column_mapping.key(i)
            if mapping

              column_info = mapping ? COLUMN_INFOS[mapping.to_sym] : nil
              if column_info

                case column_info[:data_type]
                  when DATA_TYPE_INTEGER
                    begin
                      valid = !v.empty? && v.to_i > 0
                      value = v.to_i if valid
                    rescue => e
                      valid = false
                    end
                  when DATA_TYPE_LENGTH
                    begin
                      valid = !v.empty?
                      value = v.to_l if valid
                    rescue => e
                      valid = false
                    end
                  when DATA_TYPE_STRING_ARRAY
                    begin
                    value = v.split(',')
                    valid = true
                    rescue => e
                      valid = false
                    end
                  else
                    value = v
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
            part[:errors].push('pas de désignation valide')
          end
          if part[:length].nil?
            part[:errors].push('pas de longueur valide')
          end
          if part[:width].nil?
            part[:errors].push('pas de largeur valide')
          end
          if part[:thickness].nil?
            part[:errors].push('pas d\'épaisseur valide')
          end

          # Warnings
          if part[:count].nil?
            part[:warnings].push('pas de quantité valide')
          end
          if part[:material].nil?
            part[:warnings].push('pas de matière valide')
          end

          parts.push(part)
        end

        # Populate response
        response[:columns] = columns
        response[:parts] = parts

      end

      response
    end

    def import_command(settings)


    end

  end

end