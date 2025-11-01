module Ladb::OpenCutList::Kuix

  class Graphics3d < Graphics

    def initialize(view)
      super
    end

    # -- Drawing --

    def draw_points(
      points:,
      size: 12,
      style: POINT_STYLE_SQUARE,
      fill_color: COLOR_BLACK,
      stroke_color: COLOR_WHITE,
      stroke_width: 1
    )

      if style == POINT_STYLE_CIRCLE

        segment_count = 12
        delta = 2 * Math::PI / segment_count
        half_size = size / 2.0

        points = [ points ] if points.is_a?(Geom::Point3d)
        points.each do |point|

          screen_point = screen_coords(point)
          outer_points = Array.new(segment_count + 1) { |i| Geom::Point3d.new(screen_point.x + half_size * Math.cos(i * delta), screen_point.y + half_size * Math.sin(i * delta)) }
          triangles = outer_points.each_cons(2).to_a.flat_map { |p1, p2| [ p1, p2, screen_point ] }

          unless fill_color.nil?
            set_drawing_color(fill_color)
            @view.draw2d(GL_TRIANGLES, triangles)
          end
          unless stroke_color.nil?
            set_line_stipple(LINE_STIPPLE_SOLID)
            set_line_width(stroke_width)
            set_drawing_color(stroke_color)
            @view.draw2d(GL_LINE_LOOP, outer_points)
          end

        end

      elsif style == POINT_STYLE_DIAMOND

        half_size = size / 2.0

        points = [ points ] if points.is_a?(Geom::Point3d)
        points.each do |point|

          screen_point = screen_coords(point)
          quads = [
            Geom::Point3d.new(screen_point.x - half_size, screen_point.y),
            Geom::Point3d.new(screen_point.x, screen_point.y + half_size),
            Geom::Point3d.new(screen_point.x + half_size, screen_point.y),
            Geom::Point3d.new(screen_point.x, screen_point.y - half_size),
          ]

          unless fill_color.nil?
            set_drawing_color(fill_color)
            @view.draw2d(GL_QUADS, quads)
          end
          unless stroke_color.nil?
            set_line_stipple(LINE_STIPPLE_SOLID)
            set_line_width(stroke_width)
            set_drawing_color(stroke_color)
            @view.draw2d(GL_LINE_LOOP, quads)
          end

        end

      elsif style == POINT_STYLE_CUBE

        half_size = size / 2.0

        points = [ points ] if points.is_a?(Geom::Point3d)
        points.each do |point|

          bounds = Bounds3d.new
          bounds.origin.copy!(point).translate!(-half_size, -half_size, -half_size)
          bounds.size.set_all!(size)
          quads = bounds.get_quads

          unless fill_color.nil?
            set_drawing_color(fill_color)
            @view.draw(GL_QUADS, quads)
          end
          unless stroke_color.nil?
            set_line_stipple(LINE_STIPPLE_SOLID)
            set_line_width(stroke_width)
            set_drawing_color(stroke_color)
            @view.draw(GL_LINES, quads)
          end

        end

      else

        case style
        when POINT_STYLE_SQUARE
          fill_style = 2
          stroke_style = 1
        when POINT_STYLE_TRIANGLE
          fill_style = 7
          stroke_style = 6
        when POINT_STYLE_PLUS
          fill_style = nil
          stroke_style = 3
        when POINT_STYLE_CROSS
          fill_style = nil
          stroke_style = 4
        when POINT_STYLE_STAR
          fill_style = nil
          stroke_style = 5
        end

        set_line_stipple(LINE_STIPPLE_SOLID)
        set_line_width(stroke_width)
        @view.draw_points(points, size, fill_style, fill_color) unless fill_style.nil? || fill_color.nil?
        @view.draw_points(points, size, stroke_style, stroke_color) unless stroke_style.nil? || stroke_color.nil?

      end

    end

    def draw_lines(
      points:,
      color: nil,
      line_width: nil,
      line_stipple: nil
    )
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stipple) if line_stipple
      @view.draw_lines(points)
    end

    def draw_line_strip(
      points:,
      color: nil,
      line_width: nil,
      line_stipple: nil
    )
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stipple) if line_stipple
      @view.draw(GL_LINE_STRIP, points)
    end

    def draw_line_loop(
      points:,
      color: nil,
      line_width: nil,
      line_stipple: nil
    )
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stipple) if line_stipple
      @view.draw(GL_LINE_LOOP, points)
    end

    def draw_triangles(
      points:,
      fill_color: nil
    )
      set_drawing_color(fill_color) if fill_color
      @view.draw(GL_TRIANGLES, points)
    end

    def draw_quads(
      points:,
      fill_color: nil
    )
      set_drawing_color(fill_color) if fill_color
      @view.draw(GL_QUADS, points)
    end

  end

end