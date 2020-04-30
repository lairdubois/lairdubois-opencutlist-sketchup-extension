module Ladb::OpenCutList

  require 'csv'
  require_relative '../../lib/rchardet'

  class ImporterLoadWorker

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

    def initialize(settings)
      @path = settings['path']
      @filename = settings['filename']
      @first_line_headers = settings['first_line_headers']
      @col_sep = settings['col_sep']
      @column_mapping = settings['column_mapping']   # { :field_name => COLUMN_INDEX, ... }
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.importer.error.no_model' ] } unless model

      # Clear previously generated parts
      @parts = nil

      response = {
          :warnings => [],
          :errors => [],
          :path => @path,
          :filename => @filename,
          :length_unit => DimensionUtils.instance.length_unit,
          :columns => [],
          :parts => [],
          :importable_part_count => 0,
      }

      # Add model infos to response
      response[:model_is_empty] = model.active_entities.length == 0 && model.definitions.length == 0 && model.materials.length == 0

      if @path

        begin

          # Convert col_sep
          case @col_sep.to_i
          when LOAD_OPTION_COL_SEP_COMMA
            @col_sep = ','
          when LOAD_OPTION_COL_SEP_SEMICOLON
            @col_sep = ';'
          else
            @col_sep = "\t"
          end

          # Try to detect file encoding with rchardet lib
          cd = CharDet.detect(File.read(@path))
          encoding = cd['encoding']

          rows = CSV.read(@path, {
              :encoding => encoding + ':utf-8',
              :headers => @first_line_headers,
              :col_sep => @col_sep
          })

          # Extract headers
          headers = @first_line_headers ? rows.headers : nil

          # Columns
          column_count = rows.empty? ? 0 : rows[0].length

          for i in 0..column_count - 1
            mapping = @column_mapping.key(i)
            column_info = mapping ? COLUMN_INFOS[mapping.to_sym] : nil
            response[:columns][i] = {
                :header => @first_line_headers ? headers[i] : nil,
                :mapping => mapping,
                :align => column_info ? column_info[:align] : 'left',
            }
          end

          # Parts
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

              mapping = @column_mapping.key(i)
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
            response[:parts].push(part)

            # Increment importable part count if applicable
            response[:importable_part_count] += part[:count].nil? ? 1 : part[:count] if part[:errors].empty?

          end

          if response[:importable_part_count] == 0
            if response[:parts].length == 0
              response[:errors] << 'tab.importer.error.empty_file'
            else
              response[:errors] << 'tab.importer.error.no_importable_part'
            end
          end

        rescue => e
          puts e.message
          puts e.backtrace
          response[:errors] << [ 'tab.importer.error.failed_to_load_csv_file', { :error => e.message } ]
        end

      end

      response
    end

    # -----

  end

end