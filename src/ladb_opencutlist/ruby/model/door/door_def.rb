module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../attributes/definition_attributes'

  # A DOOR : a part that turns on its hinges.
  #
  # Nothing is stored on the door itself - see DefinitionAttributes, ROLE. A
  # part is a door because hinges are glued into its definition : fittings laid
  # by SmartJoinTool (ACTION_ADD_FITTINGS) whose hardware definition bears the
  # ROLE_HINGE role. Where it turns is read off those hinges, so it follows the
  # part whatever reshapes it, and a mirrored pair of doors gets opposite
  # hinged edges for free.
  #
  # Each hinge definition bears, in its library SKP, the data of its own
  # kinematics, in the FITTING FRAME (see SmartJoinTool#_get_add_joinery_def) :
  # X along the joint line, +Y towards the hinged edge, +Z into the carcass,
  # the origin on the joint line on the door's back face.
  #  - 'hinge_max_angle' : Float, the widest opening in degrees ;
  #  - 'hinge_pivot' : [ y, z ] Floats in mm, the fixed axis the door turns
  #    around, parallel to X ;
  #  - 'hinge_pivot_approximate' : true when that fixed axis only stands in for
  #    a multi-link hinge whose axis moves while it opens.
  #
  # Everything here is in the door DEFINITION's coordinates.
  class DoorDef < DataContainer

    HINGE_ATTRIBUTE_MAX_ANGLE = 'hinge_max_angle'.freeze
    HINGE_ATTRIBUTE_PIVOT = 'hinge_pivot'.freeze
    HINGE_ATTRIBUTE_PIVOT_APPROXIMATE = 'hinge_pivot_approximate'.freeze

    # How far apart two hinges' pivots may lie and still turn on the same axis.
    AXIS_TOLERANCE = 0.1.mm

    attr_reader :definition,
                :hinge_defs   # Array<DoorHingeDef>, never empty

    # The door the given definition - or instance, read through its definition -
    # is, nil when no hinge is glued into it.
    #
    # Only the hinges glued DIRECTLY into the definition count : that is where
    # SmartJoinTool lays them, next to the faces of the part.
    def self.from(entity)
      definition = entity.respond_to?(:definition) ? entity.definition : entity
      return nil unless definition.is_a?(Sketchup::ComponentDefinition)

      hinge_defs = definition.entities.grep(Sketchup::ComponentInstance).map { |instance| DoorHingeDef.from(instance) }.compact
      return nil if hinge_defs.empty?

      DoorDef.new(definition, hinge_defs)
    end

    def initialize(definition, hinge_defs)
      @definition = definition
      @hinge_defs = hinge_defs
    end

    # -----

    # Whether all the hinges turn on one and the same axis, the same way. A
    # door that is not cannot open : its hinges fight each other.
    def coherent?
      return @coherent if defined?(@coherent)
      reference = @hinge_defs.first
      @coherent = @hinge_defs.all? { |hinge_def|
        hinge_def.axis.samedirection?(reference.axis) &&
          hinge_def.pivot.distance_to_line(reference.axis_line) <= AXIS_TOLERANCE
      }
    end

    # The axis the door turns around, in SketchUp's [ point, vector ] form. The
    # vector is oriented so that a POSITIVE rotation (right-hand rule) opens the
    # door - see #opening_transformation. nil unless #coherent?.
    def axis_line
      return nil unless coherent?
      @hinge_defs.first.axis_line
    end

    # The widest opening the door allows, in degrees : its most restrictive
    # hinge's. nil unless #coherent?.
    def max_angle
      return nil unless coherent?
      @hinge_defs.map(&:max_angle).min
    end

    def approximate?
      @hinge_defs.any?(&:approximate?)
    end

    # The rotation that opens the door by the given angle in degrees, clamped
    # to [0, #max_angle] - to apply to the door's instance transformation on
    # the right : instance.transformation * opening_transformation(angle). nil
    # unless #coherent?.
    def opening_transformation(angle)
      return nil unless coherent?
      angle = [ [ angle.to_f, 0.0 ].max, max_angle ].min
      Geom::Transformation.rotation(axis_line[0], axis_line[1], angle.degrees)
    end

  end

  # One HINGE of a door : a glued instance whose definition bears ROLE_HINGE,
  # with the data of its definition (see DoorDef) set in the door definition's
  # coordinates - or in whatever space the frame it is built from is given.
  class DoorHingeDef < DataContainer

    attr_reader :instance,   # Sketchup::ComponentInstance, nil on a hinge only previewed
                :max_angle,  # Float, degrees
                :pivot,      # Geom::Point3d, a point of the axis
                :axis        # Geom::Vector3d, unit, along the axis, oriented to open by a positive rotation

    # The hinge the given instance is, nil when its definition is no hinge or
    # lacks a valid pivot or max angle.
    def self.from(instance)
      return nil unless instance.is_a?(Sketchup::ComponentInstance)
      from_definition(instance.definition, instance.transformation, instance)
    end

    # The hinge the given definition would be once placed by the given fitting
    # frame - what SmartJoinTool previews before gluing any instance - nil when
    # it is no hinge or lacks a valid pivot or max angle.
    def self.from_definition(definition, transformation, instance = nil)
      return nil unless definition.is_a?(Sketchup::ComponentDefinition)
      return nil unless DefinitionAttributes.role_of(definition) == DefinitionAttributes::ROLE_HINGE

      max_angle = definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, DoorDef::HINGE_ATTRIBUTE_MAX_ANGLE)
      pivot = definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, DoorDef::HINGE_ATTRIBUTE_PIVOT)
      return nil unless max_angle.is_a?(Numeric) && max_angle > 0
      return nil unless pivot.is_a?(Array) && pivot.length == 2 && pivot.all? { |v| v.is_a?(Numeric) }

      approximate = definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, DoorDef::HINGE_ATTRIBUTE_PIVOT_APPROXIMATE) == true

      DoorHingeDef.new(instance, transformation, max_angle.to_f, pivot[0].to_f.mm, pivot[1].to_f.mm, approximate)
    end

    def initialize(instance, transformation, max_angle, pivot_y, pivot_z, approximate)
      @instance = instance
      @max_angle = max_angle
      @approximate = approximate

      # The fitting frame puts the door's back face at Z = 0, its body towards
      # -Y and the carcass towards +Z : the door opens by turning its body
      # (-Y) out of the carcass (-Z), i.e. positively around Y x Z - which is
      # +X, but read from the transformed Y and Z axes it holds on a mirrored
      # hinge too.
      t = transformation
      @pivot = Geom::Point3d.new(0, pivot_y, pivot_z).transform(t)
      @axis = (t.yaxis * t.zaxis).normalize
    end

    # -----

    def approximate?
      @approximate
    end

    def axis_line
      [ @pivot, @axis ]
    end

  end

end
