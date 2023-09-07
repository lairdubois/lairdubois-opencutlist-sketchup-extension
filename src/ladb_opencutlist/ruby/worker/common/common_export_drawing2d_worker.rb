module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/face_triangles_helper'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/svg_writer_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../utils/color_utils'
  require_relative '../../model/cutlist/drawing_def'

  class CommonExportDrawing2dWorker

    include FaceTrianglesHelper
    include DxfWriterHelper
    include SvgWriterHelper
    include SanitizerHelper

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_DXF, FILE_FORMAT_SVG ]

    def initialize(drawing_def, settings)

      @drawing_def = drawing_def

      @file_name = _sanitize_filename(settings.fetch('file_name', 'FACE'))
      @file_format = settings.fetch('file_format', nil)
      @unit = settings.fetch('unit', nil)
      @anchor = settings.fetch('anchor', false)
      @curves = settings.fetch('curves', false)
      @max_depth = settings.fetch('max_depth', 0)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export_to_3d.title', { :file_format => @file_format }), '', "#{@file_name}.#{@file_format}")
      if path

        # Force "file_format" file extension
        unless path.end_with?(".#{@file_format}")
          path = "#{path}.#{@file_format}"
        end

        begin

          case @unit
          when DimensionUtils::INCHES
            unit_converter = 1.0
          when DimensionUtils::FEET
            unit_converter = 1.0.to_l.to_feet
          when DimensionUtils::YARD
            unit_converter = 1.0.to_l.to_yard
          when DimensionUtils::MILLIMETER
            unit_converter = 1.0.to_l.to_mm
          when DimensionUtils::CENTIMETER
            unit_converter = 1.0.to_l.to_cm
          when DimensionUtils::METER
            unit_converter = 1.0.to_l.to_m
          else
            unit_converter = DimensionUtils.instance.length_to_model_unit_float(1.0.to_l)
          end

          success = _write_2d(path, @drawing_def.face_infos, @drawing_def.edge_infos, unit_converter) && File.exist?(path)

          return { :errors => [ [ 'tab.cutlist.error.failed_export_to_3d_file', { :file_format => @file_format, :error => e.message } ] ] } unless success
          return { :export_path => path }
        rescue => e
          puts e.inspect
          puts e.backtrace
          return { :errors => [ [ 'tab.cutlist.error.failed_export_to_3d_file', { :file_format => @file_format, :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

    private

    def _write_2d(path, face_infos, edge_infos, unit_converter)

      # Open output file
      file = File.new(path , 'w')

      case @file_format
      when FILE_FORMAT_DXF

        layer_defs = []
        layer_defs.push({ :name => 'OCL_DRAWING', :color => 7 }) unless face_infos.empty?
        layer_defs.push({ :name => 'OCL_GUIDE', :color => 150 }) unless edge_infos.empty?

        _dxf_write_header(file, _convert_point(@drawing_def.bounds.min, unit_converter), _convert_point(@drawing_def.bounds.max, unit_converter), layer_defs)

        _dxf_write(file, 0, 'SECTION')
        _dxf_write(file, 2, 'ENTITIES')

        face_infos.each do |face_info|

          face = face_info.face
          transformation = face_info.transformation

          face.loops.each do |loop|

            if @curves && loop.edges.first.curve.is_a?(Sketchup::ArcCurve) && loop.edges.first.curve.circular?

              curve = loop.edges.first.curve
              center = curve.center.transform(transformation)
              radius = curve.radius # TODO : transform

              cx = _convert(center.x, unit_converter)
              cy = _convert(center.y, unit_converter)
              r = _convert(radius, unit_converter)

              _dxf_write_circle(file, cx, cy, r, 'OCL_DRAWING')

            else

              _dxf_write_polygon(file, loop.vertices.map { |vertex|
                point = vertex.position.transform(transformation)
                Geom::Point3d.new(_convert(point.x, unit_converter), _convert(point.y, unit_converter))
              }, 'OCL_DRAWING')

            end

          end

        end

        edge_infos.each do |edge_info|

          edge = edge_info.edge
          transformation = edge_info.transformation

          point1 = edge.start.position.transform(transformation)
          point2 = edge.end.position.transform(transformation)

          x1 = _convert(point1.x, unit_converter)
          y1 = _convert(point1.y, unit_converter)
          x2 = _convert(point2.x, unit_converter)
          y2 = _convert(point2.y, unit_converter)

          _dxf_write_line(file, x1, y1, x2, y2, 'OCL_GUIDE')

        end

        _dxf_write(file, 0, 'ENDSEC')
        _dxf_write(file, 0, 'EOF')

      when FILE_FORMAT_SVG

        bounds = Geom::BoundingBox.new
        if @anchor
          bounds.add([ Geom::Point3d.new, Geom::Point3d.new(0, 10.mm), Geom::Point3d.new(5.mm, 0) ]) if @anchor
        end
        face_infos.each do |face_info|
          bounds.add(_compute_children_faces_triangles([ face_info.face ], face_info.transformation))
        end
        edge_infos.each do |edge_info|
          bounds.add(edge_info.edge.start.position.transform(edge_info.transformation))
          bounds.add(edge_info.edge.end.position.transform(edge_info.transformation))
        end

        # Tweak unit converter to restrict to SVG compatible units (in, mm, cm)
        case @unit
        when DimensionUtils::INCHES
          unit_sign = 'in'
        when DimensionUtils::CENTIMETER
          unit_sign = 'cm'
        else
          unit_converter = 1.0.to_mm
          unit_sign = 'mm'
        end

        x = _convert(bounds.min.x, unit_converter)
        y = _convert(-(bounds.height + bounds.min.y), unit_converter)
        width = _convert(bounds.width, unit_converter)
        height = _convert(bounds.height, unit_converter)

        _svg_write_start(file, x, y, width, height, unit_sign)

        face_infos.sort_by { |face_info| face_info.data[:depth] }.each do |face_info|

          face = face_info.face
          transformation = face_info.transformation
          depth = face_info.data[:depth].to_f
          depth_ratio = face_info.data[:depth_ratio]

          face.loops.each do |loop|

            if @curves && loop.edges.first.curve.is_a?(Sketchup::ArcCurve) && loop.edges.first.curve.circular?

              curve = loop.edges.first.curve
              center = curve.center.transform(transformation)
              radius = curve.radius # TODO : transform

              cx = _convert(center.x, unit_converter)
              cy = _convert(-center.y, unit_converter)
              r = _convert(radius, unit_converter)

              if loop.outer?
                if depth.round(6) == 0
                  _svg_write_circle(file, cx, cy, r, '#000000', '#000000', 'shaper:cutType': 'outside')
                else
                  _svg_write_circle(file, cx, cy, r, nil, ColorUtils.color_to_hex(Sketchup::Color.new('#7F7F7F').blend(Sketchup::Color.new('#AAAAAA'), depth_ratio)), 'shaper:cutType': 'inside', 'shaper:cutDepth': "#{_convert(depth, unit_converter)}#{unit_sign}")
                end
              else
                _svg_write_circle(file, cx, cy, r, '#000000', '#ffffff', 'shaper:cutType': 'inside', 'shaper:cutDepth': @max_depth)
              end

            else

              coords = []
              loop.vertices.each do |vertex|
                point = vertex.position.transform(transformation)
                coords << "#{_convert(point.x, unit_converter)},#{_convert(-point.y, unit_converter)}"
              end
              data = "M#{coords.join('L')}Z"
              if loop.outer?
                if depth.round(6) == 0
                  # Outside
                  _svg_write_path(file, data, '#000000', '#000000', 'shaper:cutType': 'outside')
                else
                  # Pocket
                  _svg_write_path(file, data, nil, ColorUtils.color_to_hex(Sketchup::Color.new('#7F7F7F').blend(Sketchup::Color.new('#AAAAAA'), depth_ratio)), 'shaper:cutType': 'pocket', 'shaper:cutDepth': "#{_convert(depth, unit_converter)}#{unit_sign}")
                end
              else
                # Inside
                _svg_write_path(file, data, '#000000', '#FFFFFF', 'shaper:cutType': 'inside', 'shaper:cutDepth': @max_depth)
              end

            end

          end

        end

        unless edge_infos.empty?
          data = ''
          edge_infos.each do |edge_info|

            edge = edge_info.edge
            transformation = edge_info.transformation

            coords = []
            edge.vertices.each do |vertex|
              point = vertex.position.transform(transformation)
              coords << "#{_convert(point.x, unit_converter)},#{_convert(-point.y, unit_converter)}"
            end
            data += "M#{coords.join('L')}"

          end
          _svg_write_group_start(file, id: 'OCL_GUIDES')
          _svg_write_path(file, data, '#0068FF', nil, 'shaper:cutType': 'guide')
          _svg_write_group_end(file)
        end

        if @anchor

          x1 = 0
          y1 = 0
          x2 = 0
          y2 = _convert(-10.mm, unit_converter)
          x3 = _convert(5.mm, unit_converter)
          y3 = 0

          _svg_write_group_start(file, id: 'OCL_ANCHOR')
          _svg_write_polygon(file, "#{x1},#{y1} #{x2},#{y2} #{x3},#{y3}", nil, '#FF0000')
          _svg_write_group_end(file)

        end

        _svg_write_end(file)

      end

      # Close output file
      file.close

      true
    end

    def _convert(value, unit_converter, precision = 6)
      (value.to_f * unit_converter).round(precision)
    end

    def _convert_point(point, unit_converter, precision = 6)
      point.x = _convert(point.x, unit_converter, precision)
      point.y = _convert(point.y, unit_converter, precision)
      point.z = _convert(point.z, unit_converter, precision)
      point
    end

  end

end