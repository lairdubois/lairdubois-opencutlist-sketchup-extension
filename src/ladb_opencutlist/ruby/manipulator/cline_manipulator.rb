module Ladb::OpenCutList

  require_relative 'line_manipulator'

  class ClineManipulator < LineManipulator

    def initialize(cline, transformation = IDENTITY)
      super([ cline.position, cline.direction ], transformation)
      raise "cline must be a Sketchup::ConstructionLine." unless cline.is_a?(Sketchup::ConstructionLine)
      @cline = cline
    end

    # -----

    def reset_cache
      super
      @start_point = nil
      @end_point = nil
      @middle_point = nil
      @third_points = nil
      @points = nil
    end
    
    # -----

    def infinite?
      @cline.start.nil?
    end

    def start_point
      return nil if infinite?
      @start_point = @cline.start.transform(@transformation) if @start_point.nil?
      @start_point
    end

    def end_point
      return nil if infinite?
      @end_point = @cline.end.transform(@transformation) if @end_point.nil?
      @end_point
    end

    def middle_point
      return nil if infinite?
      if @middle_point.nil?
        @middle_point = Geom::linear_combination(0.5, start_point, 0.5, end_point)# start_point.offset(v, v.length / 2.0)
      end
      @middle_point
    end

    def third_points
      return nil if infinite?
      if @third_points.nil?
        @third_points = [
          Geom::linear_combination(1 / 3.0, start_point, 2 / 3.0, end_point),
          Geom::linear_combination(2 / 3.0, start_point, 1 / 3.0, end_point),
        ]
      end
      @third_points
    end

    def points
      @points = [ start_point, end_point ] if @points.nil?
      @points
    end

    alias_method :segment, :points

    def length
      return 0 if infinite?
      (end_point - start_point).length
    end

    # -----

    def to_s
      [
        "CLINE",
        "- start_point = #{start_point}",
        "- end_point = #{end_point}",
      ].join("\n")
    end

  end

end
