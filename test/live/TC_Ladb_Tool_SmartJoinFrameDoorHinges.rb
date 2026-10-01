# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : the fixtures - a caisson with a frame door, see
# HingeFixture::FRAME_DOORS - are built in it and the model operation they
# are built in is aborted afterwards : the model is left as it was.
#
# What it checks : SmartJoinAddHingesActionHandler lays the hinges on a door
# made of several parts - stiles, rails and a panel held by a component
# bearing ROLE_FRONT_PANEL - hovered on its left stile, each hinge into the
# part under it, and SmartJoinRemoveHingesActionHandler removes them all,
# the door hovered on its panel, which bears none ; the whole door is
# highlighted while hovering - to lay or to remove - and the opening previewed turns around the
# axis the door gets ; SmartHandleInteractActionHandler turns the whole door :
#  - frame          : rails between the stiles - both hinges in the left
#                     stile, made unique : the right one shares its
#                     definition ;
#  - frame_through  : rails across the whole width, 150 mm high - one hinge
#                     in each rail, the top one sharing the bottom one's
#                     definition : made unique too ;
#  - frame_straddle : the bottom rail 100 mm high - its hinge would straddle
#                     the rail and the stile : left out ;
#  - frame_inset    : the frame door set in the mouth - read as inset ;
#  - frame_mirror   : the left stile the right one mirrored - the opening
#                     previewed still turns the door out of the carcass.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartJoinFrameDoorHinges.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartJoinFrameDoorHinges.rb'
#   FrameDoorHingesRegression.run                     # one line per case
require_relative 'hinge_fixture'
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module FrameDoorHingesRegression

  OCL = Ladb::OpenCutList

  CASES = HingeFixture::FRAME_DOORS.keys

  # What each case gives once laid : the kind of the door, the hinges of
  # the door (DoorDef.door_hinge_instances) and of each part, whether it
  # turns (DoorDef.from), on an axis along its left edge, the plates in the
  # left side, whether the parts that shared a definition still do, and
  # whether a hovered stile picks the whole door to interact with.
  LAID = {
    'kind' => :overlay, 'hinges' => 2, 'door' => true, 'axis_left' => true, 'side_l' => 2, 'side_r' => 0,
    'stiles_shared' => false, 'rails_shared' => true, 'interact' => true, 'preview_axis' => true, 'highlight' => true,
  }
  EXPECTED = {
    'frame' => LAID.merge('parts' => { 'STILE_L' => 2 }),
    'frame_through' => LAID.merge('parts' => { 'RAIL_B' => 1, 'RAIL_T' => 1 }, 'stiles_shared' => true, 'rails_shared' => false),
    'frame_straddle' => LAID.merge('hinges' => 1, 'side_l' => 1, 'parts' => { 'RAIL_T' => 1 }, 'rails_shared' => false, 'stiles_shared' => false),
    'frame_inset' => LAID.merge('kind' => :inset, 'parts' => { 'STILE_L' => 2 }),
    'frame_mirror' => LAID.merge('parts' => { 'STILE_L' => 2 }),
  }
  REMOVED = { 'hinges' => 0, 'side_l' => 0, 'highlight' => true }

  # Records the axis each preview of the door opening turns around, in the
  # door definition's space.
  # And the door highlighted.
  module Probe
    def _preview_door_swing(transformation, axis_line, *args)
      (@probe_axis_lines ||= []) << axis_line
      super
    end
    def _preview_door_assembly(door_entity_path, *args)
      (@probe_highlighted ||= []) << door_entity_path.last
      super
    end
  end

  # Whether the given axis line is the one the door turns around.
  def self.same_axis?(door, axis_line)
    door_def = OCL::DoorDef.from(door)
    return false if door_def.nil? || !door_def.coherent? || axis_line.nil?
    point, vector = door_def.axis_line
    vector.samedirection?(axis_line[1]) && axis_line[0].distance_to_line([ point, vector ]).to_mm < 0.01
  end

  def self.state(fixture, spec)
    parts = fixture['parts']
    door_def = OCL::DoorDef.from(fixture['DOOR'])
    left = spec[:box][0]
    {
      'hinges' => OCL::DoorDef.door_hinge_instances(fixture['DOOR']).length,
      'door' => !door_def.nil? && door_def.coherent?,
      'axis_left' => !door_def.nil? && door_def.coherent? && door_def.axis_line[1].parallel?(Z_AXIS) && (door_def.axis_line[0].x.to_mm - left).abs < 40,
      'parts' => parts.map { |name, instance| [ name, OCL::DoorDef.hinge_instances(instance).length ] }.select { |_, count| count > 0 }.to_h,
      'side_l' => fixture['SIDE_L'].definition.entities.count { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) },
      'side_r' => fixture['SIDE_R'].definition.entities.count { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) },
      'stiles_shared' => parts['STILE_L'].definition == parts['STILE_R'].definition,
      'rails_shared' => parts['RAIL_B'].definition == parts['RAIL_T'].definition,
    }
  end

  # Whether SmartHandle's interact, its left stile hovered, picks the door.
  def self.interact_picks_door?(model, fixture, pick)
    tool = OCL::SmartHandleTool.new(current_action: OCL::SmartHandleTool::ACTION_INTERACT)
    model.select_tool(tool)
    handler = tool.instance_variable_get(:@action_handler)
    handler.send(:_pick_part, HingeFixture.picker(fixture, 'STILE_L', pick), model.active_view)
    path = handler.get_active_part_entity_path
    path.is_a?(Array) && path.last == fixture['DOOR']
  ensure
    model.select_tool(nil)
  end

  def self.run_case(model, descriptor_path, id)
    messages = []
    spec = HingeFixture::FRAME_DOORS[id]
    pick = spec[:pick] || HingeFixture::PICK_POINT
    fixture = HingeFixture.build(model, frame: id)
    kind = nil
    previewed = nil
    highlighted = false
    HingeFixture.with_handler(model, OCL::SmartJoinTool::ACTION_ADD_HINGES, messages, descriptor_path) do |handler, tool|
      handler.singleton_class.send(:prepend, Probe)
      picker = HingeFixture.picker(fixture, 'STILE_L', pick)
      handler.onPickerChanged(picker, model.active_view)
      kind = handler.instance_variable_get(:@hinge_kind)
      previewed = (handler.instance_variable_get(:@probe_axis_lines) || []).first
      highlighted = (handler.instance_variable_get(:@probe_highlighted) || []).include?(fixture['DOOR'])
      handler.onToolLButtonUp(tool, 0, 0, 0, model.active_view)
    end
    laid = state(fixture, spec).merge('kind' => kind, 'interact' => interact_picks_door?(model, fixture, pick), 'preview_axis' => same_axis?(fixture['DOOR'], previewed), 'highlight' => highlighted)

    # Removed at once : the panel hovered, near its left edge, half way up
    box = HingeFixture.frame_parts(spec)['PANEL'].first
    point = [ box[0] + 10, box[1], (box[2] + box[5]) / 2.0 ]
    highlighted = false
    HingeFixture.with_handler(model, OCL::SmartJoinTool::ACTION_REMOVE_HINGES, messages) do |handler, tool|
      handler.singleton_class.send(:prepend, Probe)
      HingeFixture.hover_and_click(model, handler, tool, fixture, HingeFixture.picker(fixture, 'PANEL', point))
      highlighted = (handler.instance_variable_get(:@probe_highlighted) || []).include?(fixture['DOOR'])
    end
    removed = state(fixture, spec).merge('highlight' => highlighted).select { |key, _| REMOVED.key?(key) }

    { 'laid' => laid, 'removed' => removed, 'messages' => messages }
  ensure
    HingeFixture.erase(fixture) unless fixture.nil?
  end

  # The results by case - computed, then undone.
  def self.results
    model = Sketchup.active_model
    results = {}
    HingeFixture.aborted(model) do |dir|
      path = HingeFixture.write_descriptor(dir, HingeFixture.descriptor('frame'))
      CASES.each do |id|
        begin
          results[id] = run_case(model, path, id)
        rescue Exception => e
          results[id] = { 'error' => "#{e.class}: #{e.message} @ #{e.backtrace.first(3).join(' < ')}" }
        end
      end
    end
    results
  end

  # Why the given result of the given case is wrong, nil when it is right.
  def self.failure(id, result)
    return result['error'] if result.key?('error')
    return "laid #{result['laid'].inspect}" unless result['laid'] == EXPECTED[id]
    return "removed #{result['removed'].inspect}" unless result['removed'] == REMOVED
    return "messages #{result['messages'].inspect}" unless result['messages'].empty?
    nil
  end

  def self.run
    results.map { |id, result|
      failure = failure(id, result)
      "#{id} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"} — laid #{result['laid'].inspect}"
    }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartJoinFrameDoorHinges < TestUp::TestCase

    def test_lay_and_remove_frame_door_hinges
      results = FrameDoorHingesRegression.results
      FrameDoorHingesRegression::CASES.each do |id|
        failure = FrameDoorHingesRegression.failure(id, results[id])
        assert(failure.nil?, "#{id} : #{failure}\n#{results[id].inspect}")
      end
    end

  end

end
