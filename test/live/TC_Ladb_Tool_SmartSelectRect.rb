# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : the fixture - a few groups laid flat, far from the model's
# content - is built in it, inside a model operation aborted afterwards, and
# the camera is given back : the model is left as it was.
#
# What it checks : the rectangle selection of SmartSelectActionHandler
# (STATE_SELECT_RECT) - dragged left to right it keeps the instances FULLY
# inside the rectangle (PICK_INSIDE), right to left the ones it touches
# (PICK_CROSSING) - at the root and inside an edit context.
#
# What PickHelper#window_pick returns, and why the handler filters it :
#   - paths are absolute - from the model root - whatever the edit context ;
#   - each path stops at the highest entity fully inside the rectangle, at
#     ANY depth : INSIDE must not turn G2 > G2a into G2 ;
#   - a rectangle enclosing the edit context or one of its ancestors returns
#     that ancestor's path only - shorter than the active path.
#
# The rectangle is driven through the real SmartHandleTool (move) - mouse
# down, move, up - its onSelected stubbed to record the selected instances.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartSelectRect.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartSelectRect.rb'
#   SelectRectRegression.run                     # one line per case
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module SelectRectRegression

  OCL = Ladb::OpenCutList

  # The fixture : far from whatever the model holds, seen from the top.
  ORIGIN_OFFSET = [ 50000, 50000, 0 ]   # mm

  # The groups, as boxes [ x0, y0, x1, y1 ] in mm, 50 mm high. G2 holds G2a -
  # itself holding G2a1 - and C2b, an instance of a component.
  #
  #   y
  #   400 +-----+
  #       | HID |                               hidden
  #   300 +-----+
  #   230 +------------------------------------+
  #       |               LONG                 |
  #   200 +------------------------------------+
  #   100 +-----+     +-----+      +-----+
  #       | G1  |     | G2a |      | C2b |     G2 = G2a + C2b
  #     0 +-----+     +-----+      +-----+
  #       0    100   200   300    350   450  x
  BOXES = {
    'G1' => [ 0, 0, 100, 100 ],
    'G2a1' => [ 200, 0, 300, 100 ],
    'C2b' => [ 350, 0, 450, 100 ],
    'LONG' => [ 0, 200, 450, 230 ],
    'HID' => [ 0, 300, 100, 400 ],
  }

  # Each case : the edit context (names), the rectangle [ x0, y0, x1, y1 ] in
  # mm, its direction - :inside = left to right, :crossing = right to left -
  # and the names of the instances it must select.
  CASES = {
    'root_inside_full' => { context: [], rect: [ -10, -10, 110, 110 ], type: :inside, expected: %w[G1] },
    'root_inside_nested_only' => { context: [], rect: [ 190, -10, 310, 110 ], type: :inside, expected: [] },
    'root_crossing_nested_only' => { context: [], rect: [ 190, -10, 310, 110 ], type: :crossing, expected: %w[G2] },
    'root_inside_partial' => { context: [], rect: [ -10, -10, 110, 240 ], type: :inside, expected: %w[G1] },
    'root_crossing_partial' => { context: [], rect: [ -10, -10, 110, 240 ], type: :crossing, expected: %w[G1 LONG] },
    'root_inside_hidden' => { context: [], rect: [ -10, 290, 110, 410 ], type: :inside, expected: [] },
    'root_crossing_hidden' => { context: [], rect: [ -10, 290, 110, 410 ], type: :crossing, expected: [] },
    'g2_inside_context_enclosed' => { context: %w[G2], rect: [ 190, -10, 460, 110 ], type: :inside, expected: %w[G2a C2b] },
    'g2_inside_child' => { context: %w[G2], rect: [ 190, -10, 400, 110 ], type: :inside, expected: %w[G2a] },
    'g2_crossing_child' => { context: %w[G2], rect: [ 190, -10, 400, 110 ], type: :crossing, expected: %w[G2a C2b] },
    'g2_inside_outside_context' => { context: %w[G2], rect: [ -10, -10, 110, 110 ], type: :inside, expected: [] },
    'g2a_inside_ancestor_enclosed' => { context: %w[G2 G2a], rect: [ 190, -10, 460, 110 ], type: :inside, expected: %w[G2a1] },
    'g2a_crossing_ancestor_enclosed' => { context: %w[G2 G2a], rect: [ 190, -10, 460, 110 ], type: :crossing, expected: %w[G2a1] },
  }

  def self.point(x, y, z = 0)
    Geom::Point3d.new((ORIGIN_OFFSET[0] + x).mm, (ORIGIN_OFFSET[1] + y).mm, (ORIGIN_OFFSET[2] + z).mm)
  end

  def self.add_box(entities, name, box)
    x0, y0, x1, y1 = box
    group = entities.add_group
    group.name = name
    face = group.entities.add_face(point(x0, y0), point(x1, y0), point(x1, y1), point(x0, y1))
    face.reverse! if face.normal.z < 0
    face.pushpull(50.mm)
    group
  end

  # Builds the fixture in the given model : its instances by name.
  def self.build(model)
    entities = model.entities
    instances = {}
    instances['G1'] = add_box(entities, 'G1', BOXES['G1'])
    g2 = instances['G2'] = entities.add_group
    g2.name = 'G2'
    g2a = instances['G2a'] = g2.entities.add_group
    g2a.name = 'G2a'
    instances['G2a1'] = add_box(g2a.entities, 'G2a1', BOXES['G2a1'])
    definition = model.definitions.add('SelectRectFixture')
    x0, y0, x1, y1 = BOXES['C2b']
    face = definition.entities.add_face([ 0, 0, 0 ], [ (x1 - x0).mm, 0, 0 ], [ (x1 - x0).mm, (y1 - y0).mm, 0 ], [ 0, (y1 - y0).mm, 0 ])
    face.reverse! if face.normal.z < 0
    face.pushpull(50.mm)
    c2b = instances['C2b'] = g2.entities.add_instance(definition, Geom::Transformation.translation(point(x0, y0)))
    c2b.name = 'C2b'
    instances['LONG'] = add_box(entities, 'LONG', BOXES['LONG'])
    instances['HID'] = add_box(entities, 'HID', BOXES['HID'])
    instances['HID'].hidden = true
    instances
  end

  # The real move tool, its messages recorded, its onSelected recording the
  # selected instances instead of starting the move.
  def self.with_handler(model, messages, selected)
    tool = OCL::SmartHandleTool.new(current_action: OCL::SmartHandleTool::ACTION_MOVE_LINE)
    [ :notify_success, :notify_warnings, :notify_errors, :notify, :show_tooltip, :show_message ].each do |name|
      tool.define_singleton_method(name) do |*args|
        next if [ :notify_success, :show_tooltip, :show_message ].include?(name)
        messages << [ name.to_s, args.first ].inspect
      end
    end
    model.select_tool(tool)
    begin
      handler = tool.instance_variable_get(:@action_handler)
      handler.define_singleton_method(:onSelected) do
        selected.concat(get_active_selection_instances.to_a)
        true
      end
      yield handler, tool
    ensure
      model.select_tool(nil)
    end
  end

  # Drags the given rectangle : the names of the instances it selects.
  def self.run_case(model, instances, spec, messages)
    view = model.active_view
    x0, y0, x1, y1 = spec[:rect]
    a = view.screen_coords(point(x0, y0))
    b = view.screen_coords(point(x1, y1))
    left, right = [ a.x, b.x ].min, [ a.x, b.x ].max
    p1, p2 = spec[:type] == :inside ? [ left, right ] : [ right, left ]
    p1 = Geom::Point3d.new(p1, a.y, 0)
    p2 = Geom::Point3d.new(p2, b.y, 0)
    raise "#{spec[:rect].inspect} off screen" unless [ p1, p2 ].all? { |p| p.x.between?(0, view.vpwidth) && p.y.between?(0, view.vpheight) }

    # The edit context is changed with no tool active
    model.select_tool(nil)
    model.active_path = spec[:context].empty? ? nil : spec[:context].map { |name| instances[name] }
    model.selection.clear

    selected = []
    with_handler(model, messages, selected) do |handler, tool|
      handler.onToolLButtonDown(tool, 0, p1.x, p1.y, view)
      handler.onToolMouseMove(tool, 0, p2.x, p2.y, view)   # Leaves STATE_SELECT for STATE_SELECT_RECT
      handler.onToolMouseMove(tool, 0, p2.x, p2.y, view)   # Previews the rectangle
      handler.onToolLButtonUp(tool, 0, p2.x, p2.y, view)
    end
    selected.map(&:name).sort
  end

  # Runs the given cases - all of them by default - in an aborted operation,
  # the camera given back : the results by case.
  def self.results(names = CASES.keys)
    model = Sketchup.active_model
    view = model.active_view
    camera = view.camera
    saved_camera = Sketchup::Camera.new(camera.eye, camera.target, camera.up, camera.perspective?)
    saved_camera.perspective? ? saved_camera.fov = camera.fov : saved_camera.height = camera.height
    saved_active_path = model.active_path
    model.select_tool(nil)
    model.active_path = nil unless saved_active_path.nil?

    results = {}
    model.start_operation('Select rect fixture', true)
    neutralized = [ :start_operation, :commit_operation, :abort_operation ]
    begin
      neutralized.each { |name| model.define_singleton_method(name) { |*_args| true } }
      instances = build(model)

      # Every rectangle on screen - a move at a negative coordinate is ignored
      top_camera = Sketchup::Camera.new(point(225, 200, 10000), point(225, 200, 0), [ 0, 1, 0 ], false)
      top_camera.height = 700.mm
      view.camera = top_camera

      names.each do |name|
        spec = CASES[name]
        messages = []
        selected = run_case(model, instances, spec, messages)
        results[name] = { 'expected' => spec[:expected].sort, 'selected' => selected, 'messages' => messages }
      end
    ensure
      model.select_tool(nil)
      model.active_path = nil
      neutralized.each { |name| model.singleton_class.send(:remove_method, name) }
      model.abort_operation
      view.camera = saved_camera
    end
    results
  end

  # Why the given result is wrong, nil when it is right.
  def self.failure(result)
    return "selected #{result['selected'].inspect} expected #{result['expected'].inspect}" unless result['selected'] == result['expected']
    return "messages #{result['messages'].inspect}" unless result['messages'].empty?
    nil
  end

  def self.run(names = CASES.keys)
    results(names).map { |name, result|
      failure = failure(result)
      "#{name} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"} — #{result['selected'].inspect}"
    }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartSelectRect < TestUp::TestCase

    def test_rect_selection_follows_the_pick_type
      SelectRectRegression.results.each do |name, result|
        failure = SelectRectRegression.failure(result)
        assert(failure.nil?, "#{name} : #{failure}\n#{result.inspect}")
      end
    end

  end

end
