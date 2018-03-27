module Ladb
  module Toolbox
    class GLButton

      COLOR_BORDER = Sketchup::Color.new(0, 0, 0, 255).freeze
      COLOR_FILL = Sketchup::Color.new(255, 255, 255, 128).freeze
      COLOR_FILL_HOVER = Sketchup::Color.new(255, 255, 255, 200).freeze
      COLOR_FILL_DOWN = Sketchup::Color.new(255, 255, 255, 255).freeze

      def initialize(view, text, x, y, width, height, &block)
        @text = text
        @x = x
        @y = y
        @width = width
        @height = height
        @block = block
        @hover = false
        @down = false
        update_coords(view)
      end

      def onLButtonDown(flags, x, y, view)
        down = @down
        @down = inside?(x, y)
        if down != @down
          view.invalidate
        end
        @down
      end

      def onLButtonUp(flags, x, y, view)
        if inside?(x, y)
          @down = false
          view.invalidate
          if @block
            @block.call(flags, x, y, view)
          end
          return true
        end
        false
      end

      def onMouseMove(flags, x, y, view)
        hover = @hover
        @hover = inside?(x, y)
        if hover != @hover
          view.invalidate
        end
      end

      def draw(view)
        update_coords(view)
        view.drawing_color = @down ? COLOR_FILL_DOWN : @hover ? COLOR_FILL_HOVER : COLOR_FILL
        view.draw2d(GL_QUADS, @points)
        view.drawing_color = COLOR_BORDER
        view.draw2d(GL_LINE_LOOP, @points)
        view.draw_text(@text_point, @text, color: COLOR_BORDER, size: 15, align: TextAlignCenter)
      end

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
        @text_point = Geom::Point3d.new(x + @width / 2, y + (@height - 20) / 2, 0)
      end

    end
  end
end