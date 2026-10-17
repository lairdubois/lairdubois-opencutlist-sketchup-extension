# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : it reuses the TC_Ladb_Tool_SmartSelectRect fixture - built
# in an aborted operation, the camera given back.
#
# The parts are components : the fixture leaf groups are turned into ones.
#
# What it checks : the rectangle selection of SmartPaintActionHandler picks
# the PARTS, not the active context children holding them :
#   - inside (left to right), the fully inside parts - or the parts of a fully
#     inside container - at any depth ;
#   - crossing (right to left), the touched parts only ;
#   - Clean's containers : only the ones whose parts are all picked - a
#     partially picked one is left as it is ;
#   - the live preview, while dragging, draws the parts the release picks ;
#   - ESC while dragging drops the rectangle : back to STATE_SELECT, no
#     preview, the release - even on a part - selects nothing.
#
# The rectangle is driven through the real SmartPaintTool (clean action) -
# mouse down, move, up - its onSelected stubbed to record the picked parts and
# the containers to clean.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartPaintRect.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartPaintRect.rb'
#   PaintRectRegression.run                      # one line per case
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

load File.join(__dir__, 'TC_Ladb_Tool_SmartSelectRect.rb') unless defined?(SelectRectRegression)

module PaintRectRegression

  OCL = Ladb::OpenCutList
  FIXTURE = SelectRectRegression

  # Each case : as SelectRectRegression ones, expecting the picked part names
  # and the container names Clean would clean.
  CASES = {
    'root_inside_nested_part' => { context: [], rect: [ 190, -10, 310, 110 ], type: :inside, parts: %w[G2a1], containers: %w[G2a] },
    'root_inside_container' => { context: [], rect: [ 190, -10, 460, 110 ], type: :inside, parts: %w[C2b G2a1], containers: %w[G2 G2a] },
    'root_inside_partial' => { context: [], rect: [ -10, -10, 110, 240 ], type: :inside, parts: %w[G1], containers: [] },
    'root_crossing_one_part' => { context: [], rect: [ 340, -10, 400, 110 ], type: :crossing, parts: %w[C2b], containers: [] },
    'root_crossing_nested_part' => { context: [], rect: [ 190, -10, 310, 110 ], type: :crossing, parts: %w[G2a1], containers: %w[G2a] },
    'root_crossing_partial' => { context: [], rect: [ -10, -10, 110, 240 ], type: :crossing, parts: %w[G1 LONG], containers: [] },
    'g2_inside_child' => { context: %w[G2], rect: [ 190, -10, 400, 110 ], type: :inside, parts: %w[G2a1], containers: %w[G2a] },
    'g2_crossing_child' => { context: %w[G2], rect: [ 190, -10, 400, 110 ], type: :crossing, parts: %w[C2b G2a1], containers: %w[G2a] },
    'root_canceled' => { context: [], rect: [ -10, -10, 50, 50 ], type: :crossing, cancel: true, parts: [], containers: [] },
  }

  # The SelectRectRegression fixture, its leaf groups turned into components
  # - groups are not parts.
  def self.build(model)
    instances = FIXTURE.build(model)
    %w[G1 G2a1 LONG].each do |name|
      instance = instances[name].to_component
      instance.name = name
      instances[name] = instance
    end
    instances
  end

  # The real paint tool, its onSelected recording the picked parts and the
  # containers to clean instead of painting.
  def self.with_handler(model, messages, selected)
    tool = OCL::SmartPaintTool.new(current_action: OCL::SmartPaintTool::ACTION_PAINT_CLEAN)
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
        @test_selected = true
        @selection_material_entries = _get_selection_material_entries
        @selection_material_entries.each { |entry| entry.selected = true }
        selected.concat(_get_selection_part_instances_and_containers)
        true
      end
      yield handler, tool
    ensure
      model.select_tool(nil)
    end
  end

  def self.run_case(model, instances, spec, messages)
    view = model.active_view
    x0, y0, x1, y1 = spec[:rect]
    a = view.screen_coords(FIXTURE.point(x0, y0))
    b = view.screen_coords(FIXTURE.point(x1, y1))
    left, right = [ a.x, b.x ].min, [ a.x, b.x ].max
    p1, p2 = spec[:type] == :inside ? [ left, right ] : [ right, left ]
    p1 = Geom::Point3d.new(p1, a.y, 0)
    p2 = Geom::Point3d.new(p2, b.y, 0)

    # The edit context is changed with no tool active
    model.select_tool(nil)
    model.active_path = spec[:context].empty? ? nil : spec[:context].map { |name| instances[name] }
    model.selection.clear

    selected = []
    previewed = nil
    with_handler(model, messages, selected) do |handler, tool|
      handler.onToolLButtonDown(tool, 0, p1.x, p1.y, view)
      handler.onToolMouseMove(tool, 0, p2.x, p2.y, view)   # Leaves STATE_SELECT for STATE_SELECT_RECT
      handler.onToolMouseMove(tool, 0, p2.x, p2.y, view)   # Previews the rectangle and its parts
      previewed = (handler.instance_variable_get(:@select_rect_preview_part_paths) || []).map { |path| path.last.name }.sort
      if spec[:cancel]
        handler.onToolCancel(tool, 0, view)
        state = handler.instance_variable_get(:@state)
        messages << "state #{state}" unless state == OCL::SmartSelectActionHandler::STATE_SELECT
        messages << 'preview kept' unless handler.instance_variable_get(:@select_rect_preview_part_paths).nil?
        previewed = []
        handler.onToolMouseMove(tool, 0, p2.x, p2.y, view)   # Hovers G1
      end
      handler.onToolLButtonUp(tool, 0, p2.x, p2.y, view)
      messages << 'selected' if spec[:cancel] && handler.instance_variable_get(:@test_selected)
    end
    part_instances, containers = selected
    parts = (part_instances || []).map(&:name).sort
    messages << "previewed #{previewed.inspect}" unless previewed == parts
    [ parts, (containers || []).map(&:name).sort ]
  end

  def self.results(names = CASES.keys)
    model = Sketchup.active_model
    view = model.active_view
    camera = view.camera
    saved_camera = Sketchup::Camera.new(camera.eye, camera.target, camera.up, camera.perspective?)
    saved_camera.perspective? ? saved_camera.fov = camera.fov : saved_camera.height = camera.height
    model.select_tool(nil)
    model.active_path = nil unless model.active_path.nil?

    results = {}
    model.start_operation('Paint rect fixture', true)
    neutralized = [ :start_operation, :commit_operation, :abort_operation ]
    begin
      neutralized.each { |name| model.define_singleton_method(name) { |*_args| true } }
      instances = build(model)

      top_camera = Sketchup::Camera.new(FIXTURE.point(225, 200, 10000), FIXTURE.point(225, 200, 0), [ 0, 1, 0 ], false)
      top_camera.height = 700.mm
      view.camera = top_camera

      names.each do |name|
        spec = CASES[name]
        messages = []
        parts, containers = run_case(model, instances, spec, messages)
        results[name] = { 'expected' => [ spec[:parts].sort, spec[:containers].sort ], 'selected' => [ parts, containers ], 'messages' => messages }
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

  class TC_Ladb_Tool_SmartPaintRect < TestUp::TestCase

    def test_rect_selection_picks_parts
      PaintRectRegression.results.each do |name, result|
        failure = PaintRectRegression.failure(result)
        assert(failure.nil?, "#{name} : #{failure}\n#{result.inspect}")
      end
    end

  end

end
