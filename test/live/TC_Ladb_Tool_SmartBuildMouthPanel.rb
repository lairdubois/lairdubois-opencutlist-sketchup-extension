# LIVE test : needs a real SketchUp with OpenCutList loaded AND
# docs/skp/test_mouth_panels.skp as the active model. It is never opened from
# here - that would replace the model being worked on.
#
# Every case of that model is a top level ComponentInstance "Bnn" (back
# panels) or "Fnn" (front panels, and back and front panels together) holding
# its parts (instance name = part id) and a "ladb_mouth_panel_test" attribute
# dictionary :
#   description  String
#   picks        JSON [ { kind, origin, target, facing | camera, options, merge: [ { origin, target } ] } ]
#                (mm, case local).
#                kind is 'back' (the default) or 'front' : the handler that
#                draws. A new handler is made whenever the kind changes from
#                one pick to the next, the way switching action does in the
#                tool - the same one is kept while it does not.
#                A BACK pick is read through the panels, like the handler does
#                (see SmartBuildPanelActionHandler#_snap_point_through_cavities) :
#                the ray must enter the mouth and land on a wall of the cavity.
#                A FRONT pick is read off the MODEL, like the handler does : the
#                ray is cast at the model (Model#raytest) and the face it stops
#                on is what the picker would hand over - a panel already
#                standing in the way included.
#                facing forces the direction the opening must face ; camera is a
#                camera DIRECTION instead, handed to the handler's own
#                _panel_opening_facing_vector - what exercises the choice
#                between several openings the view sees at once.
#                options, when given, overrides the case options for that pick.
#   options      JSON { thickness, depth, setback (mm), through_groove, overlay (optional, false by default),
#                       front_offset (mm, optional, 0 by default), mirror (optional, false by default) }
#   expected     JSON, what is compared (see MouthPanelRegression::COMPARED) - written by record: true
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartBuildMouthPanel.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartBuildMouthPanel.rb'
#   MouthPanelRegression.run                                   # every case : report, compared to 'expected'
#   MouthPanelRegression.run([ 'B06', 'F01' ])                 # some cases
#   MouthPanelRegression.run(nil, record: true)                # store the results as 'expected'
#   MouthPanelRegression.run([ 'B12' ], overrides: { 'through_groove' => false })
#
# Each case draws its panel(s) with the real SmartBuildBackPanelActionHandler
# and SmartBuildFrontPanelActionHandler, driven without the mouse, inside a
# model operation that is aborted afterwards : the file is left as it was. The
# handlers' own operations are neutralized for the duration (SketchUp commits
# an open operation when another one starts, which would make the abort a
# no-op).
require 'json'
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module MouthPanelRegression

  DICT = 'ladb_mouth_panel_test'
  OCL = Ladb::OpenCutList

  HANDLERS = {
    'back' => [ OCL::SmartBuildTool::ACTION_BUILD_BACK_PANEL, OCL::SmartBuildBackPanelActionHandler ],
    'front' => [ OCL::SmartBuildTool::ACTION_BUILD_FRONT_PANEL, OCL::SmartBuildFrontPanelActionHandler ],
  }

  module Probe
    def _cut_extension_defs(opening_def, ti)
      result = super
      (@probe_extensions ||= []).concat(result.map { |drawing_def, _path| drawing_def.container_path.last.name })
      result
    end
    def _cut_host_defs(panel_defs, extension_defs)
      result = super
      (@probe_passes ||= []) << result.group_by { |host_def| host_def[2] }.select { |pass, _| pass > 0 }.sort_by(&:first).map { |_pass, host_defs|
        host_defs.map { |host_def| (path = _descendant_path(_get_cavities_def.container_path, host_def[0])) ? path.last.name : '?' }.sort
      }
      result
    end
  end

  # What the handler reads off a SmartPicker, and nothing more.
  Picker = Struct.new(:picked_face_path, :picked_plane_manipulator, :picked_point, :view)

  def self.vec(a, t) ; Geom::Vector3d.new(*a.map { |v| v.to_f.mm }).transform(t) ; end
  def self.pnt(a, t) ; Geom::Point3d.new(*a.map { |v| v.to_f.mm }).transform(t) ; end

  def self.part_stats(case_instance)
    case_instance.definition.entities.grep(Sketchup::ComponentInstance).concat(case_instance.definition.entities.grep(Sketchup::Group)).map { |instance|
      edges = instance.definition.entities.grep(Sketchup::Edge)
      [ instance, {
        'name' => instance.name.empty? ? "(#{instance.layer.name})" : instance.name,
        'definition' => instance.definition.name,
        'volume' => (instance.volume.to_f * 16387.064).round(0),   # in3 -> mm3
        'manifold' => instance.manifold?,
        'bad_edges' => edges.count { |edge| edge.faces.length != 2 },
        'faces' => instance.definition.entities.grep(Sketchup::Face).length,
        'bad_edge_points' => edges.select { |edge| edge.faces.length != 2 }.first(6).map { |edge|
          [ edge.faces.length ] + [ edge.start, edge.end ].map { |vertex| vertex.position.transform(instance.transformation).to_a.map { |v| (v.to_f * 25.4).round(2) } }
        },
      } ]
    }
  end

  def self.make_handler(tool, kind, options)
    handler = HANDLERS[kind].last.new(tool)
    handler.singleton_class.send(:prepend, Probe)
    fixed = {
      :_fetch_option_thickness => options['thickness'].to_f.mm,
      :_fetch_option_overlay_full_overlay? => options['overlay'] == true,
      :_fetch_option_reduce_envelope? => false,
      :_fetch_option_reuse_definition? => true,
      :_fetch_option_measure_reversed? => false,
      :_fetch_option_ask_name? => false,
    }
    if kind == 'back'
      fixed.merge!({
        :_fetch_option_groove_depth => options['depth'].to_f.mm,
        :_fetch_option_groove_setback => options['setback'].to_f.mm,
        :_fetch_option_groove_through? => options['through_groove'],
      })
    else
      fixed.merge!({
        :_fetch_option_front_panel_offset => options['front_offset'].to_f.mm,
        :_fetch_option_mirror? => options['mirror'] == true,
      })
    end
    fixed.each { |name, value| handler.define_singleton_method(name) { value } }
    handler.define_singleton_method(:_reset_active_part) { @active_part_entity_path = nil ; @active_part = nil }
    handler
  end

  # The face a ray stops on in the model, as [ point, path ] - edges and
  # construction geometry (the case's own pick markers) are stepped over.
  def self.raytest_face(origin, direction)
    model = Sketchup.active_model
    100.times do
      hit = model.raytest([ origin, direction ], true)
      return nil if hit.nil?
      return hit if hit[1].last.is_a?(Sketchup::Face)
      origin = hit[0].offset(direction, 0.01.mm)
    end
    nil
  end

  # One pick : nil when it drew, else why it did not - the tooltip the tool
  # would show there ('invalid_cavity', 'closed_opening'), 'missed' when the
  # ray found nothing to stand on, 'refused' when the pick was fine but the
  # handler drew nothing.
  def self.draw(handler, kind, view, case_instance, pick)
    t = case_instance.transformation
    if pick['camera']
      # A real look : the handler's own hook turns it into the facing it asks for
      camera_view = Struct.new(:camera).new(Struct.new(:direction).new(vec(pick['camera'], t).normalize))
      handler.define_singleton_method(:_panel_opening_facing_vector) { |_view| super(camera_view) }
    else
      facing = vec(pick['facing'], t).normalize
      handler.define_singleton_method(:_panel_opening_facing_vector) { |_view| [ facing.x, facing.y, facing.z ] }
    end

    part_path = [ case_instance, case_instance.definition.entities.grep(Sketchup::ComponentInstance).find { |instance| !OCL::LayerAttributes.panel_type?(OCL::LayerAttributes.type_of(instance)) } ]
    part = handler.send(:_generate_part_from_path, part_path)
    raise 'no part' unless part.is_a?(OCL::Part)
    handler.instance_variable_set(:@active_part_entity_path, part_path)
    handler.instance_variable_set(:@active_part, part)

    cavities_def = handler.send(:_get_cavities_def)
    raise "no cavities (#{cavities_def.inspect[0, 200]})" unless cavities_def.is_a?(OCL::SmartBuildPanelActionHandler::CavitiesDef) && cavities_def.valid?

    ray = lambda { |r|
      origin = pnt(r['origin'], t)
      cavities_def.pick_ray(origin, origin.vector_to(pnt(r['target'], t)).normalize)
    }

    if kind == 'back'
      picked = ray.call(pick)
      return 'invalid_cavity' if picked.nil?
      fragment_def, point, plane_manipulator = picked
      handler.instance_variable_set(:@picked_fragment_def, fragment_def)
      handler.instance_variable_set(:@picked_point, point)
      handler.instance_variable_set(:@picked_plane_manipulator, plane_manipulator)
    else
      origin = pnt(pick['origin'], t)
      hit = raytest_face(origin, origin.vector_to(pnt(pick['target'], t)).normalize)
      return 'missed' if hit.nil?
      point, face_path = hit
      picker = Picker.new(face_path, OCL::FaceManipulator.new(face_path.last, OCL::PathUtils.get_transformation(face_path[0...-1], IDENTITY)), point, view)
      handler.instance_variable_set(:@picker, picker)
      return 'invalid_cavity' unless handler.send(:_snap_point, picker)
      point = handler.instance_variable_get(:@picked_point)
    end
    return 'closed_opening' if handler.send(:_picked_on_closed_opening?, view)

    unless (merge = pick['merge'] || []).empty?
      context = handler.send(:_compute_panel_context, point, view)
      raise 'merge seed refused' unless context.is_a?(OCL::SmartBuildMouthPanelActionHandler::MouthPanelContext)
      ti = context.transformation.inverse
      handler.instance_variable_set(:@merge_context, context)
      handler.instance_variable_set(:@merge_fragment_defs, [ context.fragment_def ])
      handler.instance_variable_set(:@merge_paths, [ OCL::Fiddle::Clippy.points_to_rpath(handler.send(:_get_cavity_share_points, context.fragment_def, context.opening_def, ti)) ])
      handler.instance_variable_set(:@merge_mouth_paths, [ OCL::Fiddle::Clippy.points_to_rpath(handler.send(:_get_cavity_mouth_points, context.fragment_def, context.opening_def, ti)) ])
      merge.each do |r|
        raise "merge missed #{r['target'].inspect}" if (picked = ray.call(r)).nil?
        raise "merge refused #{r['target'].inspect}" unless handler.send(:_merge_add, picked[0])
      end
    end

    created = handler.send(:_create_entity, point, view)
    handler.send(:_reset_merge)
    created ? nil : 'refused'
  end

  def self.run_case(case_instance, overrides = {})
    model = Sketchup.active_model
    view = model.active_view
    picks = JSON.parse(case_instance.get_attribute(DICT, 'picks'))
    options = JSON.parse(case_instance.get_attribute(DICT, 'options')).merge(overrides)

    messages = []
    tools = {}
    handlers = []
    handler = nil
    handler_kind = nil

    before = Hash[part_stats(case_instance).map { |instance, stats| [ instance.name, stats ] }]

    refusals = picks.map { |pick|
      kind = pick['kind'] || 'back'
      begin
        unless handler_kind == kind
          tool = tools[kind] ||= OCL::SmartBuildTool.new(current_action: HANDLERS[kind].first).tap { |new_tool|
            [ :notify_success, :notify_warnings, :notify_errors, :notify, :show_tooltip, :remove_tooltip, :push_cursor, :pop_cursor ].each do |name|
              new_tool.define_singleton_method(name) { |*args| messages << [ name.to_s, args.first ].inspect unless [ :notify_success, :remove_tooltip, :push_cursor, :pop_cursor ].include?(name) }
            end
          }
          handler = make_handler(tool, kind, options.merge(pick['options'] || {}))
          handler_kind = kind
          handlers << handler
        end
        draw(handler, kind, view, case_instance, pick)
      rescue Exception => e
        messages << "#{e.class}: #{e.message} @ #{e.backtrace.first(2).join(' < ')}"
        'error'
      end
    }

    after = part_stats(case_instance).map(&:last)
    extensions = Hash.new(0)
    handlers.flat_map { |h| h.instance_variable_get(:@probe_extensions) || [] }.each { |name| extensions[name] += 1 }
    carcass = after.select { |stats| before.key?(stats['name']) }
    shared = carcass.group_by { |stats| stats['definition'] }.values.select { |group| group.length > 1 }.map { |group| group.map { |stats| stats['name'] }.sort }.sort

    {
      'created' => refusals.map(&:nil?),
      'refusals' => refusals,
      'extensions' => Hash[extensions.sort],
      'passes' => handlers.flat_map { |h| h.instance_variable_get(:@probe_passes) || [] },
      'grooved' => carcass.select { |stats| stats['volume'] < before[stats['name']]['volume'] }.map { |stats| stats['name'] }.sort,
      'removed_mm3' => Hash[carcass.map { |stats| [ stats['name'], before[stats['name']]['volume'] - stats['volume'] ] }.sort],
      'panels' => after.reject { |stats| before.key?(stats['name']) }.map { |stats| stats['volume'] }.sort,
      'non_manifold' => after.reject { |stats| stats['manifold'] && stats['bad_edges'] == 0 }.map { |stats| "#{stats['name']}:#{stats['bad_edges']}" },
      'bad_edge_points' => Hash[after.reject { |stats| stats['bad_edge_points'].empty? }.map { |stats| [ stats['name'], stats['bad_edge_points'] ] }],
      'shared' => shared,
      'messages' => messages,
    }
  end

  # What must match the expectation. Volumes are reported, not compared : a
  # tessellation change moves them by a few mm3 without anything being wrong.
  COMPARED = %w[created refusals extensions passes grooved panels non_manifold shared]

  MODEL_NAME = 'test_mouth_panels.skp'

  def self.model_ready?
    (model = Sketchup.active_model) && File.basename(model.path.to_s) == MODEL_NAME
  end

  def self.case_instances(ids = nil)
    Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).select { |instance| instance.attribute_dictionary(DICT) && (ids.nil? || ids.include?(instance.name)) }.sort_by(&:name)
  end

  def self.expected(case_instance)
    JSON.parse(case_instance.get_attribute(DICT, 'expected') || '{}')
  end

  # The results of the given cases, by id - computed, then undone.
  def self.results(ids = nil, overrides = {})
    model = Sketchup.active_model
    results = {}
    model.start_operation('Mouth panel regression', true)
    neutralized = [ :start_operation, :commit_operation, :abort_operation ]
    begin
      neutralized.each { |name| model.define_singleton_method(name) { |*_args| true } }
      case_instances(ids).each { |case_instance| results[case_instance.name] = run_case(case_instance, overrides) }
    ensure
      neutralized.each { |name| model.singleton_class.send(:remove_method, name) }
      model.abort_operation
    end
    results
  end

  # The value as the expectation stores it : JSON round tripped.
  def self.normalize(value)
    JSON.parse(JSON.generate([ value ])).first
  end

  def self.run(ids = nil, record: false, overrides: {})
    model = Sketchup.active_model

    lines = []
    results(ids, overrides).each do |id, result|
      case_instance = case_instances([ id ]).first
      if record
        model.start_operation('Record mouth panel expectations', true)
        case_instance.set_attribute(DICT, 'expected', JSON.generate(result.select { |key, _| COMPARED.include?(key) }))
        model.commit_operation
        status = 'RECORDED'
      else
        expected = expected(case_instance)
        diffs = COMPARED.reject { |key| expected[key] == normalize(result[key]) }
        status = expected.empty? ? 'NO-EXPECTED' : (diffs.empty? ? 'PASS' : "FAIL(#{diffs.join(',')})")
      end
      lines << "#{id} #{status} — #{case_instance.get_attribute(DICT, 'description')}"
      result.each { |key, value| lines << "    #{key}: #{value.inspect}" unless ((key == 'messages' || key == 'bad_edge_points') && value.empty?) }
    end
    lines.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartBuildMouthPanel < TestUp::TestCase

    CASES = %w[B01 B02 B03 B04 B05 B06 B07 B08 B09 B10 B11 B12 B13 B14 B15 B16 B17 B18 B19 B20 F01 F02 F03 F04 F05]

    def setup
      assert(MouthPanelRegression.model_ready?, "Live test : open docs/skp/#{MouthPanelRegression::MODEL_NAME} first (active model : #{Sketchup.active_model.path.inspect})")
    end

    CASES.each do |id|
      define_method("test_#{id.downcase}") do
        case_instance = MouthPanelRegression.case_instances([ id ]).first
        assert(!case_instance.nil?, "#{id} : no such case in the model")
        expected = MouthPanelRegression.expected(case_instance)
        assert(!expected.empty?, "#{id} : no expectation recorded")

        result = MouthPanelRegression.results([ id ])[id]
        description = case_instance.get_attribute(MouthPanelRegression::DICT, 'description')
        MouthPanelRegression::COMPARED.each do |key|
          details = result.reject { |detail_key, value| detail_key == key || ((detail_key == 'messages' || detail_key == 'bad_edge_points') && value.empty?) }
          assert_equal(expected[key], MouthPanelRegression.normalize(result[key]), "#{id} #{key} — #{description}\n#{details.inspect}")
        end
      end
    end

  end

end
