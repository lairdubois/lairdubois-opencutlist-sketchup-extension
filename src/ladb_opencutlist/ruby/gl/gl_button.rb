module Ladb::OpenCutList

  class GLButton

    COLOR_BORDER = Sketchup::Color.new(0, 0, 0, 255).freeze
    COLOR_TEXT = Sketchup::Color.new(0, 0, 0, 255).freeze
    COLOR_FILL = Sketchup::Color.new(255, 255, 255, 255).freeze
    COLOR_FILL_HOVER = Sketchup::Color.new(190, 190, 190, 255).freeze
    COLOR_FILL_DOWN = Sketchup::Color.new(128, 128, 128, 255).freeze

    FONT_TEXT = 'Verdana'

    def initialize(view, text, x, y, width, height, text_options, &callback)
      @text = text
      @x = x
      @y = y
      @width = width
      @height = height
      @text_options = text_options
      @text_font_size = text_options[:size] ? text_options[:size] : 12
      @callback = callback
      @is_hover = false
      @is_down = false
      update_coords(view)
    end

    # -- Events ---

    def onLButtonDown(flags, x, y, view)
      down = @is_down
      @is_down = inside?(x, y)
      if down != @is_down
        view.invalidate
      end
      @is_down
    end

    def onLButtonUp(flags, x, y, view)
      if inside?(x, y)
        @is_down = false
        view.invalidate
        if @callback
          @callback.call(flags, x, y, view)
        end
        return true
      end
      false
    end

    def onMouseMove(flags, x, y, view)
      hover = @is_hover
      @is_hover = inside?(x, y)
      if hover != @is_hover
        if @is_down && !@is_hover
          @is_down = false
        end
        view.invalidate
      end
    end

    # -- Render --

    def draw(view)
      update_coords(view)
      view.drawing_color = @is_down ? COLOR_FILL_DOWN : @is_hover ? COLOR_FILL_HOVER : COLOR_FILL
      view.line_stipple = ''
      view.line_width = 1
      view.draw2d(GL_QUADS, @points)
      view.drawing_color = COLOR_BORDER
      view.draw2d(GL_LINE_LOOP, @points)
      view.draw_text(@text_point, @text, @text_options)
    end

    # -- Internal --

    def inside?(x, y)
      x >= @left and x <= @right and y >= @top and y <= @bottom
    end

    def update_coords(view)
      x = view.vpwidth - @x
      y = view.vpheight - @y
      @left = x
      @right = x + @width
      @top = y
      @bottom = y + @height
      @points = [
          Geom::Point3d.new(x          , y           , 0),
          Geom::Point3d.new(x + @width , y           , 0),
          Geom::Point3d.new(x + @width , y + @height , 0),
          Geom::Point3d.new(x          , y + @height , 0)
      ]
      @text_point = Geom::Point3d.new(x + @width / 2, y + (@height - @text_font_size - 10) / 2, 0)
    end

  end

end