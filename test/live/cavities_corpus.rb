# LIVE regression dump of CommonSolidFindCavitiesWorker : needs a real
# SketchUp with OpenCutList loaded AND docs/skp/test_cavities.skp as the
# active model. It is never opened from here - that would replace the model
# being worked on.
#
# Every case of that model is a top level ComponentInstance "Tnn · ..." (its
# definition name) holding its panels as direct children. Each case is read
# the way SmartActionHandlerCavitiesHelper#_get_cavities_def reads a
# container : the children with an applied panel role (front_panel /
# back_panel) are handed apart as front_panel_drawing_defs, read whole and
# blind to visibility, the others as the panels of the carcass.
#
# Nothing is asserted : the dump - per case and per reduce setting, the
# cavity count then, per cavity, its bounds in the case's own frame, its
# distinct vertex count and its volume - is meant to be DIFFED between two
# runs, before and after a change to the worker :
#
#   load '<repo>/test/live/cavities_corpus.rb'
#   CavitiesCorpus.run('/path/to/before.txt')
#   # change, then reload the worker (Ruby only - never a Fiddle lib)
#   CavitiesCorpus.run('/path/to/after.txt')
#
# The volume is there for what the bounds miss : a face that tilts but still
# reaches the same extreme - the inset back of T45, recessed along a
# quantized normal - keeps the bounds, never the volume.
module CavitiesCorpus

  OCL = Ladb::OpenCutList

  CASE_NAME_PATTERN = /\AT\d+/

  CUBIC_INCHES_TO_CUBIC_CENTIMETERS = 16.387064

  # Writes the dump to +output_path+ and returns a one-line summary.
  def self.run(output_path, max_opening_planes: 4)
    model = Sketchup.active_model
    raise 'docs/skp/test_cavities.skp must be the active model' unless model.path.end_with?('test_cavities.skp')

    lines = []
    start = Time.now
    cases = model.entities.grep(Sketchup::ComponentInstance)
                 .select { |instance| _case_name(instance) =~ CASE_NAME_PATTERN }
                 .sort_by { |instance| _case_name(instance)[/\d+/].to_i }
    cases.each do |instance|
      name = _case_name(instance)[CASE_NAME_PATTERN]
      inverse = instance.transformation.inverse

      children = instance.definition.entities.select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
      applied, plain = children.partition { |entity| OCL::DefinitionAttributes.applied_panel_role?(OCL::DefinitionAttributes.role_of(entity)) }
      drawing_defs = plain.map { |entity| _decompose([ instance, entity ], false) }
      front_panel_drawing_defs = applied.flat_map { |entity| _applied_panel_part_paths([ instance, entity ]).map { |path| _decompose(path, true) } }

      [ true, false ].each do |reduce_envelope|
        result_def = OCL::CommonSolidFindCavitiesWorker.new(drawing_defs,
                                                            max_opening_planes: max_opening_planes,
                                                            reduce_envelope: reduce_envelope,
                                                            front_panel_drawing_defs: front_panel_drawing_defs
        ).run
        unless result_def.success?
          lines << "#{name} reduce=#{reduce_envelope} ERROR #{result_def.errors.inspect}"
          next
        end
        descriptions = result_def.fragment_defs.map { |fragment_def| _describe(fragment_def, inverse) }.sort
        lines << "#{name} reduce=#{reduce_envelope} frags=#{descriptions.length}"
        descriptions.each { |description| lines << "    #{description}" }
      end
    end

    File.write(output_path, lines.join("\n") + "\n")
    "#{cases.length} cases, #{(Time.now - start).round(1)} s"
  end

  def self._case_name(instance)
    instance.name.empty? ? instance.definition.name : instance.name
  end

  # One panel, the way SmartActionHandlerCavitiesHelper#_decompose_cavity_panel reads it.
  def self._decompose(path, ignore_visibility)
    OCL::CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(path) ],
                                              ignore_surfaces: true,
                                              ignore_edges: true,
                                              container_validator: OCL::CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS,
                                              ignore_visibility: ignore_visibility,
                                              flatten: false
    ).run
  end

  # An applied panel holding faces is one part, an assembly (a frame door)
  # one part per child - a simplified
  # SmartActionHandlerCavitiesHelper#_get_applied_panel_part_entity_paths,
  # enough for the corpus.
  def self._applied_panel_part_paths(path)
    return [ path ] if path.last.definition.entities.any? { |entity| entity.is_a?(Sketchup::Face) }
    path.last.definition.entities
        .select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
        .map { |entity| path + [ entity ] }
  end

  # Bounds in the case's own frame (mm), distinct vertex count, volume (cm³).
  def self._describe(fragment_def, inverse)
    points = fragment_def.vertices.each_slice(3).map { |x, y, z| Geom::Point3d.new(x, y, z).transform(inverse) }
    min = (0..2).map { |axis| points.map { |point| point[axis].to_mm }.min.round(2) }
    max = (0..2).map { |axis| points.map { |point| point[axis].to_mm }.max.round(2) }
    vertex_count = points.map { |point| point.to_a.map { |coord| coord.to_mm.round(2) } }.uniq.length
    "#{min}..#{max} nv=#{vertex_count} vol=#{format('%.2f', fragment_def.volume * CUBIC_INCHES_TO_CUBIC_CENTIMETERS)}cm3"
  end

end
