module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../utils/path_utils'
  require_relative '../helper/screen_scale_factor_helper'
  require_relative '../model/attributes/material_attributes'

  class PaintFaceTool < Kuix::KuixTool

    include ScreenScaleFactorHelper

    COLOR_TEXT = Sketchup::Color.new(0, 0, 0, 255).freeze
    FONT_TEXT = 'Verdana'

    COLOR_MATERIAL_TYPES = {
      1 => Sketchup::Color.new(76, 175, 80, 255).freeze,
      2 => Sketchup::Color.new(237, 162, 0, 255).freeze,
      3 => Sketchup::Color.new(245, 89, 172, 255).freeze,
      4 => Sketchup::Color.new(102, 142, 238, 255).freeze,
      5 => Sketchup::Color.new(0, 0, 0, 255).freeze
    }

    @@current_material = nil

    def initialize
      super

      model = Sketchup.active_model
      if model

        @add = true
        @selected_button = nil

        @materials = []
        model.materials.each do |material|
          # material_attributes = MaterialAttributes.new(material)
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
        @cursor_paint_id = create_cursor('paint', 7, 25)
        @cursor_unpaint_id = create_cursor('unpaint', 7, 25)

      end

    end

    def setup_widgets(view)

      @canvas.layout = Kuix::BorderLayout.new

      unit = [ [ view.vpheight / 150, 10 ].min, 5 ].max

      panel = Kuix::Widget.new
      panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      panel.layout = Kuix::BorderLayout.new
      @canvas.append(panel)

        # Status label

        lbl_status = Kuix::Label.new
        lbl_status.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
        lbl_status.text_size = unit * 3
        lbl_status.visible = false
        lbl_status.padding.set_all(unit)
        lbl_status.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 128))
        panel.append(lbl_status)

        # Buttons panel

        btns = Kuix::Widget.new
        btns.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
        btns.layout = Kuix::GridLayout.new([ @materials.length, 10 ].min, (@materials.length / 10.0).ceil, unit / 2, unit / 2)
        btns.padding.set_all(unit)
        btns.set_style_attribute(:background_color, Sketchup::Color.new('white'))
        panel.append(btns)

        @materials.each do |material|

          material_attributes = MaterialAttributes.new(material)
          material_color_is_dark = (0.2126 * material.color.red + 0.7152 * material.color.green + 0.0722 * material.color.blue) <= 128

          btn = Kuix::Button.new
          btn.min_size.set(unit * 20, unit * 10)
          btn.border.set_all(unit)
          btn.set_style_attribute(:background_color, material.color)
          btn.set_style_attribute(:background_color, material.color.blend(Sketchup::Color.new(material_color_is_dark ? 'white' : 'black'), 0.7), :active)
          btn.set_style_attribute(:border_color, material.color.blend(Sketchup::Color.new(material_color_is_dark ? 'white' : 'black'), 0.7), :hover)
          btn.set_style_attribute(:border_color, Sketchup::Color.new('blue'), :selected)
          btn.layout = Kuix::StaticLayout.new
          btn.on(:click) { |button|
            @selected_button.selected = false if @selected_button
            @selected_button = button
            @selected_button.selected = true
            @@current_material = material
            _update_paint_color
          }
          btn.on(:enter) { |button|
            lbl_status.text = material.name + (material_attributes.type > 0 ? " (#{Plugin.instance.get_i18n_string("tab.materials.type_#{material_attributes.type}")})" : '')
            lbl_status.visible = true
          }
          btn.on(:leave) { |button|
            lbl_status.text = ''
            lbl_status.visible = false
          }
          btns.append(btn)

            btn_lbl = Kuix::Label.new
            btn_lbl.layout_data = Kuix::StaticLayoutData.new(0, 0, 1.0, 1.0)
            btn_lbl.text = material.name.length > 12 ? "#{material.name[0..11]}..." : material.name
            btn_lbl.text_size = unit * 3
            if material_color_is_dark
              btn_lbl.set_style_attribute(:color, Sketchup::Color.new('white'))
            end
            btn.append(btn_lbl)

            if material_attributes.type > 0

              btn_overlay = Kuix::Widget.new
              btn_overlay.layout_data = Kuix::StaticLayoutData.new(1.0, 0, unit * 2, unit * 2, Kuix::Anchor.new(Kuix::Anchor::TOP_RIGHT))
              btn_overlay.set_style_attribute(:background_color, COLOR_MATERIAL_TYPES[material_attributes.type])
              btn_overlay.set_style_attribute(:border_color, Sketchup::Color.new('white'))
              btn_overlay.border.set(0, 0, unit / 2, unit / 2)
              btn_overlay.hittable = false
              btn.append(btn_overlay)

            end

          if material == @@current_material
            @selected_button = btn
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

      # Set startup cursor
      set_root_cursor(@add ? @cursor_paint_id : @cursor_unpaint_id)

      # Retrive pick helper
      @pick_helper = view.pick_helper

    end

    def onKeyDown(key, repeat, flags, view)
      return if super
      if key == COPY_MODIFIER_KEY
        @add = false
        set_root_cursor(@cursor_unpaint_id)
        view.invalidate
      end
    end

    def onKeyUp(key, repeat, flags, view)
      return if super
      if key == COPY_MODIFIER_KEY
        @add = true
        set_root_cursor(@cursor_paint_id)
        view.invalidate
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
