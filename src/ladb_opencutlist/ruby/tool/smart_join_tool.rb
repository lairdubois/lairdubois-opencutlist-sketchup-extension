module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../utils/color_utils'
  require_relative '../utils/path_utils'
  require_relative '../lib/fiddle/clippy/clippy'
  require_relative '../lib/fiddle/skpy/skpy'
  require_relative '../helper/user_text_helper'

  class SmartJoinTool < SmartTool

    ACTION_ADD_CONNECTORS = 0
    ACTION_REMOVE_CONNECTORS = 1
    ACTION_ADD_FITTINGS = 2
    ACTION_REMOVE_FITTINGS = 3

    ACTION_OPTION_HEIGHT = 'height'
    ACTION_OPTION_OFFSETS = 'offsets'
    ACTION_OPTION_SPACINGS = 'spacings'
    ACTION_OPTION_OPTIONS = 'options'
    ACTION_OPTION_GEOMETRY = 'geometry'

    ACTION_OPTION_OFFSETS_START_OFFSET = 'start_offset'
    ACTION_OPTION_OFFSETS_END_OFFSET = 'end_offset'

    ACTION_OPTION_SPACINGS_MIN_SPACING = 'min_spacing'
    ACTION_OPTION_SPACINGS_MAX_SPACING = 'max_spacing'

    ACTION_OPTION_OPTIONS_OPPOSITE = 'opposite'
    ACTION_OPTION_OPTIONS_MAKE_UNIQUE = 'make_unique'

    ACTION_OPTION_GEOMETRY_HARDWARE_A = 'hardware_a'
    ACTION_OPTION_GEOMETRY_HARDWARE_B = 'hardware_b'
    ACTION_OPTION_GEOMETRY_MACHINING_A = 'machining_a'
    ACTION_OPTION_GEOMETRY_MACHINING_B = 'machining_b'
    ACTION_OPTION_GEOMETRY_HARDWARE_MATERIAL_NAME = 'hardware_material_name'
    ACTION_OPTION_GEOMETRY_MACHINING_MATERIAL_NAME = 'machining_material_name'
    ACTION_OPTION_GEOMETRY_HARDWARE_LAYER_NAME = 'hardware_layer_name'
    ACTION_OPTION_GEOMETRY_MACHINING_LAYER_NAME = 'machining_layer_name'

    ACTIONS = [
      {
        :action => ACTION_ADD_CONNECTORS,
        :options => {
          ACTION_OPTION_HEIGHT => [ ACTION_OPTION_HEIGHT ],
          ACTION_OPTION_OFFSETS => [ ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET ],
          ACTION_OPTION_SPACINGS => [ ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MAKE_UNIQUE ],
        }
      },
      {
        :action => ACTION_REMOVE_CONNECTORS
      },
      {
        :action => ACTION_ADD_FITTINGS,
        :options => {
          ACTION_OPTION_OFFSETS => [ ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET ],
          ACTION_OPTION_SPACINGS => [ ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_OPPOSITE, ACTION_OPTION_OPTIONS_MAKE_UNIQUE ],
        }
      },
      {
        :action => ACTION_REMOVE_FITTINGS,
        :options => {
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_OPPOSITE ],
        }
      }
    ].freeze

    # -----

    def initialize(

      current_action: nil

    )

      super(
        current_action: current_action
      )

    end

    def get_stripped_name
      'join'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_ADD_CONNECTORS
        return SmartCursorManager.cursor_select_join
      end

      super
    end

    def get_action_options_modal?(action)

      case action
      when ACTION_ADD_CONNECTORS
        return true
      when ACTION_ADD_FITTINGS
        return true
      end

      super
    end

    def get_action_option_sync_actions(action, option_group, option)

      case option_group
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_OPPOSITE
          return [ ACTION_ADD_FITTINGS, ACTION_REMOVE_FITTINGS ]
        end
      end

      super
    end

    def get_action_option_toggle?(action, option_group, option)

      case option_group
      when ACTION_OPTION_HEIGHT
        case option
        when ACTION_OPTION_HEIGHT
          return false
        end
      when ACTION_OPTION_OFFSETS
        case option
        when ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET
          return false
        end
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING
          return false
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_MAKE_UNIQUE
          return true
        end
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_HEIGHT
        case option
        when ACTION_OPTION_HEIGHT
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_OFFSETS
        case option
        when ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_OPPOSITE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,0L1,1 M0.5,0L0.5,0.25 M0.5,0.75L0.5,1 M0.5,0.375L0.5,0.625 M0,0.5L1,0.5 M0.75,0.25L1,0.5L0.75,0.75'))
        when ACTION_OPTION_OPTIONS_MAKE_UNIQUE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0.167L0.167,0.833 M0.417,0.167L0.417,0.833 M0,0.333L0.583,0.333 M0,0.667L0.583,0.667 M0.75,0.333L1,0.167L1,0.833'))
        end
      end

      super
    end

    def get_action_option_btn_prefix(action, option_group, option)

      case option_group

      when ACTION_OPTION_OFFSETS
        case option
        when ACTION_OPTION_OFFSETS_START_OFFSET
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_offsets_start_offset'))
        when ACTION_OPTION_OFFSETS_END_OFFSET
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_offsets_end_offset'))
        end
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MIN_SPACING
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_spacings_min_spacing'))
        when ACTION_OPTION_SPACINGS_MAX_SPACING
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_spacings_max_spacing'))
        end
      end

      super
    end

    # -- Events --

    def onActivate(view)
      super
    end

    def onKeyDown(key, repeat, flags, view)
      return true if super
      if is_key_alt_or_command?(key)
        case fetch_action
        when ACTION_ADD_CONNECTORS
          push_action(ACTION_REMOVE_CONNECTORS)
        when ACTION_ADD_FITTINGS
          push_action(ACTION_REMOVE_FITTINGS)
        end
        return true
      end
      false
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
      if is_key_alt_or_command?(key)
        pop_action
        return true
      end
      false
    end

    def onActionChanged(action)

      clear_all_2d
      clear_all_3d

      case action
      when ACTION_ADD_CONNECTORS
        set_action_handler(SmartJoinAddConnectorsActionHandler.new(self))
      when ACTION_REMOVE_CONNECTORS
        set_action_handler(SmartJoinRemoveConnectorsActionHandler.new(self))
      when ACTION_ADD_FITTINGS
        set_action_handler(SmartJoinAddFittingsActionHandler.new(self))
      when ACTION_REMOVE_FITTINGS
        set_action_handler(SmartJoinRemoveFittingsActionHandler.new(self))
      end

      super
    end

    def onViewChanged(view)
      super
      refresh
    end

    def onTransactionUndo(model)
      super
      refresh
    end

  end

  class SmartJoinActionHandler < SmartActionHandler

    Skpy = Fiddle::Skpy

    include SmartActionHandlerPartHelper

    COLOR_DEFAULT_HARDWARE_MATERIAL = Sketchup::Color.new('#999999').freeze
    COLOR_DEFAULT_MACHINING_MATERIAL = Sketchup::Color.new('#0068ff').freeze

    COLOR_PART_A = COLOR_PART
    COLOR_PART_B = ColorUtils.color_translucent(Kuix::COLOR_GREEN, 0.3)

    COLOR_REF_FACE_A = Kuix::COLOR_MAGENTA.blend(COLOR_PART_A, 0.2).freeze
    COLOR_REF_FACE_B = Kuix::COLOR_MAGENTA.blend(COLOR_PART_B, 0.2).freeze
    COLOR_REF_DARKEN_A = ColorUtils.color_darken(COLOR_REF_FACE_A, 0.4).freeze
    COLOR_REF_DARKEN_B = ColorUtils.color_darken(COLOR_REF_FACE_B, 0.4).freeze

    COLOR_HARDWARE = Kuix::COLOR_DARK_GREY
    COLOR_HARDWARE_PROPAGATED = ColorUtils.color_translucent(COLOR_HARDWARE, 0.3)
    COLOR_MACHINING = Kuix::COLOR_CYAN
    COLOR_MACHINING_PROPAGATED = ColorUtils.color_translucent(COLOR_MACHINING, 0.3)

    LAYER_3D_JOIN_PREVIEW = 3
    LAYER_3D_MACHINING_PREVIEW = 4
    LAYER_3D_HARDWARE_PREVIEW = 5
    LAYER_3D_SNAP_POINT_PREVIEW = 6

    LAYER_3D_PART_A_PREVIEW = 10
    LAYER_3D_PART_B_PREVIEW = 20

    TRANSFORMATION_FLIP_Z = Geom::Transformation.axes(ORIGIN, X_AXIS, Y_AXIS, Z_AXIS.reverse).freeze

    # -----

    def initialize(action, tool, previous_action_handler = nil)
      super

      # Create 3D layers
      tool.create_3d(LAYER_3D_PART_A_PREVIEW)
      tool.create_3d(LAYER_3D_PART_B_PREVIEW)
      tool.create_3d(LAYER_3D_JOIN_PREVIEW)
      tool.create_3d(LAYER_3D_MACHINING_PREVIEW)
      tool.create_3d(LAYER_3D_HARDWARE_PREVIEW)
      tool.create_3d(LAYER_3D_SNAP_POINT_PREVIEW)

    end

    # -----

    def onPickerChanged(picker, view)
      _pick_part(picker, view)
      super
    end

    def onToolGlobalPresetChanged(tool, dictionary, section)
      @geometries_def = nil
      _refresh
    end

    # -----

    protected

    # -----

    def _start_with_model_selection?
      false
    end

    def _clear_selection_on_start?
      true
    end

    # -----

    def _preview_all_instances?
      false
    end

    # -----

    def _can_activate_part?(part_entity_path, part)
      return [ false, 'tool.smart_join.error.not_assemblable' ] if part.is_a?(Part) && part.group.material_type == MaterialAttributes::TYPE_HARDWARE
      super
    end

    # -----

    def _get_drawing_def_parameters
      {
        ignore_surfaces: true,
        ignore_faces: false,
        ignore_edges: true,
        ignore_soft_edges: true,
        ignore_clines: true,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS
      }
    end

    # -----

    def _read_measure(tool, text, option_group, option, error_key, length_only: false)

      if !length_only && text.start_with?('/')

        divider = text[1..-1].gsub(',', '.').to_f
        if divider <= 0
          tool.notify_errors([[ error_key, { :value => text } ]])
          return true
        end
        divider = divider.to_i if divider.to_i == divider
        measure = "/#{divider.to_s.sub('.', DimensionUtils.decimal_separator)}"

      else

        measure = _read_user_text_length(tool, text)
        return true if measure.nil?

        if measure < 0
          tool.notify_errors([[ error_key, { :value => measure } ]])
          return true
        end

        measure = DimensionUtils.d_add_units(measure.to_s)

      end

      @tool.store_action_option_value(@action, option_group, option, measure.to_s, fire_event: true)

      false
    end

    # -----

    def _fetch_option_height
      @tool.fetch_action_option_factor_or_length(@action, SmartJoinTool::ACTION_OPTION_HEIGHT, SmartJoinTool::ACTION_OPTION_HEIGHT)
    end

    def _fetch_option_start_offset
      @tool.fetch_action_option_factor_or_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_START_OFFSET)
    end

    def _fetch_option_end_offset
      @tool.fetch_action_option_factor_or_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_END_OFFSET)
    end

    def _fetch_option_min_spacing
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_SPACINGS_MIN_SPACING)
    end

    def _fetch_option_max_spacing
      @tool.fetch_action_option_factor_or_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_SPACINGS_MAX_SPACING)
    end

    def _fetch_option_opposite?
      @tool.fetch_action_option_boolean(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_OPPOSITE)
    end

    def _fetch_option_make_unique?
      @tool.fetch_action_option_boolean(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE)
    end

    def _fetch_option_hardware_a
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE_A)
    end

    def _fetch_option_hardware_b
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE_B)
    end

    def _fetch_option_machining_a
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_MACHINING_A)
    end

    def _fetch_option_machining_b
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_MACHINING_B)
    end

    def _fetch_option_hardware_material_name
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE_MATERIAL_NAME)
    end

    def _fetch_option_machining_material_name
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_MACHINING_MATERIAL_NAME)
    end

    def _fetch_option_hardware_layer_name
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE_LAYER_NAME)
    end

    def _fetch_option_machining_layer_name
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_MACHINING_LAYER_NAME)
    end

    # -----

    def _get_geometries_def
      return @geometries_def if @geometries_def.is_a?(GeometriesDef) && @geometries_def.valid?

      model = Sketchup.active_model
      model.start_operation('OCL Loading Geometry', true)
      begin

        fn_get_definition = lambda do |ref|
          return nil if !ref.is_a?(String) || ref.strip.empty?
          if (extname = File.extname(ref)).downcase == '.skp'
            name = File.basename(ref, extname)
            definition = model.definitions[name]  # Try to get definition from DefinitionList first
            if definition.nil?
              begin

                if Sketchup.version_number < 2100000000
                  skp_version_info = Skpy.get_skp_version_info({ filepath: ref })
                  if skp_version_info['error']
                    raise skp_version_info['error']
                  end
                  if skp_version_info['version_number'] > Sketchup.version_number
                    @tool.notify_errors([
                                          [ 'tool.smart_join.error.failed_to_load_skp_file', { file: ref } ],
                                          [ 'tool.smart_join.error.unsupported_skp_version', { version: skp_version_info['version_label'] } ]
                                        ])
                    return nil
                  end
                end

                definition = Sketchup.version_number >= 2100000000 ? model.definitions.load(ref.gsub('\\', '/'), allow_newer: true) : model.definitions.load(ref.gsub('\\', '/'))
                if definition && definition.name != name
                  @tool.notify_warnings([ [ 'tool.smart_join.warning.different_file_name', { file_name: name, definition_name: definition.name } ] ])
                end

              rescue Exception => e
                @tool.notify_errors([ [ 'tool.smart_join.error.failed_to_load_skp_file', { file: ref } ] ])
              end
            end
          else
            definition = model.definitions[ref]
          end
          definition
        end

        hardware_a_definition = fn_get_definition.call(_fetch_option_hardware_a)
        hardware_b_definition = fn_get_definition.call(_fetch_option_hardware_b)
        machining_a_definition = fn_get_definition.call(_fetch_option_machining_a)
        machining_b_definition = fn_get_definition.call(_fetch_option_machining_b)

        fn_get_drawing_def = lambda do |definition|
          return nil if definition.nil?
          CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new([ definition ]) ],
                                               ignore_surfaces: true,
                                               ignore_faces: true,
                                               ignore_edges: false,
                                               ignore_soft_edges: false,
                                               container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_ALL
          ).run
        end

        hardware_a_drawing_def = fn_get_drawing_def.call(hardware_a_definition)
        hardware_b_drawing_def = fn_get_drawing_def.call(hardware_b_definition)
        machining_a_drawing_def = fn_get_drawing_def.call(machining_a_definition)
        machining_b_drawing_def = fn_get_drawing_def.call(machining_b_definition)

        fn_get_material = lambda do |ref, default_color = nil, default_type = nil|
          return nil if !ref.is_a?(String) || ref.strip.empty?
          if File.extname(ref).downcase == '.skm'
            material = model.materials.load(ref)
          else
            material = model.materials[ref]
            if material.nil?
              material = model.materials.add(ref)
              material.color = default_color unless default_color.nil?
              unless default_type.nil?
                ma = MaterialAttributes.new(material)
                ma.type = default_type
                ma.write_to_attributes
              end
            end
          end
          material
        end

        hardware_material = fn_get_material.call(_fetch_option_hardware_material_name, COLOR_DEFAULT_HARDWARE_MATERIAL, MaterialAttributes::TYPE_HARDWARE)
        machining_material = fn_get_material.call(_fetch_option_machining_material_name, COLOR_DEFAULT_MACHINING_MATERIAL, MaterialAttributes::TYPE_MACHINING)

        fn_get_layer = lambda do |ref|
          return nil if !ref.is_a?(String) || ref.strip.empty?
          layer = model.layers[ref]
          if layer.nil?
            layer = model.layers.add(ref)
          end
          layer
        end

        hardware_layer = fn_get_layer.call(_fetch_option_hardware_layer_name)
        machining_layer = fn_get_layer.call(_fetch_option_machining_layer_name)

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
        return nil
      end

      bounds = Geom::BoundingBox.new
      bounds.add(hardware_a_drawing_def.bounds) unless hardware_a_drawing_def.nil?
      bounds.add(hardware_b_drawing_def.bounds) unless hardware_b_drawing_def.nil?
      bounds.add(machining_a_drawing_def.bounds) unless machining_a_drawing_def.nil?
      bounds.add(machining_b_drawing_def.bounds) unless machining_b_drawing_def.nil?

      @geometries_def = GeometriesDef.new(
        GeometriesEntityDef.new(hardware_a_definition, hardware_a_drawing_def),
        GeometriesEntityDef.new(hardware_b_definition, hardware_b_drawing_def),
        GeometriesEntityDef.new(machining_a_definition, machining_a_drawing_def),
        GeometriesEntityDef.new(machining_b_definition, machining_b_drawing_def),
        hardware_material,
        machining_material,
        hardware_layer,
        machining_layer,
        bounds,
      )
    end

    # -- UTILS --

    def _get_active_path
      @_active_path ||= Sketchup.active_model.active_path.to_a
    end

    def _get_grouped_glued_instances(face_manipulator, poly_3d)
      if (glued_instances = face_manipulator.face.get_glued_instances).any?

        fm_ti = face_manipulator.transformation.inverse
        poly_2d = poly_3d.map { |point| point.transform(fm_ti) }

        # Selects only the glued instances whose anchor point is on the segment.
        # And group them by anchor point coords
        return glued_instances.select { |glued_instance| Geom.point_in_polygon_2D(ORIGIN.transform(glued_instance.transformation), poly_2d, true) }
                              .group_by { |glued_instance| ORIGIN.transform(face_manipulator.transformation * glued_instance.transformation).to_a }  # Anchor point coords Array<Geom::Point3d>

      end
      {}
    end

    def _is_geometries_intersect_glued_instances?(geometries_bounds, anchor_point, glued_instances, fm, t, ti, at)
      glued_instances.any? { |glued_instance|

        fm_t = fm.transformation
        fm_ti = fm_t.inverse

        b_t = glued_instance.transformation
        min = glued_instance.definition.bounds.min.transform(b_t)
        max = glued_instance.definition.bounds.max.transform(b_t)
        glued_instance_bounds = Geom::BoundingBox.new.add(min, max)

        b_t = fm_ti * t * Geom::Transformation.translation(anchor_point.transform(ti)) * at
        min = geometries_bounds.min.transform(b_t)
        max = geometries_bounds.max.transform(b_t)
        new_instance_bounds = Geom::BoundingBox.new.add(min, max)

        glued_instance_bounds.intersect(new_instance_bounds).valid?
      }
    end

    def _add_glued_instance(definition, material, layer, face, entities, dti, pt, at)
      if definition.is_a?(Sketchup::ComponentDefinition)
        definition.behavior.no_scale_mask = 0b1111111 # No scale in all direction
        definition.behavior.is2d = true               # Force 2D behavior to ba able to glue to face
        instance = entities.add_instance(definition, dti * Geom::Transformation.translation(pt) * at)
        instance.material = material if material.is_a?(Sketchup::Material)
        instance.layer = layer if layer.is_a?(Sketchup::Layer)
        instance.glued_to = face
      end
    end

    # -- Propagation --

    # Joinery is written into definitions, so it exists on every instance of the
    # touched definitions while it is only picked for one instance couple. The
    # helpers below walk the contact graph (A -> B -> A' -> B' -> ...) to keep
    # the mating parts consistent on every instance.

    # Walks the contact graph from the given seed placements. Placements are
    # deduplicated by (definition, anchor). For each accepted placement, every
    # instance of its owner definition is handed to the block as
    # |placement, world_frame, instance_path| - where 'world_frame' is the
    # placement frame transported on this instance - which probes for a mating
    # part and returns the placement to enqueue, or nil to stop the walk on this
    # branch. Returns the accepted placements, with their
    # 'instance_transformations' filled.
    def _walk_contact_graph(seeds, tolerance = 0.001.mm)

      model = Sketchup.active_model

      placements = []
      seen = {}
      queue = seeds.dup

      until queue.empty?

        placement = queue.shift

        o = ORIGIN.transform(placement.transformation)
        key = [ placement.definition.entityID, (o.x / tolerance).round, (o.y / tolerance).round, (o.z / tolerance).round ]
        next if seen.has_key?(key)
        seen[key] = true
        placements << placement

        # The placement lives in the shared definition => present on all its
        # instances. Look for a mating neighbor at each instance.
        instance_paths = []
        _instances_to_paths(placement.definition.instances, instance_paths, model.entities, [])

        placement.instance_transformations = []

        instance_paths.each do |instance_path|

          t_i = Sketchup::InstancePath.new(instance_path).transformation
          placement.instance_transformations << t_i

          n_placement = yield(placement, t_i * placement.transformation, instance_path)
          queue << n_placement unless n_placement.nil?

        end

      end

      placements
    end

    # Walks a ray through the model, resolving each hit to its host part (glued
    # instances - connectors - are resolved through 'glued_to' ; the source part
    # and already rejected parts are walked past), decomposes each candidate part
    # to 'world' space and returns its first face manipulator accepted by the
    # block, or nil.
    def _raytest_part_face(ray_point, ray_vector, source_path, max_hits = 10)

      model = Sketchup.active_model

      source_serialized = PathUtils.serialize_path(source_path)
      tested = {}

      max_hits.times do

        hit_point, hit_path = model.raytest([ ray_point, ray_vector ])
        return nil if hit_path.nil?

        part_path = _get_part_entity_path_from_path(hit_path)

        # Resolve glued instances (connectors) to the part they are glued in
        while part_path.is_a?(Array) && part_path.length > 1 && part_path.last.respond_to?(:glued_to) && !part_path.last.glued_to.nil?
          part_path = _get_part_entity_path_from_path(part_path[0...-1])
        end

        if part_path.is_a?(Array) &&
           (serialized = PathUtils.serialize_path(part_path)) != source_serialized &&  # Exclude the source instance itself
           !tested.has_key?(serialized)

          tested[serialized] = true

          drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(part_path) ], **_get_drawing_def_parameters).run
          if drawing_def.is_a?(DrawingDef)

            # Bring face manipulators to 'world' space (same normalization as _get_neighborhood_def)
            drawing_def.transform!(drawing_def.transformation.inverse)

            fm = drawing_def.face_manipulators.find { |face_manipulator| yield(face_manipulator) }
            return fm unless fm.nil?

          end

        end

        # Walk past this hit
        ray_point = hit_point.offset(ray_vector, 0.01.mm)

      end

      nil
    end

    # Deterministic fallback of the ray probes : finds the part face passing
    # through 'world_point' accepted by the block, by walking the instance tree
    # bounded by point containment (only the parts whose world bounds contain
    # the point are candidates - the mate face passes through it). Used when a
    # ray misses the mate because its face is shadowed by a coplanar face of
    # another part (raytest reports a single arbitrary face per hit).
    def _find_part_face_at(world_point, source_path, tolerance)

      model = Sketchup.active_model

      source_serialized = PathUtils.serialize_path(source_path)

      point_bounds = Geom::BoundingBox.new
      point_bounds.add(world_point.offset(Geom::Vector3d.new(-1, -1, -1), tolerance * 10))
      point_bounds.add(world_point.offset(Geom::Vector3d.new(1, 1, 1), tolerance * 10))

      candidate_paths = {}
      fn_collect = lambda do |entities, path, transformation|
        entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.visible? && _layer_visible?(entity.layer, path.empty?)
          t = transformation * entity.transformation
          definition_bounds = entity.definition.bounds
          entity_bounds = Geom::BoundingBox.new
          (0..7).each { |i| entity_bounds.add(definition_bounds.corner(i).transform(t)) }
          next unless entity_bounds.intersect(point_bounds).valid?
          child_path = path + [ entity ]
          if (part_path = _get_part_entity_path_from_path(child_path))

            # Resolve glued instances (connectors) to the part they are glued in
            while part_path.is_a?(Array) && part_path.length > 1 && part_path.last.respond_to?(:glued_to) && !part_path.last.glued_to.nil?
              part_path = _get_part_entity_path_from_path(part_path[0...-1])
            end

            if part_path.is_a?(Array) && (serialized = PathUtils.serialize_path(part_path)) != source_serialized  # Exclude the source instance itself
              candidate_paths[serialized] ||= part_path
            end

          end
          fn_collect.call(entity.definition.entities, child_path, t)
        end
      end
      fn_collect.call(model.entities, [], IDENTITY)

      candidate_paths.each_value do |part_path|

        drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(part_path) ], **_get_drawing_def_parameters).run
        next unless drawing_def.is_a?(DrawingDef)

        # Bring face manipulators to 'world' space (same normalization as _get_neighborhood_def)
        drawing_def.transform!(drawing_def.transformation.inverse)

        fm = drawing_def.face_manipulators.find { |face_manipulator| yield(face_manipulator) }
        return fm unless fm.nil?

      end

      nil
    end

    # Finds the part face touching at 'world_point', on the +'world_normal' side.
    # The mating part lies just behind the contact plane, so a ray shot from
    # slightly inside its material along +'world_normal' identifies it (the ray
    # exits through one of its faces) without walking the model entities. When
    # the exit face is shadowed by a coplanar face of the part behind (parts in
    # a row), the ray misses the mate : a deterministic point-containment search
    # takes over. Returns a 'world' space FaceManipulator (its transformation
    # maps the neighbor definition to world) or nil.
    def _find_touching_neighbor(world_point, world_normal, source_path, tolerance)

      fn_accept = lambda do |fm|
        fm.normal.parallel?(world_normal) &&
          !fm.normal.samedirection?(world_normal) &&                                     # Opposite normal
          world_point.distance_to_plane([ fm.position, fm.normal ]).to_f < tolerance &&  # Coplanar
          _is_point_on_face?(fm, world_point)                                            # Under the anchor
      end

      nfm = _raytest_part_face(world_point.offset(world_normal, tolerance * 10), world_normal, source_path, &fn_accept)
      nfm || _find_part_face_at(world_point, source_path, tolerance, &fn_accept)
    end

    def _is_point_on_face?(face_manipulator, world_point)
      local_point = world_point.transform(face_manipulator.transformation.inverse).project_to_plane(face_manipulator.face.plane)
      [ Sketchup::Face::PointInside, Sketchup::Face::PointOnVertex, Sketchup::Face::PointOnEdge ].include?(face_manipulator.face.classify_point(local_point))
    end

    # Returns the glued instances of 'face' intersecting 'bounds' placed at 'mt'
    # (both expressed in the face owner definition space).
    def _get_glued_instances_at(face, mt, bounds)
      placed_bounds = Geom::BoundingBox.new.add(bounds.min.transform(mt), bounds.max.transform(mt))
      face.get_glued_instances.select do |glued_instance|
        gt = glued_instance.transformation
        glued_instance_bounds = Geom::BoundingBox.new.add(glued_instance.definition.bounds.min.transform(gt), glued_instance.definition.bounds.max.transform(gt))
        placed_bounds.intersect(glued_instance_bounds).valid?
      end
    end

    # Returns the glued instances of 'face' anchored at the 'mt' origin (both
    # expressed in the face owner definition space). Unlike the bounds
    # intersection test, this works whatever the glued definitions' geometry
    # footprint is (it can be offset from the anchor).
    def _get_glued_instances_anchored_at(face, mt, tolerance = 0.001.mm)
      anchor = ORIGIN.transform(mt)
      face.get_glued_instances.select { |glued_instance| ORIGIN.transform(glued_instance.transformation).distance(anchor).to_f < tolerance }
    end

    # Data Structs -----

    GeometriesDef = Struct.new(:hardware_a, :hardware_b, :machining_a, :machining_b, :hardware_material, :machining_material, :hardware_layer, :machining_layer, :bounds) do
      def valid?
        hardware_a.valid? &&
          hardware_b.valid? &&
          machining_a.valid? &&
          machining_b.valid? &&
          (hardware_material.nil? || hardware_material.valid?) &&
          (machining_material.nil? || machining_material.valid?) &&
          (hardware_layer.nil? || hardware_layer.valid?) &&
          (machining_layer.nil? || machining_layer.valid?)
      end
    end
    GeometriesEntityDef = Struct.new(:definition, :drawing_def) do
      def empty?
        definition.nil? || !valid?
      end
      def valid?
        definition.nil? || definition.valid?
      end
    end

    # A joinery placement resolved once and applied to a shared definition
    # (so it propagates to all its instances). 'transformation' is the anchor
    # frame expressed in the target definition's local space (Z axis pointing
    # toward the mating part) ; 'role' (:a|:b) selects the geometry ;
    # 'instance_transformations' are the world transformations of the definition's
    # instances (used to preview the placement everywhere it will appear) ;
    # 'seed_transformation' is the picked instance's one - only set on the picked
    # couple's placements (seeds), nil on the placements discovered by walking
    # the contact graph ; 'glued_instances' holds the existing glued instances at
    # the anchor when the placement targets them (remove).
    PropagationDef = Struct.new(:placements)
    PropagationPlacementDef = Struct.new(:definition, :face, :transformation, :role, :instance_transformations, :seed_transformation, :glued_instances) do
      def entities
        face.parent.entities
      end
      # Is this instance occurrence the picked one ?
      def picked?(instance_transformation)
        return false if seed_transformation.nil?
        return true if instance_transformation.equal?(seed_transformation)
        ta = instance_transformation.to_a
        sa = seed_transformation.to_a
        ta.each_index.all? { |i| (ta[i] - sa[i]).abs < 1e-6 }
      end
    end

  end

  # -- Connectors --

  class SmartJoinConnectorsActionHandler < SmartJoinActionHandler

    Clippy = Fiddle::Clippy

    def initialize(action, tool, previous_action_handler = nil)
      super
    end

    # -----

    # -- STATE --

    def get_state_status(state)
      PLUGIN.get_i18n_string("tool.smart_#{@tool.get_stripped_name}.action_#{@action}_state_#{state}_status") + '.'
    end

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self, pick_point: true, drawable: false, lockable: false)
    end

    # -----

    def onPickerChanged(picker, view)
      super
      if _pick_join
        _preview_join
      end
      _preview_snap_point
    end

    def onActivePartChanged(part_entity_path, part, highlighted = false)
      _preview_part(part_entity_path, part, LAYER_3D_PART_A_PREVIEW, highlighted: highlighted)
      _reset_neighborhood_def
    end

    # -----

    protected

    def _reset
      super
      @mouse_snap_point = nil
      _reset_active_part_a
      _reset_neighborhood_def
    end

    def _reset_active_part_a
      @active_face_manipulator_a = nil
      @active_edge_manipulator_a = nil
      @active_vertex_manipulator_a = nil
    end

    def _reset_neighborhood_def
      @neighborhood_def = nil
      @propagation_def = nil
    end

    # -- Propagation --

    # Probes for the part mating the given connector world frame 'wf' : parts
    # touch through the connector XY plane, so the mate lies just behind it,
    # along +Z. Returns [ face_manipulator, mt ] - where 'mt' is the mating
    # connector frame (Z flipped : at_a <-> at_b relationship) expressed in the
    # mate face owner definition space - or nil.
    def _find_mating_connector(wf, instance_path, tolerance = 0.001.mm)

      world_point = ORIGIN.transform(wf)
      world_normal = Z_AXIS.transform(wf)             # Points from this part toward the mate
      world_normal.normalize!

      nfm = _find_touching_neighbor(world_point, world_normal, instance_path, tolerance)
      return nil if nfm.nil?

      [ nfm, nfm.transformation.inverse * wf * TRANSFORMATION_FLIP_Z ]
    end

    def _refresh
      @mouse_snap_point = nil
      _reset_active_part_a
      @picker.invalidate if @picker.is_a?(SmartPicker)
      super
    end

    # -----

    def _pick_join

      face_manipulator = @picker.picked_plane_manipulator
      if face_manipulator.is_a?(FaceManipulator) &&
         (neighborhood_def = _get_neighborhood_def).is_a?(SmartJoinConnectorsActionHandler::NeighborhoodDef)

        neighbor_defs = neighborhood_def.neighbor_defs

        pt = @picker.picked_point

        edge_manipulator = face_manipulator.loop_manipulators
                                           .flat_map { |lm| lm.edge_manipulators }
                                           .select { |em| neighbor_defs.any? { |nd| nd.touching_defs.any? { |td| td.face_manipulator.face != face_manipulator.face && td.face_manipulator.face.edges.include?(em.edge) } } }
                                           .min { |em1, em2| em1.distance_to(pt) <=> em2.distance_to(pt) }

        if edge_manipulator.is_a?(EdgeManipulator)

          vertex_manipulator = edge_manipulator.nearest_vertex_manipulator_to(pt)
          snap_point = pt

        else

          vertex_manipulator = nil
          snap_point = nil

        end

      else

        edge_manipulator = nil
        vertex_manipulator = nil
        snap_point = nil

      end

      # Check if the base context has changed since last pick iteration
      context_changed = @active_face_manipulator_a != face_manipulator || @active_edge_manipulator_a != edge_manipulator || @active_vertex_manipulator_a != vertex_manipulator

      @active_face_manipulator_a = face_manipulator
      @active_edge_manipulator_a = edge_manipulator
      @active_vertex_manipulator_a = vertex_manipulator
      @mouse_snap_point = snap_point

      context_changed
    end

    def _preview_join

      @tool.clear_3d([ LAYER_3D_PART_B_PREVIEW, LAYER_3D_JOIN_PREVIEW, LAYER_3D_HARDWARE_PREVIEW, LAYER_3D_MACHINING_PREVIEW ])
      @tool.hide_message

      return true if (neighborhood_def = _get_neighborhood_def).nil?

      _preview_join_context(neighborhood_def)

    end

    def _preview_join_context(neighborhood_def)

      if @active_face_manipulator_a.is_a?(FaceManipulator)

        # Offset transformation to force mesh to be on top of part preview
        ov = Geom::Vector3d.new(@active_face_manipulator_a.normal)
        ov.length = 0.01
        ot = Geom::Transformation.translation(ov)

        # Highlight picked face
        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(@active_face_manipulator_a.triangles)
        k_mesh.background_color = COLOR_REF_FACE_A
        k_mesh.transformation = ot
        @tool.append_3d(k_mesh, LAYER_3D_JOIN_PREVIEW)

      end

      if @active_edge_manipulator_a.is_a?(EdgeManipulator)

        # Highlight picked segment
        k_segments = Kuix::Segments.new
        k_segments.add_segments(@active_edge_manipulator_a.segment)
        k_segments.color = COLOR_REF_DARKEN_A
        k_segments.line_width = 3
        k_segments.on_top = true
        @tool.append_3d(k_segments, LAYER_3D_JOIN_PREVIEW)

      end

    end

    def _preview_snap_point
    end

    # -----

    def _get_neighborhood_def(tolerance = 0.001.mm, aperture = 1.mm)
      return @neighborhood_def unless @neighborhood_def.nil?

      return nil unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      # Aperture must be greater or equal to tolerance
      aperture = tolerance if tolerance > aperture

      h_neighbor_defs = {}

      kbd = Kuix::Bounds3d.new.copy!(drawing_def.bounds)
      kbi = Kuix::Bounds3d.new.copy!(drawing_def.bounds).inflate_all!(aperture)

      # Hide instance
      _hide_instance

      begin

        model = Sketchup.active_model
        view = model.active_view

        ph = view.pick_helper

        fn_try_to_add_neighbor = lambda do |path|

          picked_part_entity_path = _get_part_entity_path_from_path(path)
          return nil if picked_part_entity_path.nil?                                                  # Exclude non-part entities
          return nil if h_neighbor_defs.has_key?(picked_part_entity_path)                             # Exclude already picked part
          return nil if picked_part_entity_path == get_active_selection_path                          # Exclude selected part
          return nil unless ArrayUtils.array_start_with?(picked_part_entity_path, _get_active_path)   # Exclude out of active path parts
          if (picked_drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(picked_part_entity_path) ], **_get_drawing_def_parameters).run).is_a?(DrawingDef)

            # Exclude invalid drawing defs
            return unless picked_drawing_def.bounds.valid?

            # Transform the drawing def to the 'World' space
            picked_drawing_def.transform!(picked_drawing_def.transformation.inverse)

            # Store the new neighbor def
            h_neighbor_defs[picked_part_entity_path] = NeighborhoodNeighborDef.new(picked_part_entity_path, picked_drawing_def, [])

          end

        end

        # 1. Pick from the bounding box

        num_picked = ph.boundingbox_pick(kbi.to_b, Sketchup::PickHelper::PICK_CROSSING, drawing_def.transformation)
        num_picked.times do |index|

          path = ph.path_at(index)

          fn_try_to_add_neighbor.call(path)

        end

        # 2. Pick by 8 ray corners

        8.times do |corner|

          p0 = kbd.corner(corner).to_p.transform(drawing_def.transformation)
          p1 = kbi.corner(corner).to_p.transform(drawing_def.transformation)

          v = p0.vector_to(p1)
          dmax = v.length
          ray = [ p0.offset(v.reverse), v ]

          hit_point, path = model.raytest(ray)
          if hit_point

            next if p0.distance(hit_point) > dmax

            fn_try_to_add_neighbor.call(path)

          end

        end

      ensure

        # Restore instance visibility
        _unhide_instance

      end

      # Transform the drawing def to the 'World' space
      drawing_def.transform!(drawing_def.transformation.inverse)

      # 3. Search touching faces

      neighbor_defs = h_neighbor_defs.values
      neighbor_defs.select! do |neighbor_def|

        # Iterate on part faces
        drawing_def.face_manipulators.each do |fm|

          # Iterate on neighbor part faces
          neighbor_def.drawing_def.face_manipulators.each do |nfm|

            next unless fm.normal.parallel?(nfm.normal)
            next if fm.normal.samedirection?(nfm.normal)
            next unless fm.position.distance_to_plane([ nfm.position, nfm.normal ]).to_f < tolerance

            # Touching !

            # Compute the transformation to transform world space to touching 2D space
            origin = fm.position
            z_axis = fm.normal
            x_axis = fm.outer_loop_manipulator.edge_manipulators.first.direction.normalize  # Use first outer loop edge direction as arbitrary x axis
            y_axis = z_axis * x_axis
            at = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
            ati = at.inverse

            # Compute part and neighbor touching intersections polygons
            f_2d_paths = fm.loop_manipulators
                           .map { |loop_manipulator| loop_manipulator.points.map { |point| point.transform(ati) } }
                           .map! { |points| Clippy.points_to_rpath(points) }
            nf_2d_paths = nfm.loop_manipulators
                             .map { |loop_manipulator| loop_manipulator.points.map { |point| point.transform(ati) } }
                             .map! { |points| Clippy.points_to_rpath(points) }

            touching_2d_paths, op = Clippy.execute_intersection(closed_subjects: f_2d_paths, clips: nf_2d_paths)
            touching_polys = touching_2d_paths.map { |path| Clippy.rpath_to_points(path, 0).map { |point| point.transform(at)} }

            neighbor_def.touching_defs << NeighborhoodTouchingDef.new(fm, nfm, touching_polys) if touching_polys.any?

          end

        end

        neighbor_def.touching_defs.any?
      end

      # 4. Keep useful data

      path = get_active_part_entity_path

      @neighborhood_def = NeighborhoodDef.new(
        path,
        drawing_def,
        neighbor_defs
      )
    end

    # Data Structs -----

    NeighborhoodDef = Struct.new(:path, :drawing_def, :neighbor_defs) do
      def instance_a
        path.last
      end
      def t_a
        @t_a ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_a
        @ti_a ||= t_a.inverse
      end
    end
    NeighborhoodNeighborDef = Struct.new(:path, :drawing_def, :touching_defs) do
      def instance_b
        path.last
      end
      def t_b
        @t_b ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_b
        @ti_b ||= t_b.inverse
      end
    end
    NeighborhoodTouchingDef = Struct.new(:face_manipulator, :neighbor_face_manipulator, :touching_polys)

  end

  class SmartJoinAddConnectorsActionHandler < SmartJoinConnectorsActionHandler

    include UserTextHelper

    TRANSFORMATION_ROTATION_Z_180 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 180.degrees).freeze

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_ADD_CONNECTORS, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      SmartCursorManager.cursor_select_join_plus
    end

    def get_state_status(state)
      super +
        ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_1") + '.'
    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)

      if has_active_part?
        _add_connectors
        _restart
        return true
      end

      super
    end

    def onToolUserText(tool, text, view)
      return true if super

      return true if _read_measures(tool, text, view)

      false
    end

    # -----

    def enableVCB?
      true
    end

    # -----

    protected

    # -----

    def _preview_join_context(neighborhood_def)
      super

      unless (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

        neighbor_join_defs = joinery_def.neighbor_join_defs

        geometries_def = _get_geometries_def
        hardware_a = geometries_def.hardware_a
        hardware_b = geometries_def.hardware_b
        machining_a = geometries_def.machining_a
        machining_b = geometries_def.machining_b

        no_valid_join = true
        occupied_anchor_count = 0
        neighbor_join_defs.each do |neighbor_join_def|

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(neighbor_join_def.neighbor_def.drawing_def.face_manipulators.flat_map(&:triangles))
          k_mesh.background_color = COLOR_PART_B
          @tool.append_3d(k_mesh, LAYER_3D_PART_B_PREVIEW)

          neighbor_join_def.join_defs.each do |join_def|

            k_polyline = Kuix::Polyline.new
            k_polyline.add_points(join_def.touching_poly)
            k_polyline.line_width = 2
            k_polyline.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if join_def.anchor_points_3d.empty?
            k_polyline.color = join_def.anchor_points_3d.empty? ? Kuix::COLOR_DARK_GREY : Kuix::COLOR_MAGENTA
            k_polyline.closed = true
            k_polyline.on_top = true
            @tool.append_3d(k_polyline, LAYER_3D_JOIN_PREVIEW)

            k_points = _create_floating_points(
              points: join_def.anchor_points_3d,
              style: Kuix::POINT_STYLE_PLUS,
              stroke_color: Kuix::COLOR_MAGENTA
            )
            @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

            k_points = _create_floating_points(
              points: join_def.occupied_anchor_points_3d,
              style: Kuix::POINT_STYLE_CROSS,
              stroke_color: Kuix::COLOR_RED,
              stroke_width: 2
            )
            @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

            unless join_def.anchor_points_3d.empty?

              k_edge = Kuix::EdgeMotif3d.new
              k_edge.start.copy!(join_def.start_point_3d)
              k_edge.end.copy!(join_def.end_point_3d)
              k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
              k_edge.line_width = 1
              k_edge.color = Kuix::COLOR_MAGENTA
              k_edge.on_top = true
              @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

            end

            no_valid_join = false if join_def.anchor_points_3d.any?
            occupied_anchor_count += join_def.occupied_anchor_points_3d.length

          end

        end

        # Preview the connectors : only the picked couple's placements when
        # make_unique is true, every instance of the touched definitions otherwise.
        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

          hardware = placement.role == :a ? hardware_a : hardware_b
          machining = placement.role == :a ? machining_a : machining_b

          placement.instance_transformations.each do |instance_transformation|

            t = instance_transformation * placement.transformation
            picked = placement.picked?(instance_transformation)

            # -- Hardware --

            _preview_join_drawing_def(
              hardware.drawing_def,
              t,
              picked ? COLOR_HARDWARE : COLOR_HARDWARE_PROPAGATED,
              1,
              LAYER_3D_HARDWARE_PREVIEW,
            ) if hardware.drawing_def

            # -- Machinings --

            _preview_join_drawing_def(
              machining.drawing_def,
              t,
              picked ? COLOR_MACHINING : COLOR_MACHINING_PROPAGATED,
              0.5,
              LAYER_3D_MACHINING_PREVIEW
            ) if machining.drawing_def

          end

        end

        if occupied_anchor_count > 0
          @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.occupied_anchors', { :count => occupied_anchor_count }), SmartTool::MESSAGE_TYPE_ERROR)
        elsif no_valid_join
          @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.no_valid_join'), SmartTool::MESSAGE_TYPE_ERROR)
        end

      end

      if @active_vertex_manipulator_a.is_a?(VertexManipulator)

        k_points = _create_floating_points(
          points: @active_vertex_manipulator_a.point,
          style: Kuix::POINT_STYLE_CIRCLE,
          fill_color: Kuix::COLOR_MAGENTA,
          stroke_color: Kuix::COLOR_WHITE,
        )
        @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

      end

    end

    def _preview_snap_point

      @tool.clear_3d(LAYER_3D_SNAP_POINT_PREVIEW)

      if @mouse_snap_point.is_a?(Geom::Point3d)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@mouse_snap_point)
        k_edge.end.copy!(@active_vertex_manipulator_a.point)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_SNAP_POINT_PREVIEW)

      end

    end

    def _preview_join_drawing_def(drawing_def, transformation, color, line_width, layer)

      k_segments = Kuix::Segments.new
      k_segments.add_segments(
        drawing_def.edge_manipulators.flat_map(&:segment) +
        drawing_def.curve_manipulators.flat_map(&:segments)
      )
      k_segments.color = color
      k_segments.line_width = line_width
      k_segments.transformation = transformation
      k_segments.on_top = true
      @tool.append_3d(k_segments, layer)

    end

    # -----

    def _read_measures(tool, text, view)

      height, start_offset, end_offset, min_spacing, max_spacing = _split_user_text(text)

      if height.is_a?(String) && !height.empty?
        return true if _read_measure(tool, height, SmartJoinTool::ACTION_OPTION_HEIGHT, SmartJoinTool::ACTION_OPTION_HEIGHT, 'tool.smart_join.error.invalid_height')
      end

      if start_offset.is_a?(String) && !start_offset.empty?
        return true if _read_measure(tool, start_offset, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_START_OFFSET, 'tool.smart_join.error.invalid_start_offset')
      end
      if end_offset.is_a?(String) && !end_offset.empty?
        return true if _read_measure(tool, end_offset, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_END_OFFSET, 'tool.smart_join.error.invalid_end_offset')
      end

      if min_spacing.is_a?(String) && !min_spacing.empty?
        return true if _read_measure(tool, min_spacing, SmartJoinTool::ACTION_OPTION_SPACINGS, SmartJoinTool::ACTION_OPTION_SPACINGS_MIN_SPACING, 'tool.smart_join.error.invalid_min_spacing', length_only: true)
      end
      if max_spacing.is_a?(String) && !max_spacing.empty?
        return true if _read_measure(tool, max_spacing, SmartJoinTool::ACTION_OPTION_SPACINGS, SmartJoinTool::ACTION_OPTION_SPACINGS_MAX_SPACING, 'tool.smart_join.error.invalid_max_spacing')
      end

      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      true
    end

    # -----

    def _add_connectors
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

      neighbor_join_defs = joinery_def.neighbor_join_defs

      instance_a = neighborhood_def.instance_a
      definition_a = instance_a.definition
      entities_a = definition_a.entities

      geometries_def = _get_geometries_def
      hardware_a = geometries_def.hardware_a
      hardware_b = geometries_def.hardware_b
      machining_a = geometries_def.machining_a
      machining_b = geometries_def.machining_b
      hardware_material = geometries_def.hardware_material
      machining_material = geometries_def.machining_material
      hardware_layer = geometries_def.hardware_layer
      machining_layer = geometries_def.machining_layer

      model = Sketchup.active_model
      model.start_operation('OCL Add Connectors', true)
      begin

        if _fetch_option_make_unique?

          # Make unique the picked instances (if necessary). The joinery def face
          # manipulators are re-targeted to the new definitions, so the placements
          # resolved below point to them (the propagation signature changes with
          # the definition ids, discarding the preview cache).

          if !hardware_a.empty? || !machining_a.empty?

            u_instance_a = instance_a.make_unique
            u_definition_a = u_instance_a.definition
            if u_definition_a != definition_a

              u_entities_a = u_definition_a.entities

              neighbor_join_defs.each do |neighbor_join_def|
                neighbor_join_def.join_defs.each do |join_def|
                  face = join_def.touching_def.face_manipulator.face
                  if face.parent == definition_a
                    face_index = entities_a.to_a.index(face)
                    u_face = u_entities_a[face_index]
                    if u_face
                      join_def.touching_def.face_manipulator = FaceManipulator.new(u_face, join_def.touching_def.face_manipulator.transformation)
                      break
                    end
                  end
                end
              end

            end

          end

          if !hardware_b.empty? || !machining_b.empty?

            neighbor_join_defs.each do |neighbor_join_def|

              instance_b = neighbor_join_def.neighbor_def.instance_b
              definition_b = instance_b.definition
              entities_b = definition_b.entities

              u_instance_b = instance_b.make_unique
              u_definition_b = u_instance_b.definition
              if u_definition_b != definition_b

                u_entities_b = u_definition_b.entities

                neighbor_join_def.join_defs.each do |join_def|
                  neighbor_face = join_def.touching_def.neighbor_face_manipulator.face
                  if neighbor_face.parent == definition_b
                    neighbor_face_index = entities_b.to_a.index(neighbor_face)
                    u_neighbor_face = u_entities_b[neighbor_face_index]
                    if u_neighbor_face
                      join_def.touching_def.neighbor_face_manipulator = FaceManipulator.new(u_neighbor_face, join_def.touching_def.neighbor_face_manipulator.transformation)
                    end
                  end
                end

              end

            end

          end

        end

        # Add the connectors : only the picked couple's placements when make_unique
        # is true, the whole contact graph (A -> B -> A' -> B' -> ...) otherwise.
        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

          hardware = placement.role == :a ? hardware_a : hardware_b
          machining = placement.role == :a ? machining_a : machining_b
          entities = placement.entities

          _add_glued_instance(hardware.definition, hardware_material, hardware_layer, placement.face, entities, placement.transformation, ORIGIN, IDENTITY)
          _add_glued_instance(machining.definition, machining_material, machining_layer, placement.face, entities, placement.transformation, ORIGIN, IDENTITY)

        end

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

    end

    # -----

    def _get_add_joinery_def(neighborhood_def)
      return nil if @active_face_manipulator_a.nil? || @active_edge_manipulator_a.nil? || @active_vertex_manipulator_a.nil?

      t_a = neighborhood_def.t_a
      ti_a = neighborhood_def.ti_a

      start_offset = _fetch_option_start_offset
      end_offset = _fetch_option_end_offset
      min_spacing = _fetch_option_min_spacing
      max_spacing = _fetch_option_max_spacing
      height = _fetch_option_height

      geometries_def = _get_geometries_def
      geometries_bounds = geometries_def.bounds

      neighbor_join_defs = []

      neighborhood_def.neighbor_defs.each do |neighbor_def|

        t_b = neighbor_def.t_b
        ti_b = neighbor_def.ti_b

        join_defs = []

        neighbor_def.touching_defs
                    .select { |touching_def|
                      touching_def.face_manipulator.face != @active_face_manipulator_a.face &&
                      touching_def.face_manipulator.face.edges.any? { |edge| edge == @active_edge_manipulator_a.edge }
                    }
                    .each do |touching_def|

          origin = @active_vertex_manipulator_a.point
          x_axis = @active_edge_manipulator_a.direction
          x_axis = x_axis.reverse if origin == @active_edge_manipulator_a.end_point
          z_axis = touching_def.face_manipulator.normal
          y_axis = z_axis * x_axis
          at = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
          ati = at.inverse

          touching_def.touching_polys.each do |touching_poly|

            touching_poly_2d = touching_poly.map { |point| point.transform(ati) }
            touching_poly_bounds = Geom::BoundingBox.new.add(touching_poly_2d)
            touching_vy = ORIGIN.vector_to([
                                             touching_poly_bounds.min.project_to_line([ ORIGIN, Y_AXIS ]),
                                             touching_poly_bounds.max.project_to_line([ ORIGIN, Y_AXIS ])
                                           ].max { |p1, p2| ORIGIN.distance(p1) <=> ORIGIN.distance(p2) })

            total_length = touching_poly_bounds.width
            start_offset_length = start_offset.is_a?(Length) ? start_offset : total_length * start_offset
            start_offset_length = 0 if start_offset_length < geometries_bounds.width / 2
            end_offset_length = end_offset.is_a?(Length) ? end_offset : total_length * end_offset
            end_offset_length = 0 if end_offset_length < geometries_bounds.width / 2
            min_spacing_length = [ min_spacing, geometries_bounds.width ].max

            if total_length < geometries_bounds.width
              # Touching face is not large enough to contain at least one join
              coords = []
            else
              if total_length > start_offset_length + min_spacing_length + end_offset_length
                middle_length = total_length - start_offset_length - end_offset_length
                max_spacing_length = max_spacing.is_a?(Length) ? max_spacing : middle_length * max_spacing
                spacing_count = max_spacing_length <= 0 ? 1 : (middle_length / max_spacing_length).round(3).ceil
                spacing_count = 2 if spacing_count < 2 && start_offset_length == 0 && end_offset_length == 0
                spacing = middle_length / spacing_count
                if spacing < min_spacing_length
                  spacing_count = [ (middle_length / min_spacing_length).floor, 1 ].max
                  spacing = middle_length / spacing_count
                end
                coords = []
                coords << start_offset_length if start_offset_length > 0
                coords += (1...spacing_count).map { |i| start_offset_length + spacing * i }
                coords << total_length - end_offset_length if end_offset_length > 0
              else
                coords = [ total_length / 2 ]
              end
            end

            ly = if height.is_a?(Length)
                   height
                 else
                   touching_poly_bounds.height * height
                 end

            anchor_points_2d = coords.map! { |lx| ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + lx).offset(touching_vy, ly) }
                                     .delete_if { |point| !Geom.point_in_polygon_2D(point, touching_poly_2d, true) }

            anchor_points_3d = anchor_points_2d.map { |point| point.transform(at) }

            grouped_glued_instances_a = _get_grouped_glued_instances(touching_def.face_manipulator, touching_poly)
            grouped_glued_instances_b = _get_grouped_glued_instances(touching_def.neighbor_face_manipulator, touching_poly)

            at_a = Geom::Transformation.axes(
              ORIGIN,
              x_axis.transform(ti_a),
              y_axis.transform(ti_a),
              z_axis.transform(ti_a)
            )

            at_b = Geom::Transformation.axes(
              ORIGIN,
              x_axis.transform(ti_b),
              y_axis.transform(ti_b),
              z_axis.transform(ti_b).reverse!
            )

            if touching_vy.samedirection?(Y_AXIS)
              at_a *= TRANSFORMATION_ROTATION_Z_180
              at_b *= TRANSFORMATION_ROTATION_Z_180
            end

            occupied_anchor_points_3d = []
            anchor_points_3d.delete_if do |point|
              occupied = grouped_glued_instances_a.any? { |_, glued_instances| _is_geometries_intersect_glued_instances?(geometries_bounds, point, glued_instances, touching_def.face_manipulator, t_a, ti_a, at_a) } ||
                         grouped_glued_instances_b.any? { |_, glued_instances| _is_geometries_intersect_glued_instances?(geometries_bounds, point, glued_instances, touching_def.neighbor_face_manipulator, t_b, ti_b, at_b)  }
              occupied_anchor_points_3d << point if occupied
              occupied
            end

            start_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + (anchor_points_3d.length > 1 ? start_offset_length : 0)).offset!(touching_vy, ly).transform!(at)
            end_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + touching_poly_bounds.width - (anchor_points_3d.length > 1 ? end_offset_length : 0)).offset!(touching_vy, ly).transform!(at)

            join_defs << AddJoineryJoinDef.new(touching_poly,
                                               touching_def,
                                               anchor_points_3d,
                                               occupied_anchor_points_3d,
                                               start_point_3d,
                                               end_point_3d,
                                               at_a,
                                               at_b
            )

          end

        end

        neighbor_join_defs << AddJoineryNeighborJoinDef.new(neighbor_def, join_defs) if join_defs.any?

      end

      AddJoineryDef.new(
        neighbor_join_defs
      )
    end

    # -- Propagation --

    # Resolves the connector placements to preview and to add.
    #
    # When make_unique is true, they are simply the picked couple's anchors.
    # When make_unique is false, connectors are written directly into shared
    # definitions, so they appear on every instance. But the join is only picked
    # for one instance couple : other instances of the same definition may touch
    # other parts at the same anchor, which must also receive the mating connector.
    # This walks the contact graph A -> B -> A' -> B' -> ... adding one placement
    # per (definition, anchor), alternating the A/B role at each contact.
    def _get_propagation_def(neighborhood_def, joinery_def)

      signature = _get_propagation_signature(neighborhood_def, joinery_def)
      return @propagation_def if @propagation_def.is_a?(PropagationDef) && @propagation_signature == signature

      geometries_def = _get_geometries_def
      geometries_bounds = geometries_def.bounds

      seeds = []

      # A placement targets the entities that own the face (face.parent). Expressing
      # the transformation as 'face.transformation.inverse * world_frame' matches the
      # existing add path (dti * translation(pt) * at) and also handles nested faces.
      fn_seed = lambda do |face, mt, role, owner_t|
        seeds << PropagationPlacementDef.new(face.parent, face, mt, role, [ owner_t ], owner_t)
      end

      # 1. Seed with the picked couple's placements

      ti_a = neighborhood_def.ti_a

      has_geometry_a = !geometries_def.hardware_a.empty? || !geometries_def.machining_a.empty?
      has_geometry_b = !geometries_def.hardware_b.empty? || !geometries_def.machining_b.empty?

      joinery_def.neighbor_join_defs.each do |neighbor_join_def|

        ti_b = neighbor_join_def.neighbor_def.ti_b

        neighbor_join_def.join_defs.each do |join_def|

          fm_a = join_def.touching_def.face_manipulator
          fm_b = join_def.touching_def.neighbor_face_manipulator
          face_a = fm_a.face
          face_b = fm_b.face

          dti_a = (ti_a * fm_a.transformation).inverse
          dti_b = (ti_b * fm_b.transformation).inverse

          join_def.anchor_points_3d.each do |point|

            if has_geometry_a
              pt_a = point.transform(ti_a).project_to_plane(face_a.plane)
              fn_seed.call(face_a, dti_a * Geom::Transformation.translation(pt_a) * join_def.at_a, :a, fm_a.transformation)
            end
            if has_geometry_b
              pt_b = point.transform(ti_b).project_to_plane(face_b.plane)
              fn_seed.call(face_b, dti_b * Geom::Transformation.translation(pt_b) * join_def.at_b, :b, fm_b.transformation)
            end

          end

        end

      end

      if _fetch_option_make_unique?

        # 2a. No graph walk : the picked instances are made unique on add, so the
        # connectors only target the picked couple.

        placements = seeds

      else

        # 2b. Walk the contact graph

        placements = _walk_contact_graph(seeds) do |placement, wf, instance_path|

          nfm, mt_n = _find_mating_connector(wf, instance_path)
          next nil if nfm.nil?

          # Skip if the neighbor anchor is already physically occupied by a glued instance
          next nil if _get_glued_instances_at(nfm.face, mt_n, geometries_bounds).any?

          PropagationPlacementDef.new(nfm.face.parent, nfm.face, mt_n, placement.role == :a ? :b : :a)
        end

      end

      @propagation_signature = signature
      @propagation_def = PropagationDef.new(placements)
    end

    # Lightweight fingerprint of the joinery inputs (active part + neighbors + anchors).
    # Used to reuse the (heavy) propagation result while nothing relevant changed.
    # Definition ids are included so that making the picked instances unique (add
    # with make_unique) discards the placements resolved during the preview.
    def _get_propagation_signature(neighborhood_def, joinery_def)
      instance_a = neighborhood_def.instance_a
      sig = [ instance_a.entityID, instance_a.definition.entityID, _fetch_option_make_unique? ]
      joinery_def.neighbor_join_defs.each do |neighbor_join_def|
        instance_b = neighbor_join_def.neighbor_def.instance_b
        sig << instance_b.entityID
        sig << instance_b.definition.entityID
        neighbor_join_def.join_defs.each do |join_def|
          join_def.anchor_points_3d.each { |point| sig << point.to_a.map { |c| c.to_f.round(6) } }
        end
      end
      sig
    end

    # Data Structs -----

    AddJoineryDef = Struct.new(:neighbor_join_defs)
    AddJoineryNeighborJoinDef = Struct.new(:neighbor_def, :join_defs)
    AddJoineryJoinDef = Struct.new(:touching_poly, :touching_def, :anchor_points_3d, :occupied_anchor_points_3d, :start_point_3d, :end_point_3d, :at_a, :at_b)

  end

  class SmartJoinRemoveConnectorsActionHandler < SmartJoinConnectorsActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_REMOVE_CONNECTORS, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      SmartCursorManager.cursor_select_join_minus
    end

    def get_state_status(state)
      super +
        ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_1_only_one_status") + '.'
    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)

      if has_active_part?
        _remove_connectors
        _restart
        return true
      end

      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if tool.is_key_shift?(key)
        _refresh
        return true
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if tool.is_key_shift?(key)
        _refresh
        return true
      end

      false
    end

    # -----

    protected

    def _reset
      super
      @snap_anchor = nil
    end

    # -----

    def _pick_join
      context_changed = super

      if @tool.is_key_shift_down? &&
         @mouse_snap_point.is_a?(Geom::Point3d) &&
         (neighborhood_def = _get_neighborhood_def) &&
         (joinery_def = _get_remove_joinery_def(neighborhood_def))

        snap_anchor = _get_anchors(joinery_def).min { |p1, p2| @mouse_snap_point.distance(p1) <=> @mouse_snap_point.distance(p2) }

      else
        snap_anchor = nil
      end

      (context_changed || @snap_anchor != snap_anchor).tap { @snap_anchor = snap_anchor }
    end

    def _preview_join_context(neighborhood_def)
      super

      count = 0

      unless (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

        neighbor_join_defs = joinery_def.neighbor_join_defs
        neighbor_join_defs.each do |neighbor_join_def|

          neighbor_join_def.join_defs.each do |join_def|

            k_polyline = Kuix::Polyline.new
            k_polyline.add_points(join_def.touching_poly)
            k_polyline.line_width = 2
            k_polyline.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            k_polyline.color = Kuix::COLOR_DARK_GREY
            k_polyline.closed = true
            k_polyline.on_top = true
            @tool.append_3d(k_polyline, LAYER_3D_JOIN_PREVIEW)

          end

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(neighbor_join_def.neighbor_def.drawing_def.face_manipulators.flat_map(&:triangles))
          k_mesh.background_color = COLOR_PART_B
          @tool.append_3d(k_mesh, LAYER_3D_JOIN_PREVIEW)

        end

        # Preview the connectors to remove : red boxes on the picked couple,
        # translucent ones on the placements propagated through the contact graph.
        anchors = {}
        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

          placement.instance_transformations.each do |instance_transformation|

            picked = placement.picked?(instance_transformation)

            placement.glued_instances.each do |glued_instance|

              t = instance_transformation * glued_instance.transformation

              k_box = Kuix::BoxFillMotif3d.new
              k_box.bounds.copy!(glued_instance.definition.bounds)
              k_box.line_width = 2
              k_box.color = ColorUtils.color_translucent(Kuix::COLOR_RED, picked ? 0.3 : 0.15)
              k_box.on_top = true
              k_box.transformation = t
              @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

              k_box = Kuix::BoxMotif3d.new
              k_box.bounds.copy!(glued_instance.definition.bounds)
              k_box.line_width = 2
              k_box.color = picked ? Kuix::COLOR_RED : ColorUtils.color_translucent(Kuix::COLOR_RED, 0.5)
              k_box.on_top = true
              k_box.transformation = t
              @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

            end

            anchor = ORIGIN.transform(instance_transformation * placement.transformation)
            anchors[anchor.to_a.map { |coord| coord.round(3) }] = true

            if picked

              k_point = _create_floating_points(
                points: anchor,
                style: Kuix::POINT_STYLE_PLUS,
                stroke_color: Kuix::COLOR_BLACK,
                )
              @tool.append_3d(k_point, LAYER_3D_JOIN_PREVIEW)

            end

          end

        end

        count = anchors.length

      end

      if count > 0
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.x_connectors_to_remove', { :count => count }), SmartTool::MESSAGE_TYPE_WARNING)
      else
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.no_connector_to_remove'), SmartTool::MESSAGE_TYPE_WARNING)
      end

    end

    def _preview_snap_point

      @tool.clear_3d(LAYER_3D_SNAP_POINT_PREVIEW)

      if @mouse_snap_point.is_a?(Geom::Point3d) && @snap_anchor.is_a?(Geom::Point3d)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@mouse_snap_point)
        k_edge.end.copy!(@snap_anchor)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_SNAP_POINT_PREVIEW)

      end

    end

    # -----

    def _get_anchors(joinery_def)
      joinery_def.neighbor_join_defs
                 .flat_map { |neighbor_join_def| neighbor_join_def.join_defs }
                 .flat_map { |join_defs| (join_defs.grouped_glued_instances_a.keys + join_defs.grouped_glued_instances_b.keys) }
                 .map! { |coords| coords.map! { |coord| coord.round(6) }}
                 .uniq
                 .map! { |coords| Geom::Point3d.new(coords) }
    end

    def _is_snap_anchor?(anchor)
      !@snap_anchor.is_a?(Geom::Point3d) || @snap_anchor.distance(anchor).round(3) == 0
    end

    # -----

    def _remove_connectors
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

      model = Sketchup.active_model
      model.start_operation('OCL Remove Connectors', true)
      begin

        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|
          placement.glued_instances.each do |glued_instance|
            next if glued_instance.deleted?
            glued_instance.erase!
          end
        end

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

    end

    # -- Propagation --

    # Resolves the connector placements to remove. Connectors live in shared
    # definitions : erasing one removes it from every instance, so the mating
    # connectors of the parts touching the other instances must be removed too,
    # walking the contact graph (A -> B -> A' -> B' -> ...). The walk stops on
    # branches where no glued instance exists at the anchor.
    def _get_propagation_def(neighborhood_def, joinery_def)

      signature = _get_propagation_signature(neighborhood_def, joinery_def)
      return @propagation_def if @propagation_def.is_a?(PropagationDef) && @propagation_signature == signature

      seeds = []

      # The glued instance transformation is the connector frame in the face
      # owner definition space (Z axis pointing toward the mating part)
      fn_seed = lambda do |fm, grouped_glued_instances, role|
        grouped_glued_instances.each do |anchor_coords, glued_instances|
          next unless _is_snap_anchor?(Geom::Point3d.new(anchor_coords))
          seeds << PropagationPlacementDef.new(fm.face.parent, fm.face, glued_instances.first.transformation, role, [ fm.transformation ], fm.transformation, glued_instances)
        end
      end

      joinery_def.neighbor_join_defs.each do |neighbor_join_def|
        neighbor_join_def.join_defs.each do |join_def|
          fn_seed.call(join_def.touching_def.face_manipulator, join_def.grouped_glued_instances_a, :a)
          fn_seed.call(join_def.touching_def.neighbor_face_manipulator, join_def.grouped_glued_instances_b, :b)
        end
      end

      placements = _walk_contact_graph(seeds) do |placement, wf, instance_path|

        nfm, mt_n = _find_mating_connector(wf, instance_path)
        next nil if nfm.nil?

        # Only propagate onto anchors where a mating glued instance exists
        glued_instances = _get_glued_instances_anchored_at(nfm.face, mt_n)
        next nil if glued_instances.empty?

        PropagationPlacementDef.new(nfm.face.parent, nfm.face, mt_n, placement.role == :a ? :b : :a, nil, nil, glued_instances)
      end

      @propagation_signature = signature
      @propagation_def = PropagationDef.new(placements)
    end

    # Lightweight fingerprint of the removal inputs (active part + neighbors +
    # glued anchors + snap anchor). Used to reuse the (heavy) propagation result
    # while nothing relevant changed.
    def _get_propagation_signature(neighborhood_def, joinery_def)
      instance_a = neighborhood_def.instance_a
      sig = [ instance_a.entityID, instance_a.definition.entityID, @snap_anchor ]
      joinery_def.neighbor_join_defs.each do |neighbor_join_def|
        instance_b = neighbor_join_def.neighbor_def.instance_b
        sig << instance_b.entityID
        sig << instance_b.definition.entityID
        neighbor_join_def.join_defs.each do |join_def|
          sig.concat(join_def.grouped_glued_instances_a.keys)
          sig.concat(join_def.grouped_glued_instances_b.keys)
        end
      end
      sig
    end

    # -----

    def _get_remove_joinery_def(neighborhood_def)
      return nil if @active_face_manipulator_a.nil? || @active_edge_manipulator_a.nil? || @active_vertex_manipulator_a.nil?

      neighbor_join_defs = []

      neighborhood_def.neighbor_defs.each do |neighbor_def|

        join_defs = []

        neighbor_def.touching_defs
                    .select { |touching_def|
                      touching_def.face_manipulator.face != @active_face_manipulator_a.face &&
                      touching_def.face_manipulator.face.edges.any? { |edge| edge == @active_edge_manipulator_a.edge }
                    }
                    .each do |touching_def|

          touching_def.touching_polys.each do |touching_poly|

            grouped_glued_instances_a = _get_grouped_glued_instances(touching_def.face_manipulator, touching_poly)
            grouped_glued_instances_b = _get_grouped_glued_instances(touching_def.neighbor_face_manipulator, touching_poly)

            join_defs << RemoveJoineryJoinDef.new(touching_poly, touching_def, grouped_glued_instances_a, grouped_glued_instances_b)

          end

        end

        neighbor_join_defs << RemoveJoineryNeighborJoinDef.new(neighbor_def, join_defs) if join_defs.any?

      end

      RemoveJoineryDef.new(
        neighbor_join_defs
      )
    end

    # Data Structs -----

    RemoveJoineryDef = Struct.new(:neighbor_join_defs)
    RemoveJoineryNeighborJoinDef = Struct.new(:neighbor_def, :join_defs)
    RemoveJoineryJoinDef = Struct.new(:touching_poly, :touching_def, :grouped_glued_instances_a, :grouped_glued_instances_b)

  end

  # -- LINKS --

  class SmartJoinFittingsActionHandler < SmartJoinActionHandler

    STATE_SELECT_A = 0
    STATE_SELECT_B = 1

    def initialize(action, tool, previous_action_handler = nil)
      super

      @active_part_entity_path_a = nil
      @active_part_entity_path_b = nil

      @active_part_a = nil
      @active_part_b = nil

    end

    # -----

    # -- STATE --

    def get_state_status(state)
      PLUGIN.get_i18n_string("tool.smart_#{@tool.get_stripped_name}.action_#{@action}_state_#{state}_status") + '.' +
        ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_option_options_opposite_status") + '.'
    end

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self, pick_point: true, drawable: false, lockable: false)
    end

    def get_state_cursor(state)
      case state
      when STATE_SELECT_A
        return SmartCursorManager.cursor_select_a
      end
      super
    end

    # -----

    def onToolCancel(tool, reason, view)
      super

      case @state

      when STATE_SELECT_B
        _reset

      end
      _refresh

    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SELECT_A
        if _has_active_part_a?
          set_state(STATE_SELECT_B)
          _refresh
        end
        return true

      end

      false
    end

    def onPickerChanged(picker, view)
      super

      case @state

      when STATE_SELECT_A
        @tool.clear_3d([ LAYER_3D_JOIN_PREVIEW ])
        @tool.hide_message
        if _pick_ref_face_a(picker)
          _reset_neighborhood_def
        end
        _preview_ref_face_a(picker)
        return true

      when STATE_SELECT_B
        @tool.clear_3d([ LAYER_3D_JOIN_PREVIEW, LAYER_3D_SNAP_POINT_PREVIEW ])
        @tool.hide_message
        if _pick_ref_face_b(picker)
          _reset_neighborhood_def
        end
        if _snap_ref_point_b(picker)
          _reset_joinery_def
        end
        _preview_ref_face_a
        _preview_join(picker)
        return true

      end
    end

    def onActivePartChanged(part_entity_path, part, highlighted = false)

      case @state

      when STATE_SELECT_A
        _preview_part(part_entity_path, part, LAYER_3D_PART_A_PREVIEW, highlighted: highlighted)
        @active_part_entity_path_a = part_entity_path
        @active_part_a = part
        @active_face_manipulator_a = nil

      when STATE_SELECT_B
        _preview_part(part_entity_path, part, LAYER_3D_PART_B_PREVIEW, highlighted: highlighted)
        @active_part_entity_path_b = part_entity_path
        @active_part_b = part
        @active_face_manipulator_b = nil

      end

      _reset_neighborhood_def
    end

    # -----

    protected

    def _reset
      super
      @mouse_snap_point = nil
      _reset_active_part_a
      _reset_active_part_b
      _reset_neighborhood_def
      set_state(STATE_SELECT_A)
    end

    def _reset_active_part_a
      @active_part_entity_path_a = nil
      @active_part_a = nil
      @active_face_manipulator_a = nil
    end

    def _reset_active_part_b
      @active_part_entity_path_b = nil
      @active_part_b = nil
      @active_face_manipulator_b = nil
    end

    def _reset_neighborhood_def
      @neighborhood_def = nil
      @propagation_def = nil
      _reset_joinery_def
    end

    def _reset_joinery_def
      @joinery_def = nil
    end

    # -- Propagation --

    # Lateral step used to probe inside a face body from its axis edge
    PROPAGATION_PROBE_LATERAL_OFFSET = 1.mm

    # Characterizes the picked couple's dihedral relationship :
    # - 'mate_transformation' maps a fitting frame to its mating frame (a
    #   rotation around the shared X axis - the joint axis - by the dihedral
    #   angle) ; apply its inverse to go the other way (b -> a)
    # - 'side_a' / 'side_b' tell on which lateral side (+1 : +Y, -1 : -Y of
    #   their frame) each face body extends from the axis
    def _get_propagation_context(line_def)

      x_axis = line_def.line_manipulator.direction

      fm_a = line_def.face_manipulator
      fm_b = line_def.neighbor_face_manipulator

      z_axis_a = fm_a.normal
      y_axis_a = z_axis_a * x_axis
      z_axis_b = fm_b.normal
      y_axis_b = z_axis_b * x_axis

      point = line_def.start_point

      [
        Geom::Transformation.axes(ORIGIN, x_axis, y_axis_a, z_axis_a).inverse * Geom::Transformation.axes(ORIGIN, x_axis, y_axis_b, z_axis_b),
        (fm_a.centroid - point) % y_axis_a >= 0 ? 1 : -1,
        (fm_b.centroid - point) % y_axis_b >= 0 ? 1 : -1
      ]
    end

    # Probes for the part mating the given expected fitting world frame 'wf' :
    # the mate face lies on the frame XY plane (which contains the joint axis
    # = X) with its material behind (-Z). The anchor sits on the face's axis
    # edge, so the probe point is stepped laterally (side * +Y) into the face
    # body. Returns [ face_manipulator, mt ] - where 'mt' is the mating fitting
    # frame expressed in the mate face owner definition space - or nil.
    def _find_mating_fitting(wf, side, instance_path, tolerance = 0.001.mm)

      world_point = ORIGIN.transform(wf)
      world_y = Y_AXIS.transform(wf)
      world_y.normalize!
      world_z = Z_AXIS.transform(wf)
      world_z.normalize!

      probe_point = world_point.offset(world_y, PROPAGATION_PROBE_LATERAL_OFFSET * side)

      fn_accept = lambda do |fm|
        fm.normal.samedirection?(world_z) &&                                             # Same normal (the fitting is glued ON the face)
          world_point.distance_to_plane([ fm.position, fm.normal ]).to_f < tolerance &&  # Anchor on the face plane
          _is_point_on_face?(fm, probe_point)                                            # Probe point within the face
      end

      nfm = _raytest_part_face(probe_point.offset(world_z, tolerance * 10), world_z.reverse, instance_path, &fn_accept)
      nfm = _find_part_face_at(probe_point, instance_path, tolerance, &fn_accept) if nfm.nil?
      return nil if nfm.nil?

      [ nfm, nfm.transformation.inverse * wf ]
    end

    def _refresh
      _reset_active_part
      _reset_active_part_b
      @mouse_snap_point = nil
      @picker.invalidate if @picker.is_a?(SmartPicker)
      super
    end

    # -----

    def _get_active_part_preview_color(part, highlighted = false)
      case @state
      when STATE_SELECT_A
        COLOR_PART_A
      when STATE_SELECT_B
        COLOR_PART_B
      end
    end

    # -----

    def _has_active_part_a?
      @active_part_a.is_a?(Part)
    end

    def _has_active_part_b?
      @active_part_b.is_a?(Part)
    end

    # -----

    def _pick_ref_face_a(picker)
      _pick_ref_face(picker, :_has_active_part_a?, :@active_face_manipulator_a)
    end

    def _pick_ref_face_b(picker)
      _pick_ref_face(picker, :_has_active_part_b?, :@active_face_manipulator_b)
    end

    def _pick_ref_face(picker, check_method_name, var_name)

      face_manipulator = self.send(check_method_name) ? picker.picked_plane_manipulator : nil
      if face_manipulator.is_a?(FaceManipulator)

        if _fetch_option_opposite?
          snap_point, face_manipulator = _pick_opposite_face_at(picker.picked_point, face_manipulator)
        else
          snap_point = picker.picked_point
        end

      else
        snap_point = nil
        face_manipulator = nil
      end

      (self.instance_variable_get(var_name) != face_manipulator).tap do
        @mouse_snap_point = snap_point
        self.instance_variable_set(var_name, face_manipulator)
      end
    end

    def _snap_ref_point_b(picker)
      false
    end

    def _preview_ref_face_a(picker = nil)
      _preview_ref_face(picker, @active_face_manipulator_a, COLOR_REF_FACE_A, COLOR_REF_DARKEN_A)
    end

    def _preview_ref_face_b(picker = nil)
      _preview_ref_face(picker, @active_face_manipulator_b, COLOR_REF_FACE_B, COLOR_REF_DARKEN_B)
    end

    def _preview_ref_face(picker, face_manipulator, color, darken_color)
      if face_manipulator.is_a?(FaceManipulator)

        arrow_length = Sketchup.active_model.active_view.pixels_to_model(60, face_manipulator.centroid)
        arrow_size = 15

        # Offset transformation to force mesh to be on top of part preview
        ov = Geom::Vector3d.new(face_manipulator.normal)
        ov.length = 0.01
        ot = Geom::Transformation.translation(ov)

        # --

        # Colorize face
        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(face_manipulator.triangles)
        k_mesh.background_color = color
        k_mesh.transformation = ot
        @tool.append_3d(k_mesh, LAYER_3D_JOIN_PREVIEW)

        # --

        # Draw face normal arrow
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(face_manipulator.centroid)
        k_edge.end.copy!(face_manipulator.centroid.offset(face_manipulator.normal, arrow_length))
        k_edge.line_width = 2
        k_edge.end_arrow = true
        k_edge.arrow_size = arrow_size
        k_edge.color = darken_color
        k_edge.on_top = false
        @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

        # Draw face normal arrow (dashed)
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(face_manipulator.centroid)
        k_edge.end.copy!(face_manipulator.centroid.offset(face_manipulator.normal, arrow_length))
        k_edge.line_width = 1.5
        k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_edge.end_arrow = true
        k_edge.arrow_size = arrow_size
        k_edge.color = darken_color
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

        # --

        # Draw face outer edges
        k_polyline = Kuix::Polyline.new
        k_polyline.add_points(face_manipulator.outer_loop_manipulator.points)
        k_polyline.line_width = 1
        k_polyline.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_polyline.color = darken_color
        k_polyline.closed = true
        k_polyline.on_top = true
        @tool.append_3d(k_polyline, LAYER_3D_JOIN_PREVIEW)

        # --

        # Draw "opposite" point (if possible)
        if @mouse_snap_point && picker && @mouse_snap_point != picker.picked_point

          k_point = _create_floating_points(
            points: @mouse_snap_point,
            style: Kuix::POINT_STYLE_DIAMOND,
            fill_color: color,
            stroke_color: Kuix::COLOR_DARK_GREY,
            stroke_width: 1,
            )
          @tool.append_3d(k_point, LAYER_3D_JOIN_PREVIEW)

          k_edge = Kuix::EdgeMotif3d.new
          k_edge.start.copy!(picker.picked_point)
          k_edge.end.copy!(@mouse_snap_point)
          k_edge.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_edge.line_width = 1
          k_edge.color = Kuix::COLOR_DARK_GREY
          k_edge.on_top = true
          @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

        end

      end
    end

    def _preview_join(picker)
      _preview_ref_face_b(picker)
    end

    # -----

    def _pick_opposite_face_at(point, face_manipulator)
      model = Sketchup.active_model
      view = model.active_view
      face_point = Geom.intersect_line_plane([ view.camera.eye, view.camera.eye.vector_to(point) ], face_manipulator.plane)
      point = face_point if face_point.is_a?(Geom::Point3d) # Point may be out of the face plane, so override it if we have found a best candidate.
      hit_point, hit_path = model.raytest([ point, face_manipulator.normal.reverse ], true)
      if hit_point &&
         (face = hit_path.last).is_a?(Sketchup::Face) &&
         face.parent == face_manipulator.face.parent &&
         (hit_face_manipulator = FaceManipulator.new(face, PathUtils.get_transformation(hit_path))).normal.parallel?(face_manipulator.normal)

        return [ hit_point, hit_face_manipulator ]

      end
      [ point, face_manipulator ]
    end

    # ------

    def _get_neighborhood_def(tolerance = 0.001)
      return @neighborhood_def unless @neighborhood_def.nil?

      return nil unless _has_active_part_a? && _has_active_part_b?
      return nil if @active_part_entity_path_a == @active_part_entity_path_b
      return nil unless @active_face_manipulator_a.is_a?(FaceManipulator) && @active_face_manipulator_b.is_a?(FaceManipulator)

      if (line = Geom.intersect_plane_plane(@active_face_manipulator_a.plane, @active_face_manipulator_b.plane))

        line_manipulator = LineManipulator.new(line)

        pos_a = @active_face_manipulator_a.outer_loop_manipulator
                                        .points
                                        .map { |point| p = point.project_to_line(line); [ (p - line_manipulator.position) % line_manipulator.direction, p ] }
                                        .sort_by! { |pos, _| pos }
        pos_b = @active_face_manipulator_b.outer_loop_manipulator
                                        .points
                                        .map { |point| p = point.project_to_line(line); [ (p - line_manipulator.position) % line_manipulator.direction, p ] }
                                        .sort_by! { |pos, _| pos }

        # Compute bounds intersection

        pos_s, point_s = [ pos_a.first, pos_b.first ].max { |(pos1, _), (pos2, _)| pos1 <=> pos2 }
        pos_e, point_e = [ pos_a.last, pos_b.last ].min { |(pos1, _), (pos2, _)| pos1 <=> pos2 }

        return nil if pos_s > pos_e || point_s.distance(point_e).to_f < tolerance # No intersection

        neighbor_def = NeighborhoodNeighborDef.new(
          @active_part_entity_path_b,
          NeighborhoodLineDef.new(
            @active_face_manipulator_a,
            @active_face_manipulator_b,
            line_manipulator,
            point_s,
            point_e
          )
        )

      else
        return nil
      end

      # Keep useful data

      @neighborhood_def = NeighborhoodDef.new(
        @active_part_entity_path_a,
        neighbor_def
      )
    end

    # Data Structs -----

    NeighborhoodDef = Struct.new(:path, :neighbor_def) do
      def instance_a
        path.last
      end
      def t_a
        @t_a ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_a
        @ti_a ||= t_a.inverse
      end
    end
    NeighborhoodNeighborDef = Struct.new(:path, :line_def) do
      def instance_b
        path.last
      end
      def t_b
        @t_b ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_b
        @ti_b ||= t_b.inverse
      end
    end
    NeighborhoodLineDef = Struct.new(:face_manipulator, :neighbor_face_manipulator, :line_manipulator, :start_point, :end_point)

  end

  class SmartJoinAddFittingsActionHandler < SmartJoinFittingsActionHandler

    include UserTextHelper

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_ADD_FITTINGS, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      case state
      when STATE_SELECT_B
        return SmartCursorManager.cursor_select_join_plus
      end
      super
    end

    def get_state_status(state)
      super +
        ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_3") + '.'
    end

    # -----

    def onToolUserText(tool, text, view)
      return true if super

      return true if _read_measures(tool, text, view)

      false
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SELECT_B
        if _has_active_part_b?
          _add_fittings
          _restart
        else
          UI.beep
        end
        return true

      end

      super
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if tool.is_key_ctrl_or_option?(key)
        @tool.store_action_option_value(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_OPPOSITE, !_fetch_option_opposite?, fire_event: true)
        return true
      end

      false
    end

    # -----

    def enableVCB?
      true
    end

    # -----

    protected

    def _reset
      super
      @snap_start_point = nil
    end

    # -----

    def _snap_ref_point_b(picker)
      return false if (neighborhood_def = _get_neighborhood_def).nil?

      line_def = neighborhood_def.neighbor_def.line_def

      snap_start_point = [ line_def.start_point, line_def.end_point ].min { |p1, p2| p1.distance(picker.picked_point) <=> p2.distance(picker.picked_point) }

      # Returns true if changed
      (@snap_start_point != snap_start_point).tap { @snap_start_point = snap_start_point }
    end

    def _preview_join(picker)
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

      super

      # Preview line

      line_def = neighborhood_def.neighbor_def.line_def

      k_points = _create_floating_points(
        points: [ line_def.start_point, line_def.end_point ],
        style: Kuix::POINT_STYLE_CIRCLE,
        fill_color: Kuix::COLOR_MAGENTA,
        stroke_color: nil,
        size: 1.5
      )
      @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

      if @snap_start_point.is_a?(Geom::Point3d)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(picker.picked_point)
        k_edge.end.copy!(@snap_start_point)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_SNAP_POINT_PREVIEW)

        k_point = _create_floating_points(
          points: @snap_start_point,
          style: Kuix::POINT_STYLE_CIRCLE,
          fill_color: Kuix::COLOR_MAGENTA,
          stroke_color: Kuix::COLOR_WHITE,
          )
        @tool.append_3d(k_point, LAYER_3D_SNAP_POINT_PREVIEW)

      end

      join_def = joinery_def.join_def

      unless join_def.anchor_points_3d.empty?

        # Preview anchors

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(join_def.start_point_3d)
        k_edge.end.copy!(join_def.end_point_3d)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1.5
        k_edge.color = Kuix::COLOR_MAGENTA
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

        k_points = _create_floating_points(
          points: join_def.anchor_points_3d,
          style: Kuix::POINT_STYLE_PLUS,
          stroke_color: Kuix::COLOR_MAGENTA
        )
        @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

        # Preview geometries

        geometries_def = _get_geometries_def
        hardware_a = geometries_def.hardware_a
        hardware_b = geometries_def.hardware_b
        machining_a = geometries_def.machining_a
        machining_b = geometries_def.machining_b

        fn_preview_join_drawing_def = lambda do |drawing_def, transformation, color, line_width|

          k_segments = Kuix::Segments.new
          k_segments.add_segments(
            drawing_def.edge_manipulators.flat_map(&:segment) +
            drawing_def.curve_manipulators.flat_map(&:segments)
          )
          k_segments.color = color
          k_segments.line_width = line_width
          k_segments.transformation = transformation
          k_segments.on_top = true
          @tool.append_3d(k_segments, LAYER_3D_JOIN_PREVIEW)

        end

        # Preview the fittings : only the picked couple's placements when
        # make_unique is true, every instance of the touched definitions otherwise.
        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

          hardware = placement.role == :a ? hardware_a : hardware_b
          machining = placement.role == :a ? machining_a : machining_b

          placement.instance_transformations.each do |instance_transformation|

            t = instance_transformation * placement.transformation
            picked = placement.picked?(instance_transformation)

            # -- Machinings --

            fn_preview_join_drawing_def.call(
              machining.drawing_def,
              t,
              picked ? COLOR_MACHINING : COLOR_MACHINING_PROPAGATED,
              0.5
            ) if machining.drawing_def

            # -- Hardware --

            fn_preview_join_drawing_def.call(
              hardware.drawing_def,
              t,
              picked ? COLOR_HARDWARE : COLOR_HARDWARE_PROPAGATED,
              1
            ) if hardware.drawing_def

          end

        end

      end

      k_points = _create_floating_points(
        points: join_def.occupied_anchor_points_3d,
        style: Kuix::POINT_STYLE_CROSS,
        stroke_color: Kuix::COLOR_RED,
        stroke_width: 2
      )
      @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

      no_valid_join = join_def.anchor_points_3d.empty?
      occupied_anchor_count = join_def.occupied_anchor_points_3d.length

      if occupied_anchor_count > 0
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.occupied_anchors', { :count => occupied_anchor_count }), SmartTool::MESSAGE_TYPE_ERROR)
      elsif no_valid_join
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.no_valid_join'), SmartTool::MESSAGE_TYPE_ERROR)
      end

    end

    # -----

    def _read_measures(tool, text, view)

      start_offset, end_offset, min_spacing, max_spacing = _split_user_text(text)

      if start_offset.is_a?(String) && !start_offset.empty?
        return true if _read_measure(tool, start_offset, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_START_OFFSET, 'tool.smart_join.error.invalid_start_offset')
      end
      if end_offset.is_a?(String) && !end_offset.empty?
        return true if _read_measure(tool, end_offset, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_END_OFFSET, 'tool.smart_join.error.invalid_end_offset')
      end

      if min_spacing.is_a?(String) && !min_spacing.empty?
        return true if _read_measure(tool, min_spacing, SmartJoinTool::ACTION_OPTION_SPACINGS, SmartJoinTool::ACTION_OPTION_SPACINGS_MIN_SPACING, 'tool.smart_join.error.invalid_min_spacing', length_only: true)
      end
      if max_spacing.is_a?(String) && !max_spacing.empty?
        return true if _read_measure(tool, max_spacing, SmartJoinTool::ACTION_OPTION_SPACINGS, SmartJoinTool::ACTION_OPTION_SPACINGS_MAX_SPACING, 'tool.smart_join.error.invalid_max_spacing')
      end

      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      true
    end

    # -----

    def _add_fittings
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

      neighbor_def = neighborhood_def.neighbor_def
      line_def = neighbor_def.line_def

      instance_a = neighborhood_def.instance_a
      definition_a = instance_a.definition
      entities_a = definition_a.entities

      instance_b = neighbor_def.instance_b
      definition_b = instance_b.definition
      entities_b = definition_b.entities

      geometries_def = _get_geometries_def
      hardware_a = geometries_def.hardware_a
      hardware_b = geometries_def.hardware_b
      machining_a = geometries_def.machining_a
      machining_b = geometries_def.machining_b
      hardware_material = geometries_def.hardware_material
      machining_material = geometries_def.machining_material
      hardware_layer = geometries_def.hardware_layer
      machining_layer = geometries_def.machining_layer

      model = Sketchup.active_model
      model.start_operation('OCL Add Fittings', true)
      begin

        if _fetch_option_make_unique?

          if !hardware_a.empty? || !machining_a.empty?

            # Make unique Part A (if necessary)

            u_instance_a = instance_a.make_unique
            u_definition_a = u_instance_a.definition
            if u_definition_a != definition_a

              u_entities_a = u_definition_a.entities

              face = line_def.face_manipulator.face
              if face.parent == definition_a
                face_index = entities_a.to_a.index(face)
                u_face = u_entities_a[face_index]
                if u_face
                  line_def.face_manipulator = FaceManipulator.new(u_face, line_def.face_manipulator.transformation)
                end
              end

            end

          end

          if !hardware_b.empty? || !machining_b.empty?

            # Make unique Part B (if necessary)

            u_instance_b = instance_b.make_unique
            u_definition_b = u_instance_b.definition
            if u_definition_b != definition_b

              u_entities_b = u_definition_b.entities

              neighbor_face = line_def.neighbor_face_manipulator.face
              if neighbor_face.parent == definition_b
                neighbor_face_index = entities_b.to_a.index(neighbor_face)
                u_neighbor_face = u_entities_b[neighbor_face_index]
                if u_neighbor_face
                  line_def.neighbor_face_manipulator = FaceManipulator.new(u_neighbor_face, line_def.neighbor_face_manipulator.transformation)
                end
              end

            end

          end

        end

        # Add the fittings : only the picked couple's placements when make_unique
        # is true, the whole contact graph (A -> B -> A' -> B' -> ...) otherwise.
        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

          hardware = placement.role == :a ? hardware_a : hardware_b
          machining = placement.role == :a ? machining_a : machining_b
          entities = placement.entities

          _add_glued_instance(hardware.definition, hardware_material, hardware_layer, placement.face, entities, placement.transformation, ORIGIN, IDENTITY)
          _add_glued_instance(machining.definition, machining_material, machining_layer, placement.face, entities, placement.transformation, ORIGIN, IDENTITY)

        end

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

    end

    # -- Propagation --

    # Resolves the fitting placements to preview and to add.
    #
    # When make_unique is true, they are simply the picked couple's anchors.
    # When make_unique is false, fittings are written directly into shared
    # definitions, so they appear on every instance. Other instances of the same
    # definition may form the same dihedral configuration with other parts, which
    # must also receive the mating fitting : the contact graph walk adds one
    # placement per (definition, anchor), alternating the A/B role and skipping
    # anchors already occupied by a glued instance.
    def _get_propagation_def(neighborhood_def, joinery_def)

      signature = _get_propagation_signature(neighborhood_def, joinery_def)
      return @propagation_def if @propagation_def.is_a?(PropagationDef) && @propagation_signature == signature

      neighbor_def = neighborhood_def.neighbor_def
      line_def = neighbor_def.line_def

      geometries_def = _get_geometries_def
      geometries_bounds = geometries_def.bounds

      ti_a = neighborhood_def.ti_a
      ti_b = neighbor_def.ti_b

      fm_a = line_def.face_manipulator
      fm_b = line_def.neighbor_face_manipulator
      face_a = fm_a.face
      face_b = fm_b.face

      dti_a = (ti_a * fm_a.transformation).inverse
      dti_b = (ti_b * fm_b.transformation).inverse

      has_geometry_a = !geometries_def.hardware_a.empty? || !geometries_def.machining_a.empty?
      has_geometry_b = !geometries_def.hardware_b.empty? || !geometries_def.machining_b.empty?

      # 1. Seed with the picked couple's placements

      seeds = []

      joinery_def.join_def.anchor_points_3d.each do |point|

        if has_geometry_a
          pt_a = point.transform(ti_a).project_to_plane(face_a.plane)
          seeds << PropagationPlacementDef.new(face_a.parent, face_a, dti_a * Geom::Transformation.translation(pt_a) * joinery_def.at_a, :a, [ fm_a.transformation ], fm_a.transformation)
        end
        if has_geometry_b
          pt_b = point.transform(ti_b).project_to_plane(face_b.plane)
          seeds << PropagationPlacementDef.new(face_b.parent, face_b, dti_b * Geom::Transformation.translation(pt_b) * joinery_def.at_b, :b, [ fm_b.transformation ], fm_b.transformation)
        end

      end

      if _fetch_option_make_unique?

        # 2a. No graph walk : the picked instances are made unique on add, so the
        # fittings only target the picked couple.

        placements = seeds

      else

        # 2b. Walk the contact graph

        mate_transformation, side_a, side_b = _get_propagation_context(line_def)
        mate_transformation_inverse = mate_transformation.inverse

        placements = _walk_contact_graph(seeds) do |placement, wf, instance_path|

          from_a = placement.role == :a
          nfm, mt_n = _find_mating_fitting(wf * (from_a ? mate_transformation : mate_transformation_inverse), from_a ? side_b : side_a, instance_path)
          next nil if nfm.nil?

          # Skip if the neighbor anchor is already physically occupied by a glued instance
          next nil if _get_glued_instances_at(nfm.face, mt_n, geometries_bounds).any?

          PropagationPlacementDef.new(nfm.face.parent, nfm.face, mt_n, from_a ? :b : :a)
        end

      end

      @propagation_signature = signature
      @propagation_def = PropagationDef.new(placements)
    end

    # Lightweight fingerprint of the joinery inputs (picked couple + anchors).
    # Definition ids are included so that making the picked instances unique (add
    # with make_unique) discards the placements resolved during the preview.
    def _get_propagation_signature(neighborhood_def, joinery_def)
      instance_a = neighborhood_def.instance_a
      instance_b = neighborhood_def.neighbor_def.instance_b
      sig = [ instance_a.entityID, instance_a.definition.entityID, instance_b.entityID, instance_b.definition.entityID, _fetch_option_make_unique? ]
      joinery_def.join_def.anchor_points_3d.each { |point| sig << point.to_a.map { |c| c.to_f.round(6) } }
      sig
    end

    # -----

    def _get_add_joinery_def(neighborhood_def)
      return @joinery_def unless @joinery_def.nil?

      return nil if neighborhood_def.neighbor_def.nil?

      neighbor_def = neighborhood_def.neighbor_def
      line_def = neighbor_def.line_def

      t_a = neighborhood_def.t_a
      ti_a = neighborhood_def.ti_a
      t_b = neighbor_def.t_b
      ti_b = neighbor_def.ti_b

      start_offset = _fetch_option_start_offset
      end_offset = _fetch_option_end_offset
      min_spacing = _fetch_option_min_spacing
      max_spacing = _fetch_option_max_spacing

      geometries_def = _get_geometries_def
      geometries_bounds = geometries_def.bounds

      v = line_def.start_point.vector_to(line_def.end_point)

      total_length = v.length
      start_offset_length = start_offset.is_a?(Length) ? start_offset : total_length * start_offset
      start_offset_length = 0 if start_offset_length < geometries_bounds.width / 2
      end_offset_length = end_offset.is_a?(Length) ? end_offset : total_length * end_offset
      end_offset_length = 0 if end_offset_length < geometries_bounds.width / 2

      min_spacing_length = [ min_spacing, geometries_bounds.width ].max

      if total_length < geometries_bounds.width
        # Touching face is not large enough to contain at least one join
        coords = []
      else
        if total_length > start_offset_length + min_spacing_length + end_offset_length
          middle_length = total_length - start_offset_length - end_offset_length
          max_spacing_length = max_spacing.is_a?(Length) ? max_spacing : middle_length * max_spacing
          spacing_count = max_spacing_length <= 0 ? 1 : (middle_length / max_spacing_length).round(3).ceil
          spacing_count = 2 if spacing_count < 2 && start_offset_length == 0 && end_offset_length == 0
          spacing = middle_length / spacing_count
          if spacing < min_spacing_length
            spacing_count = [ (middle_length / min_spacing_length).floor, 1 ].max
            spacing = middle_length / spacing_count
          end
          coords = []
          coords << start_offset_length if start_offset_length > 0
          coords += (1...spacing_count).map { |i| start_offset_length + spacing * i }
          coords << total_length - end_offset_length if end_offset_length > 0
        else
          coords = [ total_length / 2 ]
        end
      end

      x_axis = line_def.line_manipulator.direction

      z_axis_a = line_def.face_manipulator.normal
      y_axis_a = z_axis_a * x_axis

      z_axis_b = line_def.neighbor_face_manipulator.normal
      y_axis_b = z_axis_b * x_axis

      at_a = Geom::Transformation.axes(
        ORIGIN,
        x_axis.transform(ti_a),
        y_axis_a.transform(ti_a),
        z_axis_a.transform(ti_a)
      )

      at_b = Geom::Transformation.axes(
        ORIGIN,
        x_axis.transform(ti_b),
        y_axis_b.transform(ti_b),
        z_axis_b.transform(ti_b)
      )

      if @snap_start_point == line_def.start_point
        ps = line_def.start_point
        pe = line_def.end_point
      else
        ps = line_def.end_point
        pe = line_def.start_point
        v = v.reverse
      end

      anchor_points_3d = coords.map { |lx| ps.offset(v, lx) }

      poly_3d = [ line_def.start_point, line_def.start_point, line_def.end_point ] # Fake flat poly by doubbleling start point

      grouped_glued_instances_a = _get_grouped_glued_instances(line_def.face_manipulator, poly_3d)
      grouped_glued_instances_b = _get_grouped_glued_instances(line_def.neighbor_face_manipulator, poly_3d)

      occupied_anchor_points_3d = []
      anchor_points_3d.delete_if do |point|
        occupied = grouped_glued_instances_a.any? { |_, glued_instances| _is_geometries_intersect_glued_instances?(geometries_bounds, point, glued_instances, line_def.face_manipulator, t_a, ti_a, at_a) } ||
                   grouped_glued_instances_b.any? { |_, glued_instances| _is_geometries_intersect_glued_instances?(geometries_bounds, point, glued_instances, line_def.neighbor_face_manipulator, t_b, ti_b, at_b)  }
        occupied_anchor_points_3d << point if occupied
        occupied
      end

      start_point_3d = ps.offset(v, anchor_points_3d.length > 1 ? start_offset_length : 0)
      end_point_3d = pe.offset(v.reverse, anchor_points_3d.length > 1 ? end_offset_length : 0)

      @joinery_def = AddJoineryDef.new(
        at_a,
        at_b,
        AddJoineryJoinDef.new(
          anchor_points_3d,
          occupied_anchor_points_3d,
          start_point_3d,
          end_point_3d
        )
      )
    end

    # Data Structs -----

    AddJoineryDef = Struct.new(:at_a, :at_b, :join_def)
    AddJoineryJoinDef = Struct.new(:anchor_points_3d, :occupied_anchor_points_3d, :start_point_3d, :end_point_3d)

  end

  class SmartJoinRemoveFittingsActionHandler < SmartJoinFittingsActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_REMOVE_FITTINGS, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      case state
      when STATE_SELECT_B
        return SmartCursorManager.cursor_select_join_minus
      end
      super
    end

    def get_state_status(state)
      case state
      when STATE_SELECT_B
        super +
          ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_3_only_one_status") + '.'
      else
        super
      end
    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SELECT_B
        if _has_active_part_b?
          _remove_fittings
          if @tool.is_key_shift_down?
            _refresh
          else
            _restart
          end
        else
          UI.beep
        end
        return true

      end

      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if tool.is_key_shift?(key)
        _refresh
        return true
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if tool.is_key_shift?(key)
        _refresh
        return true
      end
      if tool.is_key_ctrl_or_option?(key)
        @tool.store_action_option_value(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_OPPOSITE, !_fetch_option_opposite?, fire_event: true)
        return true
      end

      false
    end

    # -----

    protected

    def _reset
      super
      @snap_anchor = nil
    end

    def _refresh
      @snap_anchor = nil
      super
    end

    # -----

    def _snap_ref_point_b(picker = nil)

      if @tool.is_key_shift_down? &&
         @mouse_snap_point.is_a?(Geom::Point3d) &&
         (neighborhood_def = _get_neighborhood_def) &&
         (joinery_def = _get_remove_joinery_def(neighborhood_def))

        snap_anchor = _get_anchors(joinery_def).min { |p1, p2| @mouse_snap_point.distance(p1) <=> @mouse_snap_point.distance(p2) }

      else
        snap_anchor = nil
      end

      # Returns true if changed
      (@snap_anchor != snap_anchor).tap { @snap_anchor = snap_anchor }
    end

    def _preview_join(picker)
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

      super

      # Preview the fittings to remove : red boxes on the picked couple,
      # translucent ones on the placements propagated through the contact graph.
      anchors = {}
      _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

        placement.instance_transformations.each do |instance_transformation|

          picked = placement.picked?(instance_transformation)

          placement.glued_instances.each do |glued_instance|

            t = instance_transformation * glued_instance.transformation

            k_box = Kuix::BoxFillMotif3d.new
            k_box.bounds.copy!(glued_instance.definition.bounds)
            k_box.line_width = 2
            k_box.color = ColorUtils.color_translucent(Kuix::COLOR_RED, picked ? 0.3 : 0.15)
            k_box.on_top = true
            k_box.transformation = t
            @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

            k_box = Kuix::BoxMotif3d.new
            k_box.bounds.copy!(glued_instance.definition.bounds)
            k_box.line_width = 2
            k_box.color = picked ? Kuix::COLOR_RED : ColorUtils.color_translucent(Kuix::COLOR_RED, 0.5)
            k_box.on_top = true
            k_box.transformation = t
            @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

          end

          anchor = ORIGIN.transform(instance_transformation * placement.transformation)
          anchors[anchor.to_a.map { |coord| coord.round(3) }] = true

          if picked

            k_point = _create_floating_points(
              points: anchor,
              style: Kuix::POINT_STYLE_PLUS,
              stroke_color: Kuix::COLOR_BLACK,
              )
            @tool.append_3d(k_point, LAYER_3D_JOIN_PREVIEW)

          end

        end

      end

      count = anchors.length

      if count > 0
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.x_fittings_to_remove', { :count => count }), SmartTool::MESSAGE_TYPE_WARNING)
      else
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.no_fitting_to_remove'), SmartTool::MESSAGE_TYPE_WARNING)
      end

      if @mouse_snap_point.is_a?(Geom::Point3d) && @snap_anchor.is_a?(Geom::Point3d)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@mouse_snap_point)
        k_edge.end.copy!(@snap_anchor)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_SNAP_POINT_PREVIEW)

      end

    end

    # -----

    def _remove_fittings
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

      model = Sketchup.active_model
      model.start_operation('OCL Remove Fittings', true)
      begin

        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|
          placement.glued_instances.each do |glued_instance|
            next if glued_instance.deleted?
            glued_instance.erase!
          end
        end

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

    end

    # -- Propagation --

    # Resolves the fitting placements to remove. Fittings live in shared
    # definitions : erasing one removes it from every instance, so the mating
    # fittings of the parts forming the same dihedral configuration with the
    # other instances must be removed too, walking the contact graph
    # (A -> B -> A' -> B' -> ...). The walk stops on branches where no glued
    # instance exists at the anchor.
    def _get_propagation_def(neighborhood_def, joinery_def)

      signature = _get_propagation_signature(neighborhood_def, joinery_def)
      return @propagation_def if @propagation_def.is_a?(PropagationDef) && @propagation_signature == signature

      line_def = neighborhood_def.neighbor_def.line_def

      seeds = []

      # The glued instance transformation is the fitting frame in the face
      # owner definition space (X axis along the joint axis)
      fn_seed = lambda do |fm, grouped_glued_instances, role|
        grouped_glued_instances.each do |anchor_coords, glued_instances|
          next unless _is_snap_anchor?(Geom::Point3d.new(anchor_coords))
          seeds << PropagationPlacementDef.new(fm.face.parent, fm.face, glued_instances.first.transformation, role, [ fm.transformation ], fm.transformation, glued_instances)
        end
      end

      fn_seed.call(line_def.face_manipulator, joinery_def.grouped_glued_instances_a, :a)
      fn_seed.call(line_def.neighbor_face_manipulator, joinery_def.grouped_glued_instances_b, :b)

      mate_transformation, side_a, side_b = _get_propagation_context(line_def)
      mate_transformation_inverse = mate_transformation.inverse

      placements = _walk_contact_graph(seeds) do |placement, wf, instance_path|

        from_a = placement.role == :a
        nfm, mt_n = _find_mating_fitting(wf * (from_a ? mate_transformation : mate_transformation_inverse), from_a ? side_b : side_a, instance_path)
        next nil if nfm.nil?

        # Only propagate onto anchors where a mating glued instance exists
        glued_instances = _get_glued_instances_anchored_at(nfm.face, mt_n)
        next nil if glued_instances.empty?

        PropagationPlacementDef.new(nfm.face.parent, nfm.face, mt_n, from_a ? :b : :a, nil, nil, glued_instances)
      end

      @propagation_signature = signature
      @propagation_def = PropagationDef.new(placements)
    end

    # Lightweight fingerprint of the removal inputs (picked couple + glued
    # anchors + snap anchor). Used to reuse the (heavy) propagation result while
    # nothing relevant changed.
    def _get_propagation_signature(neighborhood_def, joinery_def)
      instance_a = neighborhood_def.instance_a
      instance_b = neighborhood_def.neighbor_def.instance_b
      sig = [ instance_a.entityID, instance_a.definition.entityID, instance_b.entityID, instance_b.definition.entityID, @snap_anchor ]
      sig.concat(joinery_def.grouped_glued_instances_a.keys)
      sig.concat(joinery_def.grouped_glued_instances_b.keys)
      sig
    end

    # -----

    def _get_anchors(joinery_def)
      (joinery_def.grouped_glued_instances_a.keys + joinery_def.grouped_glued_instances_b.keys).map! { |coords| coords.map! { |coord| coord.round(6) } }
                                                                                               .uniq
                                                                                               .map! { |coords| Geom::Point3d.new(coords) }
    end

    def _is_snap_anchor?(anchor)
      !@snap_anchor.is_a?(Geom::Point3d) || @snap_anchor.distance(anchor).round(3) == 0
    end

    # -----

    def _get_remove_joinery_def(neighborhood_def)
      return nil if neighborhood_def.neighbor_def.nil?

      neighbor_def = neighborhood_def.neighbor_def
      line_def = neighbor_def.line_def

      poly_3d = [ line_def.start_point, line_def.start_point, line_def.end_point ] # Fake flat poly by doubbleling start point

      grouped_glued_instances_a = _get_grouped_glued_instances(line_def.face_manipulator, poly_3d)
      grouped_glued_instances_b = _get_grouped_glued_instances(line_def.neighbor_face_manipulator, poly_3d)

      RemoveJoineryDef.new(
        grouped_glued_instances_a,
        grouped_glued_instances_b
      )
    end

    # Data Structs -----

    RemoveJoineryDef = Struct.new(:grouped_glued_instances_a, :grouped_glued_instances_b)

  end

end