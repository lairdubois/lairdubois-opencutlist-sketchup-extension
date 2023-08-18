module Ladb::OpenCutList

  class CutlistCuttingdiagram2dExportWorker

    FILE_FORMAT_DXF = 'dxf'.freeze
    FILE_FORMAT_SVG = 'svg'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_DXF, FILE_FORMAT_SVG ]

    def initialize(settings, cutlist, cuttingdiagram2d)

      @file_format = settings.fetch('file_format', nil)
      @hide_sheet = settings.fetch('hide_sheet', false)
      @hide_parts = settings.fetch('hide_parts', false)
      @hide_leftovers = settings.fetch('hide_leftovers', true)
      @hide_cuts = settings.fetch('hide_cuts', true)

      @cutlist = cutlist
      @cuttingdiagram2d = cuttingdiagram2d

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?
      return { :errors => [ 'default.error' ] } unless @cuttingdiagram2d
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)

      # Ask for output dir
      dir = UI.select_directory(title: Plugin.instance.get_i18n_string('tab.cutlist.cuttingdiagram.export.title'), directory: @cutlist.dir)
      if dir

        sheet_index = 1
        @cuttingdiagram2d.sheets.each do |sheet|
          _write_sheet(dir, sheet, sheet_index)
          sheet_index += sheet.count
        end

        return {
          :export_path => dir
        }
      end

      {
        :cancelled => true
      }
    end

    # -----

    private

    def _write_sheet(dir, sheet, sheet_index)

      # Open output file
      file = File.new(File.join(dir, "sheet_#{sheet_index}#{sheet.count > 1 ? "_to_#{sheet.count}" : ''}.#{@file_format}") , 'w')

      case @file_format
      when FILE_FORMAT_DXF

        unit_converter = DimensionUtils.instance.length_to_model_unit_float(1.0.to_l)

        _dxf(file, 0, 'SECTION')
        _dxf(file, 2, 'ENTITIES')

        sheet_width = _convert(_to_inch(sheet.px_length), unit_converter)
        sheet_height = _convert(_to_inch(sheet.px_width), unit_converter)

        unless @hide_sheet
          _dxf_rect(file, 0, 0, sheet_width, sheet_height, 'sheet')
        end

        unless @hide_parts
          sheet.parts.each do |part|

            part_x = _convert(_to_inch(part.px_x), unit_converter)
            part_y = _convert(_to_inch(sheet.px_width - part.px_y - part.px_width), unit_converter)
            part_width = _convert(_to_inch(part.px_length), unit_converter)
            part_height = _convert(_to_inch(part.px_width), unit_converter)

            _dxf_rect(file, part_x, part_y, part_width, part_height, 'parts')

          end
        end

        unless @hide_leftovers
          sheet.leftovers.each do |leftover|

            leftover_x = _convert(_to_inch(leftover.px_x), unit_converter)
            leftover_y = _convert(_to_inch(sheet.px_width - leftover.px_y - leftover.px_width), unit_converter)
            leftover_width = _convert(_to_inch(leftover.px_length), unit_converter)
            leftover_height = _convert(_to_inch(leftover.px_width), unit_converter)

            _dxf_rect(file, leftover_x, leftover_y, leftover_width, leftover_height, 'leftovers')

          end
        end

        unless @hide_cuts
          sheet.cuts.each do |cut|

            cut_x1 = _convert(_to_inch(cut.px_x), unit_converter)
            cut_y1 = _convert(_to_inch(sheet.px_width - cut.px_y), unit_converter)
            cut_x2 = _convert(_to_inch(cut.px_x + (cut.is_horizontal ? cut.px_length : 0)), unit_converter)
            cut_y2 = _convert(_to_inch(sheet.px_width - cut.px_y - (!cut.is_horizontal ? cut.px_length : 0)), unit_converter)

            _dxf_line(file, cut_x1, cut_y1, cut_x2, cut_y2, 'cuts')

          end
        end

        _dxf(file, 0, 'ENDSEC')
        _dxf(file, 0, 'EOF')

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

        file.puts('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')
        file.puts('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">')
        file.puts("<svg width=\"#{sheet_width}#{unit_sign}\" height=\"#{sheet_height}#{unit_sign}\" viewBox=\"0 0 #{sheet_width} #{sheet_height}\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:shaper=\"http://www.shapertools.com/namespaces/shaper\">")

        unless @hide_sheet
          file.puts("<g id=\"sheet\">")
          file.puts("<rect x=\"0\" y=\"0\" width=\"#{sheet_width}\" height=\"#{sheet_height}\" fill=\"none\" stroke=\"#000000\" />")
          file.puts("</g>")
        end

        unless @hide_parts
          file.puts("<g id=\"parts\">")
          sheet.parts.each do |part|

            part_x = _convert(_to_inch(part.px_x), unit_converter)
            part_y = _convert(_to_inch(part.px_y), unit_converter)
            part_width = _convert(_to_inch(part.px_length), unit_converter)
            part_height = _convert(_to_inch(part.px_width), unit_converter)

            file.puts("<rect x=\"#{part_x}\" y=\"#{part_y}\" width=\"#{part_width}\" height=\"#{part_height}\" fill=\"none\" stroke=\"#000000\" />")

          end
          file.puts("</g>")
        end

        unless @hide_leftovers
          file.puts("<g id=\"leftovers\">")
          sheet.leftovers.each do |leftover|

            leftover_x = _convert(_to_inch(leftover.px_x), unit_converter)
            leftover_y = _convert(_to_inch(leftover.px_y), unit_converter)
            leftover_width = _convert(_to_inch(leftover.px_length), unit_converter)
            leftover_height = _convert(_to_inch(leftover.px_width), unit_converter)

            file.puts("<rect x=\"#{leftover_x}\" y=\"#{leftover_y}\" width=\"#{leftover_width}\" height=\"#{leftover_height}\" fill=\"none\" stroke=\"#000000\" />")

          end
          file.puts("</g>")
        end

        unless @hide_cuts
          file.puts("<g id=\"cuts\">")
          sheet.cuts.each do |cut|

            cut_x1 = _convert(_to_inch(cut.px_x), unit_converter)
            cut_y1 = _convert(_to_inch(cut.px_y), unit_converter)
            cut_x2 = _convert(_to_inch(cut.px_x + (cut.is_horizontal ? cut.px_length : 0)), unit_converter)
            cut_y2 = _convert(_to_inch(cut.px_y + (!cut.is_horizontal ? cut.px_length : 0)), unit_converter)

            file.puts("<line x1=\"#{cut_x1}\" y1=\"#{cut_y1}\" x2=\"#{cut_x2}\" y2=\"#{cut_y2}\" stroke=\"#000000\" />")

          end
          file.puts("</g>")
        end

        file.puts("</svg>")

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

    def _dxf(file, code, value)
      file.puts(code.to_s)
      file.puts(value.to_s)
    end

    def _dxf_rect(file, x, y, width, height, layer = 0)

      points = [
        Geom::Point3d.new(x, y, 0),
        Geom::Point3d.new(x + width, y, 0),
        Geom::Point3d.new(x + width, y + height, 0),
        Geom::Point3d.new(x, y + height, 0),
      ]

      _dxf(file, 0, 'LWPOLYLINE')
      _dxf(file, 8, layer)
      _dxf(file, 90, 4)
      _dxf(file, 70, 1) # 1 = This is a closed polyline (or a polygon mesh closed in the M direction)

      points.each do |point|
        _dxf(file, 10, point.x.to_f)
        _dxf(file, 20, point.y.to_f)
      end

      _dxf(file, 0, 'SEQEND')

    end

    def _dxf_line(file, x1, y1, x2, y2, layer = 0)

      _dxf(file, 0, 'LINE')
      _dxf(file, 8, layer)
      _dxf(file, 10, x1)
      _dxf(file, 20, y1)
      _dxf(file, 11, x2)
      _dxf(file, 21, y2)

    end

  end

end
