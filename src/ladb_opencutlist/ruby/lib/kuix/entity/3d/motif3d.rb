module Ladb::OpenCutList::Kuix

  class Motif3d < Entity3d

    attr_accessor :patterns_transformation
    attr_accessor :color
    attr_accessor :line_width, :line_stipple
    attr_accessor :on_top

    def initialize(patterns = [], id = nil)
      super(id)

      @patterns = patterns  # Normalized Array<Array<Kuix::Point3d>>
      @patterns_transformation = Geom::Transformation.new

      @color = nil
      @line_width = 1
      @line_stipple = LINE_STIPPLE_SOLID
      @on_top = false

      @_paths = []
      @_path_transformation = IDENTITY

    end

    # -- LAYOUT --

    def do_layout(transformation)
      super
      @_path_transformation = transformation * @transformation
      no_transform = @_path_transformation.identity?
      no_pattern_transform = @patterns_transformation.identity?
      @_paths.clear
      @patterns.each do |pattern|
        points = []
        pattern.each do |pattern_point|
          pt = Geom::Point3d.new(pattern_point)
          pt.transform!(@patterns_transformation) unless no_pattern_transform
          point = Geom::Point3d.new(@bounds.x + pt.x * @bounds.width, @bounds.y + pt.y * @bounds.height, @bounds.z + pt.z * @bounds.depth)
          point.transform!(@_path_transformation) unless no_transform
          points << point
        end
        @_paths << points
        @extents.add(points) unless points.empty?
      end
    end

    # -- RENDER --

    def paint_content(graphics)
      super
      @_paths.each do |points|
        if @on_top
          graphics.set_drawing_color(@color) if @color.is_a?(Sketchup::Color)
          graphics.set_line_width(@line_width)
          graphics.set_line_stipple(@line_stipple)
          graphics.view.draw2d(GL_LINE_STRIP, points.map { |point| graphics.view.screen_coords(point) })
        else
          graphics.draw_line_strip(
            points: points,
            color: @color,
            line_width: @line_width,
            line_stipple: @line_stipple
          )
        end
      end
      @extents.add(@_paths.flatten(1)) unless @on_top || @_paths.empty?
    end

  end

  class EdgeMotif3d < Motif3d

    attr_reader :start, :end
    attr_accessor :start_arrow, :end_arrow,
                  :arrow_size

    def initialize(id = nil)
      super([[

               [ 0, 0, 0 ],
               [ 1, 1, 1 ]

             ]], id)

      @start = Point3d.new
      @end = Point3d.new

      @start_arrow = false
      @end_arrow = false

      @arrow_size = 15  # Expressed in pixels

    end

    # -- LAYOUT --

    def do_layout(transformation)
      if @_paths.empty?

        v = @end - @start

        tsx = 1
        tsy = 1
        tsz = 1
        if v.x < 0
          tsx = -1
          v.x = v.x.abs
        end
        if v.y < 0
          tsy = -1
          v.y = v.y.abs
        end
        if v.z < 0
          tsz = -1
          v.z = v.z.abs
        end

        self.patterns_transformation = Geom::Transformation.scaling(tsx, tsy, tsz)
        self.bounds.origin.copy!(@start)
        self.bounds.size.set!(v.x, v.y, v.z)

      end
      super
    end

    # -- RENDER --

    def paint_content(graphics)
      super

      return unless @start_arrow || @end_arrow

      view = graphics.view

      ps_3d, pe_3d = @_paths.last

      ps_2d = view.screen_coords(ps_3d)
      ps_2d.z = 0
      pe_2d = view.screen_coords(pe_3d)
      pe_2d.z = 0
      v_2d = ps_2d.vector_to(pe_2d)
      v_2d.z = 0
      a = Math.atan2((X_AXIS * v_2d) % Z_AXIS, v_2d % X_AXIS)

      fn_draw_arrow = lambda do |p_3d, p_2d, a|

        t = Geom::Transformation.rotation(p_2d, Z_AXIS, a)

        p1_2d = p_2d.offset(Geom::Vector3d.new(@arrow_size, @arrow_size)).transform(t)
        p2_2d = p_2d.offset(Geom::Vector3d.new(@arrow_size, -@arrow_size)).transform(t)

        if @on_top

          graphics.view.draw2d(
            GL_LINE_STRIP,
            [ p1_2d, p_2d, p2_2d ]
          )

        else

          ray1 = view.pickray(p1_2d.x, p1_2d.y)
          ray2 = view.pickray(p2_2d.x, p2_2d.y)

          p1_3d = Geom.intersect_line_plane(ray1, [ p_3d, ray1.last ])
          p2_3d = Geom.intersect_line_plane(ray2, [ p_3d, ray2.last ])

          graphics.draw_line_strip(
            points: [ p1_3d, p_3d, p2_3d ]
          )

        end

      end

      if ps_2d.distance(pe_2d).to_i > 1
        fn_draw_arrow.call(ps_3d, ps_2d, a) if @start_arrow
        fn_draw_arrow.call(pe_3d, pe_2d, a + Math::PI) if @end_arrow
      end

    end

  end

  class CircleMotif3d < Motif3d

    def initialize(segment_count = 24, id = nil)
      delta = 2 * Math::PI / segment_count
      super([

               Array.new(segment_count + 1) { |i| Geom::Point3d.new(0.5 + 0.5 * Math.cos(i * delta), 0.5 + 0.5 * Math.sin(i * delta)) },

             ], id)
    end

  end

  class RectangleMotif3d < Motif3d

    def initialize(id = nil)
      super([[

               [ 0, 0, 0 ],
               [ 1, 0, 0 ],
               [ 1, 1, 0 ],
               [ 0, 1, 0 ],
               [ 0, 0, 0 ],

             ]], id)
    end

  end

  class BoxMotif3d < Motif3d

    LFB = [ 0, 0, 0 ]
    RFB = [ 1, 0, 0 ]
    LBB = [ 0, 1, 0 ]
    RBB = [ 1, 1, 0 ]
    LFT = [ 0, 0, 1 ]
    RFT = [ 1, 0, 1 ]
    LBT = [ 0, 1, 1 ]
    RBT = [ 1, 1, 1 ]

    attr_accessor :shell_on_top

    def initialize(id = nil)
      super([

              [ LFB, RFB ], # 0
              [ RFB, RBB ], # 1
              [ RBB, LBB ], # 2
              [ LBB, LFB ], # 3

              [ LFT, RFT ], # 4
              [ RFT, RBT ], # 5
              [ RBT, LBT ], # 6
              [ LBT, LFT ], # 7

              [ LFB, LFT ], # 8
              [ RFB, RFT ], # 9
              [ LBB, LBT ], # 10
              [ RBB, RBT ], # 11

            ], id)

      @shell_on_top = true

    end

    # -- RENDER --

    def paint_content(graphics)
      super

      if @shell_on_top && !@on_top

        # Display only face edges that are exposed to the camera

        points_2d = 6.times
                     .select { |face|
                       face_center_3d = @bounds.face_center(face).to_p.transform(@_path_transformation)
                       face_center_2d = graphics.view.screen_coords(face_center_3d)
                       face_normal = Bounds3d.normal_by_face(face).transform(@_path_transformation)
                       _, ray = graphics.view.pickray(face_center_2d.x, face_center_2d.y)
                       face_normal.angle_between(ray) > Math::PI / 2
                     }
                     .map { |face|
                       case face
                       when Bounds3d::BOTTOM then [ 0, 1, 2, 3]
                       when Bounds3d::TOP then [ 4, 5, 6, 7 ]
                       when Bounds3d::LEFT then [ 3, 7, 8, 10 ]
                       when Bounds3d::RIGHT then [ 1, 5, 9, 11 ]
                       when Bounds3d::FRONT then [ 0, 4, 8, 9 ]
                       when Bounds3d::BACK then [ 2, 6, 10, 11 ]
                       end
                     }.flatten(1).uniq
                     .map { |i|
                       @_paths[i].map { |point_3d| graphics.view.screen_coords(point_3d) }
                     }.flatten(1)

        graphics.view.draw2d(GL_LINES, points_2d)

      end

    end

  end

  class BoxFillMotif3d < Motif3d

    def initialize(id = nil)
      super([
              [ [ 0, 0, 0 ], [ 1, 0, 0 ], [ 1, 1, 0 ], [ 0, 1, 0 ] ], # 0 = BOTTOM
              [ [ 0, 0, 1 ], [ 1, 0, 1 ], [ 1, 1, 1 ], [ 0, 1, 1 ] ], # 1 = TOP
              [ [ 0, 0, 0 ], [ 0, 1, 0 ], [ 0, 1, 1 ], [ 0, 0, 1 ] ], # 2 = LEFT
              [ [ 1, 0, 0 ], [ 1, 1, 0 ], [ 1, 1, 1 ], [ 1, 0, 1 ] ], # 3 = RIGHT
              [ [ 0, 0, 0 ], [ 1, 0, 0 ], [ 1, 0, 1 ], [ 0, 0, 1 ] ], # 4 = FRONT
              [ [ 0, 1, 0 ], [ 1, 1, 0 ], [ 1, 1, 1 ], [ 0, 1, 1 ] ], # 5 = BACK
             ], id)
    end

    # -- RENDER --

    def paint_content(graphics)

      # Display only faces that are exposed to the camera

      6.times
       .select { |face|
         face_center_3d = @bounds.face_center(face).to_p.transform(@_path_transformation)
         face_center_2d = graphics.view.screen_coords(face_center_3d)
         face_normal = Bounds3d.normal_by_face(face).transform(@_path_transformation)
         _, ray = graphics.view.pickray(face_center_2d.x, face_center_2d.y)
         face_normal.angle_between(ray) > Math::PI / 2
       }
       .each { |face|
         points = @_paths[face]
         if @on_top
           graphics.set_drawing_color(@color)
           graphics.view.draw2d(GL_QUADS, points.map { |point| graphics.view.screen_coords(point) })
         else
           graphics.draw_quads(
             points: points,
             fill_color: @color)
         end
       }

    end

  end

  class ArrowMotif3d < Motif3d

    def initialize(offset = 0.1, id = nil)
      super([[

               [   offset ,     1/3.0 , 0 ],
               [    1/1.8 ,     1/3.0 , 0 ],
               [    1/1.8 ,    offset , 0 ],
               [ 1-offset ,     1/2.0 , 0 ],
               [    1/1.8 ,  1-offset , 0 ],
               [    1/1.8 ,     2/3.0 , 0 ],
               [   offset ,     2/3.0 , 0 ],
               [   offset ,     1/3.0 , 0 ]

             ]], id)
    end

  end

  class ArrowFillMotif3d < Motif3d

    def initialize(offset = 0.1, id = nil)
      super([[

               [   offset ,     1/3.0 , 0 ],
               [    1/1.8 ,     1/3.0 , 0 ],
               [    1/1.8 ,     2/3.0 , 0 ],
               [   offset ,     2/3.0 , 0 ],

             ], [

               [    1/1.8 ,    offset , 0 ],
               [ 1-offset ,     1/2.0 , 0 ],
               [    1/1.8 ,  1-offset , 0 ],
               [    1/1.8 ,     2/3.0 , 0 ],

           ]], id)
    end

    # -- RENDER --

    def paint_content(graphics)
      @_paths.each do |points|
        if @on_top
          graphics.set_drawing_color(@color)
          graphics.view.draw2d(GL_QUADS, points.map { |point| graphics.view.screen_coords(point) })
        else
          graphics.draw_quads(
            points: points,
            fill_color: @color)
        end
      end
    end

  end

end