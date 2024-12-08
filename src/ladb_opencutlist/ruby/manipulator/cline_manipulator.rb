module Ladb::OpenCutList

  require_relative 'transformation_manipulator'

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
        v = end_point - start_point
        @middle_point = start_point.offset(v, v.length / 2.0)
      end
      @middle_point
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
