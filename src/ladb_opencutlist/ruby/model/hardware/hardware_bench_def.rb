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

    TOPOLOGY_CORNER = 'corner'.freeze         # b flat, a on its edge on it at b's end : b's edge flush with a's outer face
    TOPOLOGY_FLAT_EDGE = 'flat_edge'.freeze   # b flat, a on its edge on it
    TOPOLOGY_EDGE_EDGE = 'edge_edge'.freeze   # Both on edge, edge to edge
    TOPOLOGY_FLAT_FLAT = 'flat_flat'.freeze   # Face to face

    # A hinge : its kind - the context its variants are selected by, see
    # SmartJoinAddHingesActionHandler#_get_hardware_context.
    TOPOLOGY_OVERLAY = 'overlay'.freeze
    TOPOLOGY_HALF_OVERLAY = 'half_overlay'.freeze
    TOPOLOGY_INSET = 'inset'.freeze

    # The topologies where a and b play different parts - one flat, the
    # other on edge - : they can be swapped - a flat then.
    SWAPPABLE_TOPOLOGIES = [ TOPOLOGY_CORNER, TOPOLOGY_FLAT_EDGE ].freeze

    # The topologies of the types the bench can show, the first by default.
    TOPOLOGIES = {
      HardwareDescriptorDef::TYPE_CONNECTOR => [ TOPOLOGY_CORNER, TOPOLOGY_FLAT_EDGE, TOPOLOGY_EDGE_EDGE, TOPOLOGY_FLAT_FLAT ],
      HardwareDescriptorDef::TYPE_HINGE => [ TOPOLOGY_OVERLAY, TOPOLOGY_HALF_OVERLAY, TOPOLOGY_INSET ],
    }.freeze

    # The dimensions of the panels - Floats, Lengths would go to the JSON as strings
    PANEL_LENGTH = 170.mm.to_f   # Along the joint
    PANEL_WIDTH = 100.mm.to_f    # Of a panel on edge : its thickness as a measure
    PANEL_DEPTH = 120.mm.to_f    # Of a flat panel, across the joint
    SIDE_DEPTH = 150.mm.to_f     # Of the side a hinge is laid on, from the door
    DOOR_GAP = 2.mm.to_f         # Between a door's edge and the side's outer face - or the inner one, inset

    # A panel : the slot it is the part of, its box in the bench frame, and
    # its reference face - the one the tool picks - as [ axis, side ] : the
    # index of the axis it is normal to and 'min' or 'max' of the box along
    # it, nil for none.
    PanelDef = Struct.new(:slot, :min, :max, :reference)

    attr_reader :type, :topology, :thickness_a, :thickness_b, :swapped

    def self.supported?(type)
      TOPOLOGIES.key?(type)
    end

    # topology : one of the type's - its first when nil ; thickness_a,
    # thickness_b : of the panels, in inches ; swapped : a flat and b on
    # edge instead, where the topology can be - see swappable? ; height :
    # the connector's height option - a length in inches, or a factor of
    # the joint's height as '/n' or '*f' - half of it when nil, see
    # SmartJoinAddConnectorsActionHandler.
    def initialize(type, topology, thickness_a, thickness_b, swapped = false, height = nil)
      @type = type
      topologies = TOPOLOGIES[type] || []
      @topology = topology.nil? ? topologies.first : topology.to_s
      @thickness_a = thickness_a.to_f
      @thickness_b = thickness_b.to_f
      @swapped = swapped == true && swappable?
      @height = height
    end

    def swappable?
      !hinge? && SWAPPABLE_TOPOLOGIES.include?(@topology)
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
          # The faces whose planes meet on the joint line : the door's back
          # and the side's inner face - see SmartJoinAddFittingsActionHandler
          PanelDef.new('a', [ -l, -PANEL_DEPTH, -@thickness_a ], [ l, _door_edge, 0.0 ], [ 2, 'max' ]),
          PanelDef.new('b', [ -l, 0.0, _side_front ], [ l, @thickness_b, _side_front + SIDE_DEPTH ], [ 1, 'min' ])
        ]
      else
        [ _connector_panel('a', -1), _connector_panel('b', 1) ]
      end
    end

    # How the bench is shown - the transformation from the bench frame to
    # the view's, column after column : the panel on edge of a corner or a
    # T and both of an edge to edge lie horizontal - bench Y up, Z toward
    # the view's -Y.
    def view_transformation
      return _matrix([ 1, 0, 0 ], [ 0, 1, 0 ], [ 0, 0, 1 ]) if hinge? || @topology == TOPOLOGY_FLAT_FLAT
      _matrix([ 1, 0, 0 ], [ 0, 0, 1 ], [ 0, -1, 0 ])
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

    # Where the measures of the joint are taken, to be shown : { 'thickness_a'
    # => [ from, to ], … } - two points of the bench frame, on the end of
    # their panel toward -X. A thickness across its panel - along Z of its
    # laying frame - at its far edge, a height from the joint to that edge -
    # along Y - on its outer face.
    def measure_cotes
      cotes = {}
      panels.each do |panel|
        matrix = slot_transformation(panel.slot)
        height_axis = matrix[4, 3].index { |v| v != 0 }
        height_sign = matrix[4 + height_axis]
        thickness_axis = matrix[8, 3].index { |v| v != 0 }
        base = [ panel.min[0], 0.0, 0.0 ]
        _slot_measures(panel.slot).each do |name, value|
          from = base.dup
          to = base.dup
          if name == HardwareDescriptorDef::VARIABLE_HEIGHT
            outer = panel.min[thickness_axis].abs > panel.max[thickness_axis].abs ? panel.min[thickness_axis] : panel.max[thickness_axis]
            from[thickness_axis] = to[thickness_axis] = outer
            to[height_axis] = height_sign * value
          else
            from[height_axis] = to[height_axis] = height_sign > 0 ? panel.max[height_axis] : panel.min[height_axis]
            from[thickness_axis] = panel.min[thickness_axis]
            to[thickness_axis] = panel.max[thickness_axis]
          end
          cotes["#{name}_#{panel.slot}"] = [ from, to ]
        end
      end
      cotes
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
        # To the far side of its panel : as the panels are laid
        thickness = PANEL_WIDTH unless _flat?(slot)
        height = _connector_y_range(slot)[1] + _connector_y_shift
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
      else slot == (@swapped ? 'a' : 'b')
      end
    end

    # The panel of a connector's slot, on the side of the joint plane sign
    # says : -1 for a, 1 for b.
    def _connector_panel(slot, sign)
      l = PANEL_LENGTH / 2
      z = _flat?(slot) ? (slot == 'a' ? @thickness_a : @thickness_b) : PANEL_WIDTH
      y_min, y_max = _connector_y_range(slot).map { |y| y + _connector_y_shift }
      # a's only : the face along the joint its height is measured from, +Y of
      # its laying frame - see SmartJoinAddConnectorsActionHandler
      reference = slot == 'a' ? [ 1, 'max' ] : nil
      PanelDef.new(slot, [ -l, y_min, sign < 0 ? -z : 0.0 ], [ l, y_max, sign < 0 ? 0.0 : z ], reference)
    end

    # Where the panel of a connector's slot goes along Y, centered on the
    # joint - before _connector_y_shift : [ min, max ].
    def _connector_y_range(slot)
      if _flat?(slot)
        y_max = _flat_max_y(slot)
        [ y_max - PANEL_DEPTH, y_max ]
      else
        y_max = (slot == 'a' ? @thickness_a : @thickness_b) / 2
        [ -y_max, y_max ]
      end
    end

    # How far along Y both panels of a connector move for the anchor - the
    # bench origin - to be where the tool lays it : the height option away
    # from a's reference face - its +Y face - , a length or a factor of the
    # joint's height - where the panels overlap - , see
    # SmartJoinAddConnectorsActionHandler. Where that falls off the joint -
    # a flat, far from b on edge - the tool lays nothing : from the joint's
    # +Y side instead.
    def _connector_y_shift
      a_min, a_max = _connector_y_range('a')
      b_min, b_max = _connector_y_range('b')
      joint_min = [ a_min, b_min ].max
      joint_max = [ a_max, b_max ].min
      if @height.is_a?(Numeric)
        height = @height.to_f
      else
        text = @height.to_s
        factor = if text.start_with?('/') && (divider = text[1..-1].tr(',', '.').to_f) != 0
                   1 / divider
                 elsif text.start_with?('*')
                   text[1..-1].tr(',', '.').to_f
                 else
                   0.5
                 end
        height = (joint_max - joint_min) * factor
      end
      return height - a_max if a_max - height >= joint_min - 1e-9 && a_max - height <= joint_max + 1e-9
      height - joint_max
    end

    # Where a flat panel ends toward +Y : centered on the joint, or - in a
    # corner - flush with the outer face of the other one, on edge.
    def _flat_max_y(slot)
      return (slot == 'a' ? @thickness_b : @thickness_a) / 2 if @topology == TOPOLOGY_CORNER
      PANEL_DEPTH / 2
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
