module Ladb::OpenCutList::Kuix

  class AxesHelper < Group

    def initialize(pixel_size = 40, line_width = 5, x_color = KuixTool::COLOR_RED, y_color = KuixTool::COLOR_GREEN, z_color = KuixTool::COLOR_BLUE, id = '')
      super(id)

      @pixel_size = pixel_size

      # X axis
      @line_x = LineMotif.new
      @line_x.end.set!(1, 0, 0)
      @line_x.color = x_color
      @line_x.line_width = line_width
      append(@line_x)

      # Y axis
      @line_y = LineMotif.new
      @line_y.end.set!(0, 1, 0)
      @line_y.color = y_color
      @line_y.line_width = line_width
      append(@line_y)

      # Z axis
      @line_z = LineMotif.new
      @line_z.end.set!(0, 0, 1)
      @line_z.color = z_color
      @line_z.line_width = line_width
      append(@line_z)

    end

    # -- LAYOUT --

    def do_layout(transformation)
      inch_size = Sketchup.active_model.active_view.pixels_to_model(@pixel_size, Geom::Point3d.new.transform(transformation))
      line_transformation = Geom::Transformation.scaling(inch_size, inch_size, inch_size)
      @line_x.transformation = line_transformation
      @line_y.transformation = line_transformation
      @line_z.transformation = line_transformation
      super
    end

  end

end