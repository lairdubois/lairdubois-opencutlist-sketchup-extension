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

    EXPORT_OPTION_TARGET_TABLE = 'table'.freeze
    EXPORT_OPTION_TARGET_PASTABLE = 'pasteable'.freeze
    EXPORT_OPTION_TARGET_CSV = 'csv'.freeze

    def initialize(cutlist,

                   source: EXPORT_OPTION_SOURCE_CUTLIST,
                   col_sep: EXPORT_OPTION_COL_SEP_SEMICOLON,
                   encoding: EXPORT_OPTION_ENCODING_UTF8,

                   col_defs: {},
                   target: EXPORT_OPTION_TARGET_CSV,
                   no_header: false,

                   hidden_group_ids: []

    )

      @cutlist = cutlist

      @source = source
      @col_sep = col_sep
      @encoding = encoding
      @col_defs = col_defs
      @target = target
      @no_header = no_header

      @hidden_group_ids = hidden_group_ids

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
        path = UI.savepanel(PLUGIN.get_i18n_string('tab.cutlist.export.title'), @cutlist.dir, File.basename(@cutlist.filename, '.skp') + '.csv')
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

            material: MaterialWrapper.new(group.def.material, group.def),
            part_count: IntegerWrapper.new(group.part_count),
            total_cutting_length: LengthWrapper.new(group.def.total_cutting_length, false),
            total_cutting_area: AreaWrapper.new(group.def.total_cutting_area),
            total_cutting_volume: VolumeWrapper.new(group.def.total_cutting_volume),
            total_final_area: AreaWrapper.new((group.total_final_area.nil? || group.invalid_final_area_part_count > 0) ? 0 : group.def.total_final_area)

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

              number: StringWrapper.new(part.number),
              name: StringWrapper.new(part.name),
              count: IntegerWrapper.new(part.count),
              cutting_length: LengthWrapper.new(part.def.cutting_length),
              cutting_width: LengthWrapper.new(part.def.cutting_width),
              cutting_thickness: LengthWrapper.new(part.def.cutting_size.thickness),
              edge_cutting_length: LengthWrapper.new(part.def.edge_cutting_length),
              edge_cutting_width: LengthWrapper.new(part.def.edge_cutting_width),
              bbox_length: LengthWrapper.new(part.def.size.length),
              bbox_width: LengthWrapper.new(part.def.size.width),
              bbox_thickness: LengthWrapper.new(part.def.size.thickness),
              final_area: AreaWrapper.new(part.def.final_area),
              material: MaterialWrapper.new(group.def.material, group.def),
              entity_names: ArrayWrapper.new(part.entity_names.map(&:first)),
              description: StringWrapper.new(part.description),
              url: StringWrapper.new(part.url),
              tags: ArrayWrapper.new(part.tags),
              edge_ymin: EdgeWrapper.new(
                part.def.edge_materials[:ymin],
                part.def.edge_group_defs[:ymin]
              ),
              edge_ymax: EdgeWrapper.new(
                part.def.edge_materials[:ymax],
                part.def.edge_group_defs[:ymax]
              ),
              edge_xmin: EdgeWrapper.new(
                part.def.edge_materials[:xmin],
                part.def.edge_group_defs[:xmin]
              ),
              edge_xmax: EdgeWrapper.new(
                part.def.edge_materials[:xmax],
                part.def.edge_group_defs[:xmax]
              ),
              face_zmin: VeneerWrapper.new(
                part.def.veneer_materials[:zmin],
                part.def.veneer_group_defs[:zmin]
              ),
              face_zmax: VeneerWrapper.new(
                part.def.veneer_materials[:zmax],
                part.def.veneer_group_defs[:zmax]
              ),
              layers: ArrayWrapper.new(part.def.instance_infos.values.map { |instance_info| instance_info.layer.name }.uniq),

              component_definition: ComponentDefinitionWrapper.new(part.def.definition),

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

                  number: StringWrapper.new(part.number),
                  path: PathWrapper.new(PathUtils.get_named_path(instance_info.path, false, 1)),
                  instance_name: StringWrapper.new(instance_info.entity.name.empty? ? "##{instance_info.entity.entityID}" : instance_info.entity.name),
                  name: StringWrapper.new(part.name),
                  cutting_length: LengthWrapper.new(part.def.cutting_length),
                  cutting_width: LengthWrapper.new(part.def.cutting_width),
                  cutting_thickness: LengthWrapper.new(part.def.cutting_size.thickness),
                  edge_cutting_length: LengthWrapper.new(part.def.edge_cutting_length),
                  edge_cutting_width: LengthWrapper.new(part.def.edge_cutting_width),
                  bbox_length: LengthWrapper.new(part.def.size.length),
                  bbox_width: LengthWrapper.new(part.def.size.width),
                  bbox_thickness: LengthWrapper.new(part.def.size.thickness),
                  final_area: AreaWrapper.new(part.def.final_area),
                  material: MaterialWrapper.new(group.def.material, group.def),
                  description: StringWrapper.new(part.description),
                  url: StringWrapper.new(part.url),
                  tags: ArrayWrapper.new(part.tags),
                  edge_ymin: EdgeWrapper.new(
                    part.def.edge_materials[:ymin],
                    part.def.edge_group_defs[:ymin]
                  ),
                  edge_ymax: EdgeWrapper.new(
                    part.def.edge_materials[:ymax],
                    part.def.edge_group_defs[:ymax]
                  ),
                  edge_xmin: EdgeWrapper.new(
                    part.def.edge_materials[:xmin],
                    part.def.edge_group_defs[:xmin]
                  ),
                  edge_xmax: EdgeWrapper.new(
                    part.def.edge_materials[:xmax],
                    part.def.edge_group_defs[:xmax]
                  ),
                  face_zmin: VeneerWrapper.new(
                    part.def.veneer_materials[:zmin],
                    part.def.veneer_group_defs[:zmin]
                  ),
                  face_zmax: VeneerWrapper.new(
                    part.def.veneer_materials[:zmax],
                    part.def.veneer_group_defs[:zmax]
                  ),
                  layer: StringWrapper.new(instance_info.layer.name),

                  component_definition: ComponentDefinitionWrapper.new(instance_info.definition),
                  component_instance: ComponentInstanceWrapper.new(instance_info.entity),

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
            header.push(PLUGIN.get_i18n_string("tab.cutlist.export.#{col_def['name']}"))
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

      material:,
      part_count:,
      total_cutting_length:,
      total_cutting_area:,
      total_cutting_volume:,
      total_final_area:

    )
      @material = material
      @material_type = material.type
      @material_name = material.name
      @material_description = material.description
      @material_url = material.url
      @material_std_dimension = material.std_dimension
      @part_count = part_count
      @total_cutting_length = total_cutting_length
      @total_cutting_area = total_cutting_area
      @total_cutting_volume = total_cutting_volume
      @total_final_area = total_final_area
    end

  end

  class CutlistExportRowData < ExportRowData

    def initialize(

      number:,
      name:,
      count:,
      cutting_length:,
      cutting_width:,
      cutting_thickness:,
      edge_cutting_length:,
      edge_cutting_width:,
      bbox_length:,
      bbox_width:,
      bbox_thickness:,
      final_area:,
      material:,
      entity_names:,
      description:,
      url:,
      tags:,
      edge_ymin:,
      edge_ymax:,
      edge_xmin:,
      edge_xmax:,
      face_zmin:,
      face_zmax:,
      layers:,

      component_definition:

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
      @material = material
      @material_type = material.type
      @material_name = material.name
      @material_description = material.description
      @material_url = material.url
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
      @component_definition = component_definition
    end

  end

  class InstancesListExportRowData < ExportRowData

    def initialize(

      number:,
      path:,
      instance_name:,
      name:,
      cutting_length:,
      cutting_width:,
      cutting_thickness:,
      edge_cutting_length:,
      edge_cutting_width:,
      bbox_length:,
      bbox_width:,
      bbox_thickness:,
      final_area:,
      material:,
      description:,
      url:,
      tags:,
      edge_ymin:,
      edge_ymax:,
      edge_xmin:,
      edge_xmax:,
      face_zmin:,
      face_zmax:,
      layer:,

      component_definition:,
      component_instance:

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
      @material = material
      @material_type = material.type
      @material_name = material.name
      @material_description = material.description
      @material_url = material.url
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
      @component_instance = component_instance
      @component_definition = component_definition
    end

  end

end
