module Ladb::OpenCutList::Kuix

  require_relative '../model/metrics'

  class Graphics

    def initialize(view)
      @view = view
      @x = 0
      @y = 0
    end

    def translate(x, y)
      @x += x
      @y += y
    end

    def set_drawing_color(color)
      @view.drawing_color = color
    end

    def draw_rect(x, y, width, height, background_color = nil)
      if background_color
        set_drawing_color(background_color)
      end
      @view.draw2d(GL_QUADS, Metrics.new(
        @x + x,
        @y + y,
        width,
        height
      ).get_points)
    end

    def draw_bordered_rect(x, y, width, height, background_color, border, border_color)
      if border_color
        set_drawing_color(border_color)
        self.draw_rect(x, y, width - border.right, border.top)
        self.draw_rect(x + width - border.right, y, border.right, height - border.bottom)
        self.draw_rect(x + border.left, y + height - border.bottom, width - border.left, border.bottom)
        self.draw_rect(x, y + border.top, border.left, height - border.top)
      end
      if background_color
        self.draw_rect(x + border.left, y + border.top, width - border.left - border.right, height - border.top - border.bottom, background_color)
      end
    end

    def draw_text(x, y, text, text_options, color = nil)
      if color
        set_drawing_color(color)
      end
      puts "draw_text text=#{text}"
      @view.draw_text(Geom::Point3d.new(@x + x, @y + y, 0), text, text_options)
    end

  end

end