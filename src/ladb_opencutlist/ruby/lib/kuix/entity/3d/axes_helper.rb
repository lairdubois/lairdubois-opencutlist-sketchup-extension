module Ladb::OpenCutList::Kuix

  class AxesHelper < Group

    attr_accessor :box_0, :box_x, :box_y, :box_z

    def initialize(pixel_size = 50, color_0 = COLOR_BLACK, color_x = COLOR_X, color_y = COLOR_Y, color_z = COLOR_Z, id = '')
      super(id)

      @pixel_size = pixel_size

      @box_0 = BoxFillMotif.new
      @box_0.bounds.size.set!(0.05, 0.05, 0.05)
      @box_0.bounds.origin.set!(-0.025, -0.025, -0.025)
      @box_0.color = color_0
      append(@box_0)

      @box_x = BoxFillMotif.new
      @box_x.bounds.size.set!(1, 0.05, 0.05)
      @box_x.bounds.origin.set!(0.025, -0.025, -0.025)
      @box_x.color = color_x
      append(@box_x)

      @box_y = BoxFillMotif.new
      @box_y.bounds.size.set!(0.05, 1, 0.05)
      @box_y.bounds.origin.set!(-0.025, 0.025, -0.025)
      @box_y.color = color_y
      append(@box_y)

      @box_z = BoxFillMotif.new
      @box_z.bounds.size.set!(0.05, 0.05, 1)
      @box_z.bounds.origin.set!(-0.025, -0.025, 0.025)
      @box_z.color = color_z
      append(@box_z)

    end

    # -- LAYOUT --

    def do_layout(transformation)
      inch_size = Sketchup.active_model.active_view.pixels_to_model(@pixel_size, ORIGIN.transform(transformation))
      size_transformation = Geom::Transformation.scaling(inch_size, inch_size, inch_size)
      @box_0.transformation = size_transformation
      @box_x.transformation = size_transformation
      @box_y.transformation = size_transformation
      @box_z.transformation = size_transformation
      super
    end

  end

end