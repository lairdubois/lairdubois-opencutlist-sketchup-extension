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
      @preview = settings['preview']

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      response = {
          :errors => [],
          :export_path => ''
      }

      if @preview
        response[:rows] = _compute_rows
      else

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

            # Write ro CSV file
            File.open(export_path, "wb+:#{encoding}") do |f|
              options = { :col_sep => col_sep }
              csv_file = CSV.generate(**options) do |csv|

                _compute_rows.each { |row|
                  csv << row
                }

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

      end
      response
    end

    # -----

    def _compute_rows

      Dentaku.calculator.add_function(:to_f, :numeric, ->(value) { value.to_f })

      # Generate rows
      rows = []
      case @source

      when EXPORT_OPTION_SOURCE_SUMMARY

        # Header row
        rows << _evaluate_header

        @cutlist.groups.each { |group|
          next if @hidden_group_ids.include? group.id

          data = SummaryExportRowData.new(
            Plugin.instance.get_i18n_string("tab.materials.type_#{group.material_type}"),
            (group.material_name ? group.material_name : Plugin.instance.get_i18n_string('tab.cutlist.material_undefined')) + (group.material_type > 0 ? ' / ' + group.std_dimension : ''),
            group.part_count,
            group.total_cutting_length.nil? ? '' : _sanitize_value_string(group.total_cutting_length),
            group.total_cutting_area.nil? ? '' : _sanitize_value_string(group.total_cutting_area),
            group.total_cutting_volume.nil? ? '' : _sanitize_value_string(group.total_cutting_volume),
            (group.total_final_area.nil? || group.invalid_final_area_part_count > 0) ? '' : _sanitize_value_string(group.total_final_area),
          )

          rows << _evaluate_row(data)
        }

      when EXPORT_OPTION_SOURCE_CUTLIST

        # Header row
        rows << _evaluate_header

        # Content rows
        @cutlist.groups.each { |group|
          next if @hidden_group_ids.include? group.id
          group.parts.each { |part|

            no_cutting_dimensions = group.material_type == MaterialAttributes::TYPE_UNKNOWN
            no_dimensions = group.material_type == MaterialAttributes::TYPE_HARDWARE

            data = CutlistExportRowData.new(
              part.number,
              part.name,
              part.count,
              no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length),
              no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width),
              no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness),
              no_dimensions ? '' : _sanitize_value_string(part.length),
              no_dimensions ? '' : _sanitize_value_string(part.width),
              no_dimensions ? '' : _sanitize_value_string(part.thickness),
              no_dimensions ? '' : _sanitize_value_string(part.final_area),
              group.material_display_name,
              part.entity_names.map(&:first).join(','),
              part.description,
              part.tags.empty? ? '' : part.tags.join(','),
              _format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]),
              _format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]),
              _format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]),
              _format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]),
            )

            rows << _evaluate_row(data)
          }
        }

      when EXPORT_OPTION_SOURCE_INSTANCES_LIST

        # Header row
        rows << _evaluate_header

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

                data = InstancesListExportRowData.new(
                  part.number,
                  PathUtils.get_named_path(instance_info.path, false, 1, '/'),
                  instance_info.entity.name.empty? ? "##{instance_info.entity.entityID}" : instance_info.entity.name,
                  part.name,
                  part.count,
                  no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_length),
                  no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_width),
                  no_cutting_dimensions ? '' : _sanitize_value_string(part.cutting_thickness),
                  no_dimensions ? '' : _sanitize_value_string(part.length),
                  no_dimensions ? '' : _sanitize_value_string(part.width),
                  no_dimensions ? '' : _sanitize_value_string(part.thickness),
                  no_dimensions ? '' : _sanitize_value_string(part.final_area),
                  group.material_display_name,
                  part.entity_names.map(&:first).join(','),
                  part.description,
                  part.tags.empty? ? '' : part.tags.join(','),
                  _format_edge_value(part.edge_material_names[:ymin], part.edge_std_dimensions[:ymin]),
                  _format_edge_value(part.edge_material_names[:ymax], part.edge_std_dimensions[:ymax]),
                  _format_edge_value(part.edge_material_names[:xmin], part.edge_std_dimensions[:xmin]),
                  _format_edge_value(part.edge_material_names[:xmax], part.edge_std_dimensions[:xmax]),
                )

                rows << _evaluate_row(data)
              }

            }

          }
        }

      end

      rows
    end

    def _sanitize_value_string(value)
      value.gsub(/^~ /, '') unless value.nil?
    end

    def _format_edge_value(material_name, std_dimension)
      if material_name
        return "#{material_name} (#{std_dimension})"
      end
      ''
    end

    def _evaluate_header
      header = []
      @col_defs.each { |col_def|
        unless col_def['hidden']
          if col_def['header'].is_a?(String) && !col_def['header'].empty?
            header.push(col_def['header'])
          elsif col_def['name'].is_a?(String) && !col_def['name'].empty?
            header.push(Plugin.instance.get_i18n_string("tab.cutlist.export.#{col_def['name']}"))
          else
            header.push('')
          end
        end
      }
      header
    end

    def _evaluate_row(data)
      row = []
      @col_defs.each { |col_def|
        unless col_def['hidden']
          if col_def['formula'].nil? || col_def['formula'].empty?
            formula = '@' + col_def['name']
          else
            formula = col_def['formula']
          end
          begin
            # value = Dentaku.calculator.evaluate(formula, vars)
            value = eval(formula, data.get_binding)
          rescue Exception => e
            value = { :error => e.message }
          end
          row.push(value)
        end
      }
      row
    end

  end

  class ExportRowData

    def get_binding
      binding
    end

  end

  class SummaryExportRowData < ExportRowData

    def initialize(
      material_type,
      material_thickness,
      part_count,
      total_cutting_length,
      total_cutting_area,
      total_cutting_volume,
      total_final_area
    )
      @material_type = material_type
      @material_thickness = material_thickness
      @part_count = part_count
      @total_cutting_length = total_cutting_length
      @total_cutting_area = total_cutting_area
      @total_cutting_volume = total_cutting_volume
      @total_final_area = total_final_area
    end

  end

  class CutlistExportRowData < ExportRowData

    def initialize(
      number,
      name,
      count,
      cutting_length,
      cutting_width,
      cutting_thickness,
      bbox_length,
      bbox_width,
      bbox_thickness,
      final_area,
      material_name,
      entity_names,
      description,
      tags,
      edge_ymin,
      edge_ymax,
      edge_xmin,
      edge_xmax
    )
      @number = number
      @name = name
      @count = count
      @cutting_length = cutting_length
      @cutting_width = cutting_width
      @cutting_thickness = cutting_thickness
      @bbox_length = bbox_length
      @bbox_width = bbox_width
      @bbox_thickness = bbox_thickness
      @final_area = final_area
      @material_name = material_name
      @entity_names = entity_names
      @description = description
      @tags = tags
      @edge_ymin = edge_ymin
      @edge_ymax = edge_ymax
      @edge_xmin = edge_xmin
      @edge_xmax = edge_xmax
    end

  end

  class InstancesListExportRowData < ExportRowData

    def initialize(
      number,
      path,
      instance_name,
      definition_name,
      count,
      cutting_length,
      cutting_width,
      cutting_thickness,
      bbox_length,
      bbox_width,
      bbox_thickness,
      final_area,
      material_name,
      entity_names,
      description,
      tags,
      edge_ymin,
      edge_ymax,
      edge_xmin,
      edge_xmax
    )
      @number = number
      @path = path
      @instance_name = instance_name
      @definition_name = definition_name
      @count = count
      @cutting_length = cutting_length
      @cutting_width = cutting_width
      @cutting_thickness = cutting_thickness
      @bbox_length = bbox_length
      @bbox_width = bbox_width
      @bbox_thickness = bbox_thickness
      @final_area = final_area
      @material_name = material_name
      @entity_names = entity_names
      @description = description
      @tags = tags
      @edge_ymin = edge_ymin
      @edge_ymax = edge_ymax
      @edge_xmin = edge_xmin
      @edge_xmax = edge_xmax
    end

  end

end
