module Ladb::OpenCutList::Kuix

  class Entity3d < Entity

    attr_reader :bounds, :extents
    attr_accessor :transformation

    def initialize(id = nil)
      super(id)

      # Bounds relative to parent
      @bounds = Bounds3d.new

      # Transformation relative to parent
      @transformation = IDENTITY

      # Bounding box in 3D world
      @extents = Geom::BoundingBox.new

    end

    # -- DOM --

    # Append a given entity to self and returns self
    def append(entity)
      raise 'Entity3d.append only supports Entity3d' unless entity.is_a?(Entity3d)
      super
    end

    # Prepend a given entity to self and returns self
    def prepend(entity)
      raise 'Entity3d.prepend only supports Entity3d' unless entity.is_a?(Entity3d)
      super
    end

    # -- LAYOUT --

    def do_layout(transformation)
      @extents.clear
      do_layout_content(transformation * @transformation)
      self.invalidated = false
    end

    def do_layout_content(transformation)
      @children.each do |child|
        child.do_layout(transformation)
        @extents.add(child.extents)
      end
    end

  end

  # The part of a depth tested line hidden by the model, drawn on top in its
  # own style : the visible part, drawn after it by the normal pass, covers it.
  # Ignored with on_top, the whole line being already drawn on top.
  module HiddenLinesHelper

    attr_writer :show_hidden_lines,
                :hidden_line_color,
                :hidden_line_stipple,
                :hidden_line_width

    # -- PROPERTIES --

    def show_hidden_lines
      @show_hidden_lines == true
    end

    def hidden_line_color
      @hidden_line_color.nil? ? @color : @hidden_line_color
    end

    def hidden_line_stipple
      @hidden_line_stipple.nil? ? LINE_STIPPLE_LONG_DASHES : @hidden_line_stipple
    end

    def hidden_line_width
      @hidden_line_width.nil? ? 1 : @hidden_line_width
    end

    # -- RENDER --

    protected

    def paint_hidden_lines(graphics, mode, points)
      return if @on_top || !show_hidden_lines || points.empty?
      view = graphics.view
      graphics.set_drawing_color(hidden_line_color) if hidden_line_color.is_a?(Sketchup::Color)
      graphics.set_line_width(hidden_line_width)
      graphics.set_line_stipple(hidden_line_stipple)
      view.draw2d(mode, points.map { |point| view.screen_coords(point) })
    end

  end

  # A depth tested line drawn a few pixels closer to the camera, to win the
  # depth test over the model edges it lies on.
  module DepthOffsetHelper

    attr_writer :depth_offset

    # -- PROPERTIES --

    # Pixels, 0 = none
    def depth_offset
      @depth_offset.nil? ? 0 : @depth_offset
    end

    # -- RENDER --

    protected

    # The +points+ moved along their view ray toward the camera by
    # depth_offset : the same screen position, a nearer depth.
    def depth_offset_points(view, points)
      return points unless depth_offset > 0
      camera = view.camera
      points.map { |point|
        v = camera.perspective? ? point.vector_to(camera.eye) : camera.direction.reverse
        v.valid? ? point.offset(v, view.pixels_to_model(depth_offset, point)) : point
      }
    end

  end

end