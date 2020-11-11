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
      @col_defs = settings['col_defs']
      @hide_entity_names = settings['hide_entity_names']
      @hide_tags = settings['hide_tags']
      @hide_cutting_dimensions = settings['hide_cutting_dimensions']
      @hide_bbox_dimensions = settings['hide_bbox_dimensions']
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
            options = { :col_sep => col_sep, :force_quotes => force_quotes }
            csv_file = CSV.generate(**options) do |csv|

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
                  @col_defs.each { |col_def|
                    unless col_def['hidden']
                      header.push(Plugin.instance.get_i18n_string("tab.cutlist.export.#{col_def['name']}"))
                    end
                  }

                  csv << header

                  @cutlist.groups.each { |group|
                    next if @hidden_group_ids.include? group.id

                    row = []
                    @col_defs.each { |col_def|
                      unless col_def['hidden']
                        case col_def['name']
                          when 'material_type'
                            row.push(Plugin.instance.get_i18n_string("tab.materials.type_#{group.material_type}"))
                          when 'material_thickness'
                            row.push((group.material_name ? group.material_name : Plugin.instance.get_i18n_string('tab.cutlist.material_undefined')) + (group.material_type > 0 ? ' / ' + group.std_dimension : ''))
                          when 'part_count'
                            row.push(group.part_count)
                          when 'total_cutting_length'
                            row.push(group.total_cutting_length.nil? ? '' : _sanitize_value_string(group.total_cutting_length))
                          when 'total_cutting_area'
                            row.push(group.total_cutting_area.nil? ? '' : _sanitize_value_string(group.total_cutting_area))
                          when 'total_cutting_volume'
                            row.push(group.total_cutting_volume.nil? ? '' : _sanitize_value_string(group.total_cutting_volume))
                          when 'total_final_area'
                            row.push((group.total_final_area.nil? or group.invalid_final_area_part_count > 0) ? '' : _sanitize_value_string(group.total_final_area))
                          else
                            row.push('')
                        end
                      end
                    }

                    csv << row
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
                      no_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN || group.material_type == MaterialAttributes::TYPE_ACCESSORY

                      row = []
                      @col_defs.each { |col_def|
                        unless col_def['hidden']
                          case col_def['name']
                            when 'number'
                              row.push(part.number)
                            when 'name'
                              row.push(part.name)
                            when 'count'
                              row.push(part.count)
                            when 'cutting_length'
                              row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length))
                            when 'cutting_width'
                              row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width))
                            when 'cutting_thickness'
                              row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness))
                            when 'bbox_length'
                              row.push(no_dimensions ? '' : _sanitize_value_string(part.length))
                            when 'bbox_width'
                              row.push(no_dimensions ? '' : _sanitize_value_string(part.width))
                            when 'bbox_thickness'
                              row.push(no_dimensions ? '' : _sanitize_value_string(part.thickness))
                            when 'final_area'
                              row.push(no_dimensions ? '' : _sanitize_value_string(part.final_area))
                            when 'material_name'
                              row.push(group.material_display_name)
                            when 'entity_names'
                              row.push(part.is_a?(Part) ? part.entity_names.map(&:first).join(',') : '')
                            when 'tags'
                              row.push(part.tags.empty? ? '' : part.tags.join(','))
                            when 'edge_ymin'
                              row.push(_format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]))
                            when 'edge_ymax'
                              row.push(_format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]))
                            when 'edge_xmin'
                              row.push(_format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]))
                            when 'edge_xmax'
                              row.push(_format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]))
                            else
                              row.push('')
                          end
                        end
                      }

                      csv << row
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
                      no_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN || group.material_type == MaterialAttributes::TYPE_ACCESSORY

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
                          @col_defs.each { |col_def|
                            unless col_def['hidden']
                              case col_def['name']
                                when 'number'
                                  row.push(part.number)
                                when 'path'
                                  row.push(path_names.join('/'))
                                when 'instance_name'
                                  row.push(instance_name)
                                when 'definition_name'
                                  row.push(part.name)
                                when 'cutting_length'
                                  row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length))
                                when 'cutting_width'
                                  row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width))
                                when 'cutting_thickness'
                                  row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness))
                                when 'bbox_length'
                                  row.push(no_dimensions ? '' : _sanitize_value_string(part.length))
                                when 'bbox_width'
                                  row.push(no_dimensions ? '' : _sanitize_value_string(part.width))
                                when 'bbox_thickness'
                                  row.push(no_dimensions ? '' : _sanitize_value_string(part.thickness))
                                when 'final_area'
                                  row.push(no_dimensions ? '' : _sanitize_value_string(part.final_area))
                                when 'material_name'
                                  row.push(group.material_display_name)
                                when 'tags'
                                  row.push(part.tags.empty? ? '' : part.tags.join(','))
                                when 'edge_ymin'
                                  row.push(_format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]))
                                when 'edge_ymax'
                                  row.push(_format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]))
                                when 'edge_xmin'
                                  row.push(_format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]))
                                when 'edge_xmax'
                                  row.push(_format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]))
                                else
                                  row.push('')
                              end
                            end
                          }

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
