module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/face_triangles_helper'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/svg_writer_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../utils/color_utils'
  require_relative '../../worker/common/common_decompose_drawing_worker'

  class CommonExportDrawing2dWorker

    include FaceTrianglesHelper
    include DxfWriterHelper
    include SvgWriterHelper
    include SanitizerHelper

    LAYER_DRAWING = 'OCL_DRAWING'.freeze
    LAYER_GUIDES = 'OCL_GUIDES'.freeze
    LAYER_ANCHOR = 'OCL_ANCHOR'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_DXF, FILE_FORMAT_SVG ]

    def initialize(drawing_def, settings = {})

      @drawing_def = drawing_def

      @file_name = _sanitize_filename(settings.fetch('file_name', 'FACE'))
      @file_format = settings.fetch('file_format', nil)
      @unit = settings.fetch('unit', nil)
      @anchor = settings.fetch('anchor', false)
      @curves = settings.fetch('curves', false)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('core.savepanel.export_to_file', { :file_format => @file_format.upcase }), '', "#{@file_name}.#{@file_format}")
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

          success = _write_2d(path, @drawing_def.face_manipulators, @drawing_def.edge_manipulators, unit_converter) && File.exist?(path)

          return { :errors => [ [ 'core.error.failed_export_to_file', { :file_format => @file_format, :error => '' } ] ] } unless success
          return { :export_path => path }
        rescue => e
          puts e.inspect
          puts e.backtrace
          return { :errors => [ [ 'core.error.failed_export_to_file', { :file_format => @file_format, :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

    private

    def _write_2d(path, face_manipulators, edge_manipulators, unit_converter)

      # Compute projection
      projection_def = CommonProjectionWorker.new(@drawing_def, {
        'down_to_top_union' => true,
        'passthrough_holes' => true
      }).run

      # Open output file
      file = File.new(path , 'w')

      case @file_format
      when FILE_FORMAT_DXF

        layer_defs = []
        layer_defs.push({ :name => LAYER_DRAWING, :color => 7 }) unless face_manipulators.empty?
        layer_defs.push({ :name => LAYER_GUIDES, :color => 150 }) unless edge_manipulators.empty?

        _dxf_write_header(file, _convert_point(@drawing_def.bounds.min, unit_converter), _convert_point(@drawing_def.bounds.max, unit_converter), layer_defs)

        _dxf_write(file, 0, 'SECTION')
        _dxf_write(file, 2, 'ENTITIES')

        projection_def.layer_defs.each do |layer_def|
          layer_def.polygon_defs.each do |polygon_def|

            if @curves && polygon_def.loop_def

              # Extract loop points from ordered edges and arc curves
              polygon_def.loop_def.portions.each { |portion|

                if portion.is_a?(Geometrix::ArcLoopPortionDef)

                  center = portion.ellipse_def.center
                  xaxis = portion.ellipse_def.xaxis

                  # DXF ellipse angles must be counter clockwise
                  if portion.loop_def.ellipse?
                    start_angle = 0.0
                    end_angle = 2.0 * Math::PI
                  elsif portion.normal.samedirection?(Z_AXIS)
                    start_angle = portion.start_angle
                    end_angle = portion.end_angle
                  else
                    start_angle = portion.end_angle
                    end_angle = portion.start_angle
                  end

                  cx = _convert(center.x, unit_converter)
                  cy = _convert(center.y, unit_converter)
                  vx = _convert(xaxis.x, unit_converter)
                  vy = _convert(xaxis.y, unit_converter)
                  vr = portion.ellipse_def.yradius / portion.ellipse_def.xradius
                  as = start_angle
                  ae = end_angle

                  _dxf_write_ellipse(file, cx, cy, vx, vy, vr, as, ae, LAYER_DRAWING)

                else

                  start_point = portion.start_point
                  end_point = portion.end_point

                  x1 = _convert(start_point.x, unit_converter)
                  y1 = _convert(start_point.y, unit_converter)
                  x2 = _convert(end_point.x, unit_converter)
                  y2 = _convert(end_point.y, unit_converter)

                  _dxf_write_line(file, x1, y1, x2, y2, LAYER_DRAWING)

                end

              }

            else

              # Extract loop points from vertices (quicker)
              _dxf_write_polygon(file, polygon_def.points.map { |point| _convert_point(point, unit_converter) }, LAYER_DRAWING)

            end

          end
        end

        edge_manipulators.each do |edge_manipulator|

          start_point = edge_manipulator.start_point
          end_point = edge_manipulator.end_point

          x1 = _convert(start_point.x, unit_converter)
          y1 = _convert(start_point.y, unit_converter)
          x2 = _convert(end_point.x, unit_converter)
          y2 = _convert(end_point.y, unit_converter)

          _dxf_write_line(file, x1, y1, x2, y2, LAYER_GUIDES)

        end

        _dxf_write(file, 0, 'ENDSEC')

        _dxf_write_footer(file)

      when FILE_FORMAT_SVG

        if @anchor
          # Recompute bounding box to be sur to extends to anchor triangle
          bounds = Geom::BoundingBox.new
          bounds.add(@drawing_def.bounds.min)
          bounds.add(@drawing_def.bounds.max)
          bounds.add([ Geom::Point3d.new, Geom::Point3d.new(0, 10.mm), Geom::Point3d.new(5.mm, 0) ])
        else
          bounds = @drawing_def.bounds
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

        unless projection_def.layer_defs.empty?

          _svg_write_group_start(file, id: LAYER_DRAWING)

          projection_def.layer_defs.each do |layer_def|

            if layer_def.position == CommonProjectionWorker::LAYER_POSITION_TOP
              attributes = {
                fill: '#000000',
                'shaper:cutType': 'outside'
              }
              attributes.merge!({ 'shaper:cutDepth': "#{_convert(@drawing_def.bounds.depth, unit_converter)}#{unit_sign}" }) if @drawing_def.bounds.depth > 0
            elsif layer_def.position == CommonProjectionWorker::LAYER_POSITION_BOTTOM
              attributes = {
                stroke: '#000000',
                'stroke-with': '0.1mm',
                fill: '#FFFFFF',
                'shaper:cutType': 'inside'
              }
              attributes.merge!({ 'shaper:cutDepth': "#{_convert(@drawing_def.bounds.depth, unit_converter)}#{unit_sign}" }) if @drawing_def.bounds.depth > 0
            else
              attributes = {
                fill: ColorUtils.color_to_hex(Sketchup::Color.new('#AAAAAA').blend(Sketchup::Color.new('#7F7F7F'), @drawing_def.bounds.depth > 0 ? layer_def.depth / @drawing_def.bounds.depth : 1.0)),
                'shaper:cutType': 'pocket',
                'shaper:cutDepth': "#{_convert(layer_def.depth, unit_converter)}#{unit_sign}"
              }
            end

            data = []

            layer_def.polygon_defs.each do |polygon_def|

              if @curves && polygon_def.loop_def

                # Extract loop points from ordered edges and arc curves
                data << "#{polygon_def.loop_def.portions.map.with_index { |portion, index|

                  polygon_data = []
                  start_point = portion.start_point
                  end_point = portion.end_point
                  polygon_data << "M #{_convert(start_point.x, unit_converter)},#{_convert(-start_point.y, unit_converter)}" if index == 0

                  if portion.is_a?(Geometrix::ArcLoopPortionDef)

                    center = portion.ellipse_def.center
                    middle = portion.mid_point

                    rx = _convert(portion.ellipse_def.xradius, unit_converter)
                    ry = _convert(portion.ellipse_def.yradius, unit_converter)
                    xrot = -portion.ellipse_def.angle.radians.round(6)
                    lflag = 0
                    sflag = (middle - center).dot(_cw_normal(start_point - center)) > 0 ? 0 : 1
                    x1 = _convert(middle.x, unit_converter)
                    y1 = _convert(-middle.y, unit_converter)
                    x2 = _convert(end_point.x, unit_converter)
                    y2 = _convert(-end_point.y, unit_converter)

                    polygon_data << "A #{rx},#{ry} #{xrot} #{lflag},#{sflag} #{x1},#{y1}"
                    polygon_data << "A #{rx},#{ry} #{xrot} #{lflag},#{sflag} #{x2},#{y2}"

                  else

                    polygon_data << "L #{_convert(end_point.x, unit_converter)},#{_convert(-end_point.y, unit_converter)}"

                  end

                  polygon_data
                }.join(' ')} Z"

              else

                # Extract loop points from vertices (quicker)
                data << "M #{polygon_def.points.map { |point| "#{_convert(point.x, unit_converter)},#{_convert(-point.y, unit_converter)}" }.join(' L ')} Z"

              end

            end

            unless data.empty?
              _svg_write_tag(file, 'path', attributes.merge(
                d: data.join(' ')
              ))
            end

          end

          _svg_write_group_end(file)

        end

        unless edge_manipulators.empty?

          _svg_write_group_start(file, id: LAYER_GUIDES)

          data = ''
          edge_manipulators.each do |edge_manipulator|

            data += "M #{edge_manipulator.points.each.map { |point| "#{_convert(point.x, unit_converter)},#{_convert(-point.y, unit_converter)}" }.join(' L')}"

          end

          _svg_write_tag(file, 'path', {
            d: data,
            stroke: '#0068FF',
            fill: 'none',
            'shaper:cutType': 'guide'
          })

          _svg_write_group_end(file)

        end

        if @anchor

          x1 = 0
          y1 = 0
          x2 = 0
          y2 = _convert(-10.mm, unit_converter)
          x3 = _convert(5.mm, unit_converter)
          y3 = 0

          _svg_write_group_start(file, id: LAYER_ANCHOR)
          _svg_write_tag(file, 'polygon', {
            points: "#{x1},#{y1} #{x2},#{y2} #{x3},#{y3}",
            fill: '#FF0000'
          })
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
      point = point.clone
      point.x = _convert(point.x, unit_converter, precision)
      point.y = _convert(point.y, unit_converter, precision)
      point.z = _convert(point.z, unit_converter, precision)
      point
    end

    def _cw_normal(v)
      Geom::Vector3d.new(-v.y, v.x, 0)
    end

  end

end