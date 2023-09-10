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
      @segments = nil
    end

    # -----

    def start_point
      points.first
    end

    def end_point
      points.last
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

    def xradius
      self.xaxis.length
    end

    def yradius
      self.yaxis.length
    end

    def start_angle
      @arc_curve.start_angle
    end

    def end_angle
      @arc_curve.end_angle
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

    # -----

    def to_s
      [
        "ARCCURVE from #{self.start} to #{self.end}",
        "- #{@arc_curve.count_edges} edges",
        "- circular? = #{circular?}",
        "- center = #{center}",
        "- xaxis = #{xaxis}",
        "- xaxis angle = #{xaxis.angle_between(X_AXIS).radians}",
        "- yaxis = #{yaxis}",
        "- radius = #{@arc_curve.radius}",
        "- xradius = #{xradius}",
        "- yradius = #{yradius}",
        "- start_angle = #{start_angle.radians}",
        "- end_angle = #{end_angle.radians}",
      ].join("\n")
    end

  end

end
