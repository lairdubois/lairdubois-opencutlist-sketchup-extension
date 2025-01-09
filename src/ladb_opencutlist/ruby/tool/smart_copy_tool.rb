module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/geometrix/finder/circle_finder'
  require_relative '../lib/fiddle/clippy/clippy'
  require_relative '../manipulator/vertex_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/plane_manipulator'
  require_relative '../manipulator/cline_manipulator'
  require_relative '../helper/entities_helper'
  require_relative '../helper/user_text_helper'
  require_relative '../worker/common/common_drawing_decomposition_worker'

  class SmartCopyTool < SmartTool

    ACTION_COPY_MOVE = 1
    ACTION_COPY_ARRAY = 2
    ACTION_COPY_ALONG = 3

    ACTIONS = [
      {
        :action => ACTION_COPY_MOVE,
      },
      {
        :action => ACTION_COPY_ARRAY,
      },
      {
        :action => ACTION_COPY_ALONG,
      }
    ].freeze

    # -----

    attr_reader :cursor_move, :cursor_move_copy

    def initialize
      super

      # Create cursors
      @cursor_move = create_cursor('move', 16, 16)
      @cursor_move_copy = create_cursor('move-copy', 16, 16)

    end

    def get_stripped_name
      'copy'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_COPY_MOVE, ACTION_COPY_ARRAY, ACTION_COPY_ALONG
          return @cursor_move_copy
      end

      super
    end

    def get_action_options_modal?(action)
      false
    end

    def get_action_option_toggle?(action, option_group, option)
      false
    end

    def get_action_option_btn_child(action, option_group, option)
      super
    end

    # -- Events --

    def onActivate(view)

      # Clear current selection
      Sketchup.active_model.selection.clear if Sketchup.active_model

      super
    end

    def onActionChanged(action)

      case action
      when ACTION_COPY_MOVE
        set_action_handler(SmartCopyMoveActionHandler.new(self))
      when ACTION_COPY_ARRAY
        set_action_handler(SmartCopyArrayActionHandler.new(self))
      when ACTION_COPY_ALONG
        set_action_handler(SmartCopyAlongActionHandler.new(self))
      end

      super

      refresh

    end

    def onViewChanged(view)
      super
      refresh
    end

  end

  # -----

  class SmartCopyActionHandler < SmartActionHandler

    include UserTextHelper
    include SmartActionHandlerPartHelper

    STATE_SELECT = 0
    STATE_COPY = 1

    def initialize(action, tool, action_handler = nil)
      super

      @mouse_ip = SmartInputPoint.new(@tool)

      @mouse_snap_point = nil

      @picked_copy_first_point = nil
      @picked_copy_last_point = nil

      set_state(STATE_SELECT)

    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SELECT
        return @tool.cursor_select
      when STATE_COPY
        return @tool.cursor_move_copy
      end

      super
    end

    def get_state_picker(state)

      case state
      when STATE_SELECT
        return SmartPicker.new(tool: @tool, pick_point: true)
      end

      super
    end

    def get_state_status(state)
      super
    end

    def get_state_vcb_label(state)
      super
    end

    # -----

    def onMouseMove(flags, x, y, view)
      super

      if @state == STATE_SELECT

        _pick_part(@picker, view)

        if @active_part_entity_path.is_a?(Array) && @active_part_entity_path.length > 1

          parent = @active_part_entity_path[-2]
          parent_transformation = PathUtils.get_transformation(@active_part_entity_path[0...-2], IDENTITY)

          k_box = Kuix::BoxMotif.new
          k_box.bounds.copy!(parent.bounds)
          k_box.line_width = 1
          k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_box.transformation = parent_transformation
          @tool.append_3d(k_box)

        end

      elsif @state == STATE_COPY

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_3d(1)

        _snap_copy_point(flags, x, y, view)
        _preview_copy(view)

      end

      view.tooltip = @mouse_ip.tooltip
      view.invalidate

    end

    def onMouseLeave(view)
      @tool.remove_all_2d
      @tool.remove_all_3d
      @mouse_ip.clear
      view.tooltip = ''
      super
    end

    def onLButtonUp(flags, x, y, view)

      if @state == STATE_SELECT

        if @active_part_entity_path.nil?
          UI.beep
          return true
        end

        @definition = @active_part_entity_path.last.definition
        @drawing_def = CommonDrawingDecompositionWorker.new(@active_part_entity_path,
                                                            ignore_surfaces: true,
                                                            ignore_faces: true,
                                                            ignore_edges: false,
                                                            ignore_soft_edges: false,
                                                            ignore_clines: false
        ).run

        @picked_copy_first_point = @picker.picked_point

        set_state(STATE_COPY)
        _refresh
      elsif @state == STATE_COPY
        @picked_copy_last_point = @mouse_snap_point
        _copy_entity
        _restart
      end

    end

    # -----

    def draw(view)
      super
      @mouse_ip.draw(view) if @mouse_ip.valid?
    end

    def getExtents
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)

        min = drawing_def.bounds.min.transform(drawing_def.transformation)
        max = drawing_def.bounds.max.transform(drawing_def.transformation)

        bounds = Geom::BoundingBox.new
        bounds.add(min)
        bounds.add(max)

        ps = @picked_copy_first_point
        pe = @picked_copy_last_point.nil? ? @mouse_snap_point : @picked_copy_last_point

        unless ps.nil? || pe.nil?

          v = ps.vector_to(pe)
          bounds.add(min.offset(v))
          bounds.add(max.offset(v))

        end

        bounds
      end
    end

    # -----

    def _reset
      @mouse_ip.clear
      @mouse_snap_point = nil
      @picked_copy_first_point = nil
      @picked_copy_last_point = nil
      super
      set_state(STATE_SELECT)
    end

    # -----

    def _snap_copy_point(flags, x, y, view)

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _preview_copy(view)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      ps = @picked_copy_first_point
      pe = @mouse_snap_point
      v = ps.vector_to(pe)

      segments = []
      segments += drawing_def.cline_manipulators.map { |manipulator| manipulator.segment }.flatten(1)
      segments += drawing_def.edge_manipulators.map { |manipulator| manipulator.segment }.flatten(1)
      segments += drawing_def.curve_manipulators.map { |manipulator| manipulator.segments }.flatten(1)

      mt = Geom::Transformation.translation(v)

      k_segments = Kuix::Segments.new
      k_segments.add_segments(segments)
      k_segments.line_width = 1.5
      k_segments.color = Kuix::COLOR_BLACK
      k_segments.transformation = mt * drawing_def.transformation
      @tool.append_3d(k_segments, 1)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(ps)
      k_line.end.copy!(pe)
      k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_line.color = Kuix::COLOR_MEDIUM_GREY
      k_line.on_top = true
      @tool.append_3d(k_line, 1)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(ps)
      k_line.end.copy!(pe)
      k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_line.color = _get_vector_color(v)
      @tool.append_3d(k_line, 1)

    end

    # -----

    def _copy_entity(operator_1 = '*', number_1 = 1, operator_2 = '*', number_2 = 1)
      return if @definition.nil? || !@drawing_def.is_a?(DrawingDef)

      ps = @picked_copy_first_point
      pe = @picked_copy_last_point
      v = ps.vector_to(pe)

      model = Sketchup.active_model
      model.start_operation('Copy Part', true)

      if operator_1 == '/'
        ux = v.x / number_1
        uy = v.y / number_1
        uz = v.z / number_1
      else
        ux = v.x
        uy = v.y
        uz = v.z
      end

      if @active_part_entity_path.one?
        entities = model.entities
        # t = @drawing_def.transformation
      else
        entities = @active_part_entity_path[-2].definition.entities
        # t = @active_part_entity_path[-1].transformation
      end
      (1..number_1).each do |i|
        entities.add_instance(@definition, Geom::Transformation.translation(Geom::Vector3d.new(ux * i, uy * i, uz * i)) * @active_part_entity_path[-1].transformation)
      end

      model.commit_operation

    end

  end

  class SmartCopyMoveActionHandler < SmartCopyActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartDrawTool::ACTION_COPY_MOVE, tool, action_handler)
    end

  end

  class SmartCopyArrayActionHandler < SmartCopyActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartDrawTool::ACTION_COPY_ARRAY, tool, action_handler)
    end

  end

  class SmartCopyAlongActionHandler < SmartCopyActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartDrawTool::ACTION_COPY_ALONG, tool, action_handler)
    end

  end

end