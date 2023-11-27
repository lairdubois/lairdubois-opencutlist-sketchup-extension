module Ladb::OpenCutList

  require 'csv'
  require_relative '../../model/attributes/material_attributes'
  require_relative '../../model/export/wrappers'

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

      options = Plugin.instance.get_model_preset('cutlist_export_options')

      @source = settings.fetch('source', options.fetch('source'))
      @col_sep = settings.fetch('col_sep', options.fetch('col_sep'))
      @encoding = settings.fetch('encoding', options.fetch('encoding'))
      @col_defs = settings.fetch('col_defs')
      @target = settings.fetch('target')
      @no_header = settings.fetch('no_header', false)
      @hidden_group_ids = settings.fetch('hidden_group_ids')

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      response = {
          :errors => [],
          :export_path => ''
      }

      case @target
      when 'table'

        response[:rows] = _compute_rows

      when 'pasteable'

        options = { :col_sep => "\t" }
        pasteable = CSV.generate(**options) do |csv|

          _compute_rows.each { |row|
            csv << row
          }

        end
        response[:pasteable] = pasteable

      when 'csv'

        # Ask for export file path
        path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export.title'), @cutlist.dir, File.basename(@cutlist.filename, '.skp') + '.csv')
        if path

          # Force "csv" file extension
          unless path.end_with?('.csv')
            path = path + '.csv'
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

            # Convert encoding
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

            # Write CSV file
            File.open(path, "wb+:#{encoding}") do |f|
              options = { :col_sep => col_sep }
              content = CSV.generate(**options) do |csv|

                _compute_rows.each { |row|
                  csv << row
                }

              end

              # Write file
              f.write(bom)
              f.write(content)

              # Populate response
              response[:export_path] = path.tr("\\", '/')  # Standardize path by replacing \ by /

            end

          rescue => e
            puts e.message
            puts e.backtrace
            response[:errors] << [ 'core.error.failed_export_to', { path => path, :error => e.message } ]
          end

        end

      else
        response[:errors] << [ 'Unknow target' ]
      end
      response
    end

    # -----

    def _compute_rows

      # Generate rows
      rows = []
      case @source

      when EXPORT_OPTION_SOURCE_SUMMARY

        # Header row
        rows << _evaluate_header unless @no_header

        @cutlist.groups.each { |group|
          next if @hidden_group_ids.include?(group.id)

          data = SummaryExportRowData.new(
            MaterialTypeWrapper.new(group.material_type),
            StringWrapper.new(group.material_name ? group.material_name : Plugin.instance.get_i18n_string('tab.cutlist.material_undefined')),
            StringWrapper.new(group.std_dimension),
            StringWrapper.new(group.material_description),
            StringWrapper.new(group.material_url),
            IntegerWrapper.new(group.part_count),
            LengthWrapper.new(group.def.total_cutting_length, false),
            AreaWrapper.new(group.def.total_cutting_area),
            VolumeWrapper.new(group.def.total_cutting_volume),
            AreaWrapper.new((group.total_final_area.nil? || group.invalid_final_area_part_count > 0) ? 0 : group.def.total_final_area)
          )

          rows << _evaluate_row(data)
        }

      when EXPORT_OPTION_SOURCE_CUTLIST

        # Header row
        rows << _evaluate_header unless @no_header

        # Content rows
        @cutlist.groups.each { |group|
          next if @hidden_group_ids.include?(group.id)
          group.parts.each { |part|

            data = CutlistExportRowData.new(
              StringWrapper.new(part.number),
              StringWrapper.new(part.name),
              IntegerWrapper.new(part.count),
              LengthWrapper.new(part.def.cutting_length),
              LengthWrapper.new(part.def.cutting_width),
              LengthWrapper.new(part.def.cutting_size.thickness),
              LengthWrapper.new(part.def.edge_cutting_length),
              LengthWrapper.new(part.def.edge_cutting_width),
              LengthWrapper.new(part.def.size.length),
              LengthWrapper.new(part.def.size.width),
              LengthWrapper.new(part.def.size.thickness),
              AreaWrapper.new(part.def.final_area),
              MaterialTypeWrapper.new(group.material_type),
              StringWrapper.new(group.material_display_name),
              StringWrapper.new(group.material_description),
              StringWrapper.new(group.material_url),
              ArrayWrapper.new(part.entity_names.map(&:first)),
              StringWrapper.new(part.description),
              StringWrapper.new(part.url),
              ArrayWrapper.new(part.tags),
              EdgeWrapper.new(
                part.edge_material_names[:ymin],
                part.edge_material_colors[:ymin],
                part.def.edge_group_defs[:ymin] ? part.def.edge_group_defs[:ymin].std_thickness : nil,
                part.def.edge_group_defs[:ymin] ? part.def.edge_group_defs[:ymin].std_width : nil
              ),
              EdgeWrapper.new(
                part.edge_material_names[:ymax],
                part.edge_material_colors[:ymax],
                part.def.edge_group_defs[:ymax] ? part.def.edge_group_defs[:ymax].std_thickness : nil,
                part.def.edge_group_defs[:ymax] ? part.def.edge_group_defs[:ymax].std_width : nil
              ),
              EdgeWrapper.new(
                part.edge_material_names[:xmin],
                part.edge_material_colors[:xmin],
                part.def.edge_group_defs[:xmin] ? part.def.edge_group_defs[:xmin].std_thickness : nil,
                part.def.edge_group_defs[:xmin] ? part.def.edge_group_defs[:xmin].std_width : nil
              ),
              EdgeWrapper.new(
                part.edge_material_names[:xmax],
                part.edge_material_colors[:xmax],
                part.def.edge_group_defs[:xmax] ? part.def.edge_group_defs[:xmax].std_thickness : nil,
                part.def.edge_group_defs[:xmax] ? part.def.edge_group_defs[:xmax].std_width : nil
              ),
              VeneerWrapper.new(
                part.face_material_names[:zmin],
                part.face_material_colors[:zmin],
                part.def.veneer_group_defs[:zmin] ? part.def.veneer_group_defs[:zmin].std_thickness : nil
              ),
              VeneerWrapper.new(
                part.face_material_names[:zmax],
                part.face_material_colors[:zmax],
                part.def.veneer_group_defs[:zmax] ? part.def.veneer_group_defs[:zmax].std_thickness : nil
              ),
              ArrayWrapper.new(part.def.instance_infos.values.map { |instance_info| instance_info.layer.name }.uniq),
            )

            rows << _evaluate_row(data)
          }
        }

      when EXPORT_OPTION_SOURCE_INSTANCES_LIST

        # Header row
        rows << _evaluate_header unless @no_header

        # Content rows
        @cutlist.groups.each { |group|
          next if @hidden_group_ids.include?(group.id)
          next if group.material_type == MaterialAttributes::TYPE_EDGE      # Edges don't have instances
          next if group.material_type == MaterialAttributes::TYPE_VENEER    # Veneers don't have instances
          group.parts.each { |part|

            parts = part.is_a?(FolderPart) ? part.children : [ part ]
            parts.each { |part|

              # Ungroup parts
              part.def.instance_infos.each { |serialized_path, instance_info|

                data = InstancesListExportRowData.new(
                  StringWrapper.new(part.number),
                  PathWrapper.new(PathUtils.get_named_path(instance_info.path, false, 1)),
                  StringWrapper.new(instance_info.entity.name.empty? ? "##{instance_info.entity.entityID}" : instance_info.entity.name),
                  StringWrapper.new(part.name),
                  LengthWrapper.new(part.def.cutting_length),
                  LengthWrapper.new(part.def.cutting_width),
                  LengthWrapper.new(part.def.cutting_size.thickness),
                  LengthWrapper.new(part.def.edge_cutting_length),
                  LengthWrapper.new(part.def.edge_cutting_width),
                  LengthWrapper.new(part.def.size.length),
                  LengthWrapper.new(part.def.size.width),
                  LengthWrapper.new(part.def.size.thickness),
                  AreaWrapper.new(part.def.final_area),
                  MaterialTypeWrapper.new(group.material_type),
                  StringWrapper.new(group.material_display_name),
                  StringWrapper.new(group.material_description),
                  StringWrapper.new(group.material_url),
                  StringWrapper.new(part.description),
                  StringWrapper.new(part.url),
                  ArrayWrapper.new(part.tags),
                  EdgeWrapper.new(
                    part.edge_material_names[:ymin],
                    part.edge_material_colors[:ymin],
                    part.def.edge_group_defs[:ymin] ? part.def.edge_group_defs[:ymin].std_thickness : nil,
                    part.def.edge_group_defs[:ymin] ? part.def.edge_group_defs[:ymin].std_width : nil
                  ),
                  EdgeWrapper.new(
                    part.edge_material_names[:ymax],
                    part.edge_material_colors[:ymax],
                    part.def.edge_group_defs[:ymax] ? part.def.edge_group_defs[:ymax].std_thickness : nil,
                    part.def.edge_group_defs[:ymax] ? part.def.edge_group_defs[:ymax].std_width : nil
                  ),
                  EdgeWrapper.new(
                    part.edge_material_names[:xmin],
                    part.edge_material_colors[:xmin],
                    part.def.edge_group_defs[:xmin] ? part.def.edge_group_defs[:xmin].std_thickness : nil,
                    part.def.edge_group_defs[:xmin] ? part.def.edge_group_defs[:xmin].std_width : nil
                  ),
                  EdgeWrapper.new(
                    part.edge_material_names[:xmax],
                    part.edge_material_colors[:xmax],
                    part.def.edge_group_defs[:xmax] ? part.def.edge_group_defs[:xmax].std_thickness : nil,
                    part.def.edge_group_defs[:xmax] ? part.def.edge_group_defs[:xmax].std_width : nil
                  ),
                  VeneerWrapper.new(
                    part.face_material_names[:zmin],
                    part.face_material_colors[:zmin],
                    part.def.veneer_group_defs[:zmin] ? part.def.veneer_group_defs[:zmin].std_thickness : nil
                  ),
                  VeneerWrapper.new(
                    part.face_material_names[:zmax],
                    part.face_material_colors[:zmax],
                    part.def.veneer_group_defs[:zmax] ? part.def.veneer_group_defs[:zmax].std_thickness : nil
                  ),
                  StringWrapper.new(instance_info.layer.name),
                )

                rows << _evaluate_row(data)
              }

            }

          }
        }

      end

      rows
    end

    def _evaluate_header
      header = []
      @col_defs.each { |col_def|
        unless col_def['hidden']
          if col_def['title'].is_a?(String) && !col_def['title'].empty?
            header.push(col_def['title'])
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
            formula = col_def['name'].nil? || col_def['name'].empty? ? '' : '@' + col_def['name']
          else
            formula = col_def['formula']
          end
          begin
            value = eval(formula, data.get_binding)
            value = value.export if value.is_a?(Wrapper)
          rescue Exception => e
            value = { :error => e.message.split(/cutlist_export_worker[.]rb:\d+:/).last } # Remove path in exception message
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
      material_name,
      material_std_dimension,
      material_description,
      material_url,
      part_count,
      total_cutting_length,
      total_cutting_area,
      total_cutting_volume,
      total_final_area
    )
      @material_type = material_type
      @material_name = material_name
      @material_std_dimension = material_std_dimension
      @material_description = material_description
      @material_url = material_url
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
      edge_cutting_length,
      edge_cutting_width,
      bbox_length,
      bbox_width,
      bbox_thickness,
      final_area,
      material_type,
      material_name,
      material_description,
      material_url,
      entity_names,
      description,
      url,
      tags,
      edge_ymin,
      edge_ymax,
      edge_xmin,
      edge_xmax,
      face_zmin,
      face_zmax,
      layers
    )
      @number = number
      @name = name
      @count = count
      @cutting_length = cutting_length
      @cutting_width = cutting_width
      @cutting_thickness = cutting_thickness
      @edge_cutting_length = edge_cutting_length
      @edge_cutting_width = edge_cutting_width
      @bbox_length = bbox_length
      @bbox_width = bbox_width
      @bbox_thickness = bbox_thickness
      @final_area = final_area
      @material_type = material_type
      @material_name = material_name
      @material_description = material_description
      @material_url = material_url
      @entity_names = entity_names
      @description = description
      @url = url
      @tags = tags
      @edge_ymin = edge_ymin
      @edge_ymax = edge_ymax
      @edge_xmin = edge_xmin
      @edge_xmax = edge_xmax
      @face_zmin = face_zmin
      @face_zmax = face_zmax
      @layers = layers
    end

  end

  class InstancesListExportRowData < ExportRowData

    def initialize(
      number,
      path,
      instance_name,
      name,
      cutting_length,
      cutting_width,
      cutting_thickness,
      edge_cutting_length,
      edge_cutting_width,
      bbox_length,
      bbox_width,
      bbox_thickness,
      final_area,
      material_type,
      material_name,
      material_description,
      material_url,
      description,
      url,
      tags,
      edge_ymin,
      edge_ymax,
      edge_xmin,
      edge_xmax,
      face_zmin,
      face_zmax,
      layer
    )
      @number = number
      @path = path
      @instance_name = instance_name
      @name = name
      @cutting_length = cutting_length
      @cutting_width = cutting_width
      @cutting_thickness = cutting_thickness
      @edge_cutting_length = edge_cutting_length
      @edge_cutting_width = edge_cutting_width
      @bbox_length = bbox_length
      @bbox_width = bbox_width
      @bbox_thickness = bbox_thickness
      @final_area = final_area
      @material_type = material_type
      @material_name = material_name
      @material_description = material_description
      @material_url = material_url
      @description = description
      @url = url
      @tags = tags
      @edge_ymin = edge_ymin
      @edge_ymax = edge_ymax
      @edge_xmin = edge_xmin
      @edge_xmax = edge_xmax
      @face_zmin = face_zmin
      @face_zmax = face_zmax
      @layer = layer
    end

  end

end
