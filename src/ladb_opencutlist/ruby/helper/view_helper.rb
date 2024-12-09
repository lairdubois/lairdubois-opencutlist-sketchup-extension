module Ladb::OpenCutList

  module ViewHelper

    POINT_STYLE_SQUARE = 1
    POINT_STYLE_TRIANGLE = 2
    POINT_STYLE_CIRCLE = 3

    def _view_draw_filled_points(
      view:,
      points:,
      size: 12,
      style: POINT_STYLE_SQUARE,
      fill_color: 'black',
      stroke_color: 'white'
    )

      if style == POINT_STYLE_CIRCLE

        points = [ points ] if points.is_a?(Geom::Point3d)
        points.each do |point|

          screen_point = view.screen_coords(point)
          segment_count = 12
          delta = 2 * Math::PI / segment_count
          half_size = UI.scale_factor * size / 2.0
          outer_points = Array.new(segment_count + 1) { |i| Geom::Point3d.new(screen_point.x + half_size * Math.cos(i * delta), screen_point.y + half_size * Math.sin(i * delta)) }
          triangles = outer_points.each_cons(2).to_a.map { |p1, p2| [ p1, p2, screen_point ] }.flatten(1)

          view.drawing_color = fill_color
          view.draw2d(GL_TRIANGLES, triangles)
          view.line_width = 1.5
          view.drawing_color = stroke_color
          view.draw2d(GL_LINE_LOOP, outer_points)

        end

      else

        case style
        when POINT_STYLE_SQUARE
          fill_style = 2
          stroke_style = 1
        when POINT_STYLE_TRIANGLE
          fill_style = 7
          stroke_style = 6
        end

        view.draw_points(points, UI.scale_factor * size, fill_style, fill_color)
        view.draw_points(points, UI.scale_factor * size, stroke_style, stroke_color)

      end

    end

  end

end