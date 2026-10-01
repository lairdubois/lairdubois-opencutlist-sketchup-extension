module Ladb::OpenCutList

  require_relative '../model/attributes/definition_attributes'
  require_relative '../model/solid/cavities_def'
  require_relative '../utils/hash_utils'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_solid_find_cavities_worker'
  require_relative '../worker/cutlist/cutlist_generate_worker'

  # The CAVITIES of the container of a part - the compartments of a carcass -
  # detected on demand, and kept for the containers the pick last went over :
  # what a Smart tool action handler that works INSIDE a carcass, or through
  # what stands in its mouths, reads them from (see CavitiesDef#pick_ray).
  #
  # The including handler provides get_active_part_entity_path,
  # get_active_part (see SmartActionHandlerPartHelper), active? and _refresh,
  # wraps its onToolMouseMove in #_defer_cavities, and calls
  # #_cancel_cavities_dwell when it stops and #_reset_cavities_def when the
  # model may have changed under it. The _cavities_* hooks say how it reads
  # a container.
  module SmartActionHandlerCavitiesHelper

    # How many containers #_get_cavities_def keeps the cavities of at once.
    CAVITIES_CACHE_SIZE = 16

    # How long, in seconds, the pick has to stay on a container whose cavities
    # are not known yet before they are detected - see #_schedule_cavities_def.
    CAVITIES_DWELL_DELAY = 0.15

    # How long, in seconds, the detection may run before it gives up (see
    # CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX) and the container is
    # refused. Measured 2026-09-14 with the envelope reduced : a machined open
    # carcass takes ~3 s, an assembly of sculpted CNC slices ~7.5 s.
    CAVITIES_TIME_BUDGET = 3.0

    protected

    # -----

    # Runs the given block with the detection of the cavities DEFERRED : a pick
    # on the move only designates containers in passing, the cavities of one
    # not known yet are not detected under it, but once it has dwelt there -
    # see #_get_cavities_def. What a handler wraps its onToolMouseMove in ;
    # anything else (a click, a key, a panel being built) still gets them on
    # the spot.
    def _defer_cavities
      deferring = @cavities_deferring
      @cavities_deferring = true
      yield
    ensure
      @cavities_deferring = deferring
    end

    # Drops the cavities of EVERY container kept, not only the active one's :
    # what changes the model under one container may change it under the
    # others - its ancestors hold it.
    #
    # All but the verdicts of excess complexity (see
    # CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX) : nothing a handler
    # does can simplify a container it refuses to work in, and forgetting them
    # would pay for the detection again at the very next pass over it.
    def _reset_cavities_def
      @cavities_defs = @cavities_defs.is_a?(Array) ? @cavities_defs.select(&:too_complex?) : nil
    end

    # -----

    # Whether the cavity envelope must be REDUCED to what the panels really
    # enclose (see CommonSolidFindCavitiesWorker, ENVELOPE REDUCTION). Off
    # here : the reduction pulls the envelope back to a recessed chant, and
    # with it the CAPS that stand for the openings - which is precisely where
    # a front panel sits. A handler that fits a panel INTO a compartment may turn
    # it on ; one that fits a panel ONTO an opening must not.
    def _cavities_reduce_envelope?
      false
    end

    # Whether the OVERALL cavity is wanted alongside the compartments : the
    # interior as if the enclosure were empty, bounded by its contour panels
    # only (see CommonSolidFindCavitiesWorker, OVERALL CAVITY). That is what
    # a full height front panel spans, across the compartments its internal panels
    # carve out.
    def _cavities_overall?
      false
    end

    # Whether the panels merely LAID ON the assembly are to be left out of
    # the enclosure (see CommonSolidFindCavitiesWorker, DETACHED PARTS). Off
    # here : a panel of the container is part of it until proven otherwise.
    # A handler that DRAWS such panels has to turn it on, or the ones it has
    # already drawn would be read as part of the carcass and inflate the
    # envelope over the openings that are left.
    def _cavities_ignore_applied_panels?
      false
    end

    # Which kinds of APPLIED PANEL already drawn (see DefinitionAttributes::
    # ROLES_APPLIED_PANEL) make the openings they fill recede - see
    # CommonSolidFindCavitiesWorker, INSET FRONT PANELS. None here : a handler
    # that fits a panel ONTO an opening has to read that opening as the
    # carcass leaves it, or it would lay its front panel against the back of
    # the one already there. A handler that fits a panel INTO a compartment
    # must name them, on pain of telescoping into an inset panel.
    def _cavities_recess_panel_types
      []
    end

    # Which kinds of APPLIED PANEL already drawn are read aside as the panels
    # STANDING IN THE WAY - handed to nobody, kept on the CavitiesDef so that a
    # handler can tell an opening it has already filled from a bare one. None
    # here : a handler that draws no panel has none of its own to run into.
    #
    # Deliberately NOT the same list as #_cavities_recess_panel_types, and
    # never overlapping it : a panel that recedes an opening is one the cavity
    # STOPS at, a panel read aside here is one the cavity is blind to - which
    # is precisely why it has to be looked for by hand.
    def _cavities_own_panel_types
      []
    end

    # How many opening planes a cavity may have and still be a compartment -
    # see CommonSolidFindCavitiesWorker, max_opening_planes. Generous here : a
    # part fitted INTO a compartment is at home in one open on every side it
    # does not lean on.
    def _cavities_max_opening_planes
      4
    end

    # Whether the openings of a cavity must turn their backs on one another
    # for it to be a compartment - see CommonSolidFindCavitiesWorker,
    # apart_opening_planes. Off here, for the same reason as above.
    def _cavities_apart_opening_planes?
      false
    end

    # -----

    # The paths of the APPLIED PANELS the given container holds - a front
    # panel or a back, see DefinitionAttributes::ROLES_APPLIED_PANEL - of the given TYPES,
    # at any depth and WHATEVER its visibility.
    #
    # A panel of a type NOT asked for is skipped, never descended into : it is
    # read whole or not at all, exactly like one that is kept.
    #
    # The cutlist #_get_cavities_def runs cannot hand them over : like the rest
    # of the extension it reads what the model SHOWS, and hiding the panels -
    # their tag, or the instances themselves - to work inside the carcass is
    # precisely how a box is drawn. The panel a part would telescope into
    # would then be the one nobody has in front of them.
    #
    # Only the RECESS reads this list. A hidden PANEL stays out of the cavities
    # exactly as it stays out of the cutlist : what it does there is WIDEN a
    # cavity, which errs the way the model reads, where a panel gone missing
    # puts a part through another.
    def _fetch_applied_panel_entity_paths(container, container_path, types, applied_panel_entity_paths = [])
      return applied_panel_entity_paths unless container.respond_to?(:definition)
      container.definition.entities.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        next if entity.definition.behavior.always_face_camera?
        entity_path = container_path + [ entity ]
        role = DefinitionAttributes.role_of(entity)
        if DefinitionAttributes.applied_panel_role?(role)
          applied_panel_entity_paths << entity_path if types.include?(role)   # An applied panel is read WHOLE : what it holds is its own business, and a panel inside a panel is none
        else
          _fetch_applied_panel_entity_paths(entity, entity_path, types, applied_panel_entity_paths)
        end
      end
      applied_panel_entity_paths
    end

    # -----

    # The path of the entity whose container the cavities are read in - by
    # default the ACTIVE part's. A handler for which the part stands for more
    # than itself says so here : the door a stile belongs to, see
    # SmartJoinAddHingesActionHandler.
    def _get_cavities_part_entity_path
      get_active_part_entity_path
    end

    # The cavities of the given part's container - by default the ACTIVE
    # part's, see #_get_cavities_part_entity_path. The explicit parameters
    # exist for #_can_activate_part?, which runs BEFORE the part it examines
    # is activated and so cannot rely on the active one.
    def _get_cavities_def(part_entity_path = _get_cavities_part_entity_path, part = get_active_part)
      return nil unless part_entity_path.is_a?(Array) && part_entity_path.length > 1

      container_path = part_entity_path[0...-1]
      return nil if container_path.empty?

      container = container_path.last
      return nil if container.nil?

      # Cavities belong to the CONTAINER, not to the picked part : sliding the
      # pick from one panel to another of the same box must reuse the boolean
      # pass rather than pay for it again. Comparing the paths compares the
      # entities themselves, so a #_make_unique_groups_in_path that replaced
      # them invalidates the cache - which is exactly what it should do.
      #
      # Several containers are kept, most recently used first : a pick that
      # slides from a carcass onto the drawers it holds and back would
      # otherwise pay again, at every crossing, for a detection the previous
      # crossing had already paid for - and the carcass is the dearest of them.
      @cavities_defs = [] unless @cavities_defs.is_a?(Array)
      options_key = _cavities_options_key
      if (index = @cavities_defs.index { |cavities_def| cavities_def.container_path == container_path && cavities_def.options_key == options_key })
        @cavities_defs.unshift(@cavities_defs.delete_at(index)) if index > 0
        return @cavities_defs.first
      end

      return nil if !part.is_a?(Part) || part.group.material_is_virtual || part.group.material_type == MaterialAttributes::TYPE_HARDWARE

      # Not known yet, and the pick merely passing over it : detected once it
      # has dwelt there (see #_defer_cavities) - PENDING until then, see
      # #_cavities_pending?.
      if @cavities_deferring
        _schedule_cavities_def(container_path)
        return nil
      end
      _cancel_cavities_dwell if _cavities_pending?(part_entity_path)

      cutlist = CutlistGenerateWorker.new(**HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_options'))
                                                     .merge({ active_entity: container, active_path: container_path[0...-1] })
      ).run

      parts = cutlist.groups
                     .reject { |group| group.material_is_virtual || group.material_type == MaterialAttributes::TYPE_HARDWARE}
                     .flat_map { |group| group.get_parts }

      # The APPLIED PANELS - a front panel or a back, see
      # DefinitionAttributes::ROLES_APPLIED_PANEL - are held apart from the panels of the
      # carcass : one is laid ON the carcass, and read as a panel of it, it
      # pushes the envelope forward over the part of itself it covers - the
      # openings that are left then read on a slanted, oversized cap, and the
      # next panel is fitted to a mouth that does not exist. Nothing in their
      # geometry says what they are (see CommonSolidFindCavitiesWorker, APPLIED
      # PANELS) : their ROLE does. BOTH kinds, and for the same reason - a back
      # laid on the rear of a carcass closes its rear opening exactly as a front
      # closes the front one.
      #
      # They are not necessarily out of the picture, though : a panel fitted
      # INTO its mouth occupies that end of the compartment it closes, and a
      # handler that fits a panel in there has to stop at its back. Handed to
      # the worker aside, that is exactly what they do - they recede the
      # openings they fill, and nothing else (see
      # CommonSolidFindCavitiesWorker, INSET FRONT PANELS). Aside also means read
      # aside : #_fetch_applied_panel_entity_paths goes and gets them from the
      # container itself, where the ones the model hides are still there.
      # The part each panel is read from, by the path of its instance - the
      # one a wall of the cavities is then told to belong to (see
      # CavitiesDef#part_of).
      panel_parts = {}
      parts.each do |container_part|
        container_part.def.instance_infos.each_value { |instance_info| panel_parts[instance_info.path] = container_part }
      end

      panel_instance_infos = parts.flat_map { |container_part|
        container_part.def.instance_infos.values
      }.reject { |instance_info|
        # The panel itself, or anything it holds : an applied panel is read
        # WHOLE - the stiles of a frame door, the hinges glued into a front
        # panel are no more walls of the carcass than the panel is.
        instance_info.path.any? { |entity| DefinitionAttributes.applied_panel_role?(DefinitionAttributes.role_of(entity)) }
      }

      drawing_defs = panel_instance_infos.map { |instance_info| _decompose_cavity_panel(instance_info.path, false) }
      # An applied panel is read whole and blind to what the model shows : the tag it
      # is put on is the tag its own faces are likely to carry, and hidden
      # once it is the mesh that would come back empty.
      #
      # The SAME walk serves the two readings an applied panel gets - the ones
      # that make an opening recede, and the ones read aside as standing in the
      # way (see #_cavities_own_panel_types) - and a panel of neither kind is
      # not decomposed at all, so a handler that asks for nothing pays nothing.
      recess_panel_types = _cavities_recess_panel_types
      own_panel_types = _cavities_own_panel_types
      front_panel_drawing_defs = []
      own_panel_drawing_defs = []
      unless recess_panel_types.empty? && own_panel_types.empty?
        _fetch_applied_panel_entity_paths(container, container_path, recess_panel_types + own_panel_types).each do |entity_path|
          role = DefinitionAttributes.role_of(entity_path.last)
          drawing_def = _decompose_cavity_panel(entity_path, true)
          front_panel_drawing_defs << drawing_def if recess_panel_types.include?(role)
          own_panel_drawing_defs << drawing_def if own_panel_types.include?(role)
        end
      end

      result_def = CommonSolidFindCavitiesWorker.new(drawing_defs,
                                                     max_opening_planes: _cavities_max_opening_planes,
                                                     apart_opening_planes: _cavities_apart_opening_planes?,
                                                     reduce_envelope: _cavities_reduce_envelope?,
                                                     overall_cavity: _cavities_overall?,
                                                     ignore_applied_panels: _cavities_ignore_applied_panels?,
                                                     front_panel_drawing_defs: front_panel_drawing_defs,
                                                     time_budget: CAVITIES_TIME_BUDGET
      ).run

      cavities_def = CavitiesDef.new(container_path, result_def, drawing_defs, own_panel_drawing_defs, options_key, front_panel_drawing_defs, panel_parts)
      @cavities_defs.unshift(cavities_def)
      @cavities_defs.pop while @cavities_defs.length > CAVITIES_CACHE_SIZE

      # A refusal for excess complexity is said where the pick is, see the handler's _can_activate_part?
      unless result_def.success? || cavities_def.too_complex?
        @tool.notify_errors(result_def.errors)
      end

      cavities_def
    end

    # One panel of a container, the way #_get_cavities_def reads it.
    #
    # The glued cuts-opening machinings stay IN : SketchUp punches their
    # opening in the host face tessellation, so a drilled panel without them
    # is an open shell (one open edge loop per mortise) that no boolean can
    # take. They are what closes it back — SolidMeshDef marks them virtual,
    # and CommonSolidFindCavitiesWorker drops the voids they enclose. Hence
    # flatten: false, without which they land in the drawing def's own faces
    # and lose that provenance.
    def _decompose_cavity_panel(entity_path, ignore_visibility)
      CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(entity_path) ],
                                           ignore_surfaces: true,
                                           ignore_edges: true,
                                           container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS,
                                           ignore_visibility: ignore_visibility,
                                           flatten: false
      ).run
    end

    # Reads again, for every container kept, the applied panels of the
    # handler's OWN kinds (see #_cavities_own_panel_types) - and only them.
    #
    # What a handler that has just built such a panel calls : the cavities
    # themselves are blind to it and stand as they were, but the panels read
    # aside are precisely the ones that tell an opening it has just closed from
    # a bare one. Every container kept is read, the one the panel went into as
    # much as its ancestors - they hold it too.
    def _refresh_cavities_own_panels
      return unless @cavities_defs.is_a?(Array)
      own_panel_types = _cavities_own_panel_types
      return if own_panel_types.empty?
      @cavities_defs.each do |cavities_def|
        next unless cavities_def.valid?
        container_path = cavities_def.container_path
        cavities_def.own_panel_drawing_defs = _fetch_applied_panel_entity_paths(container_path.last, container_path, own_panel_types).map { |entity_path| _decompose_cavity_panel(entity_path, true) }
      end
    end

    # The cavity fragment a pick designates, or nil when the point sits in no
    # cavity at all.
    #
    # The lookup point is nudged to the cavity side of the picked face : a
    # point picked exactly on a boundary face is ambiguous between the
    # cavities it separates (fragment_defs_for_point would return both).
    def _get_cavity_fragment_def(cavities_def, point, picked_face_manipulator)
      inward_point = point.offset(picked_face_manipulator.normal.reverse, SolidMeshDef::TOLERANCE * 10)
      cavities_def.fragment_defs_for_point(inward_point).first || cavities_def.fragment_defs_for_point(point).first
    end

    # What the cavities of a container depend on besides the container itself :
    # the way this handler reads it. See #_get_cavities_def.
    def _cavities_options_key
      [ _cavities_reduce_envelope?, _cavities_overall?, _cavities_ignore_applied_panels?, _cavities_recess_panel_types, _cavities_own_panel_types, _cavities_max_opening_planes, _cavities_apart_opening_planes? ]
    end

    # Whether the cavities of the given part's container - by default the
    # active part's - are PENDING : not known yet, and waiting for the pick to
    # dwell there (see #_schedule_cavities_def). Nothing can be said of a
    # position in them in the meantime, either way.
    def _cavities_pending?(part_entity_path = _get_cavities_part_entity_path)
      !@cavities_dwell.nil? && part_entity_path.is_a?(Array) && @cavities_dwell.first == part_entity_path[0...-1]
    end

    # Arms the detection of the given container's cavities, to run once the
    # pick has stayed on it CAVITIES_DWELL_DELAY. A pick still on the same
    # container leaves the count running : moving over its panels is dwelling
    # on it all the same.
    def _schedule_cavities_def(container_path)
      return if !@cavities_dwell.nil? && @cavities_dwell.first == container_path
      _cancel_cavities_dwell
      timer_id = UI.start_timer(CAVITIES_DWELL_DELAY, false) { _on_cavities_dwell(timer_id) }
      @cavities_dwell = [ container_path, timer_id ]
    end

    def _cancel_cavities_dwell
      return if @cavities_dwell.nil?
      UI.stop_timer(@cavities_dwell.last)
      @cavities_dwell = nil
    end

    def _on_cavities_dwell(timer_id)
      return if @cavities_dwell.nil? || @cavities_dwell.last != timer_id  # Called off, or superseded
      container_path = @cavities_dwell.first
      @cavities_dwell = nil
      return unless active?

      # Only for the container the pick is still on : it may have left it for
      # nothing since, which armed no other count
      part_entity_path = _get_cavities_part_entity_path
      return unless part_entity_path.is_a?(Array) && part_entity_path[0...-1] == container_path

      model = Sketchup.active_model
      return if model.nil?

      # The detection freezes the view : the message is painted first
      # (View#refresh, SketchUp 2020+)
      @tool.show_tooltip(PLUGIN.get_i18n_string('tool.smart_build.detecting_cavities'))
      model.active_view.refresh if model.active_view.respond_to?(:refresh)

      _get_cavities_def(part_entity_path, get_active_part)
      @tool.remove_tooltip
      _refresh
    end

    # Detects at once the cavities the pick is dwelling on, if it is : what a
    # click on a container still waiting for them asks for. Returns whether it
    # did - the click then stands for that, and for nothing more.
    def _flush_cavities_dwell
      return false unless _cavities_pending?
      _cancel_cavities_dwell
      _get_cavities_def
      _refresh
      true
    end

  end

end
