module Ladb::OpenCutList::Kuix

  class AxesHelper < Group

    def initialize(id = '')
      super(id)

      view = Sketchup.active_model.active_view
      line_length = view.pixels_to_model(30, view.guess_target)
      line_width = 5

      # X axis
      line = Line.new
      line.bounds.size.set!(line_length, 0, 0)
      line.color = Sketchup::Color.new(255, 0, 0)
      line.line_width = line_width
      append(line)

      # Y axis
      line = Line.new
      line.bounds.size.set!(0, line_length, 0)
      line.color = Sketchup::Color.new(0, 255, 0)
      line.line_width = line_width
      append(line)

      # Z axis
      line = Line.new
      line.bounds.size.set!(0, 0, line_length)
      line.color = Sketchup::Color.new(0, 0, 255)
      line.line_width = line_width
      append(line)

    end

  end

end