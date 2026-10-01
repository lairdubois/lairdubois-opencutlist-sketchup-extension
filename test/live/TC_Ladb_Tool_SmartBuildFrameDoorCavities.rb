# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : the fixtures - a caisson with a frame door, see
# HingeFixture::FRAME_DOORS - are built in it and the model operation they
# are built in is aborted afterwards : the model is left as it was.
#
# What it checks : the SmartBuildTool panel actions work THROUGH a front
# panel made of several parts - stiles, rails and a panel held by a
# component bearing ROLE_FRONT_PANEL :
#  - divider, back : a stile of the door hovered activates it, the cavities
#                    are the caisson's (not the door assembly's, which holds
#                    none) and a ray cast through the door lands in one ;
#  - front         : the front opening of the caisson, already closed by the
#                    door read part by part, is refused - with or without
#                    the door's middle panel : an empty frame closes it all
#                    the same.
# Cases :
#  - frame         : overlay frame door ;
#  - frame_empty   : the same without its middle panel ;
#  - frame_through : rails across the whole width ;
#  - frame_inset   : the frame door set in the mouth ;
#  - none          : no door at all - the parts hovered are the caisson's,
#                    and the front opening is free.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartBuildFrameDoorCavities.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartBuildFrameDoorCavities.rb'
#   FrameDoorCavitiesRegression.run                   # one line per case
require_relative 'hinge_fixture'
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module FrameDoorCavitiesRegression

  OCL = Ladb::OpenCutList

  HANDLERS = {
    'divider' => [ OCL::SmartBuildTool::ACTION_BUILD_DIVIDER, OCL::SmartBuildDividerActionHandler ],
    'back' => [ OCL::SmartBuildTool::ACTION_BUILD_BACK_PANEL, OCL::SmartBuildBackPanelActionHandler ],
    'front' => [ OCL::SmartBuildTool::ACTION_BUILD_FRONT_PANEL, OCL::SmartBuildFrontPanelActionHandler ],
  }

  # Where the door is hovered, on the left stile, as HingeFixture::FRAME_DOORS
  # puts it - and the ray cast through the door, in front of its middle
  # (mm, caisson local).
  RAY_ORIGIN = [ 300, -500, 360 ]
  RAY_DIRECTION = [ 0, 1, 0 ]

  THROUGH = { 'active' => true, 'container' => true, 'fragments' => true, 'ray' => true }
  EXPECTED_FRAME = { 'divider' => THROUGH, 'back' => THROUGH, 'front' => { 'active' => true, 'closed' => true } }
  EXPECTED = {
    'frame' => EXPECTED_FRAME,
    'frame_empty' => EXPECTED_FRAME,
    'frame_through' => EXPECTED_FRAME,
    'frame_inset' => EXPECTED_FRAME,
    'none' => EXPECTED_FRAME.merge('front' => { 'active' => true, 'closed' => false }),
  }
  CASES = EXPECTED.keys

  # The picker hovering the given part of the fixture : a part of the door
  # - its name in the door - or of the caisson.
  def self.picker(fixture, part)
    path = [ fixture['caisson'] ]
    path << fixture['DOOR'] if fixture.key?('parts') && fixture['parts'].key?(part)
    path << (fixture.key?('parts') && fixture['parts'][part] || fixture[part])
    picker = HingeFixture::Picker.new
    picker.picked_face_path = path + [ path.last.definition.entities.grep(Sketchup::Face).first ]
    picker
  end

  # Yields the handler of the given kind, its tool selected - the tool's
  # messages appended to the given array.
  def self.with_handler(model, kind, messages)
    action, _ = HANDLERS[kind]
    tool = OCL::SmartBuildTool.new(current_action: action)
    [ :notify_success, :notify_warnings, :notify_errors, :notify, :show_tooltip, :remove_tooltip, :push_cursor, :pop_cursor ].each do |name|
      tool.define_singleton_method(name) { |*args| messages << [ kind, name.to_s, args.first ].inspect if [ :notify_warnings, :notify_errors, :notify ].include?(name) }
    end
    model.select_tool(tool)
    begin
      handler = tool.instance_variable_get(:@action_handler)
      raise "#{kind} : no #{HANDLERS[kind].last.name}" unless handler.is_a?(HANDLERS[kind].last)
      handler.define_singleton_method(:_fetch_option_reduce_envelope?) { false }
      handler.define_singleton_method(:_panel_opening_facing_vector) { |_view| [ 0, -1, 0 ] } if kind == 'front'   # The front of the caisson
      yield handler
    ensure
      model.select_tool(nil)
    end
  end

  # The handler of the given kind, the given part hovered : its state.
  def self.probe(model, fixture, kind, part, messages)
    with_handler(model, kind, messages) { |handler| _probe(model, fixture, kind, part, handler) }
  end

  def self._probe(model, fixture, kind, part, handler)
    handler.send(:_pick_part, picker(fixture, part), model.active_view)
    state = { 'active' => handler.has_active_part? }
    return state unless state['active']
    cavities_def = handler.send(:_get_cavities_def)
    t = fixture['caisson'].transformation
    if kind == 'front'
      center = Geom::Point3d.new(300.mm, 280.mm, 360.mm).transform(t)
      fragment_def = cavities_def.fragment_defs_for_point(center).first
      opening_def = fragment_def && handler.send(:_get_panel_opening_def, fragment_def, model.active_view)
      state['closed'] = !opening_def.nil? && handler.send(:_opening_already_panelled?, fragment_def, opening_def, handler.send(:_get_opening_transformation, opening_def).inverse)
    else
      state['container'] = cavities_def.is_a?(OCL::CavitiesDef) && cavities_def.container_path == [ fixture['caisson'] ]
      state['fragments'] = cavities_def.is_a?(OCL::CavitiesDef) && cavities_def.valid? && !cavities_def.fragment_defs.empty?
      state['ray'] = state['fragments'] && !cavities_def.pick_ray(Geom::Point3d.new(RAY_ORIGIN.map(&:mm)).transform(t), Geom::Vector3d.new(*RAY_DIRECTION).transform(t)).nil?
    end
    state
  end

  def self.run_case(model, id)
    messages = []
    fixture = id == 'none' ? HingeFixture.build(model) : HingeFixture.build(model, frame: id == 'frame_empty' ? 'frame' : id)
    fixture['DOOR'].erase! if id == 'none'
    fixture['parts'].delete('PANEL').erase! if id == 'frame_empty'
    stile = id == 'none' ? 'SIDE_L' : 'STILE_L'
    result = {
      'divider' => probe(model, fixture, 'divider', stile, messages),
      'back' => probe(model, fixture, 'back', stile, messages),
      'front' => probe(model, fixture, 'front', 'SIDE_L', messages),
    }
    result['messages'] = messages
    result
  ensure
    HingeFixture.erase(fixture) unless fixture.nil?
  end

  # The results by case - computed, then undone.
  def self.results
    model = Sketchup.active_model
    results = {}
    HingeFixture.aborted(model) do |_dir|
      CASES.each do |id|
        begin
          results[id] = run_case(model, id)
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
    EXPECTED[id].each do |kind, expected|
      return "#{kind} #{result[kind].inspect}" unless result[kind] == expected
    end
    return "messages #{result['messages'].inspect}" unless result['messages'].empty?
    nil
  end

  def self.run
    results.map { |id, result|
      failure = failure(id, result)
      "#{id} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"}"
    }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartBuildFrameDoorCavities < TestUp::TestCase

    def test_panel_actions_through_frame_door
      results = FrameDoorCavitiesRegression.results
      FrameDoorCavitiesRegression::CASES.each do |id|
        failure = FrameDoorCavitiesRegression.failure(id, results[id])
        assert(failure.nil?, "#{id} : #{failure}\n#{results[id].inspect}")
      end
    end

  end

end
