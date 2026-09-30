# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : the fixture - a caisson with an overlay door - is built in
# it, far below its content, inside a model operation that is aborted
# afterwards : the model is left as it was. The handlers' own operations are
# neutralized for the duration (SketchUp commits an open operation when
# another one starts, which would make the abort a no-op).
#
# What it checks : the opening SmartJoin previews while hinges are hovered
# (SmartJoinAddFittingsActionHandler#_preview_door_opening) turns around the
# axis the door gets once they are laid - the hinge's pivot shifted along Z of
# its fitting frame by the z_offset of its hardware, a plain length or an
# expression of the measures.
#
# The hinge is a descriptor written to a temporary folder : a cup given as
# primitives - no SKP file - its pivot [ 17mm, -29mm ].
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartJoinHingePreview.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartJoinHingePreview.rb'
#   HingePreviewRegression.run                     # one line per z_offset
require 'json'
require 'tmpdir'
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module HingePreviewRegression

  OCL = Ladb::OpenCutList

  # The z_offsets of the hardware tried, and how far each shifts it : the
  # door is 19 mm thick.
  Z_OFFSETS = {
    nil => 0.0,
    '2mm' => 2.0,
    '-3mm' => -3.0,
    '@thickness_a * 4 / 19' => 4.0,
  }

  PIVOT = [ 17.0, -29.0 ]   # mm, y and z in the fitting frame

  # The fixture : far below whatever the model holds.
  ORIGIN_OFFSET = [ 0, 0, -20000 ]   # mm

  # The parts of the caisson, as boxes [ x0, y0, z0, x1, y1, z1 ] in mm : the
  # door lies over the sides, its back on their front edges.
  PARTS = {
    'SIDE_L' => [ 0, 0, 0, 18, 560, 720 ],
    'SIDE_R' => [ 582, 0, 0, 600, 560, 720 ],
    'BOTTOM' => [ 18, 0, 0, 582, 560, 18 ],
    'TOP' => [ 18, 0, 702, 582, 560, 720 ],
    'BACK' => [ 18, 542, 18, 582, 560, 702 ],
    'DOOR' => [ 2, -19, 2, 598, 0, 718 ],
  }

  # Where the door is hovered : near its left edge, on its front face.
  PICK_POINT = [ 40, -19, 360 ]   # mm, caisson local

  # How far two axes may lie apart and still be the same line.
  TOLERANCE = 0.01   # mm

  # What the handler reads off a SmartPicker, nil for the rest.
  class Picker
    attr_accessor :picked_face_path, :picked_point
    def method_missing(*)
      nil
    end
    def respond_to_missing?(*)
      true
    end
  end

  # Records the axis each preview of the door opening turns around.
  module Probe
    def _preview_door_swing(transformation, axis_line, *args)
      (@probe_axis_lines ||= []) << axis_line
      super
    end
  end

  def self.descriptor(z_offset)
    cup = lambda do |y, screws_y|
      {
        'hardware' => { 'cylinders' => [ { 'y' => y, 'diameter' => '35mm', 'from' => '-11.5mm', 'to' => '0mm' } ] },
        'machining' => { 'drillings' => [
          { 'y' => y, 'diameter' => '35mm', 'depth' => '13mm' },
          { 'x' => '-22.5mm', 'y' => screws_y, 'diameter' => '8mm', 'depth' => '13mm' },
          { 'x' => '22.5mm', 'y' => screws_y, 'diameter' => '8mm', 'depth' => '13mm' },
        ] },
      }
    end
    a = {
      'attributes' => { 'hinge_max_angle' => 110, 'hinge_pivot' => PIVOT.map { |v| "#{v}mm" } },
      'variants' => {
        'select' => { 'by' => 'hinge_kind' },
        'fallback' => 'overlay',
        'items' => { 'overlay' => cup.call('-6.5mm', '-16mm'), 'half_overlay' => cup.call('-16mm', '-25.5mm'), 'inset' => cup.call('-24.5mm', '-34mm') },
      },
    }
    a['z_offset'] = z_offset unless z_offset.nil?
    {
      'format' => 'ocl-hardware', 'version' => 1,
      'id' => "hinge-preview-test-#{z_offset.to_s.hash.abs}", 'type' => 'hinge',
      'name' => "Hinge preview test #{z_offset.inspect}",
      'components' => {
        'a' => a,
        'b' => { 'machining' => { 'drillings' => [ { 'x' => '-16mm', 'y' => '37mm', 'diameter' => '5mm', 'depth' => '12mm' }, { 'x' => '16mm', 'y' => '37mm', 'diameter' => '5mm', 'depth' => '12mm' } ] } },
      },
      'options' => { 'start_offset' => '100mm', 'end_offset' => '100mm', 'max_spacing' => '800mm' },
    }
  end

  # The caisson, as [ caisson instance, door instance ].
  def self.build_fixture(model)
    caisson = model.definitions.add('HINGE_PREVIEW_TEST')
    door = nil
    PARTS.each do |name, (x0, y0, z0, x1, y1, z1)|
      definition = model.definitions.add("HINGE_PREVIEW_TEST_#{name}")
      face = definition.entities.add_face([ x0.mm, y0.mm, z0.mm ], [ x1.mm, y0.mm, z0.mm ], [ x1.mm, y1.mm, z0.mm ], [ x0.mm, y1.mm, z0.mm ])
      face.reverse! if face.normal.z < 0
      face.pushpull((z1 - z0).mm)
      OCL::DefinitionAttributes.write_role(definition, OCL::DefinitionAttributes::ROLE_FRONT_PANEL) if name == 'DOOR'
      instance = caisson.entities.add_instance(definition, IDENTITY)
      door = instance if name == 'DOOR'
    end
    [ model.entities.add_instance(caisson, Geom::Transformation.translation(ORIGIN_OFFSET.map(&:mm))), door ]
  end

  # The axis the preview turns around and the one the door gets once the
  # hinges are laid - [ pivot (mm), axis ] of the hinge nearest the bottom,
  # in the door definition's coordinates - and the tool's messages.
  def self.run_case(model, caisson, door, descriptor_path)
    view = model.active_view
    messages = []

    tool = OCL::SmartJoinTool.new(current_action: OCL::SmartJoinTool::ACTION_ADD_HINGES)
    [ :notify_success, :notify_warnings, :notify_errors, :notify, :show_tooltip, :show_message ].each do |name|
      tool.define_singleton_method(name) { |*args| messages << [ name.to_s, args.first ].inspect unless name == :notify_success }
    end
    model.select_tool(tool)
    begin
      handler = tool.instance_variable_get(:@action_handler)
      handler.singleton_class.send(:prepend, Probe)
      handler.define_singleton_method(:_fetch_option_hardware) { descriptor_path }
      handler.set_state(handler.get_startup_state)

      picker = Picker.new
      picker.picked_face_path = [ caisson, door, door.definition.entities.grep(Sketchup::Face).find { |face| face.normal.y < -0.9 } ]
      picker.picked_point = Geom::Point3d.new(PICK_POINT.map(&:mm)).transform(caisson.transformation)
      handler.onPickerChanged(picker, view)

      previewed = (handler.instance_variable_get(:@probe_axis_lines) || []).min_by { |point, _| point.z }

      handler.onToolLButtonUp(tool, 0, 0, 0, view)
    ensure
      model.select_tool(nil)
    end

    door_def = OCL::DoorDef.from(door)
    laid = door_def.nil? ? nil : door_def.hinge_defs.min_by { |hinge_def| hinge_def.pivot.z }.axis_line

    fn_axis = lambda { |axis_line| axis_line.nil? ? nil : [ axis_line[0].to_a.map { |v| v.to_mm.round(3) }, axis_line[1].normalize.to_a.map { |v| v.round(6) } ] }
    { 'previewed' => fn_axis.call(previewed), 'laid' => fn_axis.call(laid), 'messages' => messages }
  end

  # The results by z_offset - computed, then undone.
  def self.results
    model = Sketchup.active_model
    results = {}
    Dir.mktmpdir do |dir|
      model.start_operation('Hinge preview regression', true)
      neutralized = [ :start_operation, :commit_operation, :abort_operation ]
      begin
        neutralized.each { |name| model.define_singleton_method(name) { |*_args| true } }
        Z_OFFSETS.each_key do |z_offset|
          caisson, door = build_fixture(model)
          path = File.join(dir, "hinge_#{results.length}.json")
          File.write(path, JSON.generate(descriptor(z_offset)))
          results[z_offset] = run_case(model, caisson, door, path)
        end
      ensure
        neutralized.each { |name| model.singleton_class.send(:remove_method, name) }
        model.abort_operation
      end
    end
    results
  end

  # Why the given result is wrong - the pivot previewed where the laid door
  # turns, and that one the unshifted pivot moved along Z of the fitting frame
  # by the given shift - nil when it is right. reference : the result without
  # z_offset.
  def self.failure(result, shift, reference)
    previewed, laid = result['previewed'], result['laid']
    return 'no preview' if previewed.nil?
    return 'no door once laid' if laid.nil?
    return "previewed #{previewed.inspect} laid #{laid.inspect}" unless same_axis?(previewed, laid)
    return nil if reference.nil? || reference['laid'].nil?
    # Z of the fitting frame : into the carcass, from the door's back - +Y of the door definition
    expected = [ reference['laid'][0].zip([ 0.0, shift, 0.0 ]).map { |v, d| v + d }, reference['laid'][1] ]
    return "laid #{laid.inspect} expected on #{expected.inspect}" unless same_axis?(laid, expected)
    nil
  end

  # Are the given axes - [ point (mm), direction ] - the same line, the same
  # way ?
  def self.same_axis?(a, b)
    direction = Geom::Vector3d.new(b[1])
    return false unless Geom::Vector3d.new(a[1]).samedirection?(direction)
    Geom::Point3d.new(a[0]).distance_to_line([ Geom::Point3d.new(b[0]), direction ]).to_f <= TOLERANCE
  end

  def self.run
    results = results()
    reference = results[nil]
    results.map { |z_offset, result|
      failure = failure(result, Z_OFFSETS[z_offset], reference)
      line = "z_offset #{z_offset.inspect} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"} — previewed #{result['previewed'].inspect}"
      line += "\n    messages: #{result['messages'].inspect}" unless result['messages'].empty?
      line
    }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartJoinHingePreview < TestUp::TestCase

    def test_opening_preview_follows_z_offset
      results = HingePreviewRegression.results
      reference = results[nil]
      HingePreviewRegression::Z_OFFSETS.each do |z_offset, shift|
        failure = HingePreviewRegression.failure(results[z_offset], shift, reference)
        assert(failure.nil?, "z_offset #{z_offset.inspect} : #{failure}\n#{results[z_offset].inspect}")
      end
    end

  end

end
