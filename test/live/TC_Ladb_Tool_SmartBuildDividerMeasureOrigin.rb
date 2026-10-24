# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : the fixtures - a caisson, see PARTS - are built in it and
# the model operation they are built in is aborted afterwards : the model is
# left as it was.
#
# What it checks : the "overall" measure origin of the Smart Build Divider
# tool (ACTION_OPTION_MEASURE_ORIGIN_OVERALL) stands at the OUTER ends of
# the caisson - past each wall of the compartment, by the panel closing it
# there (see SmartBuildDividerActionHandler#_get_divider_measure_origins) :
# the bottom of the bottom, the top of the sides, the outside of the sides.
# Cases, each with the envelope reduced or not :
#  - rails : the top made of a front and a back rail, open between them :
#            the compartment's top is a CAP under the rails, and the origin
#            still goes up to the top of the sides through them ;
#  - top   : a full top panel - the top is a wall ;
#  - open  : no top at all - the top is the hull cap, flush with the top of
#            the sides.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartBuildDividerMeasureOrigin.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartBuildDividerMeasureOrigin.rb'
#   DividerMeasureOriginRegression.run                   # one line per case
require_relative 'hinge_fixture'
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module DividerMeasureOriginRegression

  OCL = Ladb::OpenCutList

  # The parts of the caisson, as boxes [ x0, y0, z0, x1, y1, z1 ] in mm : the
  # back is set in grooves of the sides, bottom and top.
  SIDES = {
    'SIDE_L' => [ 0, 0, 0, 19, 400, 600 ],
    'SIDE_R' => [ 431, 0, 0, 450, 400, 600 ],
    'BOTTOM' => [ 19, 0, 0, 431, 400, 19 ],
    'BACK' => [ 11, 386, 11, 439, 394, 589 ],
  }
  TOPS = {
    'rails' => {
      'RAIL_F' => [ 19, 0, 581, 431, 80, 600 ],
      'RAIL_B' => [ 19, 320, 581, 431, 400, 600 ],
    },
    'top' => {
      'TOP' => [ 19, 0, 581, 431, 400, 600 ],
    },
    'open' => {},
  }

  # A point of the compartment (mm, caisson local).
  INSIDE = [ 225, 200, 300 ]

  # The divider normals checked, and the overall origins [ o0, o1 ] along
  # each - in mm, caisson local : the outer faces of the caisson.
  EXPECTED = {
    [ 0.0, 0.0, -1.0 ] => [ -600, 0 ],
    [ 0.0, 0.0, 1.0 ] => [ 0, 600 ],
    [ 1.0, 0.0, 0.0 ] => [ 0, 450 ],
  }

  CASES = TOPS.keys.product([ true, false ]).map { |top, reduce| "#{top}#{reduce ? '_reduce' : ''}" }

  def self.build(model, top)
    caisson = model.entities.add_group
    caisson.transformation = Geom::Transformation.translation(HingeFixture::ORIGIN_OFFSET.map(&:mm))
    instances = { 'caisson' => caisson }
    SIDES.merge(TOPS[top]).each do |name, box|
      instances[name] = caisson.entities.add_instance(HingeFixture.box_definition(model, "DIVIDER_FIXTURE_#{name}", box), IDENTITY)
    end
    instances
  end

  # Yields the divider handler, its tool selected, the overall measure
  # origin and the given reduction forced.
  def self.with_handler(model, reduce)
    tool = OCL::SmartBuildTool.new(current_action: OCL::SmartBuildTool::ACTION_BUILD_DIVIDER)
    [ :notify_success, :notify_warnings, :notify_errors, :notify, :set_root_tooltip, :remove_root_tooltip, :push_cursor, :pop_cursor ].each do |name|
      tool.define_singleton_method(name) { |*_args| }
    end
    model.select_tool(tool)
    begin
      handler = tool.instance_variable_get(:@action_handler)
      raise "no #{OCL::SmartBuildDividerActionHandler.name}" unless handler.is_a?(OCL::SmartBuildDividerActionHandler)
      handler.define_singleton_method(:_fetch_option_reduce_envelope?) { reduce }
      handler.define_singleton_method(:_fetch_option_measure_origin_overall?) { true }
      yield handler
    ensure
      model.select_tool(nil)
    end
  end

  # The overall origins of the given case along each normal of EXPECTED, in
  # mm caisson local.
  def self.run_case(model, id)
    top = id.sub(/_reduce\z/, '')
    fixture = build(model, top)
    t = fixture['caisson'].transformation
    with_handler(model, id.end_with?('_reduce')) do |handler|
      picker = HingeFixture::Picker.new
      side = fixture['SIDE_L']
      picker.picked_face_path = [ fixture['caisson'], side, side.definition.entities.grep(Sketchup::Face).find { |face| face.normal.x > 0.9 } ]
      handler.send(:_pick_part, picker, model.active_view)
      raise 'no active part' unless handler.has_active_part?
      cavities_def = handler.send(:_get_cavities_def)
      raise 'no cavities' unless cavities_def.is_a?(OCL::CavitiesDef) && cavities_def.valid?
      fragment_def = cavities_def.fragment_defs_for_point(Geom::Point3d.new(INSIDE.map(&:mm)).transform(t)).find { |candidate| !candidate.overall? }
      raise 'no compartment' if fragment_def.nil?
      EXPECTED.keys.map { |normal_3f|
        n0, n1 = handler.send(:_get_divider_mesh_extent, fragment_def.vertices, normal_3f)
        origins = handler.send(:_get_divider_measure_origins, cavities_def, fragment_def, normal_3f, n0, n1)
        shift = Geom::Vector3d.new(normal_3f).dot(t.origin - ORIGIN)   # The caisson's offset along the normal
        [ normal_3f, origins.map { |o| (o - shift).to_mm.round(3) } ]
      }.to_h
    end
  ensure
    fixture['caisson'].erase! if !fixture.nil? && fixture['caisson'].valid?
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

  # Why the given result is wrong, nil when it is right.
  def self.failure(result)
    return result['error'] if result.key?('error')
    EXPECTED.each do |normal_3f, expected|
      return "#{normal_3f.inspect} #{result[normal_3f].inspect} instead of #{expected.inspect}" unless result[normal_3f] == expected.map(&:to_f)
    end
    nil
  end

  def self.run
    results.map { |id, result|
      failure = failure(result)
      "#{id} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"}"
    }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartBuildDividerMeasureOrigin < TestUp::TestCase

    def test_overall_measure_origin
      results = DividerMeasureOriginRegression.results
      DividerMeasureOriginRegression::CASES.each do |id|
        failure = DividerMeasureOriginRegression.failure(results[id])
        assert(failure.nil?, "#{id} : #{failure}\n#{results[id].inspect}")
      end
    end

  end

end
