module Ladb::OpenCutList

  require_relative 'transformation_manipulator'

  class LineManipulator < TransformationManipulator

    def initialize(line, transformation = IDENTITY)
      super(transformation)
      raise "Bad line data structure. Must be an Array." unless line.is_a?(Array)
      if line.length == 2
        raise "Bad plane data structure. Must be [ Geom::Point3d, Geom::Vector3d ]." if !line[0].is_a?(Geom::Point3d) || !line[1].is_a?(Geom::Vector3d)
        @line_position = line[0]
        @line_direction = line[1]
      else
        raise "Bad line data structure. Must be [ Geom::Point3d, Geom::Vector3d ]."
      end
    end

    # -----

    def reset_cache
      super
      @line = nil
      @position = nil
      @direction = nil
    end
    
    # -----

    def line
      @line = [ position, direction ] if @line.nil?
      @line
    end

    def position
      @position = @line_position.transform(@transformation) if @position.nil?
      @position
    end

    def direction
      @direction = @line_direction.transform(@transformation).normalize if @direction.nil?
      @direction
    end

    # -----

    def to_s
      [
        "LINE",
        "- position = #{position}",
        "- direction = #{direction}",
      ].join("\n")
    end

  end

end
