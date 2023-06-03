module Ladb::OpenCutList::Kuix

  class AxesHelper < Group

    attr_accessor :box_0, :box_x, :box_y, :box_z

    def initialize(pixel_size = 40, line_width = 5, x_color = COLOR_X, y_color = COLOR_Y, z_color = COLOR_Z, id = '')
      super(id)

      @pixel_size = pixel_size

      @box_0 = BoxFillMotif.new
      @box_0.bounds.size.set!(0.05, 0.05, 0.05)
      @box_0.bounds.origin.set!(-0.025, -0.025, -0.025)
      @box_0.color = COLOR_BLACK
      append(@box_0)

      @box_x = BoxFillMotif.new
      @box_x.bounds.size.set!(1, 0.05, 0.05)
      @box_x.bounds.origin.set!(0.025, -0.025, -0.025)
      @box_x.color = x_color
      append(@box_x)

      @box_y = BoxFillMotif.new
      @box_y.bounds.size.set!(0.05, 1, 0.05)
      @box_y.bounds.origin.set!(-0.025, 0.025, -0.025)
      @box_y.color = y_color
      append(@box_y)

      @box_z = BoxFillMotif.new
      @box_z.bounds.size.set!(0.05, 0.05, 1)
      @box_z.bounds.origin.set!(-0.025, -0.025, 0.025)
      @box_z.color = z_color
      append(@box_z)

    end

    # -- LAYOUT --

    def do_layout(transformation)
      inch_size = Sketchup.active_model.active_view.pixels_to_model(@pixel_size, Geom::Point3d.new.transform(transformation))
      line_transformation = Geom::Transformation.scaling(inch_size, inch_size, inch_size)
      @box_0.transformation = line_transformation
      @box_x.transformation = line_transformation
      @box_y.transformation = line_transformation
      @box_z.transformation = line_transformation
      super
    end

  end

end