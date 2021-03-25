module Ladb::OpenCutList

  require 'csv'
  require_relative '../../model/attributes/material_attributes'
  require_relative '../../lib/dentaku'

  class CutlistExportWorker

    EXPORT_OPTION_SOURCE_SUMMARY = 0
    EXPORT_OPTION_SOURCE_CUTLIST = 1
    EXPORT_OPTION_SOURCE_INSTANCES_LIST = 2

    EXPORT_OPTION_COL_SEP_TAB = 0
    EXPORT_OPTION_COL_SEP_COMMA = 1
    EXPORT_OPTION_COL_SEP_SEMICOLON = 2

    EXPORT_OPTION_ENCODING_UTF8 = 0
    EXPORT_OPTION_ENCODING_UTF16LE = 1
    EXPORT_OPTION_ENCODING_UTF16BE = 2

    def initialize(settings, cutlist)
      @source = settings['source']
      @col_sep = settings['col_sep']
      @encoding = settings['encoding']
      @col_defs = settings['col_defs']
      @hidden_group_ids = settings['hidden_group_ids']

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      response = {
          :errors => [],
          :export_path => ''
      }

      # Ask for export file path
      export_path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export.title'), @cutlist.dir, File.basename(@cutlist.filename, '.skp') + '.csv')
      if export_path

        # Force "csv" file extension
        unless export_path.end_with?('.csv')
          export_path = export_path + '.csv'
        end

        begin

          # Convert col_sep
          case @col_sep
            when EXPORT_OPTION_COL_SEP_COMMA
              col_sep = ','
            when EXPORT_OPTION_COL_SEP_SEMICOLON
              col_sep = ';'
            else
              col_sep = "\t"
          end

          # Convert col_sep
          case @encoding
            when EXPORT_OPTION_ENCODING_UTF16LE
              bom = "\xFF\xFE".force_encoding('utf-16le')
              encoding = 'UTF-16LE'
            when EXPORT_OPTION_ENCODING_UTF16BE
              bom = "\xFE\xFF".force_encoding('utf-16be')
              encoding = 'UTF-16BE'
            else
              bom = "\xEF\xBB\xBF"
              encoding = 'UTF-8'
          end

          File.open(export_path, "wb+:#{encoding}") do |f|
            options = { :col_sep => col_sep }
            csv_file = CSV.generate(**options) do |csv|

              # Create the formula calculator
              calculator = Dentaku::Calculator.new

              case @source

                when EXPORT_OPTION_SOURCE_SUMMARY

                  # Header row
                  header = []
                  @col_defs.each { |col_def|
                    unless col_def['hidden']
                      header.push(Plugin.instance.get_i18n_string("tab.cutlist.export.#{col_def['name']}"))
                    end
                  }

                  csv << header

                  @cutlist.groups.each { |group|
                    next if @hidden_group_ids.include? group.id

                    vars = {
                      :material_type => Plugin.instance.get_i18n_string("tab.materials.type_#{group.material_type}"),
                      :material_thickness => (group.material_name ? group.material_name : Plugin.instance.get_i18n_string('tab.cutlist.material_undefined')) + (group.material_type > 0 ? ' / ' + group.std_dimension : ''),
                      :part_count => group.part_count,
                      :total_cutting_length => group.total_cutting_length.nil? ? '' : _sanitize_value_string(group.total_cutting_length),
                      :total_cutting_area => group.total_cutting_area.nil? ? '' : _sanitize_value_string(group.total_cutting_area),
                      :total_cutting_volume => group.total_cutting_volume.nil? ? '' : _sanitize_value_string(group.total_cutting_volume),
                      :total_final_area => (group.total_final_area.nil? || group.invalid_final_area_part_count > 0) ? '' : _sanitize_value_string(group.total_final_area),
                    }

                    csv << _evaluate_row(calculator, vars)
                  }

                when EXPORT_OPTION_SOURCE_CUTLIST

                  # Header row
                  header = []
                  @col_defs.each { |col_def|
                    unless col_def['hidden']
                      header.push(Plugin.instance.get_i18n_string("tab.cutlist.export.#{col_def['name']}"))
                    end
                  }

                  csv << header

                  # Content rows
                  @cutlist.groups.each { |group|
                    next if @hidden_group_ids.include? group.id
                    group.parts.each { |part|

                      no_cutting_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN
                      no_dimensions = group.material_type == MaterialAttributes::TYPE_HARDWARE

                      vars = {
                        :number => part.number,
                        :name => part.name,
                        :count => part.count,
                        :cutting_length => no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length),
                        :cutting_width => no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width),
                        :cutting_thickness => no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness),
                        :bbox_length => no_dimensions ? '' : _sanitize_value_string(part.length),
                        :bbox_width => no_dimensions ? '' : _sanitize_value_string(part.width),
                        :bbox_thickness => no_dimensions ? '' : _sanitize_value_string(part.thickness),
                        :final_area => no_dimensions ? '' : _sanitize_value_string(part.final_area),
                        :material_name => group.material_display_name,
                        :entity_names => part.is_a?(Part) ? part.entity_names.map(&:first).join(',') : '',
                        :tags => part.tags.empty? ? '' : part.tags.join(','),
                        :edge_ymin => _format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]),
                        :edge_ymax => _format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]),
                        :edge_xmin => _format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]),
                        :edge_xmax => _format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]),
                      }

                      csv << _evaluate_row(calculator, vars)
                    }
                  }

                when EXPORT_OPTION_SOURCE_INSTANCES_LIST

                  # Header row
                  header = []
                  @col_defs.each { |col_def|
                    unless col_def['hidden']
                      header.push(Plugin.instance.get_i18n_string("tab.cutlist.export.#{col_def['name']}"))
                    end
                  }

                  csv << header

                  # Content rows
                  @cutlist.groups.each { |group|
                    next if @hidden_group_ids.include? group.id
                    next if group.material_type == MaterialAttributes::TYPE_EDGE    # Edges don't have instances
                    group.parts.each { |part|

                      no_cutting_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN
                      no_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN || group.material_type == MaterialAttributes::TYPE_HARDWARE

                      parts = part.is_a?(FolderPart) ? part.children : [ part ]
                      parts.each { |part|

                        # Ungroup parts
                        part.def.instance_infos.each { |serialized_path, instance_info|

                          # Compute path with entities names (from root group to final entity)
                          path_names = []
                          instance_info.path.each { |entity|
                            # Uses entityID if instance name is empty
                            path_names.push(entity.name.empty? ? "##{entity.entityID}" : entity.name)
                          }
                          # Pop the instance name to put it in a separated column
                          instance_name = path_names.pop

                          vars = {
                            :number => part.number,
                            :path => path_names.join('/'),
                            :instance_name => instance_name,
                            :definition_name => part.name,
                            :cutting_length => no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length),
                            :cutting_width => no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width),
                            :cutting_thickness => no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness),
                            :bbox_length => no_dimensions ? '' : _sanitize_value_string(part.length),
                            :bbox_width => no_dimensions ? '' : _sanitize_value_string(part.width),
                            :bbox_thickness => no_dimensions ? '' : _sanitize_value_string(part.thickness),
                            :final_area => no_dimensions ? '' : _sanitize_value_string(part.final_area),
                            :material_name => group.material_display_name,
                            :tags => part.tags.empty? ? '' : part.tags.join(','),
                            :edge_ymin => _format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]),
                            :edge_ymax => _format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]),
                            :edge_xmin => _format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]),
                            :edge_xmax => _format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]),
                          }

                          csv << _evaluate_row(calculator, vars)
                        }

                      }

                    }
                  }

              end

            end

            # Write file
            f.write(bom)
            f.write(csv_file)

            # Populate response
            response[:export_path] = export_path.tr("\\", '/')  # Standardize path by replacing \ by /

          end

        rescue => e
          puts e.message
          puts e.backtrace
          response[:errors] << [ 'tab.cutlist.error.failed_to_write_export_file', { :error => e.message } ]
        end

      end

      response
    end

    # -----

    def _sanitize_value_string(value)
      value.gsub(/^~ /, '') unless value.nil?
    end

    def _format_edge_value(material_name, std_dimension)
      if material_name
        return "#{material_name} (#{std_dimension})"
      end
      ''
    end

    def _evaluate_row(calculator, vars)
      row = []
      @col_defs.each { |col_def|
        unless col_def['hidden']
          if col_def['formula'].nil? || col_def['formula'].empty?
            formula = col_def['name']
          else
            vars[:value] = vars[col_def['name'].to_sym]
            formula = col_def['formula']
          end
          begin
            value = calculator.evaluate!(formula, vars)
          rescue => e
            value = "!ERROR"
          end
          row.push(value)
        end
      }
      row
    end

  end

end
