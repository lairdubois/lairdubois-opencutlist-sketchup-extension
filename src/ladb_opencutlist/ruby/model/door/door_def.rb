module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../attributes/definition_attributes'
  require_relative '../hardware/hardware_descriptor_def'

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
  #  - 'hinge_pivot' : [ y, z ] length Strings - "17mm" - the fixed axis the
  #    door turns around, parallel to X - a length without a unit is in the
  #    model's one ;
  #  - 'hinge_pivot_approximate' : true when that fixed axis only stands in for
  #    a multi-link hinge whose axis moves while it opens.
  #
  # Everything here is in the door DEFINITION's coordinates.
  class DoorDef < DataContainer

    HINGE_ATTRIBUTE_MAX_ANGLE = HardwareDescriptorDef::ATTRIBUTE_HINGE_MAX_ANGLE
    HINGE_ATTRIBUTE_PIVOT = HardwareDescriptorDef::ATTRIBUTE_HINGE_PIVOT
    HINGE_ATTRIBUTE_PIVOT_APPROXIMATE = HardwareDescriptorDef::ATTRIBUTE_HINGE_PIVOT_APPROXIMATE

    # How far a door stands open is a state of each OCCURRENCE : it lives on
    # the INSTANCE, as [ angle, px, py, pz, vx, vy, vz ] Floats - the angle in
    # degrees and the axis it was turned around, in the door definition's
    # coordinates (inches). The axis is kept rather than read again off the
    # hinges, so the door can always be closed back whatever became of them.
    # The instance really turns : scenes, exports and renders show it open.
    INSTANCE_ATTRIBUTE_OPENING = 'door_opening'.freeze

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

    # -- Opening state --

    # How far the given instance stands open - [ angle, [ point, vector ] ],
    # the axis in its definition's coordinates - nil when it is closed.
    def self.opening_of(instance)
      return nil unless instance.is_a?(Sketchup::ComponentInstance)
      values = instance.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, INSTANCE_ATTRIBUTE_OPENING)
      return nil unless values.is_a?(Array) && values.length == 7 && values.all? { |v| v.is_a?(Numeric) }
      return nil unless values[0] > 0
      vector = Geom::Vector3d.new(values[4..6])
      return nil unless vector.valid?
      [ values[0].to_f, [ Geom::Point3d.new(values[1..3]), vector.normalize ] ]
    end

    def self.open?(instance)
      !opening_of(instance).nil?
    end

    # The transformation the given instance has once closed back.
    def self.closed_transformation(instance)
      transformation = instance.transformation
      return transformation if (opening = opening_of(instance)).nil?
      angle, axis_line = opening
      transformation * Geom::Transformation.rotation(axis_line[0], axis_line[1], -angle.degrees)
    end

    # The transformation the given instance has once open by the given angle
    # in degrees around the given axis - see #set_opening.
    def self.opened_transformation(instance, angle, axis_line)
      transformation = closed_transformation(instance)
      return transformation unless angle.to_f > 0
      transformation * Geom::Transformation.rotation(axis_line[0], axis_line[1], angle.to_f.degrees)
    end

    # Turns the given instance so that it stands open by the given angle in
    # degrees around the given axis - [ point, vector ] in its definition's
    # coordinates - closing it back first if it was open. An angle of 0, or no
    # axis while it was closed, leaves it closed. To call inside an operation.
    def self.set_opening(instance, angle, axis_line = nil)
      return false unless instance.is_a?(Sketchup::ComponentInstance)

      opening = opening_of(instance)
      axis_line = opening[1] if axis_line.nil? && !opening.nil?

      angle = angle.to_f
      if angle > 0 && axis_line.is_a?(Array)
        transformation = opened_transformation(instance, angle, axis_line)
        point, vector = axis_line
        instance.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, INSTANCE_ATTRIBUTE_OPENING, [ angle ] + point.to_a.map(&:to_f) + vector.to_a.map(&:to_f))
      elsif opening.nil?
        return false
      else
        transformation = closed_transformation(instance)
        instance.delete_attribute(Plugin::ATTRIBUTE_DICTIONARY, INSTANCE_ATTRIBUTE_OPENING)
      end

      instance.transformation = transformation
      true
    end

    # Closes the given instance back, whether it is a door or not any more.
    # Returns whether it was open. To call inside an operation.
    def self.close(instance)
      set_opening(instance, 0)
    end

    # The instances standing open in the given model. Only the definitions
    # hinges are glued into are searched : a door is found through its hinges'
    # instances, whose parent is its definition.
    def self.open_instances(model)
      return [] unless model.is_a?(Sketchup::Model)
      model.definitions
           .select { |definition| DefinitionAttributes.role_of(definition) == DefinitionAttributes::ROLE_HINGE }
           .flat_map(&:instances)
           .map(&:parent)
           .grep(Sketchup::ComponentDefinition)
           .uniq
           .flat_map(&:instances)
           .select { |instance| open?(instance) }
    end

    # Closes back all the instances standing open in the given model, in an
    # operation of its own. Returns how many were closed.
    def self.close_all(model)
      instances = open_instances(model)
      return 0 if instances.empty?
      model.start_operation('OCL Close Doors', true)
      instances.each { |instance| close(instance) }
      model.commit_operation
      instances.length
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
      pivot = HardwareDescriptorDef.hinge_pivot(definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, DoorDef::HINGE_ATTRIBUTE_PIVOT))
      return nil unless HardwareDescriptorDef.hinge_max_angle?(max_angle)
      return nil if pivot.nil?

      approximate = definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, DoorDef::HINGE_ATTRIBUTE_PIVOT_APPROXIMATE) == true

      DoorHingeDef.new(instance, transformation, max_angle.to_f, pivot[0], pivot[1], approximate)
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
