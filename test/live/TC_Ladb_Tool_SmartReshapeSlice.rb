# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : the fixture is built 20 m below the origin in an aborted
# operation, the camera and the slice options given back.
#
# The fixture : an upright board - 1000 (X) x 18 (Y) x 200 (Z) - seen from
# above, and a plain horizontal face beside it, the face reference. With
# fittings: true, the board holds machinings (x 200, 700) and, each in an
# untyped wrapper group, hardware (x 100, 600).
#
# What it checks, through the real SmartReshapeTool slice action - its
# handler driven without the mouse, hovers given in fixture coordinates :
#   - one plane : by the VCB distance or by the click, from the board end the
#     closest to the mouse (axis reference) or from a face (face reference) ;
#   - xn and /n : the same distribution (n planes / n pieces), fixed planes
#     the mouse no longer moves, applied by the click ; spacings ; SHIFT + ;
#   - @number drives the state : never STATE_SLICE with a number, ESC drops
#     the distribution, a mode change drops it but keeps the reference, the
#     restart after a slice keeps it ;
#   - cut : the side picked by the mouse, the other one erased ;
#   - the fittings (machinings, hardware) follow their piece - the hardware
#     laid in an untyped wrapper group as SmartJoin does, the wrapper shared
#     by the clones of a slice ;
#   - the SmartTool validation buttons never show ;
#   - the 3 points reference : a compound angle plane, its normal following
#     the mouse, ESC removing the last point, the axis lock, ↓ back to the
#     picked plane (face or 3 points) from an axis, then to its step.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartReshapeSlice.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartReshapeSlice.rb'
#   SliceRegression.run                          # one line per case
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module SliceRegression

  OCL = Ladb::OpenCutList
  RT = OCL::SmartReshapeTool
  HANDLER = OCL::SmartReshapeSliceActionHandler
  ACTION = RT::ACTION_SLICE

  Z0 = -20000.mm
  LENGTH = 1000
  THICKNESS = 18
  HEIGHT = 200
  TOLERANCE = 1.0  # mm : the hovers land on whole pixels

  # Each case : its options, its steps, the pieces expected - [ x0, x1, z0, z1 ]
  # in mm, the board being [ 0, 1000, 0, 200 ] - and with fittings: true, the
  # fittings each piece holds - [ kind, x ], in the pieces order. Steps :
  #   [ :hover, x(, y, z) ] the mouse over that fixture point (default : on the board top)
  #   [ :click ] / [ :esc ] / [ :key, VK ] / [ :shift_add ] / [ :text, 'vcb' ]
  #   [ :option, group, option ]
  #   [ :expect, state, number(, axis) ] the CURRENT handler state, @number (and @reference_axis)
  #   [ :point, x, y, z ] a reference point placed exactly there (3 points reference)
  #   [ :expect_points, n ] the number of reference points ; [ :expect_point, i, x, y, z ] one of them
  #   [ :expect_plane ] a plane reference (no axis) is set
  #
  # The 3 points plane (400, 0, 0), (600, 0, 200), (450, 18, 0) : x = 400 + 2.778 y + z,
  # 400 to 650 over the board ; its normal leans to -X, an offset of 50 along it is 155.9 in X.
  POINTS = [ [ :option, RT::ACTION_OPTION_SLICE_REFERENCE, RT::ACTION_OPTION_SLICE_REFERENCE_POINTS ], [ :point, 400, 0, 0 ], [ :point, 600, 0, 200 ], [ :point, 450, 18, 0 ] ]
  POINTS_PIECES = [ [ 0, 650, 0, 200 ], [ 400, 1000, 0, 200 ] ]
  CASES = {
    'one_plane_vcb' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :expect, HANDLER::STATE_SLICE, 0 ], [ :text, '200' ] ],
      pieces: [ [ 0, 200, 0, 200 ], [ 200, 1000, 0, 200 ] ],
    },
    'one_plane_click' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :hover, 300 ], [ :click ] ],
      pieces: [ [ 0, 300, 0, 200 ], [ 300, 1000, 0, 200 ] ],
    },
    'face_reference' => {
      steps: [ [ :hover, 300, 150, 0 ], [ :click ], [ :expect, HANDLER::STATE_SLICE, 0 ], [ :hover, 300 ], [ :text, '50' ] ],
      pieces: [ [ 0, 1000, 0, 50 ], [ 0, 1000, 50, 200 ] ],
    },
    'divide' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :text, '/4' ], [ :expect, HANDLER::STATE_SLICE_DISTRIBUTE, 3 ], [ :hover, 700 ], [ :click ] ],
      pieces: [ [ 0, 250, 0, 200 ], [ 250, 500, 0, 200 ], [ 500, 750, 0, 200 ], [ 750, 1000, 0, 200 ] ],
    },
    'multiply_fixed_planes' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :text, 'x3' ], [ :expect, HANDLER::STATE_SLICE_DISTRIBUTE, 3 ], [ :hover, 700 ], [ :click ] ],
      pieces: [ [ 0, 250, 0, 200 ], [ 250, 500, 0, 200 ], [ 500, 750, 0, 200 ], [ 750, 1000, 0, 200 ] ],
    },
    'spacings_first' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :text, '100;300' ], [ :expect, HANDLER::STATE_SLICE_DISTRIBUTE, 2 ], [ :click ] ],
      pieces: [ [ 0, 100, 0, 200 ], [ 100, 400, 0, 200 ], [ 400, 1000, 0, 200 ] ],
    },
    'spacings_both_ends' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :text, '100;;300' ], [ :expect, HANDLER::STATE_SLICE_DISTRIBUTE, 2 ], [ :click ] ],
      pieces: [ [ 0, 100, 0, 200 ], [ 100, 700, 0, 200 ], [ 700, 1000, 0, 200 ] ],
    },
    'shift_add' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :text, '/3' ], [ :shift_add ], [ :expect, HANDLER::STATE_SLICE_DISTRIBUTE, 3 ], [ :click ] ],
      pieces: [ [ 0, 250, 0, 200 ], [ 250, 500, 0, 200 ], [ 500, 750, 0, 200 ], [ 750, 1000, 0, 200 ] ],
    },
    'esc_drops_distribution' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :text, '/3' ], [ :esc ], [ :expect, HANDLER::STATE_SLICE, 0 ], [ :hover, 400 ], [ :click ] ],
      pieces: [ [ 0, 400, 0, 200 ], [ 400, 1000, 0, 200 ] ],
    },
    'reference_step_keeps_number' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :text, '/3' ], [ :key, VK_DOWN ], [ :expect, HANDLER::STATE_SLICE_REFERENCE, 2 ], [ :key, VK_RIGHT ], [ :expect, HANDLER::STATE_SLICE_DISTRIBUTE, 2 ], [ :click ] ],
      pieces: [ [ 0, 333.3, 0, 200 ], [ 333.3, 666.7, 0, 200 ], [ 666.7, 1000, 0, 200 ] ],
    },
    'restart_keeps_number' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :text, '/2' ], [ :click ], [ :expect, OCL::SmartSelectActionHandler::STATE_SELECT, 1 ] ],
      pieces: [ [ 0, 500, 0, 200 ], [ 500, 1000, 0, 200 ] ],
    },
    'cut_mode_change_keeps_reference' => {
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :text, '/3' ], [ :option, RT::ACTION_OPTION_SLICE_MODE, RT::ACTION_OPTION_SLICE_MODE_CUT ], [ :expect, HANDLER::STATE_SLICE, 0, X_AXIS ], [ :hover, 100 ], [ :text, '300' ], [ :expect, HANDLER::STATE_SLICE_SIDE, 0 ], [ :hover, 100 ], [ :click ] ],
      pieces: [ [ 0, 300, 0, 200 ] ],
    },
    'cut_erases_wrapped_hardware' => {
      fittings: true,
      steps: [ [ :option, RT::ACTION_OPTION_SLICE_MODE, RT::ACTION_OPTION_SLICE_MODE_CUT ], [ :hover, 100 ], [ :key, VK_RIGHT ], [ :hover, 100 ], [ :text, '300' ], [ :expect, HANDLER::STATE_SLICE_SIDE, 0 ], [ :hover, 800 ], [ :click ] ],
      pieces: [ [ 300, 1000, 0, 200 ] ],
      fittings_expected: [ [ [ 'hardware', 600 ], [ 'machining', 700 ] ] ],
    },
    'slice_splits_wrapped_hardware' => {
      fittings: true,
      steps: [ [ :hover, 100 ], [ :key, VK_RIGHT ], [ :hover, 100 ], [ :text, '300' ] ],
      pieces: [ [ 0, 300, 0, 200 ], [ 300, 1000, 0, 200 ] ],
      fittings_expected: [ [ [ 'hardware', 100 ], [ 'machining', 200 ] ], [ [ 'hardware', 600 ], [ 'machining', 700 ] ] ],
    },
    'points_reference' => {
      steps: POINTS + [ [ :expect, HANDLER::STATE_SLICE, 0 ], [ :expect_plane ], [ :text, '0' ] ],
      pieces: POINTS_PIECES,
    },
    'points_normal_toward_mouse_right' => {
      steps: POINTS + [ [ :hover, 900 ], [ :text, '50' ] ],
      pieces: [ [ 0, 805.9, 0, 200 ], [ 555.9, 1000, 0, 200 ] ],
    },
    'points_normal_toward_mouse_left' => {
      steps: POINTS + [ [ :hover, 100 ], [ :text, '50' ] ],
      pieces: [ [ 0, 494.1, 0, 200 ], [ 244.1, 1000, 0, 200 ] ],
    },
    'points_esc_removes_last' => {
      steps: POINTS[0, 3] + [ [ :expect_points, 2 ], [ :esc ], [ :expect_points, 1 ], [ :point, 600, 0, 200 ], [ :point, 450, 18, 0 ], [ :expect, HANDLER::STATE_SLICE, 0 ], [ :text, '0' ] ],
      pieces: POINTS_PIECES,
    },
    'points_collinear_refused' => {
      steps: POINTS[0, 3] + [ [ :point, 800, 0, 400 ], [ :expect_points, 2 ], [ :expect, HANDLER::STATE_SLICE_REFERENCE, 0 ], [ :point, 450, 18, 0 ], [ :text, '0' ] ],
      pieces: POINTS_PIECES,
    },
    'points_axis_lock' => {
      steps: POINTS[0, 2] + [ [ :key, VK_RIGHT ], [ :hover, 700, 9, 200 ], [ :click ], [ :expect_point, 1, 700, 0, 0 ], [ :esc ], [ :esc ], [ :expect_points, 0 ] ],
      pieces: [ [ 0, 1000, 0, 200 ] ],  # Not sliced
    },
    'points_axis_lock_rotated' => {
      # The board turned 30° around Z, the axes of the part : view.lock_inference ignores such a direction
      rotation: 30,
      steps: [ [ :option, RT::ACTION_OPTION_AXES, RT::ACTION_OPTION_AXES_ENTITY ] ] + POINTS[0, 1] + [ [ :point, 0, 0, 200 ], [ :key, VK_RIGHT ], [ :hover, 515.1, 307.8, 200 ], [ :click ], [ :expect_point, 1, 519.6, 300, 200 ] ],
      pieces: [ [ -9, 866, 0, 200 ] ],  # Not sliced
    },
    'points_axis_then_down_back_to_plane' => {
      steps: POINTS + [ [ :key, VK_RIGHT ], [ :expect, HANDLER::STATE_SLICE, 0, X_AXIS ], [ :key, VK_DOWN ], [ :expect, HANDLER::STATE_SLICE, 0 ], [ :expect_plane ], [ :text, '0' ] ],
      pieces: POINTS_PIECES,
    },
    'points_down_keeps_points' => {
      steps: POINTS + [ [ :key, VK_DOWN ], [ :expect, HANDLER::STATE_SLICE_REFERENCE, 0 ], [ :expect_points, 3 ], [ :click ], [ :expect, HANDLER::STATE_SLICE, 0 ], [ :text, '0' ] ],
      pieces: POINTS_PIECES,
    },
    'points_esc_forgets_plane' => {
      steps: POINTS + [ [ :esc ], [ :expect, HANDLER::STATE_SLICE_REFERENCE, 0 ], [ :expect_points, 0 ] ],
      pieces: [ [ 0, 1000, 0, 200 ] ],  # Not sliced
    },
    'face_axis_then_down_back_to_face' => {
      steps: [ [ :hover, 300, 150, 0 ], [ :click ], [ :key, VK_RIGHT ], [ :expect, HANDLER::STATE_SLICE, 0, X_AXIS ], [ :key, VK_DOWN ], [ :expect, HANDLER::STATE_SLICE, 0 ], [ :expect_plane ], [ :hover, 300 ], [ :text, '50' ] ],
      pieces: [ [ 0, 1000, 0, 50 ], [ 0, 1000, 50, 200 ] ],
    },
  }

  FITTING_SIZE = 10

  def self.point(x, y, z)
    Geom::Point3d.new(x.mm, y.mm, Z0 + z.mm)
  end

  # The board and the face reference, in the model root.
  def self.build(model, rotation = 0)
    definition = model.definitions.add('Slice board')
    face = definition.entities.add_face([ 0, 0, 0 ], [ LENGTH.mm, 0, 0 ], [ LENGTH.mm, THICKNESS.mm, 0 ], [ 0, THICKNESS.mm, 0 ])
    face.reverse! if face.normal.z < 0
    face.pushpull(HEIGHT.mm)
    board = model.entities.add_instance(definition, Geom::Transformation.translation(point(0, 0, 0)) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, rotation.degrees))
    reference = model.entities.add_face(point(0, 100, 0), point(LENGTH, 100, 0), point(LENGTH, 300, 0), point(0, 300, 0))
    reference.reverse! if reference.normal.z < 0
    [ board, reference ]
  end

  # Machinings laid in the board, hardware each in a wrapper group bearing no
  # material - as SmartJoin lays articles.
  def self.add_fittings(model, board)
    materials = [ [ 'Slice hardware', OCL::MaterialAttributes::TYPE_HARDWARE ], [ 'Slice machining', OCL::MaterialAttributes::TYPE_MACHINING ] ].map { |name, type|
      material = model.materials.add(name)
      attributes = OCL::MaterialAttributes.new(material)
      attributes.type = type
      attributes.write_to_attributes
      material
    }
    fitting = model.definitions.add('Slice fitting')
    face = fitting.entities.add_face([ 0, 0, 0 ], [ FITTING_SIZE.mm, 0, 0 ], [ FITTING_SIZE.mm, FITTING_SIZE.mm, 0 ], [ 0, FITTING_SIZE.mm, 0 ])
    face.reverse! if face.normal.z < 0
    face.pushpull(FITTING_SIZE.mm)
    entities = board.definition.entities
    fn_origin = lambda { |x| Geom::Transformation.translation([ (x - FITTING_SIZE / 2.0).mm, (THICKNESS - FITTING_SIZE).mm / 2.0, (HEIGHT - FITTING_SIZE).mm / 2.0 ]) }
    [ 100, 600 ].each do |x|
      wrapper = entities.add_group
      wrapper.entities.add_instance(fitting, fn_origin.call(x)).material = materials[0]
    end
    [ 200, 700 ].each { |x| entities.add_instance(fitting, fn_origin.call(x)).material = materials[1] }
  end

  # The fittings of the given piece at any depth, as [ kind, x ] in mm, sorted.
  def self.fittings(instance)
    found = []
    fn_walk = lambda { |entities, t|
      entities.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        type = OCL::MaterialAttributes.new(entity.material).type if entity.material
        if type == OCL::MaterialAttributes::TYPE_HARDWARE || type == OCL::MaterialAttributes::TYPE_MACHINING
          kind = type == OCL::MaterialAttributes::TYPE_HARDWARE ? 'hardware' : 'machining'
          found << [ kind, entity.bounds.center.transform(t).x.to_mm.round(1) ]
        else
          fn_walk.call(entity.definition.entities, t * entity.transformation)
        end
      end
    }
    fn_walk.call(instance.definition.entities, instance.transformation)
    found.sort
  end

  # The real slice tool, its messages recorded, the given board selected.
  def self.with_handler(model, board, messages)
    tool = RT.new(current_action: ACTION)
    [ :notify_success, :notify_warnings, :notify_errors, :notify, :set_root_tooltip, :show_message ].each do |name|
      tool.define_singleton_method(name) do |*args|
        next if [ :notify_success, :set_root_tooltip, :show_message ].include?(name)
        messages << [ name.to_s, args.first ].inspect
      end
    end
    model.select_tool(tool)
    begin
      handler = tool.instance_variable_get(:@action_handler)
      handler.send(:_set_active_selection, [], [ board ])
      handler.onSelected
      yield tool
    ensure
      model.select_tool(nil)
    end
  end

  def self.run_step(tool, step, messages)
    view = Sketchup.active_model.active_view
    handler = tool.instance_variable_get(:@action_handler)  # The current one : a slice restarts it
    case step[0]
    when :hover
      x, y, z = step[1], step[2] || THICKNESS / 2.0, step[3] || HEIGHT
      sp = view.screen_coords(point(x, y, z))
      tool.onMouseMove(0, sp.x.round, sp.y.round, view)
    when :click
      handler.onToolLButtonUp(tool, 0, tool.last_mouse_x, tool.last_mouse_y, view)
    when :esc
      handler.onToolCancel(tool, 0, view)
    when :key
      handler.onToolKeyDown(tool, step[1], false, 0, view)
    when :shift_add
      tool.define_singleton_method(:is_key_shift_down?) { true }
      handler.onToolKeyDown(tool, OCL::Kuix::VK_ADD, false, 0, view)
      tool.singleton_class.send(:remove_method, :is_key_shift_down?)
    when :text
      tool.onUserText(step[1], view)
    when :option
      tool.store_action_option_value(ACTION, step[1], step[2], fire_event: true)
    when :point
      handler.instance_variable_get(:@mouse_ip).copy!(point(*step[1, 3]))
      handler.onToolLButtonUp(tool, 0, tool.last_mouse_x, tool.last_mouse_y, view)
    when :expect_points
      got = handler.instance_variable_get(:@reference_points).length
      messages << "#{step.inspect} got #{got}" unless got == step[1]
    when :expect_point
      got = handler.instance_variable_get(:@reference_points)[step[1]]
      expected = point(*step[2, 3])
      messages << "#{step.inspect} got #{got.to_a.map { |v| v.to_mm.round(1) }.inspect}" unless got && got.distance(expected) <= TOLERANCE.mm
    when :expect_plane
      unless handler.instance_variable_get(:@reference_axis).nil? && handler.instance_variable_get(:@reference_plane)
        messages << "#{step.inspect} got axis #{handler.instance_variable_get(:@reference_axis).inspect}, plane #{handler.instance_variable_get(:@reference_plane).inspect}"
      end
    when :expect
      state, number, axis = step[1, 3]
      got = [ handler.fetch_state, handler.number ]
      messages << "#{step.inspect} got #{got.inspect}" unless got == [ state, number ]
      messages << "#{step.inspect} got axis #{handler.instance_variable_get(:@reference_axis).inspect}" unless axis.nil? || handler.instance_variable_get(:@reference_axis) == axis
    end
    messages << "#{step.inspect} : validation shown" if tool.instance_variable_get(:@validation_panel).visible?
  end

  # The slice instances in the model root but the fixture ones, as [ x0, x1, z0, z1 ] in mm.
  def self.pieces(model, kept)
    piece_instances(model, kept).map { |instance| piece_bounds(instance) }
  end

  def self.piece_instances(model, kept)
    (model.entities.grep(Sketchup::ComponentInstance) - kept).sort_by { |instance| piece_bounds(instance) }
  end

  def self.piece_bounds(instance)
    b = instance.bounds
    [ b.min.x.to_mm, b.max.x.to_mm, (b.min.z - Z0).to_mm, (b.max.z - Z0).to_mm ].map { |v| v.round(1) }
  end

  def self.same_fittings?(fittings, expected)
    fittings.size == expected.size &&
      fittings.zip(expected).all? { |piece, piece_expected|
        piece.size == piece_expected.size &&
          piece.zip(piece_expected.sort).all? { |(kind, x), (kind_expected, x_expected)| kind == kind_expected && (x - x_expected).abs <= TOLERANCE }
      }
  end

  def self.same_pieces?(pieces, expected)
    pieces.size == expected.size &&
      pieces.zip(expected.sort).all? { |piece, bounds| piece.zip(bounds).all? { |a, b| (a - b).abs <= TOLERANCE } }
  end

  def self.run_case(model, spec, messages)
    existing = model.entities.grep(Sketchup::ComponentInstance)
    board, reference = build(model, spec[:rotation] || 0)
    add_fittings(model, board) if spec[:fittings]
    model.active_view.refresh  # The picks read the last drawn frame
    with_handler(model, board, messages) do |tool|
      spec[:steps].each { |step| run_step(tool, step, messages) }
    end
    pieces = pieces(model, existing)
    fittings = spec[:fittings] ? piece_instances(model, existing).map { |instance| fittings(instance) } : nil
    model.entities.erase_entities((model.entities.grep(Sketchup::ComponentInstance) - existing) + reference.all_connected)
    [ pieces, fittings ]
  end

  def self.results(names = CASES.keys)
    model = Sketchup.active_model
    view = model.active_view
    camera = view.camera
    saved_camera = Sketchup::Camera.new(camera.eye, camera.target, camera.up, camera.perspective?)
    saved_camera.perspective? ? saved_camera.fov = camera.fov : saved_camera.height = camera.height
    model.select_tool(nil)
    model.active_path = nil unless model.active_path.nil?

    options_tool = RT.new(current_action: ACTION)
    saved_options = [ RT::ACTION_OPTION_SLICE_MODE, RT::ACTION_OPTION_SLICE_REFERENCE, RT::ACTION_OPTION_AXES ].map { |group| [ group, options_tool.fetch_action_option_value(ACTION, group) ] }

    results = {}
    model.start_operation('Slice fixture', true)
    neutralized = [ :start_operation, :commit_operation, :abort_operation ]
    begin
      neutralized.each { |name| model.define_singleton_method(name) { |*_args| true } }

      top_camera = Sketchup::Camera.new(point(LENGTH / 2, 150, 10000), point(LENGTH / 2, 150, 0), [ 0, 1, 0 ], false)
      top_camera.height = 1400.mm
      view.camera = top_camera

      names.each do |name|
        spec = CASES[name]
        options_tool.store_action_option_value(ACTION, RT::ACTION_OPTION_SLICE_MODE, RT::ACTION_OPTION_SLICE_MODE_SLICE)
        options_tool.store_action_option_value(ACTION, RT::ACTION_OPTION_SLICE_REFERENCE, RT::ACTION_OPTION_SLICE_REFERENCE_FACE)
        options_tool.store_action_option_value(ACTION, RT::ACTION_OPTION_AXES, RT::ACTION_OPTION_AXES_ACTIVE)
        messages = []
        pieces, fittings = run_case(model, spec, messages)
        results[name] = { 'expected' => spec[:pieces], 'pieces' => pieces, 'messages' => messages }
        results[name].merge!('fittings_expected' => spec[:fittings_expected], 'fittings' => fittings) if spec[:fittings]
      end
    ensure
      model.select_tool(nil)
      neutralized.each { |name| model.singleton_class.send(:remove_method, name) }
      model.abort_operation
      view.camera = saved_camera
      saved_options.each { |group, option| options_tool.store_action_option_value(ACTION, group, option) }
    end
    results
  end

  def self.failure(result)
    return "pieces #{result['pieces'].inspect} expected #{result['expected'].inspect}" unless same_pieces?(result['pieces'], result['expected'])
    return "fittings #{result['fittings'].inspect} expected #{result['fittings_expected'].inspect}" if result.key?('fittings') && !same_fittings?(result['fittings'], result['fittings_expected'])
    return "messages #{result['messages'].inspect}" unless result['messages'].empty?
    nil
  end

  def self.run(names = CASES.keys)
    results(names).map { |name, result|
      failure = failure(result)
      "#{name} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"} — #{result['pieces'].inspect}"
    }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartReshapeSlice < TestUp::TestCase

    def test_slice
      SliceRegression.results.each do |name, result|
        failure = SliceRegression.failure(result)
        assert(failure.nil?, "#{name} : #{failure}\n#{result.inspect}")
      end
    end

  end

end
