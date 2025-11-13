module Ladb::OpenCutList

  require_relative '../data_container'

  class DrawingContainerDef < DataContainer

    attr_accessor :transformation
    attr_reader :face_manipulators, :surface_manipulators, :edge_manipulators, :curve_manipulators, :cline_manipulators,
                :container, :container_defs

    def initialize(container, transformation = IDENTITY)

      @container = container
      @transformation = transformation

      @bounds = nil
      @faces_bounds = nil
      @edges_bounds = nil
      @clines_bounds = nil

      @face_manipulators = []
      @surface_manipulators = []
      @edge_manipulators = []
      @curve_manipulators = []
      @cline_manipulators = []

      @container_defs = []

    end

    # -----

    def is_root?
      false
    end

    # -----

    def bounds
      _compute_bounds if @bounds.nil?
      @bounds
    end

    def faces_bounds
      _compute_bounds if @bounds.nil?
      @faces_bounds
    end

    def edges_bounds
      _compute_bounds if @bounds.nil?
      @edges_bounds
    end

    def clines_bounds
      _compute_bounds if @bounds.nil?
      @clines_bounds
    end

    # -----

    def transform!(transformation)
      return false if !transformation.is_a?(Geom::Transformation) || transformation.identity?

      ti = transformation.inverse

      if is_root?
        @transformation *= transformation
      else
        @transformation = ti * @transformation
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

      @container_defs.each do |container_def|
        container_def.transform!(transformation)
      end

      _reset_bounds
      true
    end

    # -----

    private

    def _reset_bounds

      @bounds = nil
      @faces_bounds = nil
      @edges_bounds = nil
      @clines_bounds = nil

      @container_defs.each do |container_def|
        container_def._reset_bounds
      end

    end

    def _compute_bounds

      # Note that bounds are expressed in the root container coordinate system
      # and represent the entire tree content from the current container

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

      @container_defs.each do |container_def|
        @bounds.add(container_def.bounds) if container_def.bounds.valid?
        @faces_bounds.add(container_def.faces_bounds) if container_def.faces_bounds.valid?
        @edges_bounds.add(container_def.edges_bounds) if container_def.edges_bounds.valid?
        @clines_bounds.add(container_def.clines_bounds) if container_def.clines_bounds.valid?
      end

    end

  end

  class DrawingDef < DrawingContainerDef

    INPUT_VIEW_CUSTOM = nil
    INPUT_VIEW_TOP = 'top'.freeze
    INPUT_VIEW_BOTTOM = 'bottom'.freeze
    INPUT_VIEW_LEFT = 'left'.freeze
    INPUT_VIEW_RIGHT = 'right'.freeze
    INPUT_VIEW_FRONT = 'front'.freeze
    INPUT_VIEW_BACK = 'back'.freeze

    attr_accessor :input_plane_manipulator, :input_line_manipulator, :input_view

    def initialize(container)
      super

      @input_plane_manipulator = nil
      @input_line_manipulator = nil
      @input_view = INPUT_VIEW_CUSTOM

    end

    # -----

    def is_root?
      true
    end

    # -----

    def translate_to!(point)
      t = Geom::Transformation.translation(Geom::Vector3d.new(point.to_a))
      transform!(t)
    end

    def transform!(transformation)
      return false unless super(transformation)

      ti = transformation.inverse

      @input_plane_manipulator.transformation = ti * @input_plane_manipulator.transformation unless @input_plane_manipulator.nil?
      @input_line_manipulator.transformation = ti * @input_line_manipulator.transformation unless @input_line_manipulator.nil?

      true
    end

  end

end