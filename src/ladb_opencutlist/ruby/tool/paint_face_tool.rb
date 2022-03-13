module Ladb::OpenCutList

  require_relative '../utils/path_utils'
  require_relative '../helper/screen_scale_factor_helper'
  require_relative '../model/attributes/material_attributes'
  require_relative '../gl/gl_button'
  require_relative '../lib/kuix/kuix'

  class PaintFaceTool < Kuix::KuixTool

    include ScreenScaleFactorHelper

    COLOR_TEXT = Sketchup::Color.new(0, 0, 0, 255).freeze
    FONT_TEXT = 'Verdana'

    @@current_material = nil

    def initialize
      super

      model = Sketchup.active_model
      if model

        @add = true
        @selected_button = nil

        @materials = []
        model.materials.each do |material|
          material_attributes = MaterialAttributes.new(material)
          # if material_attributes.type == MaterialAttributes::TYPE_EDGE  # Filter on EDGE type
            @materials.push(material)
            @@current_material = material if @@current_material.nil? && material == model.materials.current
          # end
        end
        unless @@current_material
          @@current_material = @materials.first
        end

        @materials.sort_by! { |material| [ material.name ] }

        @unpaint_color = Sketchup::Color.new(255, 255, 255)
        _update_paint_color

        # Create cursors
        @cursor_paint_id = nil
        cursor_path = File.join(__dir__, '..', '..', 'img', 'cursor-paint.pdf')
        if cursor_path
          @cursor_paint_id = UI.create_cursor(cursor_path, 7, 25)
        end
        @cursor_unpaint_id = nil
        cursor_path = File.join(__dir__, '..', '..', 'img', 'cursor-unpaint.pdf')
        if cursor_path
          @cursor_unpaint_id = UI.create_cursor(cursor_path, 7, 25)
        end

      end

    end

    def setup_widgets(view)

      @canvas.layout = Kuix::BorderLayout.new

      unit = [ view.vpwidth, view.vpheight ].max / 400

      buttons = Kuix::Widget.new
      buttons.padding.set(unit, unit, unit, unit)
      buttons.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      buttons.layout = Kuix::GridLayout.new([ @materials.length, 10 ].min, (@materials.length / 10.0).ceil, unit, unit)
      buttons.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 128))
      @canvas.append(buttons)

      @materials.each do |material|

        button = Kuix::Button.new('') { |button|
          @selected_button.selected = false if @selected_button
          @selected_button = button
          @selected_button.selected = true
          @@current_material = material
          _update_paint_color
        }
        button.min_size.set(0, unit * 10)
        button.border.set(unit, unit, unit, unit)
        button.set_style_attribute(:background_color, material.color)
        button.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 200), :active)
        button.set_style_attribute(:border_color, Sketchup::Color.new(0, 0, 0, 100), :hover)
        button.set_style_attribute(:border_color, Sketchup::Color.new(0, 0, 255, 255), :selected)
        button.layout = Kuix::GridLayout.new
        buttons.append(button)

        label = Kuix::Label.new
        label.text = material.name
        label.text_size = unit * 3
        button.append(label)

        if material == @@current_material
          @selected_button = button
          @selected_button.selected = true
        end

      end


    end

    # -- Tool stuff --

    def deactivate(view)
      super
      onQuit(view)
    end

    def draw(view)

      if @triangles
        view.drawing_color = @add ? @paint_color : @unpaint_color
        view.draw(GL_TRIANGLES, @triangles)
      end

      super
    end

    # -- Events --

    def onActivate(view)
      super

      # Retrive pick helper
      @pick_helper = view.pick_helper

      # Set startup cursor
      UI.set_cursor(@add ? @cursor_paint_id : @cursor_unpaint_id)

    end

    def onSetCursor
      UI.set_cursor(@add ? @cursor_paint_id : @cursor_unpaint_id)
    end

    def onKeyDown(key, repeat, flags, view)
      return if super
      if key == COPY_MODIFIER_KEY
        @add = false
        view.invalidate
        UI.set_cursor(@cursor_unpaint_id)
      end
    end

    def onKeyUp(key, repeat, flags, view)
      return if super
      if key == COPY_MODIFIER_KEY
        @add = true
        view.invalidate
        UI.set_cursor(@cursor_paint_id)
      end
    end

    def onLButtonUp(flags, x, y, view)
      return if super
      _pick_hover_face(x, y, view)
      if @hover_face
        @hover_face.material = @add ? @@current_material : nil
      end
    end

    def onMouseMove(flags, x, y, view)
      if super
        _reset(view)
        return
      end
      _pick_hover_face(x, y, view)
    end

    def onMouseLeave(view)
      return if super
      _reset(view)
    end

    def onQuit(view)

      # Invalidate view
      view.invalidate

    end

    private

    def _reset(view)
      if @hover_face
        @hover_face = nil
        @triangles = nil
        view.invalidate
      end
    end

    def _quit(view)

      # Unselect tool
      view.model.select_tool(nil)  # Desactivate the tool on click

    end

    def _get_color_from_path(path)
      entity = path.last
      color = nil
      if entity
        if entity.material
          color = entity.material.color
        elsif path.length > 0
          color = _get_color_from_path(path.slice(0, path.length - 1))
        end
      end
      unless color
        color = Sketchup::Color.new(255, 255, 255)
      end
      color
    end

    def _pick_hover_face(x, y, view)
      if @pick_helper.do_pick(x, y) > 0

        @pick_helper.count.times { |pick_path_index|

          pick_path = @pick_helper.path_at(pick_path_index)
          if pick_path == @hover_pick_path
            return  # Previously detected path, stop process to optimize.
          end
          if pick_path && pick_path.last && pick_path.last.is_a?(Sketchup::Face)

            return if pick_path.last == @hover_face

            @hover_face = pick_path.last
            @unpaint_color = _get_color_from_path(pick_path.slice(0, pick_path.length - 1))
            @triangles = _compute_face_triangles(view, pick_path.last, PathUtils::get_transformation(pick_path))

            view.invalidate
            return

          end

        }
      end
      _reset(view)
    end

    def _offset_toward_camera(view, points)
      offset_direction = view.camera.direction.reverse!
      points.map { |point|
        point = point.position if point.respond_to?(:position)
        # Model.pixels_to_model converts argument to integers.
        size = view.pixels_to_model(2, point) * 0.01
        point.offset(offset_direction, size)
      }
    end

    def _transform_points(points, transformation)
      return false if transformation.nil?
      points.each { |point| point.transform!(transformation) }
      true
    end

    def _compute_face_triangles(view, face, transformation = nil)

      # Thank you @thomthom for this piece of code ;)

      if face.deleted?
        return false
      end

      mesh = face.mesh(0) # POLYGON_MESH_POINTS
      points = mesh.points

      _offset_toward_camera(view, points)
      _transform_points(points, transformation)

      triangles = []
      mesh.polygons.each { |polygon|
        polygon.each { |index|
          # Indicies start at 1 and can be negative to indicate edge smoothing.
          # Must take this into account when looking up the points in our array.
          triangles << points[index.abs - 1]
        }
      }

      triangles
    end

    def _update_paint_color
      begin
        @paint_color = @@current_material ? @@current_material.color.blend(Sketchup::Color.new(255, 255, 255), 0.85) : @unpaint_color
      rescue
        @paint_color = @unpaint_color
      end
    end

  end

end
