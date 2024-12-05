module Ladb::OpenCutList::Kuix

  class Line < Entity3d

    attr_accessor :color
    attr_accessor :line_width, :line_stipple
    attr_accessor :position, :direction

    def initialize(id = nil)
      super(id)

      @color = COLOR_BLACK
      @line_width = 1
      @line_stipple = LINE_STIPPLE_SOLID
      @position = nil   # Geom::Point3d
      @direction = nil  # Geom::Vector3d

      @_lp1_3d = nil
      @_lp2_3d = nil

    end

    # -- LAYOUT --

    def do_layout(transformation)
      if !@position.is_a?(Geom::Point3d) || !@direction.is_a?(Geom::Vector3d) || !@direction.valid?
        @_lp1_3d = nil
        @_lp2_3d = nil
      else
        @_lp1_3d = @position.transform(transformation * @transformation)
        @_lp2_3d = (@position + @direction).transform(transformation * @transformation)
      end
      super
    end

    # -- RENDER --

    def paint_content(graphics)
      unless @_lp1_3d.nil? || @_lp2_3d.nil?

        view = graphics.view

        lp1_2d = view.screen_coords(@_lp1_3d)
        lp1_2d.z = 0
        lp2_2d = view.screen_coords(@_lp2_3d)
        lp2_2d.z = 0
        
        line = [ lp1_2d, lp2_2d - lp1_2d ]

        topleft_corner = Geom::Point3d.new(view.corner(0))
        topright_corner = Geom::Point3d.new(view.corner(1))
        bottomleft_corner = Geom::Point3d.new(view.corner(2))
        bottomright_corner = Geom::Point3d.new(view.corner(3))

        top_line = [ topleft_corner, topright_corner - topleft_corner ]
        bottom_line = [ bottomleft_corner, bottomright_corner - bottomleft_corner ]
        left_line = [ topleft_corner, bottomleft_corner - topleft_corner ]
        right_line = [ topright_corner, bottomright_corner - topright_corner ]

        p1 = Geom.intersect_line_line(line, top_line)
        p1 = Geom.intersect_line_line(line, left_line) if p1.nil?
        p2 = Geom.intersect_line_line(line, bottom_line)
        p2 = Geom.intersect_line_line(line, right_line) if p2.nil?

        graphics.set_drawing_color(@color) unless @color.nil?
        graphics.set_line_width(@line_width) unless @line_width.nil?
        graphics.set_line_stipple(@line_stipple) unless @line_stipple.nil?
        graphics.view.draw2d(GL_LINE_STRIP, [ p1, p2 ])

      end
      super
    end

  end

end