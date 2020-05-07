module Ladb::OpenCutList

  require 'csv'
  require_relative '../../model/attributes/material_attributes'

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
      @hide_entity_names = settings['hide_entity_names']
      @hide_labels = settings['hide_labels']
      @hide_cutting_dimensions = settings['hide_cutting_dimensions']
      @hide_bbox_dimensions = settings['hide_bbox_dimensions']
      @hide_untyped_material_dimensions = settings['hide_untyped_material_dimensions']
      @hide_final_areas = settings['hide_final_areas']
      @hide_edges = settings['hide_edges']
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

        begin

          # Convert col_sep
          case @col_sep.to_i
            when EXPORT_OPTION_COL_SEP_COMMA
              col_sep = ','
              force_quotes = true
            when EXPORT_OPTION_COL_SEP_SEMICOLON
              col_sep = ';'
              force_quotes = false
            else
              col_sep = "\t"
              force_quotes = false
          end

          # Convert col_sep
          case @encoding.to_i
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
            csv_file = CSV.generate({ :col_sep => col_sep, :force_quotes => force_quotes }) do |csv|

              def _sanitize_value_string(value)
                value.gsub(/^~ /, '') unless value.nil?
              end
              def _format_edge_value(material_name, std_dimension)
                if material_name
                  return "#{material_name} (#{std_dimension})"
                end
                ''
              end

              case @source.to_i

                when EXPORT_OPTION_SOURCE_SUMMARY

                  # Header row
                  header = []
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_type'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_thickness'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.part_count'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_cutting_length'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_cutting_area'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_cutting_volume'))
                  unless @hide_final_areas
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_final_area'))
                  end

                  csv << header

                  @cutlist.groups.each { |group|
                    next if @hidden_group_ids.include? group.id

                    row = []
                    row.push(Plugin.instance.get_i18n_string("tab.materials.type_#{group.material_type}"))
                    row.push((group.material_name ? group.material_name : Plugin.instance.get_i18n_string('tab.cutlist.material_undefined')) + (group.material_type > 0 ? ' / ' + group.std_dimension : ''))
                    row.push(group.part_count)
                    row.push(group.total_cutting_length.nil? ? '' : _sanitize_value_string(group.total_cutting_length))
                    row.push(group.total_cutting_area.nil? ? '' : _sanitize_value_string(group.total_cutting_area))
                    row.push(group.total_cutting_volume.nil? ? '' : _sanitize_value_string(group.total_cutting_volume))
                    unless @hide_final_areas
                      row.push((group.total_final_area.nil? or group.invalid_final_area_part_count > 0) ? '' : _sanitize_value_string(group.total_final_area))
                    end

                    csv << row
                  }

                when EXPORT_OPTION_SOURCE_CUTLIST

                  # Header row
                  header = []
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.number'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.name'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.count'))
                  unless @hide_cutting_dimensions
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_length'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_width'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_thickness'))
                  end
                  unless @hide_bbox_dimensions
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_length'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_width'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_thickness'))
                  end
                  unless @hide_final_areas
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.final_area'))
                  end
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_name'))
                  unless @hide_entity_names
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.entity_names'))
                  end
                  unless @hide_labels
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.labels'))
                  end
                  unless @hide_edges
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymax'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymin'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmin'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmax'))
                  end

                  csv << header

                  # Content rows
                  @cutlist.groups.each { |group|
                    next if @hidden_group_ids.include? group.id
                    group.parts.each { |part|

                      no_cutting_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOW
                      no_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOW && @hide_untyped_material_dimensions

                      row = []
                      row.push(part.number)
                      row.push(part.name)
                      row.push(part.count)
                      unless @hide_cutting_dimensions
                        row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length))
                        row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width))
                        row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness))
                      end
                      unless @hide_bbox_dimensions
                        row.push(no_dimensions ? '' : _sanitize_value_string(part.length))
                        row.push(no_dimensions ? '' : _sanitize_value_string(part.width))
                        row.push(no_dimensions ? '' : _sanitize_value_string(part.thickness))
                      end
                      unless @hide_final_areas
                        row.push(no_dimensions ? '' : _sanitize_value_string(part.final_area))
                      end
                      row.push(group.material_display_name)
                      unless @hide_entity_names
                        row.push(part.is_a?(Part) ? part.entity_names.map(&:first).join(',') : '')
                      end
                      unless @hide_labels
                        row.push(part.labels.empty? ? '' : part.labels.join(','))
                      end
                      unless @hide_edges
                        row.push(_format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]))
                        row.push(_format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]))
                        row.push(_format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]))
                        row.push(_format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]))
                      end

                      csv << row
                    }
                  }

                when EXPORT_OPTION_SOURCE_INSTANCES_LIST

                  # Header row
                  header = []
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.number'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.path'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.instance_name'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.definition_name'))
                  unless @hide_cutting_dimensions
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_length'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_width'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_thickness'))
                  end
                  unless @hide_bbox_dimensions
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_length'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_width'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_thickness'))
                  end
                  unless @hide_final_areas
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.final_area'))
                  end
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_name'))
                  unless @hide_labels
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.labels'))
                  end
                  unless @hide_edges
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymax'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymin'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmin'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmax'))
                  end

                  csv << header

                  # Content rows
                  @cutlist.groups.each { |group|
                    next if @hidden_group_ids.include? group.id
                    next if group.material_type == MaterialAttributes::TYPE_EDGE    # Edges don't have instances
                    group.parts.each { |part|

                      no_cutting_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOW
                      no_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOW && @hide_untyped_material_dimensions

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

                          row = []
                          row.push(part.number)
                          row.push(path_names.join('/'))
                          row.push(instance_name)
                          row.push(part.name)
                          unless @hide_cutting_dimensions
                            row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length))
                            row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width))
                            row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness))
                          end
                          unless @hide_bbox_dimensions
                            row.push(no_dimensions ? '' : _sanitize_value_string(part.length))
                            row.push(no_dimensions ? '' : _sanitize_value_string(part.width))
                            row.push(no_dimensions ? '' : _sanitize_value_string(part.thickness))
                          end
                          unless @hide_final_areas
                            row.push(no_dimensions ? '' : _sanitize_value_string(part.final_area))
                          end
                          row.push(group.material_display_name)
                          unless @hide_labels
                            row.push(part.labels.empty? ? '' : part.labels.join(','))
                          end
                          unless @hide_edges
                            row.push(_format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]))
                            row.push(_format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]))
                            row.push(_format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]))
                            row.push(_format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]))
                          end

                          csv << row

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

  end

end