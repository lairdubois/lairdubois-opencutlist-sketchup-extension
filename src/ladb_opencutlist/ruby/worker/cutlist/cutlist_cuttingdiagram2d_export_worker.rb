module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/svg_writer_helper'

  class CutlistCuttingdiagram2dExportWorker

    include SanitizerHelper
    include DxfWriterHelper
    include SvgWriterHelper

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_DXF, FILE_FORMAT_SVG ]

    def initialize(settings, cutlist, cuttingdiagram2d)

      @file_format = settings.fetch('file_format', nil)
      @sheet_hidden = settings.fetch('sheet_hidden', false)
      @sheet_stroke_color = settings.fetch('sheet_stroke_color', nil)
      @sheet_fill_color = settings.fetch('sheet_fill_color', nil)
      @parts_hidden = settings.fetch('parts_hidden', false)
      @parts_stroke_color = settings.fetch('parts_stroke_color', nil)
      @parts_fill_color = settings.fetch('parts_fill_color', nil)
      @leftovers_hidden = settings.fetch('leftovers_hidden', true)
      @leftovers_stroke_color = settings.fetch('leftovers_stroke_color', nil)
      @leftovers_fill_color = settings.fetch('leftovers_fill_color', nil)
      @cuts_hidden = settings.fetch('cuts_hidden', true)
      @cuts_stroke_color = settings.fetch('cuts_stroke_color', nil)
      @hidden_sheet_indices = settings.fetch('hidden_sheet_indices', [])
      @use_names = settings.fetch('use_names', false)

      @cutlist = cutlist
      @cuttingdiagram2d = cuttingdiagram2d

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?
      return { :errors => [ 'default.error' ] } unless @cuttingdiagram2d && @cuttingdiagram2d.def.group
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)

      # Ask for output dir
      dir = UI.select_directory(title: Plugin.instance.get_i18n_string('tab.cutlist.cuttingdiagram.export.title'), directory: @cutlist.dir)
      if dir

        group = @cuttingdiagram2d.def.group
        folder = _sanitize_filename("#{group.material_display_name} - #{group.std_dimension}")
        export_path = File.join(dir, folder)

        if File.exists?(export_path)
          if UI.messagebox(Plugin.instance.get_i18n_string('core.messagebox.dir_override', { :target => folder, :parent => File.basename(dir) }), MB_YESNO) == IDYES
            FileUtils.remove_dir(export_path, true)
          else
            return { :cancelled => true }
          end
        end
        Dir.mkdir(export_path)

        sheet_index = 1
        @cuttingdiagram2d.sheets.each do |sheet|
          next if @hidden_sheet_indices.include?(sheet_index)
          _write_sheet(export_path, sheet, sheet_index)
          sheet_index += sheet.count
        end

        return {
          :export_path => export_path
        }
      end

      {
        :cancelled => true
      }
    end

    # -----

    private

    def _write_sheet(export_path, sheet, sheet_index)

      # Open output file
      file = File.new(File.join(export_path, "sheet_#{sheet_index.to_s.rjust(3, '0')}#{sheet.count > 1 ? "_to_#{(sheet_index + sheet.count - 1).to_s.rjust(3, '0')}" : ''}.#{@file_format}") , 'w')

      case @file_format
      when FILE_FORMAT_DXF

        unit_converter = DimensionUtils.instance.length_to_model_unit_float(1.0.to_l)

        _dxf_write_header(file)
        _dxf_write_tables(file)

        _dxf_write(file, 0, 'SECTION')
        _dxf_write(file, 2, 'ENTITIES')

        sheet_width = _convert(_to_inch(sheet.px_length), unit_converter)
        sheet_height = _convert(_to_inch(sheet.px_width), unit_converter)

        unless @sheet_hidden
          _dxf_write_rect(file, 0, 0, sheet_width, sheet_height, 'OCL_SHEET', 4)
        end

        unless @parts_hidden
          sheet.parts.each do |part|

            part_x = _convert(_to_inch(part.px_x), unit_converter)
            part_y = _convert(_to_inch(sheet.px_width - part.px_y - part.px_width), unit_converter)
            part_width = _convert(_to_inch(part.px_length), unit_converter)
            part_height = _convert(_to_inch(part.px_width), unit_converter)

            _dxf_write_rect(file, part_x, part_y, part_width, part_height, 'OCL_PARTS')

          end
        end

        unless @leftovers_hidden
          sheet.leftovers.each do |leftover|

            leftover_x = _convert(_to_inch(leftover.px_x), unit_converter)
            leftover_y = _convert(_to_inch(sheet.px_width - leftover.px_y - leftover.px_width), unit_converter)
            leftover_width = _convert(_to_inch(leftover.px_length), unit_converter)
            leftover_height = _convert(_to_inch(leftover.px_width), unit_converter)

            _dxf_write_rect(file, leftover_x, leftover_y, leftover_width, leftover_height, 'OCL_LEFTOVERS', 8)

          end
        end

        unless @cuts_hidden
          sheet.cuts.each do |cut|

            cut_x1 = _convert(_to_inch(cut.px_x), unit_converter)
            cut_y1 = _convert(_to_inch(sheet.px_width - cut.px_y), unit_converter)
            cut_x2 = _convert(_to_inch(cut.px_x + (cut.is_horizontal ? cut.px_length : 0)), unit_converter)
            cut_y2 = _convert(_to_inch(sheet.px_width - cut.px_y - (!cut.is_horizontal ? cut.px_length : 0)), unit_converter)

            _dxf_write_line(file, cut_x1, cut_y1, cut_x2, cut_y2, 'OCL_CUTS', 6)

          end
        end

        _dxf_write(file, 0, 'ENDSEC')
        _dxf_write(file, 0, 'EOF')

      when FILE_FORMAT_SVG

        # Tweak unit converter to restrict to SVG compatible units (in, mm, cm)
        case DimensionUtils.instance.length_unit
        when DimensionUtils::INCHES
          unit_converter = 1.0
          unit_sign = 'in'
        when DimensionUtils::CENTIMETER
          unit_converter = 1.0.to_cm
          unit_sign = 'cm'
        else
          unit_converter = 1.0.to_mm
          unit_sign = 'mm'
        end

        sheet_width = _convert(_to_inch(sheet.px_length), unit_converter)
        sheet_height = _convert(_to_inch(sheet.px_width), unit_converter)

        _svg_write_start(file, 0, 0, sheet_width, sheet_height, unit_sign)

        unless @sheet_hidden
          _svg_write_group_start(file, id: 'sheet')
          _svg_write_rect(file, 0, 0, sheet_width, sheet_height, @sheet_stroke_color, @sheet_fill_color)
          _svg_write_group_end(file)
        end

        unless @parts_hidden
          _svg_write_group_start(file, id: 'parts')
          sheet.parts.each do |part|

            part_x = _convert(_to_inch(part.px_x), unit_converter)
            part_y = _convert(_to_inch(part.px_y), unit_converter)
            part_width = _convert(_to_inch(part.px_length), unit_converter)
            part_height = _convert(_to_inch(part.px_width), unit_converter)

            _svg_write_rect(file, part_x, part_y, part_width, part_height, @parts_stroke_color, @parts_fill_color, id: (@use_names ? part.name : part.number))

          end
          _svg_write_group_end(file)
        end

        unless @leftovers_hidden
          _svg_write_group_start(file, id: 'leftovers')
          sheet.leftovers.each do |leftover|

            leftover_x = _convert(_to_inch(leftover.px_x), unit_converter)
            leftover_y = _convert(_to_inch(leftover.px_y), unit_converter)
            leftover_width = _convert(_to_inch(leftover.px_length), unit_converter)
            leftover_height = _convert(_to_inch(leftover.px_width), unit_converter)

            _svg_write_rect(file, leftover_x, leftover_y, leftover_width, leftover_height, @leftovers_stroke_color, @leftovers_fill_color)

          end
          _svg_write_group_end(file)
        end

        unless @cuts_hidden
          _svg_write_group_start(file, id: 'cuts')
          sheet.cuts.each do |cut|

            cut_x1 = _convert(_to_inch(cut.px_x), unit_converter)
            cut_y1 = _convert(_to_inch(cut.px_y), unit_converter)
            cut_x2 = _convert(_to_inch(cut.px_x + (cut.is_horizontal ? cut.px_length : 0)), unit_converter)
            cut_y2 = _convert(_to_inch(cut.px_y + (!cut.is_horizontal ? cut.px_length : 0)), unit_converter)

            _svg_write_line(file, cut_x1, cut_y1, cut_x2, cut_y2, @cuts_stroke_color)

          end
          _svg_write_group_end(file)
        end

        _svg_write_end(file)

      end

      # Close output file
      file.close

    end

    def _convert(value, unit_converter, precision = 6)
      (value.to_f * unit_converter).round(precision)
    end

    # Convert pixel float value to inch
    def _to_inch(pixel_value)
      pixel_value / 7 # 840px = 120" ~ 3m
    end

  end

end
