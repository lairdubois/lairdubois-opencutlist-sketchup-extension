module Ladb::OpenCutList

  require_relative '../utils/path_utils'

  class PaintFaceTool

    def initialize

      @add = true

      @unpaint_color = Sketchup::Color.new(255, 255, 255)
      @paint_color = Sketchup.active_model.materials.current ? Sketchup.active_model.materials.current.color.blend(Sketchup::Color.new(255, 255, 255), 0.85) : @unpaint_color

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
    end

    def onLButtonUp(flags, x, y, view)
      _pick_hover_face(x, y, view)
      if @hover_face
        @hover_face.material = @add ? Sketchup.active_model.materials.current : nil
      end
    end

    def onMouseMove(flags, x, y, view)
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

  end

end
