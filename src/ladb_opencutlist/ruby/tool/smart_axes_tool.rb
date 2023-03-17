module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/screen_scale_factor_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../worker/cutlist/cutlist_generate_worker'
  require_relative '../utils/axis_utils'
  require_relative '../utils/transformation_utils'

  class SmartAxesTool < Kuix::KuixTool

    include LayerVisibilityHelper
    include ScreenScaleFactorHelper
    include FaceTrianglesHelper
    include CutlistObserverHelper

    ACTION_NONE = -1
    ACTION_SWAP_LENGTH = 0
    ACTION_SWAP_FRONT = 1

    ACTIONS = [
      ACTION_SWAP_LENGTH,
      ACTION_SWAP_FRONT
    ]

    COLOR_DRAWING = Sketchup::Color.new(255, 255, 255, 255).freeze
    COLOR_DRAWING_AUTO_ORIENTED = Sketchup::Color.new(123, 213, 239, 255).freeze

    @@action = ACTION_SWAP_LENGTH

    def initialize
      super(true, true)

      model = Sketchup.active_model
      if model

        # Create cursors
        @cursor_axis = create_cursor('axes', 4, 7)

      end

    end

    # -- UI stuff --

    def setup_widgets(view)

      @canvas.layout = Kuix::BorderLayout.new

      @unit = [ [ view.vpheight / 150, 10 ].min, _screen_scale(4) ].max

      panel_north = Kuix::Panel.new
      panel_north.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
      panel_north.layout = Kuix::InlineLayout.new(true, @unit, Kuix::Anchor.new(Kuix::Anchor::CENTER_RIGHT))
      panel_north.padding.set_all!(@unit)
      @canvas.append(panel_north)

      panel_south = Kuix::Panel.new
      panel_south.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      panel_south.layout = Kuix::BorderLayout.new
      @canvas.append(panel_south)

      # Help Button

      help_btn = Kuix::Button.new
      help_btn.layout_data = Kuix::StaticLayoutData.new
      help_btn.layout = Kuix::GridLayout.new
      help_btn.border.set_all!(@unit)
      help_btn.padding.set!(@unit, @unit * 4, @unit, @unit * 4)
      help_btn.set_style_attribute(:background_color, Sketchup::Color.new('white'))
      help_btn.set_style_attribute(:background_color, Sketchup::Color.new(200, 200, 200, 255), :active)
      help_btn.set_style_attribute(:background_color, Sketchup::Color.new(200, 200, 200, 255).blend(Sketchup::Color.new('white'), 0.2), :hover)
      help_btn.set_style_attribute(:border_color, Sketchup::Color.new(200, 200, 200, 255), :hover)
      help_btn.append_static_label(Plugin.instance.get_i18n_string("default.help"), @unit * 3)
      help_btn.on(:click) { |button|
        UI.openURL('https://docs.opencutlist.org')  # TODO
      }
      panel_north.append(help_btn)

      # Status panel

      @status = Kuix::Panel.new
      @status.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
      @status.layout = Kuix::InlineLayout.new(true, @unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      @status.padding.set_all!(@unit * 2)
      @status.visible = false
      @status.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 200))
      panel_south.append(@status)

      @status_lbl_1 = Kuix::Label.new
      @status_lbl_1.text_size = @unit * 4
      @status.append(@status_lbl_1)

      actions = Kuix::Panel.new
      actions.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
      actions.layout = Kuix::GridLayout.new(4,1, @unit, @unit)
      actions.padding.set_all!(@unit * 2)
      actions.set_style_attribute(:background_color, Sketchup::Color.new('white'))
      panel_south.append(actions)

      actions_lbl = Kuix::Label.new
      actions_lbl.text = Plugin.instance.get_i18n_string('tool.smart_axes.action').upcase
      actions_lbl.text_size = @unit * 3
      actions_lbl.text_bold = true
      actions.append(actions_lbl)

      @action_buttons = []
      ACTIONS.each { |action|

        actions_btn = Kuix::Button.new
        actions_btn.layout = Kuix::GridLayout.new
        actions_btn.min_size.set_all!(@unit * 10)
        actions_btn.border.set_all!(@unit)
        actions_btn.set_style_attribute(:background_color, Sketchup::Color.new('white'))
        actions_btn.set_style_attribute(:background_color, Sketchup::Color.new(200, 200, 200, 255), :active)
        actions_btn.set_style_attribute(:background_color, Sketchup::Color.new(200, 200, 200, 255).blend(Sketchup::Color.new('white'), 0.2), :hover)
        actions_btn.set_style_attribute(:border_color, Sketchup::Color.new(200, 200, 200, 255), :selected)
        actions_btn.selected = @@action == action
        actions_btn.data = action
        actions_btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_axes.action_#{action}"), @unit * 3)
        actions_btn.on(:click) { |button|
          set_action(action)
        }
        actions.append(actions_btn)

        @action_buttons.push(actions_btn)

      }

    end

    # -- Setters --

    def set_status(text)
      return unless @status && text.is_a?(String)
      @status_lbl_1.text = text
      @status_lbl_1.visible = !text.empty?
      @status.visible = @status_lbl_1.visible?
    end

    def set_action(action)

      @@action = action

      # Update buttons
      if @action_buttons
        @action_buttons.each { |button|
          button.selected = button.data == action
        }
      end

    end

    # -- Events --

    def onActivate(view)
      super

      # Retrive pick helper
      @pick_helper = view.pick_helper

      set_root_cursor(@cursor_axis)

    end

    def onLButtonDown(flags, x, y, view)
      return if super
      @is_down = true
      _handle_mouse_event(x, y, view, :l_button_down)
    end

    def onLButtonUp(flags, x, y, view)
      return if super
      @is_down = false
      _handle_mouse_event(x, y, view, :l_button_up)
    end

    def onMouseMove(flags, x, y, view)
      return if super
      _handle_mouse_event(x, y, view, :move)
    end

    def onMouseLeave(view)
      return if super
    end

    private

    def _reset(view)
      if @picked_path
        set_status('')
        @is_down = false
        @picked_path = nil
        @space.remove_all
        view.invalidate
      end
    end

    def _handle_mouse_event(x, y, view, event = nil)
      if @pick_helper.do_pick(x, y) > 0
        @pick_helper.count.times { |pick_path_index|

          picked_path = @pick_helper.path_at(pick_path_index)
          if picked_path == @picked_path && event == :move
            return  # Previously detected path, stop process to optimize.
          end
          if picked_path && picked_path.last.is_a?(Sketchup::Face)

            @picked_path = picked_path.clone

            picked_part_path = _get_part_path_from_path(picked_path)
            picked_part = picked_path.last
            if picked_part

              part = _blop(picked_part, picked_part_path)
              if part && event == :l_button_up

                definition = view.model.definitions[part.def.definition_id]
                definition_attributes = DefinitionAttributes.new(definition)

                unless definition.nil?

                  ti = nil
                  if @@action == ACTION_SWAP_LENGTH
                    ti = Geom::Transformation.axes(
                      ORIGIN,
                      AxisUtils.flipped?(part.def.size.normals[1], part.def.size.normals[0], part.def.size.normals[2]) ? part.def.size.normals[1].reverse : part.def.size.normals[1],
                      part.def.size.normals[0],
                      part.def.size.normals[2]
                    )
                  elsif @@action == ACTION_SWAP_FRONT
                    ti = Geom::Transformation.axes(
                      ORIGIN,
                      part.def.size.normals[0],
                      AxisUtils.flipped?(part.def.size.normals[0], part.def.size.normals[1], part.def.size.normals[2].reverse) ? part.def.size.normals[1].reverse : part.def.size.normals[1],
                      part.def.size.normals[2].reverse
                    )
                  end
                  unless ti.nil?

                    t = ti.inverse

                    # Start model modification operation
                    view.model.start_operation('OpenCutList - Part Swap', true, false, false)

                    # Transform definition's entities
                    entities = definition.entities
                    entities.transform_entities(t, entities.to_a)

                    # Inverse transform definition's instances
                    definition.instances.each { |instance|
                      instance.transformation *= ti
                    }

                    definition_attributes.orientation_locked_on_axis = true
                    definition_attributes.write_to_attributes

                    # Commit model modification operation
                    view.model.commit_operation

                    _blop(picked_part, picked_part_path)

                  end

                end

              end

              return

            elsif picked_part_path
              puts 'Not a part'
            end

          end

        }
      end
      _reset(view)
      UI.beep if event == :l_button_up
    end

    def _get_part_path_from_path(path)
      part_path = path.to_a
      path.reverse_each { |entity|
        return part_path if entity.is_a?(Sketchup::ComponentInstance) && !entity.definition.behavior.cuts_opening? && !entity.definition.behavior.always_face_camera?
        part_path.pop
      }
    end

    def _blop(picked_part, picked_part_path)

      worker = CutlistGenerateWorker.new({}, picked_part, picked_part_path)
      cutlist = worker.run

      part = nil
      cutlist.groups.each { |group|
        group.parts.each { |p|
          if p.def.definition_id == picked_part.definition.name
            part = p
            break
          end
        }
        break unless part.nil?
      }

      if part

        set_status("#{part.name}#{part.flipped ? ' [Pièce en miroir]' : ''}")

        instance_info = part.def.instance_infos.values.first

        parent_path = picked_part_path.clone
        parent_path.pop
        transformation = TransformationUtils.multiply(PathUtils.get_transformation(parent_path), instance_info.transformation)

        @space.remove_all

        arrow_color = part.auto_oriented ? COLOR_DRAWING_AUTO_ORIENTED : COLOR_DRAWING

        arrow = Kuix::Arrow.new
        arrow.pattern_transformation = part.auto_oriented ? instance_info.size.oriented_transformation : Geom::Transformation.new
        arrow.pattern_transformation *= Geom::Transformation.translation(Geom::Vector3d.new(0.05, 0.05, 0)) * Geom::Transformation.scaling(0.9)
        arrow.transformation = transformation
        arrow.bounds.origin.copy!(instance_info.definition_bounds.min)
        arrow.bounds.size.set!(instance_info.definition_bounds.width, instance_info.definition_bounds.height, instance_info.definition_bounds.depth)
        arrow.color = arrow_color
        arrow.line_width = 3
        arrow.line_stipple = '-'
        @space.append(arrow)

        arrow = Kuix::Arrow.new
        arrow.pattern_transformation = part.auto_oriented ? instance_info.size.oriented_transformation : Geom::Transformation.new
        arrow.pattern_transformation *= Geom::Transformation.translation(Z_AXIS) * Geom::Transformation.translation(Geom::Vector3d.new(0.05, 0.05, 0)) * Geom::Transformation.scaling(0.9)
        arrow.transformation = transformation
        arrow.bounds.origin.copy!(instance_info.definition_bounds.min)
        arrow.bounds.size.set!(instance_info.definition_bounds.width, instance_info.definition_bounds.height, instance_info.definition_bounds.depth)
        arrow.color = arrow_color
        arrow.line_width = 3
        @space.append(arrow)

        box = Kuix::Box.new
        box.transformation = transformation
        box.bounds.origin.copy!(instance_info.definition_bounds.min)
        box.bounds.size.set!(instance_info.definition_bounds.width, instance_info.definition_bounds.height, instance_info.definition_bounds.depth)
        box.color = Sketchup::Color.new(0, 0, 255)
        box.line_width = 1
        box.line_stipple = '-'
        @space.append(box)

      end

      part
    end

  end

end
