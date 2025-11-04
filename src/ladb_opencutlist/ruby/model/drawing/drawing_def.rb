module Ladb::OpenCutList

  require_relative '../data_container'

  class DrawingContentDef < DataContainer

    attr_accessor :transformation
    attr_reader :face_manipulators, :surface_manipulators, :edge_manipulators, :curve_manipulators, :cline_manipulators

    def initialize

      @transformation = Geom::Transformation.new

      @bounds = nil
      @faces_bounds = nil
      @edges_bounds = nil
      @clines_bounds = nil

      @face_manipulators = []
      @surface_manipulators = []
      @edge_manipulators = []
      @curve_manipulators = []
      @cline_manipulators = []

    end

    # -----

    def bounds
      compute_bounds if @bounds.nil?
      @bounds
    end

    def faces_bounds
      compute_bounds if @bounds.nil?
      @faces_bounds
    end

    def edges_bounds
      compute_bounds if @bounds.nil?
      @edges_bounds
    end

    def clines_bounds
      compute_bounds if @bounds.nil?
      @clines_bounds
    end

    # -----

    def transform!(transformation)
      return false if !transformation.is_a?(Geom::Transformation) || transformation.identity?

      @transformation *= transformation

      transform_manipulators!(transformation)
      reset_bounds
      true
    end

    def transform_manipulators!(transformation)
      return false if !transformation.is_a?(Geom::Transformation) || transformation.identity?

      ti = transformation.inverse

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

    # -----

    def reset_bounds
      @bounds = nil
      @faces_bounds = nil
      @edges_bounds = nil
      @clines_bounds = nil
    end

    def compute_bounds

      @bounds = Geom::BoundingBox.new
      @faces_bounds = Geom::BoundingBox.new
      @edges_bounds = Geom::BoundingBox.new
      @clines_bounds = Geom::BoundingBox.new

      @face_manipulators.each do |face_manipulator|
        @faces_bounds.add(face_manipulator.outer_loop_manipulator.points)
      end
      @bounds.add(@faces_bounds) if @faces_bounds.valid?

      @edge_manipulators.each do |edge_manipulator|
        @edges_bounds.add(edge_manipulator.points)
      end
      @curve_manipulators.each do |curve_manipulator|
        @edges_bounds.add(curve_manipulator.points)
      end
      @bounds.add(@edges_bounds) if @edges_bounds.valid?

      @cline_manipulators.each do |cline_manipulator|
        @clines_bounds.add(cline_manipulator.points) unless cline_manipulator.infinite?
      end
      @bounds.add(@clines_bounds) if @clines_bounds.valid?

    end

  end

  class DrawingDef < DrawingContentDef

    INPUT_VIEW_CUSTOM = nil
    INPUT_VIEW_TOP = 'top'.freeze
    INPUT_VIEW_BOTTOM = 'bottom'.freeze
    INPUT_VIEW_LEFT = 'left'.freeze
    INPUT_VIEW_RIGHT = 'right'.freeze
    INPUT_VIEW_FRONT = 'front'.freeze
    INPUT_VIEW_BACK = 'back'.freeze

    attr_reader :tree_content_defs
    attr_accessor :input_plane_manipulator, :input_line_manipulator, :input_view

    def initialize
      super

      @tree_content_defs = {}

      @input_plane_manipulator = nil
      @input_line_manipulator = nil
      @input_view = INPUT_VIEW_CUSTOM

    end

    # -----

    def add_container(path, transformation = IDENTITY)
      unless @tree_content_defs.has_key?(path)
        @tree_content_defs[path] = DrawingContentDef.new
        @tree_content_defs[path].transformation = transformation
      end
    end

    def add_manipulator(symbol, manipulator, container_path = nil)
      send(symbol) << manipulator
      container_path
        .map.with_index { |_, i| container_path.take(i + 1) }
        .each { |path|
        unless (content_def = @tree_content_defs[path]).nil?
          content_def.send(symbol) << manipulator
        end
      } unless container_path.nil?
    end

    # -----

    def translate_to!(point)
      t = Geom::Transformation.translation(Geom::Vector3d.new(point.to_a))
      transform!(t)
    end

    def transform!(transformation)
      return false if !transformation.is_a?(Geom::Transformation) || transformation.identity?

      ti = transformation.inverse

      @input_plane_manipulator.transformation = ti * @input_plane_manipulator.transformation unless @input_plane_manipulator.nil?
      @input_line_manipulator.transformation = ti * @input_line_manipulator.transformation unless @input_line_manipulator.nil?

      super
      @tree_content_defs.each do |_, content_def|
        content_def.transformation *= transformation
        content_def.reset_bounds
      end

      true
    end

  end

end