module Ladb::OpenCutList::Kuix

  class AxesHelper < Group

    def initialize(size = 40, line_width = 5, x_color = KuixTool::COLOR_RED, y_color = KuixTool::COLOR_GREEN, z_color = KuixTool::COLOR_BLUE, id = '')
      super(id)

      view = Sketchup.active_model.active_view
      line_length = view.pixels_to_model(size, view.guess_target)

      # X axis
      line_x = Line.new
      line_x.end.set!(line_length, 0, 0)
      line_x.color = x_color
      line_x.line_width = line_width
      append(line_x)

      # Y axis
      line_y = Line.new
      line_y.end.set!(0, line_length, 0)
      line_y.color = y_color
      line_y.line_width = line_width
      append(line_y)

      # Z axis
      line_z = Line.new
      line_z.end.set!(0, 0, line_length)
      line_z.color = z_color
      line_z.line_width = line_width
      append(line_z)

    end

  end

end