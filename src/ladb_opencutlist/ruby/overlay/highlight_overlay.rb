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
         ignore_edges: true,
         ignore_clines: false
      ).run
      if @drawing_def

        view = Sketchup.active_model.active_view

        # 3D

        k_group = Kuix::Group.new
        k_group.transformation = @drawing_def.transformation
        @space.append(k_group)

          if @drawing_def.face_manipulators.any?

            # Highlight faces
            k_mesh = Kuix::Mesh.new
            k_mesh.add_triangles(@drawing_def.face_manipulators.flat_map { |face_manipulator| face_manipulator.triangles })
            k_mesh.background_color = ColorUtils.color_translucent(color, 80)
            k_group.append(k_mesh)

          end

          if @drawing_def.cline_manipulators.any?

            # Highlight clines
            k_segments = Kuix::Segments.new
            k_segments.add_segments(@drawing_def.cline_manipulators.flat_map { |cline_manipulator| cline_manipulator.segment })
            k_segments.color = ColorUtils.color_translucent(color)
            k_segments.line_width = 2
            k_group.append(k_segments)

          end

          # Box helper
          k_box = Kuix::BoxMotif.new
          k_box.bounds.copy!(@drawing_def.bounds)
          k_box.color = color
          k_box.line_width = 1
          k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          k_box.on_top = true
          k_group.append(k_box)

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

          k_box = Kuix::Panel.new
          k_box.layout_data = Kuix::StaticLayoutData.new(px, py, -1, -1, Kuix::Anchor.new(anchor_position))
          k_box.layout = Kuix::GridLayout.new
          k_box.padding.set!(unit, unit, unit * 0.7, unit)
          k_box.set_style_attribute(:background_color, color)
          @canvas.append(k_box)

            lbl = Kuix::Label.new(text)
            lbl.text_size = unit * 3 * get_text_unit_factor
            lbl.text_align = TextAlignLeft
            lbl.set_style_attribute(:color, ColorUtils.color_is_dark?(color) ? Kuix::COLOR_WHITE : Kuix::COLOR_BLACK)
            k_box.append(lbl)

        end

      end

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