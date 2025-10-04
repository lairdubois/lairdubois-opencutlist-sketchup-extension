module Ladb::OpenCutList

  require 'csv'
  require_relative '../../model/attributes/material_attributes'
  require_relative '../../model/formula/formula_data'
  require_relative '../../worker/common/common_eval_formula_worker'
  require_relative '../../helper/sanitizer_helper'

  class CutlistExportWorker

    include SanitizerHelper

    EXPORT_OPTION_SOURCE_SUMMARY = 0
    EXPORT_OPTION_SOURCE_CUTLIST = 1
    EXPORT_OPTION_SOURCE_INSTANCES_LIST = 2

    EXPORT_OPTION_CSV_COL_SEP_TAB = 0
    EXPORT_OPTION_CSV_COL_SEP_COMMA = 1
    EXPORT_OPTION_CSV_COL_SEP_SEMICOLON = 2

    EXPORT_OPTION_CSV_ENCODING_UTF8 = 0
    EXPORT_OPTION_CSV_ENCODING_UTF16LE = 1
    EXPORT_OPTION_CSV_ENCODING_UTF16BE = 2

    EXPORT_OPTION_FORMAT_TABLE = 'table'.freeze
    EXPORT_OPTION_FORMAT_PASTABLE = 'pasteable'.freeze
    EXPORT_OPTION_FORMAT_CSV = 'csv'.freeze
    EXPORT_OPTION_FORMAT_XLSX = 'xlsx'.freeze

    FOLDING_CHECK_VARS = %w[component_definition component_instances description tags final_area layers]

    def initialize(cutlist,

                   part_ids: nil,

                   source: EXPORT_OPTION_SOURCE_CUTLIST,
                   format: EXPORT_OPTION_FORMAT_CSV,

                   csv_col_sep: EXPORT_OPTION_CSV_COL_SEP_SEMICOLON,
                   csv_encoding: EXPORT_OPTION_CSV_ENCODING_UTF8,

                   col_defs: {},
                   no_header: false,

                   part_folding: true

    )

      @cutlist = cutlist

      @part_ids = part_ids

      @source = source
      @format = format

      @csv_col_sep = csv_col_sep
      @csv_encoding = csv_encoding

      @col_defs = col_defs
      @no_header = no_header

      @part_folding = part_folding && source == EXPORT_OPTION_SOURCE_CUTLIST

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      parts = @cutlist.get_parts(@part_ids, real: !@part_folding)
      return { :errors => [ 'tab.cutlist.error.no_part' ] } if parts.empty?

      parts_by_group = parts.group_by { |part| part.group }
      
      response = {
          :errors => [],
          :export_path => ''
      }

      case @format
      when EXPORT_OPTION_FORMAT_TABLE

        response[:rows] = _compute_rows(parts_by_group)

      when EXPORT_OPTION_FORMAT_PASTABLE

        options = { :col_sep => "\t" }
        pasteable = CSV.generate(**options) do |csv|

          _compute_rows(parts_by_group).each { |row|
            csv << row
          }

        end
        response[:pasteable] = pasteable

      when EXPORT_OPTION_FORMAT_CSV

        # Ask for the export file path
        path = UI.savepanel(PLUGIN.get_i18n_string('tab.cutlist.export.title'), @cutlist.dir, _default_base_filename(parts_by_group) + '.csv')
        if path

          # Force "csv" file extension
          path = path + '.csv' unless path.end_with?('.csv')

          begin

            # Convert col_sep
            case @csv_col_sep
            when EXPORT_OPTION_CSV_COL_SEP_COMMA
              col_sep = ','
            when EXPORT_OPTION_CSV_COL_SEP_SEMICOLON
              col_sep = ';'
            else
              col_sep = "\t"
            end

            # Convert encoding
            case @csv_encoding
            when EXPORT_OPTION_CSV_ENCODING_UTF16LE
              bom = "\xFF\xFE".force_encoding('utf-16le')
              encoding = 'UTF-16LE'
            when EXPORT_OPTION_CSV_ENCODING_UTF16BE
              bom = "\xFE\xFF".force_encoding('utf-16be')
              encoding = 'UTF-16BE'
            else
              bom = "\xEF\xBB\xBF"
              encoding = 'UTF-8'
            end

            # Write the CSV file
            File.open(path, "wb+:#{encoding}") do |f|
              options = { :col_sep => col_sep }
              content = CSV.generate(**options) do |csv|

                _compute_rows(parts_by_group).each { |row|
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

      when EXPORT_OPTION_FORMAT_XLSX

        return { :errors => [ [ 'core.error.feature_unavailable', { :version => 2019 } ] ] } if Sketchup.version_number < 1900000000

        # Ask for the export file path
        path = UI.savepanel(PLUGIN.get_i18n_string('tab.cutlist.export.title'), @cutlist.dir, _default_base_filename(parts_by_group) + '.xlsx')
        if path

          # Force "xlsx" file extension
          path = path + '.xlsx' unless path.end_with?('.xlsx')

          begin

            require_relative '../../lib/write_xlsx/write_xlsx'

            # Create a new Excel workbook
            workbook = WriteXLSX.new(path)

            # Add a worksheet
            worksheet = workbook.add_worksheet

            # Define formats
            formats = {
              'left' => workbook.add_format(:align => 'left'),
              'center' => workbook.add_format(:align => 'center'),
              'right' => workbook.add_format(:align => 'right'),
            }

            # Iterate on rows to add cells
            _compute_rows(parts_by_group).each_with_index { |row, row_index|
              row.each_with_index { |cell, col_index|
                unless cell.is_a?(String) && cell.empty?
                  col_def = @col_defs[col_index]
                  format = formats[col_def['align']] if col_def && col_def['align']
                  worksheet.write(row_index, col_index, cell, format)
                end
              }
            }

            # Write xlsx file to disk.
            workbook.close

            # Populate response
            response[:export_path] = path.tr("\\", '/')  # Standardize path by replacing \ by /

           rescue => e
            puts e.message
            puts e.backtrace
            response[:errors] << [ 'core.error.failed_export_to', { path => path, :error => e.message } ]
          end

        end

      else
        response[:errors] << [ 'Unknow format' ]
      end
      response
    end

    # -----

    def _default_base_filename(parts_by_group)
      filename = File.basename(@cutlist.filename, '.skp')
      if parts_by_group.keys.one?
        group = parts_by_group.keys.first
        group_name = group.material_display_name
        group_name = PLUGIN.get_i18n_string('tab.cutlist.material_undefined') if group_name.nil? || group_name.empty?
        group_name += " - #{group.std_dimension}" unless group.std_dimension.empty?
        filename += " - #{group_name}"
      end
      _sanitize_filename(filename)
    end

    def _compute_rows(parts_by_group)

      # Generate rows
      rows = []
      case @source

      when EXPORT_OPTION_SOURCE_SUMMARY

        # Header row
        rows << _evaluate_header unless @no_header

        parts_by_group.each do |group, parts|

          data = ExportSummaryRowFormulaData.new(

            material: MaterialFormulaWrapper.new(group.def.material, group.def),
            part_count: IntegerFormulaWrapper.new(group.part_count),
            total_cutting_length: LengthFormulaWrapper.new(group.def.total_cutting_length, false),
            total_cutting_area: AreaFormulaWrapper.new(group.def.total_cutting_area),
            total_cutting_volume: VolumeFormulaWrapper.new(group.def.total_cutting_volume),
            total_final_area: AreaFormulaWrapper.new((group.total_final_area.nil? || group.invalid_final_area_part_count > 0) ? 0 : group.def.total_final_area)

          )

          rows << _evaluate_row(data)
        end

      when EXPORT_OPTION_SOURCE_CUTLIST

        # Header row
        rows << _evaluate_header unless @no_header

        fn_compute_part_row = lambda do |group, part|

          data = ExportCutlistRowFormulaData.new(

            number: StringFormulaWrapper.new(part.number),
            name: StringFormulaWrapper.new(part.name),
            count: IntegerFormulaWrapper.new(part.count),
            cutting_length: LengthFormulaWrapper.new(part.def.cutting_length),
            cutting_width: LengthFormulaWrapper.new(part.def.cutting_width),
            cutting_thickness: LengthFormulaWrapper.new(part.def.cutting_size.thickness),
            edge_cutting_length: LengthFormulaWrapper.new(part.def.edge_cutting_length),
            edge_cutting_width: LengthFormulaWrapper.new(part.def.edge_cutting_width),
            bbox_length: LengthFormulaWrapper.new(part.def.size.length),
            bbox_width: LengthFormulaWrapper.new(part.def.size.width),
            bbox_thickness: LengthFormulaWrapper.new(part.def.size.thickness),
            final_area: AreaFormulaWrapper.new(part.def.final_area),
            material: MaterialFormulaWrapper.new(group.def.material, group.def),
            entity_names: ArrayFormulaWrapper.new(part.entity_names.map(&:first)),
            description: StringFormulaWrapper.new(part.description),
            url: StringFormulaWrapper.new(part.url),
            tags: ArrayFormulaWrapper.new(part.tags),
            edge_ymin: EdgeFormulaWrapper.new(
              part.def.edge_materials[:ymin],
              part.def.edge_group_defs[:ymin]
            ),
            edge_ymax: EdgeFormulaWrapper.new(
              part.def.edge_materials[:ymax],
              part.def.edge_group_defs[:ymax]
            ),
            edge_xmin: EdgeFormulaWrapper.new(
              part.def.edge_materials[:xmin],
              part.def.edge_group_defs[:xmin]
            ),
            edge_xmax: EdgeFormulaWrapper.new(
              part.def.edge_materials[:xmax],
              part.def.edge_group_defs[:xmax]
            ),
            face_zmin: VeneerFormulaWrapper.new(
              part.def.veneer_materials[:zmin],
              part.def.veneer_group_defs[:zmin]
            ),
            face_zmax: VeneerFormulaWrapper.new(
              part.def.veneer_materials[:zmax],
              part.def.veneer_group_defs[:zmax]
            ),
            layers: ArrayFormulaWrapper.new(part.def.instance_infos.values.map { |instance_info| instance_info.layer.name }.uniq),

            component_definition: ComponentDefinitionFormulaWrapper.new(part.def.definition),
            component_instances: ArrayFormulaWrapper.new(part.def.instance_infos.values.map { |instance_info| ComponentInstanceFormulaWrapper.new(instance_info.entity) })

          )

          _evaluate_row(data)
        end

        # Content rows
        parts_by_group.each do |group, parts|
          parts.each do |part|

            if part.is_a?(FolderPart) && @part_folding && _get_folding_check_col_indices.any?

              # Check if children rows are foldable on specific columns
              children_rows = part.children.map { |child| fn_compute_part_row.call(group, child) }
              if children_rows.map { |row| row.select.with_index { |col, index| _get_folding_check_col_indices.include?(index) } }.uniq.size > 1

                # Not foldable: append children rows
                rows.concat(children_rows)
                next

              end

            end

            rows << fn_compute_part_row.call(group, part)

          end
        end

      when EXPORT_OPTION_SOURCE_INSTANCES_LIST

        # Header row
        rows << _evaluate_header unless @no_header

        # Content rows
        parts_by_group.each do |group, parts|
          parts.each do |part|

            next if group.material_type == MaterialAttributes::TYPE_EDGE      # Edges don't have instances
            next if group.material_type == MaterialAttributes::TYPE_VENEER    # Veneers don't have instances

            # Ungroup parts
            part.def.instance_infos.each do |serialized_path, instance_info|

              data = ExportInstancesListRowFormulaData.new(

                number: StringFormulaWrapper.new(part.number),
                path: PathFormulaWrapper.new(instance_info.path[0...-1]),
                instance_name: StringFormulaWrapper.new(instance_info.entity.name),
                name: StringFormulaWrapper.new(part.name),
                cutting_length: LengthFormulaWrapper.new(part.def.cutting_length),
                cutting_width: LengthFormulaWrapper.new(part.def.cutting_width),
                cutting_thickness: LengthFormulaWrapper.new(part.def.cutting_size.thickness),
                edge_cutting_length: LengthFormulaWrapper.new(part.def.edge_cutting_length),
                edge_cutting_width: LengthFormulaWrapper.new(part.def.edge_cutting_width),
                bbox_length: LengthFormulaWrapper.new(part.def.size.length),
                bbox_width: LengthFormulaWrapper.new(part.def.size.width),
                bbox_thickness: LengthFormulaWrapper.new(part.def.size.thickness),
                final_area: AreaFormulaWrapper.new(part.def.final_area),
                material: MaterialFormulaWrapper.new(group.def.material, group.def),
                description: StringFormulaWrapper.new(part.description),
                url: StringFormulaWrapper.new(part.url),
                tags: ArrayFormulaWrapper.new(part.tags),
                edge_ymin: EdgeFormulaWrapper.new(
                  part.def.edge_materials[:ymin],
                  part.def.edge_group_defs[:ymin]
                ),
                edge_ymax: EdgeFormulaWrapper.new(
                  part.def.edge_materials[:ymax],
                  part.def.edge_group_defs[:ymax]
                ),
                edge_xmin: EdgeFormulaWrapper.new(
                  part.def.edge_materials[:xmin],
                  part.def.edge_group_defs[:xmin]
                ),
                edge_xmax: EdgeFormulaWrapper.new(
                  part.def.edge_materials[:xmax],
                  part.def.edge_group_defs[:xmax]
                ),
                face_zmin: VeneerFormulaWrapper.new(
                  part.def.veneer_materials[:zmin],
                  part.def.veneer_group_defs[:zmin]
                ),
                face_zmax: VeneerFormulaWrapper.new(
                  part.def.veneer_materials[:zmax],
                  part.def.veneer_group_defs[:zmax]
                ),
                layer: StringFormulaWrapper.new(instance_info.layer.name),

                component_definition: ComponentDefinitionFormulaWrapper.new(instance_info.definition),
                component_instance: ComponentInstanceFormulaWrapper.new(instance_info.entity),

              )

              rows << _evaluate_row(data)

            end

          end
        end

      end

      rows
    end

    def _evaluate_header
      header = []
      @col_defs.each do |col_def|
        unless col_def['hidden']
          if col_def['title'].is_a?(String) && !col_def['title'].empty?
            header.push(col_def['title'])
          elsif col_def['name'].is_a?(String) && !col_def['name'].empty?
            header.push(PLUGIN.get_i18n_string("tab.cutlist.export.#{col_def['name']}"))
          else
            header.push('')
          end
        end
      end
      header
    end

    def _evaluate_row(data)
      row = []
      @col_defs.each do |col_def|
        unless col_def['hidden']
          if col_def['formula'].nil? || col_def['formula'].empty?
            formula = col_def['name'].nil? || col_def['name'].empty? ? '' : '@' + col_def['name']
          else
            formula = col_def['formula']
          end
          row << CommonEvalFormulaWorker.new(formula: formula, data: data).run
        end
      end
      row
    end

    def _get_folding_check_col_indices
      @_folding_check_col_indices ||= if @part_folding
                                        @col_defs.map.with_index { |col_def, index| [ col_def, index ] }.select { |col_def, index|
                                          if col_def['hidden']
                                            false
                                          else
                                            if col_def['formula'].nil? || col_def['formula'].empty?
                                              next if col_def['name'].nil? || col_def['name'].empty?
                                              FOLDING_CHECK_VARS.any? { |v| col_def['name'] == v }
                                            else
                                              FOLDING_CHECK_VARS.any? { |v| col_def['formula'].include?("@#{v}") }
                                            end
                                          end
                                        }.map { |col_def, index| index }
                                      else
                                        []
                                      end
    end

  end

  class ExportSummaryRowFormulaData < FormulaData

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

  class ExportCutlistRowFormulaData < FormulaData

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

      component_definition:,
      component_instances:

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
      @component_instances = component_instances
    end

  end

  class ExportInstancesListRowFormulaData < FormulaData

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
