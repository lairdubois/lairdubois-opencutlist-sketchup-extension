module Ladb::OpenCutList

  require_relative '../constants'

  module SvgWriterHelper

    # Unit

    def _svg_get_unit_sign_and_factor(unit)

      require_relative '../utils/dimension_utils'

      case unit
      when DimensionUtils::INCHES
        unit_factor = 1.0
        unit_sign = 'in'
      when DimensionUtils::CENTIMETER
        unit_factor = 1.0.to_l.to_cm
        unit_sign = 'cm'
      else
        unit_factor = 1.0.to_l.to_mm
        unit_sign = 'mm'
      end

      return unit_sign, unit_factor
    end

    # Ident

    def _svg_indent(inc = 1)
      if @_svg_indent.nil?
        @_svg_indent = inc
      else
        @_svg_indent += inc
      end
    end

    def _svg_append_indent
      ''.ljust([ @_svg_indent.to_i, 0 ].max)
    end

    # Attributes

    def _svg_append_attributes(attributes = {})
      return unless attributes.is_a?(Hash)
      "#{attributes.empty? ? '' : ' '}#{attributes.map { |key, value| "#{key}=\"#{value.to_s.gsub(/["']/, '')}\"" }.join(' ')}"
    end

    # Colors

    def _svg_stroke_color_hex(stroke_color, fill_color = nil)
      return '#000000' if stroke_color.nil? && fill_color.nil?
      ColorUtils.color_to_hex(stroke_color, 'none')
    end

    def _svg_fill_color_hex(fill_color)
      ColorUtils.color_to_hex(fill_color, 'none')
    end

    # ID

    def _svg_sanitize_identifier(id)
      id.to_s.gsub(/[\s<>\/\\“:;?*|=‘.]/, '_').upcase
    end

    # Value

    def _svg_value(value)
      value.to_f.round(3)
    end

    # -----

    def _svg_write_start(file, x, y, width, height, unit_sign)
      file.puts('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')
      file.puts('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">')
      file.puts("<!-- Generator: SketchUp, #{EXTENSION_NAME} Extension, Version #{EXTENSION_VERSION} -->")
      file.puts("<svg width=\"#{width}#{unit_sign}\" height=\"#{height}#{unit_sign}\" viewBox=\"#{x} #{y} #{width} #{height}\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:serif=\"http://www.serif.com/\" xmlns:inkscape=\"http://www.inkscape.org/namespaces/inkscape\" xmlns:shaper=\"http://www.shapertools.com/namespaces/shaper\">")
      _svg_indent
    end

    def _svg_write_end(file)
      _svg_indent(-1)
      file.puts("</svg>")
    end

    def _svg_write_group_start(file, attributes = {})
      file.puts("#{_svg_append_indent}<g#{_svg_append_attributes(attributes)}>")
      _svg_indent
    end

    def _svg_write_group_end(file)
      _svg_indent(-1)
      file.puts("#{_svg_append_indent}</g>")
    end

    def _svg_write_tag(file, tag, attributes = {}, cdata = nil)
      if cdata.is_a?(String)
        file.puts("#{_svg_append_indent}<#{tag}#{_svg_append_attributes(attributes)}>#{cdata}</#{tag}>")
      else
        file.puts("#{_svg_append_indent}<#{tag}#{_svg_append_attributes(attributes)} />")
      end
    end

    def _svg_write_label(file, rx, ry, rw, rh, text, tw, th, tx = 0, ty = 0, angle = 0, hex_color = nil)
      text = text.to_s
      return unless text.length > 0

      theight = [ 60.0, th / 2, tw / text.length ].min
      tx = rx + rw / 2.0 + tx
      ty = ry + rh / 2.0 + ty
      attributes = {
        x: _svg_value(tx),
        y: _svg_value(ty),
        fill: hex_color,
        'font-family': 'monospace',
        'font-size': _svg_value(theight),
        'text-anchor': 'middle',
        'dominant-baseline': 'middle'
      }
      attributes.merge!({ transform: "rotate(-#{angle % 180} #{_svg_value(tx)} #{_svg_value(ty)})"}) unless angle % 180 == 0

      _svg_write_tag(file, 'text', attributes, text)

    end

    # -----

    def _svg_get_projection_layer_def_identifier(layer_def, unit_transformation, prefix = nil)
      return '' unless layer_def.is_a?(DrawingProjectionLayerDef)
      a = [ prefix, 'DEPTH', ('%0.04f' % [ Geom::Point3d.new(layer_def.depth, 0).transform(unit_transformation).x ]).rjust(9, '_') ]
      a << 'OUTER' if layer_def.type_outer?
      a << 'HOLES' if layer_def.type_holes?
      a << 'PATH' if layer_def.type_path?
      _svg_sanitize_identifier(a.compact.join('_'))
    end

    def _svg_write_projection_def(file, projection_def,
                                  smoothing: false,
                                  transformation: IDENTITY,
                                  unit_transformation: IDENTITY,
                                  unit_sign: '',
                                  stroke_color: nil,
                                  fill_color: nil,
                                  holes_stroke_color: nil,
                                  depths_stroke_color: nil,
                                  holes_fill_color: nil,
                                  depths_fill_color: nil,
                                  paths_stroke_color: nil,
                                  paths_fill_color: nil,
                                  prefix: '')

      require_relative '../model/drawing/drawing_projection_def'

      return unless projection_def.is_a?(DrawingProjectionDef)

      require_relative '../utils/transformation_utils'

      flipped = TransformationUtils.flipped?(transformation)
      rot_x, rot_y, rot_z = TransformationUtils.euler_angles(transformation)

      projection_def.layer_defs.sort_by { |v| [v.type_path? ? 1 : 0, v.depth ] }.each do |layer_def|   # Path's layers always on top

        id = _svg_get_projection_layer_def_identifier(layer_def, unit_transformation, prefix)

        if layer_def.type_path?
          attributes = {
            stroke: _svg_stroke_color_hex(paths_stroke_color),
            fill: layer_def.type_closed_path? ? _svg_fill_color_hex(paths_fill_color) : 'none',
            id: id,
            'serif:id': id,
            'inkscape:label': id
          }
          attributes.merge!({ 'shaper:cutDepth': "#{_svg_value(Geom::Point3d.new(layer_def.depth, 0).transform(unit_transformation).x)}#{unit_sign}" }) if layer_def.depth != 0
        elsif layer_def.type_holes? # Keep it before checking outer type
          attributes = {
            stroke: _svg_stroke_color_hex(holes_stroke_color, holes_fill_color),
            fill: _svg_fill_color_hex(holes_fill_color),
            id: id,
            'serif:id': id,
            'inkscape:label': id
          }
          attributes.merge!({ 'shaper:cutDepth': "#{_svg_value(Geom::Point3d.new(layer_def.depth, 0).transform(unit_transformation).x)}#{unit_sign}" }) if layer_def.depth > 0
        elsif layer_def.type_outer? || layer_def.depth == 0
          attributes = {
            stroke: _svg_stroke_color_hex(stroke_color, fill_color),
            fill: _svg_fill_color_hex(fill_color),
            id: id,
            'serif:id': id,
            'inkscape:label': id
          }
          attributes.merge!({ 'shaper:cutDepth': "#{_svg_value(Geom::Point3d.new(projection_def.max_depth, 0).transform(unit_transformation).x)}#{unit_sign}" }) if projection_def.max_depth > 0
        else
          attributes = {
            stroke: if depths_stroke_color
                      ColorUtils.color_to_hex(depths_stroke_color)
                    else
                        _svg_stroke_color_hex(stroke_color, fill_color)
                    end,
            fill: if depths_fill_color
                    ColorUtils.color_to_hex(depths_fill_color)
                  else
                    fill_color ? ColorUtils.color_to_hex(ColorUtils.color_lighten(fill_color, projection_def.max_depth > 0 ? (layer_def.depth / projection_def.max_depth) * 0.6 + 0.2 : 0.3)) : 'none'
                  end,
            id: id,
            'serif:id': id,
            'inkscape:label': id,
            'shaper:cutDepth': "#{_svg_value(Geom::Point3d.new(layer_def.depth, 0).transform(unit_transformation).x)}#{unit_sign}"
          }
        end

        data = []

        layer_def.poly_defs.each do |poly_def|

          if smoothing && poly_def.curve_def

            if poly_def.curve_def.circle?

              # Simplify circle drawing by using only xradius

              portion = poly_def.curve_def.portions.first
              center = portion.ellipse_def.center
              radius = portion.ellipse_def.xradius

              position1 = Geom::Point3d.new(
                center.x - radius,
                center.y
              ).transform(transformation)
              position2 = Geom::Point3d.new(
                center.x + radius,
                center.y
              ).transform(transformation)
              radius = Geom::Point3d.new(radius, 0).transform(unit_transformation)

              x1 = _svg_value(position1.x)
              y1 = _svg_value(-position1.y)
              x2 = _svg_value(position2.x)
              y2 = _svg_value(-position2.y)
              r = _svg_value(radius.x)
              sflag = portion.ccw? ? 0 : 1

              data << "M #{x1},#{y1} A #{r},#{r} 0 0,#{sflag} #{x2},#{y2} A #{r},#{r} 0 0,#{sflag} #{x1},#{y1} Z"

            else

              # Extract loop points from ordered edges and arc curves
              data << "#{poly_def.curve_def.portions.map.with_index { |portion, index|

                portion_data = []
                start_point = portion.start_point.transform(transformation)
                end_point = portion.end_point.transform(transformation)
                portion_data << "M #{_svg_value(start_point.x)},#{_svg_value(-start_point.y)}" if index == 0

                if portion.is_a?(Geometrix::ArcCurvePortionDef)

                  radius = Geom::Point3d.new(
                    portion.ellipse_def.xradius,
                    portion.ellipse_def.yradius
                  ).transform(unit_transformation)
                  middle = portion.mid_point.transform(transformation)

                  rx = _svg_value(radius.x)
                  ry = _svg_value(radius.y)
                  xrot = -portion.ellipse_def.angle.radians.round(3) + rot_z.radians.round(3)
                  lflag = 0
                  sflag = if flipped ? !portion.ccw? : portion.ccw?
                            0
                          else
                            1
                          end
                  x1 = _svg_value(middle.x)
                  y1 = _svg_value(-middle.y)
                  x2 = _svg_value(end_point.x)
                  y2 = _svg_value(-end_point.y)

                  portion_data << "A #{rx},#{ry} #{xrot} #{lflag},#{sflag} #{x1},#{y1}"
                  portion_data << "A #{rx},#{ry} #{xrot} #{lflag},#{sflag} #{x2},#{y2}"

                else

                  portion_data << "L #{_svg_value(end_point.x)},#{_svg_value(-end_point.y)}"

                end

                portion_data
              }.join(' ')} #{poly_def.curve_def.closed? ? 'Z' : ''}"

            end

          else

            # Extract loop points from vertices (quicker)
            data << "M #{poly_def.points.map { |point|
              point = point.transform(transformation)
              point.y *= -1
              "#{_svg_value(point.x)},#{_svg_value(point.y)}"
            }.join(' L ')}#{poly_def.curve_def.closed? ? 'Z' : ''}"

          end

        end

        unless data.empty?
          _svg_write_tag(file, 'path', attributes.merge(
            d: data.join(' ')
          ))
        end

      end

    end

  end

end