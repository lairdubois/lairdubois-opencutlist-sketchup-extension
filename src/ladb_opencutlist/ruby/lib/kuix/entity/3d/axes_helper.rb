module Ladb::OpenCutList::Kuix

  class AxesHelper < Group

    def initialize(id = '')
      super(id)

      view = Sketchup.active_model.active_view
      line_length = view.pixels_to_model(30, view.guess_target)
      line_width = 5

      # X axis
      line_x = Line.new
      line_x.bounds.size.set!(line_length, 0, 0)
      line_x.color = Sketchup::Color.new(255, 0, 0)
      line_x.line_width = line_width
      append(line_x)

      # Y axis
      line_y = Line.new
      line_y.bounds.size.set!(0, line_length, 0)
      line_y.color = Sketchup::Color.new(0, 255, 0)
      line_y.line_width = line_width
      append(line_y)

      # Z axis
      line_z = Line.new
      line_z.bounds.size.set!(0, 0, line_length)
      line_z.color = Sketchup::Color.new(0, 0, 255)
      line_z.line_width = line_width
      append(line_z)

    end

  end

end