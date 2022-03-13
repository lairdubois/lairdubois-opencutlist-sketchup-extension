module Ladb::OpenCutList

  require_relative '../utils/path_utils'
  require_relative '../helper/screen_scale_factor_helper'
  require_relative '../model/attributes/material_attributes'
  require_relative '../gl/gl_button'
  require_relative '../lib/kuix/kuix'

  class PaintFaceTool

    include ScreenScaleFactorHelper

    COLOR_TEXT = Sketchup::Color.new(0, 0, 0, 255).freeze
    FONT_TEXT = 'Verdana'

    @@current_material = nil

    def initialize

      SKETCHUP_CONSOLE.clear

      model = Sketchup.active_model
      if model

        view = model.active_view

        @add = true

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

        #####

        @kuix = Kuix::KuixEngine.new(view)

        canvas = @kuix.canvas
        canvas.background_color = Sketchup::Color.new(255, 0, 0, 128)
        canvas.border_color = Sketchup::Color.new(128, 128, 128, 128)
        canvas.margin.set(10, 10, 200, 10)
        canvas.border.set(50, 10, 10, 10)
        canvas.padding.set(10, 10, 10, 10)
        canvas.layout = Kuix::GridLayout.new(3, 3)
        canvas.gap.set(10, 10)

        for i in 0..7

          border = rand(50)

          w0 = Kuix::Widget.new('w0')
          w0.background_color = Sketchup::Color.new(rand(255), rand(255), rand(255), 255)
          w0.border_color = Sketchup::Color.new(rand(255), rand(255), rand(255), 255)
          w0.border.set(border, border, border, border)
          canvas.append(w0)
        end

        w0.layout = Kuix::BorderLayout.new
        w0.gap.set(20, 20)

        w1 = Kuix::Label.new('w0')
        w1.text = 'The NORTH'
        w1.text_size = 30
        w1.text_align = TextAlignCenter
        # w1.text_vertical_align = TextVerticalAlignCenter
        w1.color = Sketchup::Color.new(200, 0, 0, 255)
        w1.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
        w1.background_color = Sketchup::Color.new(255, 255, 255, 255)
        w1.border_color = Sketchup::Color.new(0, 0 ,0 , 255)
        w1.border.set(10, 10, 10, 10)
        w1.min_size.set(50, 50)
        w1.margin.set(10, 10, 10, 10)
        w1.padding.set(10, 10, 10, 10)
        w0.append(w1)

        w2 = Kuix::Widget.new('w0')
        w2.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
        w2.background_color = Sketchup::Color.new(255, 255, 255, 255)
        w2.border_color = Sketchup::Color.new(0, 0 , 255, 255)
        w2.border.set(10, 10, 10, 10)
        w2.min_size.set(50, 50)
        w0.append(w2)

        w2 = Kuix::Label.new('w0')
        w2.text = "CENTER !"
        w2.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
        w2.background_color = Sketchup::Color.new(255, 255, 255, 255)
        w2.border_color = Sketchup::Color.new(255, 0 , 255, 255)
        w2.border.set(10, 10, 10, 10)
        w2.min_size.set(50, 50)
        w0.append(w2)

        w2 = Kuix::Label.new('w0')
        w2.text = "EAST !"
        w2.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
        w2.background_color = Sketchup::Color.new(255, 255, 255, 255)
        w2.border_color = Sketchup::Color.new(255, 0 , 128, 255)
        w2.border.set(10, 10, 10, 10)
        w2.min_size.set(100, 50)
        w0.append(w2)

        w2 = Kuix::Widget.new('w0')
        w2.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
        w2.background_color = Sketchup::Color.new(255, 255, 255, 255)
        w2.border_color = Sketchup::Color.new(0, 255 , 255, 255)
        w2.border.set(10, 10, 10, 10)
        w2.min_size.set(50, 50)
        w2.layout = Kuix::GridLayout.new(2, 2)
        w0.append(w2)

        w21 = Kuix::Widget.new('w0')
        w21.background_color = Sketchup::Color.new(255, 255, 255, 255)
        w21.border_color = Sketchup::Color.new(0, 255 , 255, 255)
        w21.border.set(10, 10, 10, 10)
        w21.min_size.set(50, 50)
        w2.append(w21)


        #####

        # Create buttons
        @buttons = []
        @selected_button = nil

        unless @materials.empty?

          button_text_options = {
            color: COLOR_TEXT,
            font: FONT_TEXT,
            size: _screen_scale(Plugin.instance.current_os == :MAC ? 8 : 5),
            align: TextAlignCenter,
            y_offset: Sketchup.version_number >= 22000000 ? _screen_scale(5) : _screen_scale(10)
          }
          button_size = [ _screen_scale(80), view.vpwidth / @materials.length ].min
          button_x = (view.vpwidth - button_size * (@materials.length - 2)) / 2

          @materials.each do |material|
            button = GLButton.new(view, material.name, button_x, button_size, button_size - _screen_scale(10), button_size - _screen_scale(10), button_text_options, material.color) do |button, flags, x, y, view|
              @selected_button.is_selected = false if @selected_button
              @selected_button = button
              @selected_button.is_selected = true
              @@current_material = material
              _update_paint_color
            end
            if material == @@current_material
              @selected_button = button
              @selected_button.is_selected = true
            end
            @buttons.push(button)
            button_x += button_size
          end

        end

      end

    end

    # -- Tool stuff --

    def activate
      model = Sketchup.active_model
      if model

        # Invalidate view
        model.active_view.invalidate

        # Retrive pick helper
        @pick_helper = Sketchup.active_model.active_view.pick_helper

      end

      UI.set_cursor(@add ? @cursor_paint_id : @cursor_unpaint_id)

    end

    def deactivate(view)
      onQuit(view)
    end

    def suspend(view)
      view.invalidate
    end

    def resume(view)
      view.invalidate
    end

    def draw(view)

      if @triangles
        view.drawing_color = @add ? @paint_color : @unpaint_color
        view.draw(GL_TRIANGLES, @triangles)
      end

      # Draw buttons (only if Sketchup > 2016)
      if Sketchup.version_number >= 16000000
        @buttons.each { |button|
          button.draw(view)
        }
      end

      @kuix.draw(view)

    end

    def getExtents
      Sketchup.active_model.bounds
    end

    # -- Events --

    def onSetCursor
      UI.set_cursor(@add ? @cursor_paint_id : @cursor_unpaint_id)
    end

    def onKeyDown(key, repeat, flags, view)
      if key == COPY_MODIFIER_KEY
        @add = false
        view.invalidate
        UI.set_cursor(@cursor_unpaint_id)
      end
    end

    def onKeyUp(key, repeat, flags, view)
      if key == COPY_MODIFIER_KEY
        @add = true
        view.invalidate
        UI.set_cursor(@cursor_paint_id)
      end
    end

    def onLButtonDown(flags, x, y, view)
      @buttons.each { |button|
        if button.onLButtonDown(flags, x, y, view)
          return
        end
      }
    end

    def onLButtonUp(flags, x, y, view)
      @buttons.each { |button|
        if button.onLButtonUp(flags, x, y, view)
          return
        end
      }
      _pick_hover_face(x, y, view)
      if @hover_face
        @hover_face.material = @add ? @@current_material : nil
      end
    end

    def onMouseMove(flags, x, y, view)
      @buttons.each { |button|
        if button.onMouseMove(flags, x, y, view)
          return
        end
      }
      _pick_hover_face(x, y, view)
    end

    def onMouseLeave(view)
      _reset(view)
    end

    def onCancel(flag, view)
      _quit(view)
    end

    def onQuit(view)

      # Invalidate view
      view.invalidate

    end

    def onViewChanged(view)
      puts "onViewChanged: #{view}"
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
