module Ladb::OpenCutList

  require_relative 'manipulator'

  class LineManipulator < Manipulator

    def initialize(line, transformation = IDENTITY)
      super(transformation)
      raise "Bad line data structure. Must be an Array." unless line.is_a?(Array)
      if line.length == 2
        raise "Bad plane data structure. Must be [ Geom::Point3d, Geom::Vector3d ]." unless line[0].is_a?(Geom::Point3d) && line[1].is_a?(Geom::Vector3d)
        @line_point = line[0]
        @line_vector = line[1]
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

    def infinite?
      true
    end

    def line
      @line ||= [ position, direction ]
      @line
    end

    def position
      @position ||= @line_point.transform(@transformation)
      @position
    end

    def direction
      @direction ||= @line_vector.transform(@transformation).normalize!
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
