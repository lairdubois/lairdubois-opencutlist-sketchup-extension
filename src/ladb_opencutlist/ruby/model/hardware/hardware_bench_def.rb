module Ladb::OpenCutList

  require_relative 'hardware_descriptor_def'

  # The test bench of the hardware editor : two fictional panels joined the
  # way the given topology says, where a hardware is laid to be seen and
  # checked. It gives what the tool would take on a real joint - the frames
  # the slots are laid in, the measures - computed from the dimensions of
  # the panels instead of measured. Nothing here reads the model.
  #
  # The bench frame is the laying frame of slot a : the face of a at z = 0,
  # a toward -Z, the joint along X. Lengths are in inches.
  class HardwareBenchDef

    TOPOLOGY_FLAT_EDGE = 'flat_edge'.freeze   # a flat, b on its edge on it
    TOPOLOGY_EDGE_EDGE = 'edge_edge'.freeze   # Both on edge, edge to edge
    TOPOLOGY_FLAT_FLAT = 'flat_flat'.freeze   # Face to face

    # A hinge : its kind - the context its variants are selected by, see
    # SmartJoinAddHingesActionHandler#_get_hardware_context.
    TOPOLOGY_OVERLAY = 'overlay'.freeze
    TOPOLOGY_HALF_OVERLAY = 'half_overlay'.freeze
    TOPOLOGY_INSET = 'inset'.freeze

    # The topologies of the types the bench can show, the first by default.
    TOPOLOGIES = {
      HardwareDescriptorDef::TYPE_CONNECTOR => [ TOPOLOGY_FLAT_EDGE, TOPOLOGY_EDGE_EDGE, TOPOLOGY_FLAT_FLAT ],
      HardwareDescriptorDef::TYPE_HINGE => [ TOPOLOGY_OVERLAY, TOPOLOGY_HALF_OVERLAY, TOPOLOGY_INSET ],
    }.freeze

    # The dimensions of the panels, in inches
    PANEL_LENGTH = 170 / 25.4   # Along the joint
    PANEL_WIDTH = 100 / 25.4    # Of a panel on edge : its thickness as a measure
    PANEL_DEPTH = 120 / 25.4    # Of a flat panel, across the joint
    SIDE_DEPTH = 200 / 25.4     # Of the side a hinge is laid on, from the door
    DOOR_GAP = 2 / 25.4         # Between a door's edge and the side's outer face - or the inner one, inset

    # A panel : the slot it is the part of, its box in the bench frame.
    PanelDef = Struct.new(:slot, :min, :max)

    attr_reader :type, :topology, :thickness_a, :thickness_b

    def self.supported?(type)
      TOPOLOGIES.key?(type)
    end

    # topology : one of the type's - its first when nil ; thickness_a,
    # thickness_b : of the panels, in inches.
    def initialize(type, topology, thickness_a, thickness_b)
      @type = type
      topologies = TOPOLOGIES[type] || []
      @topology = topology.nil? ? topologies.first : topology.to_s
      @thickness_a = thickness_a.to_f
      @thickness_b = thickness_b.to_f
    end

    def valid?
      (TOPOLOGIES[@type] || []).include?(@topology) && @thickness_a > 0 && @thickness_b > 0
    end

    def hinge?
      @type == HardwareDescriptorDef::TYPE_HINGE
    end

    # What the variants are selected by - see HardwareDescriptorDef#resolve_component.
    def context
      hinge? ? { 'hinge_kind' => @topology } : {}
    end

    # The panels, as PanelDefs.
    def panels
      l = PANEL_LENGTH / 2
      if hinge?
        [
          PanelDef.new('a', [ -l, -PANEL_DEPTH, -@thickness_a ], [ l, _door_edge, 0.0 ]),
          PanelDef.new('b', [ -l, 0.0, _side_front ], [ l, @thickness_b, _side_front + SIDE_DEPTH ])
        ]
      else
        [ _connector_panel('a', -1), _connector_panel('b', 1) ]
      end
    end

    # The transformation from the laying frame of the given slot to the
    # bench frame, as the 16 values of a 4x4 matrix, column after column -
    # as Geom::Transformation#to_a and THREE.Matrix4#fromArray.
    #  - connector : b's is a's, Z reversed - a direct, b indirect, see
    #    SmartJoinConnectorsActionHandler ;
    #  - hinge : both direct, X along the joint line - where the door's inner
    #    face meets the side's inner one - Z out of each face, Y = Z × X.
    def slot_transformation(slot)
      return _matrix([ 1, 0, 0 ], [ 0, 1, 0 ], [ 0, 0, 1 ]) unless slot == 'b'
      return _matrix([ 1, 0, 0 ], [ 0, 0, 1 ], [ 0, -1, 0 ]) if hinge?
      _matrix([ 1, 0, 0 ], [ 0, 1, 0 ], [ 0, 0, -1 ])
    end

    # The measures of the joint : { 'thickness_a' => …, 'height_b' => …, … }
    # - see HardwareDescriptorDef::VARIABLES.
    def measures
      measures = {}
      %w[a b].each do |slot|
        _slot_measures(slot).each { |name, value| measures["#{name}_#{slot}"] = value }
      end
      measures
    end

    # The measures a length of the given slot's component can use : the
    # joint's, and the slot's own ones unsuffixed - as the tool gives them
    # at a placement.
    def slot_measures(slot)
      measures.merge(_slot_measures(slot))
    end

    # -----

    private

    # The measures of the given slot's panel, unsuffixed.
    def _slot_measures(slot)
      thickness = slot == 'a' ? @thickness_a : @thickness_b
      if hinge?
        # How far toward +Y of its frame each panel goes from the joint line :
        # the door to its edge, the side to its back.
        height = slot == 'a' ? _door_edge : _side_front + SIDE_DEPTH
      else
        flat = _flat?(slot)
        thickness = PANEL_WIDTH unless flat
        height = flat ? PANEL_DEPTH / 2 : (slot == 'a' ? @thickness_a : @thickness_b) / 2
      end
      {
        HardwareDescriptorDef::VARIABLE_THICKNESS => thickness,
        HardwareDescriptorDef::VARIABLE_THICKNESS_MIN => thickness,
        HardwareDescriptorDef::VARIABLE_THICKNESS_MAX => thickness,
        HardwareDescriptorDef::VARIABLE_HEIGHT => height > 0 ? height : nil,
      }.reject { |_, value| value.nil? }
    end

    # Is the given slot's panel laid flat - its face on the joint - ?
    def _flat?(slot)
      case @topology
      when TOPOLOGY_FLAT_FLAT then true
      when TOPOLOGY_EDGE_EDGE then false
      else slot == 'a'
      end
    end

    # The panel of a connector's slot, on the side of the joint plane sign
    # says : -1 for a, 1 for b.
    def _connector_panel(slot, sign)
      l = PANEL_LENGTH / 2
      thickness = slot == 'a' ? @thickness_a : @thickness_b
      if _flat?(slot)
        y = PANEL_DEPTH / 2
        z = thickness
      else
        y = thickness / 2
        z = PANEL_WIDTH
      end
      PanelDef.new(slot, [ -l, -y, sign < 0 ? -z : 0.0 ], [ l, y, sign < 0 ? 0.0 : z ])
    end

    # Where the door ends toward the side - its edge - : over the side, half
    # over it, or between the sides.
    def _door_edge
      case @topology
      when TOPOLOGY_OVERLAY then @thickness_b - DOOR_GAP
      when TOPOLOGY_HALF_OVERLAY then @thickness_b / 2 - DOOR_GAP / 2
      else -DOOR_GAP
      end
    end

    # Where the side's front edge is along Z : behind the door, or flush with
    # its outer face when it is inset.
    def _side_front
      @topology == TOPOLOGY_INSET ? -@thickness_a : 0.0
    end

    # The matrix of the given axes, no translation - column after column.
    def _matrix(x_axis, y_axis, z_axis)
      (x_axis + [ 0 ]) + (y_axis + [ 0 ]) + (z_axis + [ 0 ]) + [ 0, 0, 0, 1 ]
    end

  end

end
