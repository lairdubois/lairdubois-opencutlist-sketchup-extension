module Ladb::OpenCutList

  require_relative 'manipulator'

  class ArcCurveManipulator < Manipulator

    attr_reader :arc_curve

    def initialize(arc_curve, transformation = Geom::Transformation.new)
      super(transformation)
      @arc_curve = arc_curve
    end

    # -----

    def reset_cache
      super
      @center = nil
      @points = nil
      @xaxis = nil
      @yaxis = nil
      @vertex_xaxis = nil
      @vertex_yaxis = nil
      @vertex_angle = nil
      @xradius = nil
      @yradius = nil
      @segments = nil
    end

    # -----

    def start_point
      self.points.first
    end

    def end_point
      self.points.last
    end

    def center
      if @center.nil?
        @center = @arc_curve.center.transform(@transformation)
      end
      @center
    end

    def points
      if @points.nil?
        @points = @arc_curve.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @points.reverse! if TransformationUtils.flipped?(@transformation)
      end
      @points
    end

    def xaxis
      if @xaxis.nil?
        @xaxis = @arc_curve.xaxis.transform(@transformation)
      end
      @xaxis
    end

    def yaxis
      if @yaxis.nil?
        @yaxis = @arc_curve.yaxis.transform(@transformation)
      end
      @yaxis
    end

    def vertex_xaxis
      if @vertex_xaxis.nil?
        @vertex_xaxis = Geom::Vector3d.new(ellipse_point_at_angle(self.vertex_angle).to_a)
      end
      @vertex_xaxis
    end

    def vertex_yaxis
      if @vertex_yaxis.nil?
        @vertex_yaxis = Geom::Vector3d.new(ellipse_point_at_angle(self.vertex_angle + Math::PI / 2).to_a)
      end
      @vertex_yaxis
    end

    def vertex_angle
      if @vertex_angle.nil?
        @vertex_angle = 0.5 * Math.atan2(self.xaxis.dot(self.yaxis) * 2, self.xaxis.dot(self.xaxis) - self.yaxis.dot(self.yaxis))
      end
      @vertex_angle
    end

    def start_angle
      @arc_curve.start_angle
    end

    def end_angle
      @arc_curve.end_angle
    end

    def xradius
      if @xradius.nil?
        @xradius = self.vertex_xaxis.length
      end
      @xradius
    end

    def yradius
      if @yradius.nil?
        @yradius = self.vertex_yaxis.length
      end
      @yradius
    end

    def segments
      if @segments.nil?
        @segments = []
        @arc_curve.each_edge do |edge|
          @segments.concat(EdgeManipulator.new(edge, @transformation).segment)
        end
      end
      @segments
    end

    # -----

    def reversed_in?(face)
      @arc_curve.first_edge.reversed_in?(face)
    end

    def circular?
      @arc_curve.circular?
    end

    def ellipse_point_at_angle(angle, absolute = false)
      vx = Geom::Vector3d.new(self.xaxis.x * Math.cos(angle), self.xaxis.y * Math.cos(angle), 0)
      vy = Geom::Vector3d.new(self.yaxis.x * Math.sin(angle), self.yaxis.y * Math.sin(angle), 0)
      v = vx + vy
      v = v + Geom::Vector3d.new(center.to_a) if absolute
      Geom::Point3d.new(v.to_a)
    end

    # -----

    def to_s
      [
        "ARCCURVE from #{self.start_point} to #{self.end_point}",
        "- #{@arc_curve.count_edges} edges",
        "- circular? = #{circular?}",
        "- center = #{center}",
        "- vertex_xaxis_angle = #{vertex_xaxis.angle_between(X_AXIS).radians}",
        "- vertex_xaxis = #{vertex_xaxis}",
        "- vertex_yaxis = #{vertex_yaxis}",
        "- radius = #{@arc_curve.radius}",
        "- xradius = #{xradius}",
        "- yradius = #{yradius}",
        "- start_angle = #{start_angle.radians}",
        "- end_angle = #{end_angle.radians}",
      ].join("\n")
    end

  end

end
