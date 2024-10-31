module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../utils/path_utils'
  require_relative '../utils/color_utils'

  class HighlightOverlay < Kuix::KuixOverlay

    OVERLAY_ID = 'ladb_opencutlist.highlight_overlay'

    def initialize(path, text, color = Kuix::COLOR_RED)
      super(OVERLAY_ID, 'Highlight Overlay')

      @drawing_def = CommonDrawingDecompositionWorker.new(path,
         face_for_part: false,
         ignore_surfaces: true,
         ignore_edges: true
      ).run
      if @drawing_def

        view = Sketchup.active_model.active_view

        # 3D

        preview = Kuix::Group.new
        preview.transformation = @drawing_def.transformation
        @space.append(preview)

          # Highlight faces
          mesh = Kuix::Mesh.new
          mesh.add_triangles(@drawing_def.face_manipulators.flat_map { |face_manipulator| face_manipulator.triangles })
          mesh.background_color = ColorUtils.color_translucent(color, 80)
          preview.append(mesh)

          # Box helper
          box = Kuix::BoxMotif.new
          box.bounds.origin.copy!(@drawing_def.faces_bounds.min)
          box.bounds.size.copy!(@drawing_def.faces_bounds)
          box.color = color
          box.line_width = 1
          box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          box.on_top = true
          preview.append(box)

        # 2D

        unless text.nil? || text.empty?

          unit = get_unit(view)

          @canvas.layout = Kuix::StaticLayout.new

          margin = unit * 5
          min_x = margin
          min_y = margin
          max_x = view.vpwidth - margin
          max_y = view.vpheight - margin

          p = view.screen_coords(@drawing_def.faces_bounds.center.transform(@drawing_def.transformation))

          px = [ [ min_x, p.x.to_i ].max, max_x ].min
          py = [ [ min_y, p.y.to_i ].max, max_y ].min

          if px == min_x
            if py == min_y
              anchor_position = Kuix::Anchor::TOP_LEFT
            elsif py == max_y
              anchor_position = Kuix::Anchor::BOTTOM_LEFT
            else
              anchor_position = Kuix::Anchor::LEFT
            end
          elsif px == max_x
            if py == min_y
              anchor_position = Kuix::Anchor::TOP_RIGHT
            elsif py == max_y
              anchor_position = Kuix::Anchor::BOTTOM_RIGHT
            else
              anchor_position = Kuix::Anchor::RIGHT
            end
          else
            if py == min_y
              anchor_position = Kuix::Anchor::TOP
            elsif py == max_y
              anchor_position = Kuix::Anchor::BOTTOM
            else
              anchor_position = Kuix::Anchor::CENTER
            end
          end

          box = Kuix::Panel.new
          box.layout_data = Kuix::StaticLayoutData.new(px, py, -1, -1, Kuix::Anchor.new(anchor_position))
          box.layout = Kuix::GridLayout.new
          box.padding.set!(unit, unit, unit * 0.7, unit)
          box.set_style_attribute(:background_color, color)
          @canvas.append(box)

            lbl = Kuix::Label.new(text)
            lbl.text_size = unit * 3 * get_text_unit_factor
            lbl.text_align = TextAlignLeft
            lbl.set_style_attribute(:color, ColorUtils.color_is_dark?(color) ? Kuix::COLOR_WHITE : Kuix::COLOR_BLACK)
            box.append(lbl)

        end

      end

    end

    def getExtents
      bounds = Geom::BoundingBox.new
      bounds.add(@drawing_def.faces_bounds.min.transform(@drawing_def.transformation))
      bounds.add(@drawing_def.faces_bounds.max.transform(@drawing_def.transformation))
      bounds
    end

    def get_unit(view = nil)
      return @unit unless @unit.nil?
      return 3 if view && Sketchup.active_model.nil?
      view = Sketchup.active_model.active_view if view.nil?
      if view.respond_to?(:device_height)
        vpheight = view.device_height  # SU 2025+
      else
        vpheight = view.vpheight
      end
      if vpheight > 2000
        @unit = 8
      elsif vpheight > 1000
        @unit = 6
      elsif vpheight > 500
        @unit = 4
      else
        @unit = 3
      end
      @unit /= UI.scale_factor(view) if view.respond_to?(:device_height)
      @unit
    end

    def get_text_unit_factor
      case PLUGIN.language
      when 'ar'
        return 1.5
      else
        return 1.0
      end
    end

  end

end