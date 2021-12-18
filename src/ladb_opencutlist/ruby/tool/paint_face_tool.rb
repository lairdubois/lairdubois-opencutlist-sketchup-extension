module Ladb::OpenCutList

  require_relative '../utils/path_utils'

  class PaintFaceTool

    def initialize

      @cursor_id = nil
      cursor_path = File.join(__dir__, '..', '..', 'img', 'cursor-highlight.png')
      if cursor_path
        @cursor_id = UI.create_cursor(cursor_path, 0, 0)
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
        view.drawing_color = Sketchup.active_model.materials.current.color if Sketchup.active_model.materials.current
        view.draw(GL_TRIANGLES, @triangles)
      end
    end

    def getExtents
      Sketchup.active_model.bounds
    end

    # -- Events --

    def onSetCursor
      UI.set_cursor(@cursor_id)
    end

    def onLButtonDown(flags, x, y, view)
    end

    def onLButtonUp(flags, x, y, view)
      _pick_hover_face(x, y, view)
      if @hover_face
        @hover_face.material = flags & CONSTRAIN_MODIFIER_MASK != 0 ? nil : Sketchup.active_model.materials.current
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

    def _pick_hover_face(x, y, view)
      if @pick_helper.do_pick(x, y) > 0

        @pick_helper.count.times { |pick_path_index|

          pick_path = @pick_helper.path_at(pick_path_index)
          if pick_path == @hover_pick_path
            return  # Previously detected path, stop process to optimize.
          end
          if pick_path && pick_path.last && pick_path.last.is_a?(Sketchup::Face)

            @hover_face = pick_path.last
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
