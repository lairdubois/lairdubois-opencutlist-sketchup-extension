# LIVE test : needs a real SketchUp with OpenCutList loaded AND
# docs/skp/test_stretch.skp as the active model. It is never opened from here -
# that would replace the model being worked on.
#
# Every case of that model is a top level ComponentInstance "Snn" holding its
# assembly (every instance named, definitions prefixed "Snn_" so that no two
# cases share anything) and a "ladb_stretch_test" attribute dictionary :
#   description  String
#   stretches    JSON [ { context, targets, axes, axis, grip, ratios, distance, centered, make_unique, interior } ]
#                applied one after the other, each on a fresh split (the way
#                chained stretches go in the tool) :
#                context      instance names from the case down to the edited
#                             context (optional, [] = the case itself)
#                targets      names of the stretched instances, in the context
#                axes         'context' (the default) or 'entity' : the edit
#                             axes, as the tool's axes option (entity = the
#                             first target's own axes)
#                axis         'x', 'y' or 'z' (edit space)
#                grip         'max' (the default) or 'min' : the bounds face pulled
#                ratios       cutters along the axis (optional, [ 0.5 ] by default)
#                distance     mm : grip offset along its outward direction
#                             (> 0 expands, < 0 compresses), or the interior
#                             handle move along the axis
#                centered, make_unique  booleans (optional, false by default)
#                interior     index of the interior handle moved (optional) :
#                             grabbed at the middle of its section
#   expected     JSON, what is compared (see StretchRegression::COMPARED) - written by record: true
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Worker_Stretch.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Worker_Stretch.rb'
#   StretchRegression.run                         # every case : report, compared to 'expected'
#   StretchRegression.run([ 'S01', 'S10' ])       # some cases
#   StretchRegression.run(nil, record: true)      # store the results as 'expected'
#
# Each case goes through the workers only - CommonStretchSplitWorker,
# StretchSplitDef#stretch_def, CommonStretchApplyWorker (wrap_operation:
# false) - inside a model operation that is aborted afterwards : the file is
# left as it was. A split whose sections are not valid (a curve crossing a
# cutter) is not applied, as the tool refuses it.
require 'json'
require 'digest'
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module StretchRegression

  DICT = 'ladb_stretch_test'
  OCL = Ladb::OpenCutList

  AXES = { 'x' => X_AXIS, 'y' => Y_AXIS, 'z' => Z_AXIS }

  def self.mm(value) ; (value.to_f * 25.4).round(2) ; end

  def self.find_child(entities, name)
    entities.find { |entity| entity.respond_to?(:definition) && entity.name == name } || raise("no instance named '#{name}'")
  end

  # One stretch of the case : what the workers answered.
  def self.stretch(case_instance, spec)
    context = [ case_instance ]
    (spec['context'] || []).each { |name| context << find_child(context.last.definition.entities, name) }
    targets = spec['targets'].map { |name| find_child(context.last.definition.entities, name) }

    axis = AXES.fetch(spec['axis'] || 'x')
    et = OCL::PathUtils.get_transformation(context, IDENTITY)
    et = et * targets.first.transformation if spec['axes'] == 'entity' && targets.one?
    grip_min, grip_max = OCL::Kuix::Bounds3d.faces_by_axis(axis)
    ratios = spec['ratios'] || [ 0.5 ]

    split_def = OCL::CommonStretchSplitWorker.new(targets.map { |target| Sketchup::InstancePath.new(context + [ target ]) },
                                                  et: et,
                                                  axis: axis,
                                                  grip_index: spec['grip'] == 'min' ? grip_min : grip_max,
                                                  ratios: ratios).run
    return { 'split' => false } unless split_def.is_a?(OCL::StretchSplitDef)
    return { 'sections_valid' => false } unless split_def.sections_valid?

    distance = spec['distance'].to_f.mm
    if (interior_index = spec['interior'])
      # The handle of the interior section, grabbed at its middle - as the tool offers it
      keb = OCL::Kuix::Bounds3d.new.copy!(split_def.eb)
      pmin = keb.face_center(grip_min).to_p
      v = pmin.vector_to(keb.face_center(grip_max).to_p)
      sorted = ratios.sort.uniq
      ps = pmin.offset(v, v.length * (sorted[interior_index - 1] + sorted[interior_index]) / 2.0).transform(et)
      stretch_def = split_def.stretch_def(ps, ps.offset(axis.transform(et), distance), interior_index: interior_index)
    else
      stretch_def = split_def.stretch_def_by_distance(distance, centered: spec['centered'] == true)
    end
    return { 'stretch' => false } unless stretch_def.is_a?(OCL::StretchDef)

    result_def = OCL::CommonStretchApplyWorker.new(stretch_def,
                                                   selection_path: context,
                                                   selection_instances: targets,
                                                   make_unique: spec['make_unique'] == true,
                                                   wrap_operation: false).run

    {
      'sections_valid' => true,
      'applied' => mm(stretch_def.measure),
      'compressed' => stretch_def.compressed?,
      'cutters' => stretch_def.cutter_ratios.map { |ratio| ratio.round(4) },
      'errors' => result_def.errors,
    }
  end

  # Every instance occurrence of the case, by name path : its definition, its
  # own geometry (bounds in the case space, shape signature in its definition
  # space, free edges), mirror and glue state.
  def self.occurrences(case_instance)
    list = []
    fn = lambda { |entities, path, transformation|
      entities.each do |entity|
        next unless entity.respond_to?(:definition)
        name = entity.name.empty? ? "(#{entity.definition.group? ? 'group' : entity.definition.name})" : entity.name
        entity_path = path + [ name ]
        t = transformation * entity.transformation
        definition = entity.definition
        edges = definition.entities.grep(Sketchup::Edge)
        points = edges.flat_map { |edge| edge.vertices }.uniq.map { |vertex| vertex.position }
        bounds = Geom::BoundingBox.new
        points.each { |point| bounds.add(point.transform(t)) }
        list << [ entity, entity_path.join('/'), {
          'definition' => definition.group? ? 'group' : definition.name,
          'bounds' => bounds.valid? ? [ bounds.min, bounds.max ].flat_map { |point| point.to_a.map { |v| mm(v) } } : nil,
          'shape' => Digest::MD5.hexdigest(points.map { |point| point.to_a.map { |v| mm(v) } }.sort.inspect)[0, 8],
          'free_edges' => definition.entities.grep(Sketchup::Face).empty? ? 0 : edges.count { |edge| edge.faces.length != 2 },
          'mirror' => OCL::TransformationUtils.flipped?(entity.transformation),
          'glued' => entity.respond_to?(:glued_to) && !entity.glued_to.nil?,
        } ]
        fn.call(definition.entities, entity_path, t)
      end
    }
    fn.call(case_instance.definition.entities, [], IDENTITY)
    list
  end

  def self.run_case(case_instance)
    messages = []
    stretches = JSON.parse(case_instance.get_attribute(DICT, 'stretches')).map { |spec|
      begin
        stretch(case_instance, spec)
      rescue Exception => e
        messages << "#{e.class}: #{e.message} @ #{e.backtrace.first(2).join(' < ')}"
        'error'
      end
    }

    occurrences = self.occurrences(case_instance)
    shared = occurrences.group_by { |entity, _path, _stats| entity.definition }.values.select { |group| group.length > 1 }.map { |group| group.map { |_entity, path, _stats| path }.sort }.sort

    {
      'stretches' => stretches,
      'occurrences' => Hash[occurrences.map { |_entity, path, stats| [ path, stats ] }.sort_by(&:first)],
      'shared' => shared,
      'messages' => messages,
    }
  end

  COMPARED = %w[stretches occurrences shared]

  MODEL_NAME = 'test_stretch.skp'

  def self.model_ready?
    (model = Sketchup.active_model) && File.basename(model.path.to_s) == MODEL_NAME
  end

  def self.case_instances(ids = nil)
    Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).select { |instance| instance.attribute_dictionary(DICT) && (ids.nil? || ids.include?(instance.name)) }.sort_by(&:name)
  end

  def self.expected(case_instance)
    JSON.parse(case_instance.get_attribute(DICT, 'expected') || '{}')
  end

  # The results of the given cases, by id - computed, then undone. The workers
  # run with wrap_operation: false, inside this single operation.
  def self.results(ids = nil)
    model = Sketchup.active_model
    results = {}
    model.start_operation('Stretch regression', true)
    begin
      case_instances(ids).each { |case_instance| results[case_instance.name] = run_case(case_instance) }
    ensure
      model.abort_operation
    end
    results
  end

  # The value as the expectation stores it : JSON round tripped.
  def self.normalize(value)
    JSON.parse(JSON.generate([ value ])).first
  end

  # The keys of 'occurrences' that differ, for a readable report.
  def self.diff_occurrences(expected, actual)
    (expected.keys | actual.keys).sort.reject { |path| expected[path] == actual[path] }.map { |path|
      e = expected[path] || {}
      a = actual[path] || {}
      "#{path}: " + (e.keys | a.keys).reject { |key| e[key] == a[key] }.map { |key| "#{key} #{e[key].inspect} -> #{a[key].inspect}" }.join(', ')
    }
  end

  def self.run(ids = nil, record: false)
    model = Sketchup.active_model

    lines = []
    results(ids).each do |id, result|
      case_instance = case_instances([ id ]).first
      details = []
      if record
        model.start_operation('Record stretch expectations', true)
        case_instance.set_attribute(DICT, 'expected', JSON.generate(result.select { |key, _| COMPARED.include?(key) }))
        model.commit_operation
        status = 'RECORDED'
      else
        expected = expected(case_instance)
        diffs = COMPARED.reject { |key| expected[key] == normalize(result[key]) }
        status = expected.empty? ? 'NO-EXPECTED' : (diffs.empty? ? 'PASS' : "FAIL(#{diffs.join(',')})")
        details.concat(diff_occurrences(expected['occurrences'] || {}, normalize(result['occurrences']))) if diffs.include?('occurrences')
        details << "expected stretches: #{expected['stretches'].inspect}" if diffs.include?('stretches')
        details << "expected shared: #{expected['shared'].inspect}" if diffs.include?('shared')
      end
      lines << "#{id} #{status} — #{case_instance.get_attribute(DICT, 'description')}"
      lines << "    stretches: #{result['stretches'].inspect}"
      lines << "    shared: #{result['shared'].inspect}"
      lines << "    messages: #{result['messages'].inspect}" unless result['messages'].empty?
      details.each { |detail| lines << "    ! #{detail}" }
    end
    lines.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Worker_Stretch < TestUp::TestCase

    CASES = %w[S01 S02 S03 S04 S05 S06 S07 S08 S09 S10 S11 S12 S13 S14]

    def setup
      assert(StretchRegression.model_ready?, "Live test : open docs/skp/#{StretchRegression::MODEL_NAME} first (active model : #{Sketchup.active_model.path.inspect})")
    end

    CASES.each do |id|
      define_method("test_#{id.downcase}") do
        case_instance = StretchRegression.case_instances([ id ]).first
        assert(!case_instance.nil?, "#{id} : no such case in the model")
        expected = StretchRegression.expected(case_instance)
        assert(!expected.empty?, "#{id} : no expectation recorded")

        result = StretchRegression.results([ id ])[id]
        description = case_instance.get_attribute(StretchRegression::DICT, 'description')
        StretchRegression::COMPARED.each do |key|
          details = key == 'occurrences' ? StretchRegression.diff_occurrences(expected[key], StretchRegression.normalize(result[key])).join("\n") : result['messages'].inspect
          assert_equal(expected[key], StretchRegression.normalize(result[key]), "#{id} #{key} — #{description}\n#{details}")
        end
      end
    end

  end

end
