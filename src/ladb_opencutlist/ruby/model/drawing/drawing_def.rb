module Ladb::OpenCutList

  require_relative '../data_container'

  class DrawingDef < DataContainer

    INPUT_VIEW_CUSTOM = nil
    INPUT_VIEW_TOP = 'top'.freeze
    INPUT_VIEW_BOTTOM = 'bottom'.freeze
    INPUT_VIEW_LEFT = 'left'.freeze
    INPUT_VIEW_RIGHT = 'right'.freeze
    INPUT_VIEW_FRONT = 'front'.freeze
    INPUT_VIEW_BACK = 'back'.freeze

    attr_reader :faces_bounds, :edges_bounds, :clines_bounds, :bounds,
                :face_manipulators, :surface_manipulators, :edge_manipulators, :curve_manipulators, :cline_manipulators
    attr_accessor :transformation, :input_plane_manipulator, :input_line_manipulator, :input_view

    def initialize

      @transformation = Geom::Transformation.new

      @faces_bounds = Geom::BoundingBox.new
      @edges_bounds = Geom::BoundingBox.new
      @clines_bounds = Geom::BoundingBox.new
      @bounds = Geom::BoundingBox.new

      @face_manipulators = []
      @surface_manipulators = []
      @edge_manipulators = []
      @curve_manipulators = []
      @cline_manipulators = []

      @input_plane_manipulator = nil
      @input_line_manipulator = nil
      @input_view = INPUT_VIEW_CUSTOM

    end

    # -----

    def translate_to!(point)
      t = Geom::Transformation.translation(Geom::Vector3d.new(point.to_a))
      transform!(t)
    end

    def transform!(transformation)
      return false if !transformation.is_a?(Geom::Transformation) || transformation.identity?

      ti = transformation.inverse

      @transformation *= transformation
      @input_plane_manipulator.transformation = ti * @input_plane_manipulator.transformation unless @input_plane_manipulator.nil?
      @input_line_manipulator.transformation = ti * @input_line_manipulator.transformation unless @input_line_manipulator.nil?

      unless @faces_bounds.empty?
        min = @faces_bounds.min.transform(ti)
        max = @faces_bounds.max.transform(ti)
        @faces_bounds.clear
        @faces_bounds.add(min, max)
      end

      unless @edges_bounds.empty?
        min = @edges_bounds.min.transform(ti)
        max = @edges_bounds.max.transform(ti)
        @edges_bounds.clear
        @edges_bounds.add(min, max)
      end

      unless @clines_bounds.empty?
        min = @clines_bounds.min.transform(ti)
        max = @clines_bounds.max.transform(ti)
        @clines_bounds.clear
        @clines_bounds.add(min, max)
      end

      unless @bounds.empty?
        min = @bounds.min.transform(ti)
        max = @bounds.max.transform(ti)
        @bounds.clear
        @bounds.add(min, max)
      end

      @face_manipulators.each do |face_manipulator|
        face_manipulator.transformation = ti * face_manipulator.transformation
      end
      @surface_manipulators.each do |surface_manipulator|
        surface_manipulator.transformation = ti * surface_manipulator.transformation
      end

      @edge_manipulators.each do |edge_manipulator|
        edge_manipulator.transformation = ti * edge_manipulator.transformation
      end
      @curve_manipulators.each do |curve_manipulator|
        curve_manipulator.transformation = ti * curve_manipulator.transformation
      end

      @cline_manipulators.each do |cline_manipulator|
        cline_manipulator.transformation = ti * cline_manipulator.transformation
      end

      true
    end

  end

end