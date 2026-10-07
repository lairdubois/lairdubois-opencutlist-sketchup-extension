# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : the fixture - two panels joined in an L - is built in it
# and the model operation it is built in is aborted afterwards : the model is
# left as it was.
#
# What it checks : SmartJoinAddConnectorsActionHandler lays the connectors
# on the joint - their hardware and the machining of both panels - and
# SmartJoinRemoveConnectorsActionHandler removes them all :
#  - domino : the bundled Domino 5x30, its hardware an article given as
#             primitives : the definition laid gets the "attributes" of its
#             component - symmetrical - which an article once lost.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartJoinConnectors.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartJoinConnectors.rb'
#   ConnectorsRegression.run                 # one line per case
require_relative 'hinge_fixture'
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module ConnectorsRegression

  OCL = Ladb::OpenCutList

  # The descriptor of each case - a library ref - in the order they are run.
  CASES = {
    'domino' => '$OCL/connectors/festool/domino-5x30.json',
  }

  # The panels, as boxes [ x0, y0, z0, x1, y1, z1 ] in mm, far below whatever
  # the model holds : B stands on the end of A.
  PANELS = {
    'A' => [ 0, 0, -20000, 600, 400, -19981 ],
    'B' => [ 0, 0, -19981, 19, 400, -19381 ],
  }

  # Where A is hovered : on its front face, right below B.
  PICK_POINT = [ 10, 0, -19982 ]   # mm

  # What each case gives, once laid then once removed : the entities laid in
  # each panel, and the definitions of the hardware laid in them - as
  # [ name, symmetrical ].
  EXPECTED = {
    'domino' => { 'laid' => { 'a' => 2, 'b' => 1, 'hardware' => [ [ 'Domino 5x30', true ] ] } },
  }
  REMOVED = { 'a' => 0, 'b' => 0, 'hardware' => [] }

  # The panels, as { 'A' => instance, 'B' => instance }.
  def self.build(model)
    Hash[PANELS.map { |name, box| [ name, model.entities.add_instance(HingeFixture.box_definition(model, "CONNECTOR_FIXTURE_#{name}", box), IDENTITY) ] }]
  end

  def self.erase(fixture)
    fixture.each_value { |instance| instance.erase! if instance.valid? }
  end

  # The picker hovering the front face of A at PICK_POINT. The connector
  # handlers read their own picker - not the one given to onPickerChanged :
  # it is put in place of theirs.
  def self.picker(fixture)
    a = fixture['A']
    face = a.definition.entities.grep(Sketchup::Face).find { |f| f.normal.transform(a.transformation).y < -0.9 }
    picker = HingeFixture::Picker.new
    picker.picked_face_path = [ a, face ]
    picker.picked_point = Geom::Point3d.new(PICK_POINT.map(&:mm))
    picker.define_singleton_method(:picked_plane_manipulator) { OCL::FaceManipulator.new(face, a.transformation) }
    picker
  end

  def self.hover_and_click(model, handler, tool, fixture)
    picker = picker(fixture)
    handler.instance_variable_set(:@picker, picker)
    handler.onPickerChanged(picker, model.active_view)
    handler.onToolLButtonUp(tool, 0, 0, 0, model.active_view)
  end

  def self.state(fixture)
    fn_laid = lambda { |instance| instance.definition.entities.count { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) } }
    fn_definitions = lambda { |definition| definition.entities.grep(Sketchup::ComponentInstance).map(&:definition) + definition.entities.grep(Sketchup::Group).map(&:definition) }
    fn_all = lambda { |definition| fn_definitions.call(definition).flat_map { |d| [ d ] + fn_all.call(d) } }
    hardware = fixture.values.flat_map { |instance| fn_all.call(instance.definition) }.uniq.select { |d|
      d.get_attribute(OCL::Plugin::ATTRIBUTE_DICTIONARY, OCL::HardwareDescriptorDef::DEFINITION_ATTRIBUTE_PRIMITIVES).to_s.start_with?('hardware:')
    }
    {
      'a' => fn_laid.call(fixture['A']),
      'b' => fn_laid.call(fixture['B']),
      'hardware' => hardware.map { |d| [ d.name, d.get_attribute(OCL::Plugin::ATTRIBUTE_DICTIONARY, 'symmetrical') ] }.sort,
    }
  end

  def self.run_case(model, descriptor_ref)
    messages = []
    fixture = build(model)
    HingeFixture.with_handler(model, OCL::SmartJoinTool::ACTION_ADD_CONNECTORS, messages, descriptor_ref) do |handler, tool|
      hover_and_click(model, handler, tool, fixture)
    end
    laid = state(fixture)
    HingeFixture.with_handler(model, OCL::SmartJoinTool::ACTION_REMOVE_CONNECTORS, messages) do |handler, tool|
      hover_and_click(model, handler, tool, fixture)
    end
    { 'laid' => laid, 'removed' => state(fixture), 'messages' => messages }
  ensure
    erase(fixture) unless fixture.nil?
  end

  # The results by case - computed, then undone. The definitions already in
  # the model lose their "symmetrical" first : one laid there is reused.
  def self.results
    model = Sketchup.active_model
    results = {}
    HingeFixture.aborted(model) do |_dir|
      model.definitions.each { |definition| definition.delete_attribute(OCL::Plugin::ATTRIBUTE_DICTIONARY, 'symmetrical') }
      CASES.each do |id, ref|
        begin
          results[id] = run_case(model, ref)
        rescue Exception => e
          results[id] = { 'error' => "#{e.class}: #{e.message} @ #{e.backtrace.first(2).join(' < ')}" }
        end
      end
    end
    results
  end

  # Why the given result of the given case is wrong, nil when it is right.
  def self.failure(id, result)
    return result['error'] if result.key?('error')
    return "laid #{result['laid'].inspect}" unless result['laid'] == EXPECTED[id]['laid']
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

  class TC_Ladb_Tool_SmartJoinConnectors < TestUp::TestCase

    def test_lay_and_remove_connectors
      results = ConnectorsRegression.results
      ConnectorsRegression::CASES.each_key do |id|
        failure = ConnectorsRegression.failure(id, results[id])
        assert(failure.nil?, "#{id} : #{failure}\n#{results[id].inspect}")
      end
    end

  end

end
