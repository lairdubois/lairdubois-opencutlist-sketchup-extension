module Ladb::OpenCutList

  require_relative '../../lib/rubyzip/zip'
  require_relative '../../plugin'
  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../utils/dimension_utils'

  class CutlistLayoutToLayoutWorker

    include LayerVisibilityHelper
    include SanitizerHelper

    def initialize(settings, cutlist)

      @parts_infos = settings.fetch('parts_infos', nil)
      @pins_infos = settings.fetch('pins_infos', nil)
      @target_group_id = settings.fetch('target_group_id', nil)

      @generated_at = settings.fetch('generated_at', '')

      @page_width = settings.fetch('page_width', 0).to_l
      @page_height = settings.fetch('page_height', 0).to_l
      @page_header = settings.fetch('page_header', false)
      @parts_colored = settings.fetch('parts_colored', false)
      @parts_opacity = settings.fetch('parts_opacity', 1)
      @pins_hidden = settings.fetch('pins_hidden', false)
      @camera_view = Geom::Vector3d.new(settings.fetch('camera_view', nil))
      @camera_zoom = settings.fetch('camera_zoom', 1)
      @camera_target = Geom::Point3d.new(settings.fetch('camera_target', nil))
      @exploded_model_radius =settings.fetch('exploded_model_radius', 1)

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ [ 'core.error.feature_unavailable', { :version => 2018 } ] ] } if Sketchup.version_number < 1800000000
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      return { :errors => [ 'tab.cutlist.layout.error.no_part' ] } if @parts_infos.empty?

      # Retrieve target group
      target_group = @cutlist.get_group(@target_group_id)

      # Base document name
      doc_name = "#{@cutlist.model_name.empty? ? File.basename(@cutlist.filename, '.skp') : @cutlist.model_name}#{@cutlist.page_name.empty? ? '' : " - #{@cutlist.page_name}"}#{@cutlist.model_active_path.nil? || @cutlist.model_active_path.empty? ? '' : " - #{@cutlist.model_active_path.join('/')}"}#{target_group && target_group.material_type != MaterialAttributes::TYPE_UNKNOWN ? " - #{target_group.material_name} #{target_group.std_dimension}" : ''}"

      # Ask for layout file path
      layout_path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export.title'), @cutlist.dir, "#{_sanitize_filename(doc_name)}.layout")
      if layout_path

        # Force "layout" file extension
        unless layout_path.end_with?('.layout')
          layout_path = layout_path + '.layout'
        end

        # Start model modification operation
        model.start_operation('OCL Export To Layout', true, false, true)

        # CREATE SKP FILE

        materials = model.materials
        definitions = model.definitions
        styles = model.styles

        tmp_definition = definitions.add("export-#{Time.new.to_i}")

        skp_dir = File.join(Plugin.instance.temp_dir, 'skp')
        Dir.mkdir(skp_dir) unless Dir.exist?(skp_dir)
        skp_path = File.join(skp_dir, "#{tmp_definition.guid}.skp")
        File.delete(skp_path) if File.exist?(skp_path)

        # Iterate on parts
        @parts_infos.each do |part_info|

          # Retrieve part
          part = @cutlist.get_real_parts([ part_info['id'] ]).first

          # Convert three matrix to transformation
          transformation = Geom::Transformation.new(part_info['matrix'])

          # Retrieve part's material and definition
          material = materials[part.material_name]
          definition = definitions[part.definition_id]

          # Draw part in tmp definition
          _draw_part(tmp_definition, part, definition, transformation, @parts_colored && material ? material : nil)

        end

        view = model.active_view
        camera = view.camera
        eye = camera.eye
        target = camera.target
        up = camera.up
        perspective = camera.perspective?
        model_transparency = model.rendering_options["ModelTransparency"]

        # Workaround to set camera in Layout file : briefly change current model's camera
        camera.perspective = false
        camera.set(Geom::Point3d.new(
          @camera_view.x * @exploded_model_radius + @camera_target.x,
          @camera_view.y * @exploded_model_radius + @camera_target.y,
          @camera_view.z * @exploded_model_radius + @camera_target.z
        ), @camera_target, @camera_view.parallel?(Z_AXIS) ? Y_AXIS : Z_AXIS)

        # Add style
        selected_style = styles.selected_style
        styles.add_style(File.join(PLUGIN_DIR, 'style', "ocl_layout_#{@parts_colored ? 'colored' : 'monochrome'}_#{@parts_opacity == 1 ? 'opaque' : 'translucent'}.style"), true)

        # Save tmp definition in skp file
        skp_success = tmp_definition.save_as(skp_path) && File.exist?(skp_path)

        # Restore model's style
        styles.selected_style = selected_style

        # Restore model's camera
        camera.perspective = perspective
        camera.set(eye, target, up)

        # Restore model's transparency
        model.rendering_options["ModelTransparency"] = model_transparency

        # Remove tmp definition
        model.definitions.remove(tmp_definition)

        # Commit model modification operation
        model.commit_operation

        return { :errors => [ 'tab.cutlist.layout.error.failed_to_save_as_skp' ] } unless skp_success

        # CREATE LAYOUT FILE

        begin

          doc = Layout::Document.new

          page_width = [ 200, [ 1, @page_width ].max ].min     # Layout width limits [0, 200]
          page_height = [ 200, [ 1, @page_height ].max ].min   # Layout height limits [1, 200]
          page_top_margin = 0.25
          page_right_margin = 0.25
          page_bottom_margin = 0.25
          page_left_margin = 0.25

          # Set document's page infos
          page_info = doc.page_info
          page_info.width = page_width
          page_info.height = page_height
          page_info.top_margin = page_top_margin
          page_info.right_margin = page_right_margin
          page_info.bottom_margin = page_bottom_margin
          page_info.left_margin = page_left_margin

          # Set document's units and precision
          case DimensionUtils.instance.length_unit
          when DimensionUtils::INCHES
            if DimensionUtils.instance.length_format == DimensionUtils::FRACTIONAL
              doc.units = Layout::Document::FRACTIONAL_INCHES
            else
              doc.units = Layout::Document::DECIMAL_INCHES
            end
          when DimensionUtils::FEET
            doc.units = Layout::Document::DECIMAL_FEET
          when DimensionUtils::MILLIMETER
            doc.units = Layout::Document::DECIMAL_MILLIMETERS
          when DimensionUtils::CENTIMETER
            doc.units = Layout::Document::DECIMAL_CENTIMETERS
          when DimensionUtils::METER
            doc.units = Layout::Document::DECIMAL_METERS
          end
          doc.precision = _to_layout_length_precision(DimensionUtils.instance.length_precision)

          page = doc.pages.first
          layer = doc.layers.first

          # Set page name
          page.name = doc_name

          # Set auto text definitions
          doc.auto_text_definitions.add('OpenCutListGeneratedAt', Layout::AutoTextDefinition::TYPE_CUSTOM_TEXT).custom_text = @generated_at
          doc.auto_text_definitions.add('OpenCutListLengthUnit', Layout::AutoTextDefinition::TYPE_CUSTOM_TEXT).custom_text = Plugin.instance.get_i18n_string("default.unit_#{DimensionUtils.instance.length_unit}")
          doc.auto_text_definitions.add('OpenCutListScale', Layout::AutoTextDefinition::TYPE_CUSTOM_TEXT).custom_text = _camera_zoom_to_scale(@camera_zoom)
          doc.auto_text_definitions.add('OpenCutListModelDescription', Layout::AutoTextDefinition::TYPE_CUSTOM_TEXT).custom_text = @cutlist.model_description
          doc.auto_text_definitions.add('OpenCutListPageDescription', Layout::AutoTextDefinition::TYPE_CUSTOM_TEXT).custom_text = @cutlist.page_description

          # Add header
          current_y = page_top_margin
          if @page_header

            gutter = 0.1
            font_family = 'Verdana'

            draw_text = _add_formated_text(doc, layer, page, Plugin.instance.get_i18n_string('tab.cutlist.layout.title'), Geom::Point2d.new(page_left_margin, current_y), Layout::FormattedText::ANCHOR_TYPE_TOP_LEFT, { :font_family => font_family, :font_size => 18, :text_alignment => Layout::Style::ALIGN_LEFT })
            current_y = draw_text.drawing_bounds.lower_left.y

            _add_formated_text(doc, layer, page, '<OpenCutListGeneratedAt>  |  <OpenCutListLengthUnit>  |  <OpenCutListScale>', Geom::Point2d.new(page_width - page_right_margin, current_y), Layout::FormattedText::ANCHOR_TYPE_BOTTOM_RIGHT, { :font_family => font_family, :font_size => 10, :text_alignment => Layout::Style::ALIGN_RIGHT })

            name_text = _add_formated_text(doc, layer, page, '<PageName>', Geom::Point2d.new(page_width / 2, current_y + gutter * 2), Layout::FormattedText::ANCHOR_TYPE_TOP_CENTER, { :font_family => font_family, :font_size => 15, :text_alignment => Layout::Style::ALIGN_CENTER })
            current_y = name_text.drawing_bounds.lower_left.y

            unless @cutlist.model_description.empty?
              model_description_text = _add_formated_text(doc, layer, page, '<OpenCutListModelDescription>', Geom::Point2d.new(page_width / 2, current_y), Layout::FormattedText::ANCHOR_TYPE_TOP_CENTER, { :font_family => font_family, :font_size => 9, :text_alignment => Layout::Style::ALIGN_CENTER })
              current_y = model_description_text.drawing_bounds.lower_left.y
            end

            unless @cutlist.page_description.empty?
              page_description_text = _add_formated_text(doc, layer, page, '<OpenCutListPageDescription>', Geom::Point2d.new(page_width / 2, current_y), Layout::FormattedText::ANCHOR_TYPE_TOP_CENTER, { :font_family => font_family, :font_size => 9, :text_alignment => Layout::Style::ALIGN_CENTER })
              current_y = page_description_text.drawing_bounds.lower_left.y
            end

            rectangle = _add_rectangle(doc, layer, page, Geom::Point2d.new(page_left_margin, draw_text.bounds.lower_right.y + gutter), Geom::Point2d.new(page_width - page_right_margin, current_y + gutter), { :solid_filled => false, :stroke_width => 0.5 })
            current_y = rectangle.drawing_bounds.lower_left.y + gutter

          end

          # Add SketchUp model entity
          skp = Layout::SketchUpModel.new(skp_path, Geom::Bounds2d.new(
            [ 0, page_left_margin ].max,
            [ 0, current_y ].max,
            [ 1, page_width - page_left_margin - page_right_margin ].max,
            [ 1, page_height - current_y - page_bottom_margin ].max
          ))
          skp.perspective = false
          skp.render_mode = @parts_colored ? Layout::SketchUpModel::HYBRID_RENDER : Layout::SketchUpModel::VECTOR_RENDER
          skp.display_background = false
          skp.scale = @camera_zoom
          skp.preserve_scale_on_resize = true
          doc.add_entity(skp, layer, page)

          skp.render  # Render to be able to use 'model_to_paper_point' function

          # Add pins
          unless @pins_hidden

            @pins_infos.each do |pin_info|
              _add_connected_label(doc, layer, page, skp,
                                   pin_info['text'],
                                   Geom::Point3d.new(pin_info['target']),
                                   Geom::Point3d.new(pin_info['position']),
                                   {
                                     :text_font_size => 7,
                                     :text_solid_filled => true,
                                     :text_fill_color => pin_info['background_color'].nil? ? Sketchup::Color.new(0xffffff) : Sketchup::Color.new(pin_info['background_color']),
                                     :text_text_color => pin_info['color'].nil? ? nil : Sketchup::Color.new(pin_info['color']),
                                     :text_text_alignment => Layout::Style::ALIGN_CENTER,
                                     :text_stroke_width => 0.5,
                                     :text_stroke_color => pin_info['border_color'].nil? ? nil : Sketchup::Color.new(pin_info['border_color']),
                                     :leader_line_stroke_width => 0.5,
                                     :leader_line_start_arrow_type => Layout::Style::ARROW_FILLED_CIRCLE,
                                     :leader_line_start_arrow_size => 0.5
                                   }
              )
            end

          end

        rescue StandardError => e
          Plugin.instance.dump_exception(e)
          return { :errors => [ 'default.error' ] }
        ensure
          # Delete Skp file
          File.delete(skp_path)
        end

        begin

          # Save Layout file
          doc.save(layout_path)

        rescue => e
          return { :errors => [ [ 'tab.cutlist.layout.error.failed_to_layout', { :error => e.inspect } ] ] }
        end

        # Override layout 'LinearDimensionTool' default style

        defaults = {
          'arrow.start.size' => { :type => 6, :value => 2 },
          'arrow.start.type' => { :type => 2, :value => 17 },
          'arrow.end.size' => { :type => 6, :value => 2 },
          'arrow.end.type' => { :type => 2, :value => 17 },
          'stroke.width' => { :type => 6, :value => 0.5 },
          'dimension.units.unit' => { :type => 2, :value => DimensionUtils.instance.length_unit },
          'dimension.units.format' => { :type => 2, :value => DimensionUtils.instance.length_format },
          'dimension.units.precision' => { :type => 4, :value => DimensionUtils.instance.length_precision },
          'dimension.units.suppression' => { :type => 2, :value => DimensionUtils.instance.length_suppress_unit_display ? 1 : 0 },
          'dimension.startoffsetlength' => { :type => 7, :value => 0.125 },
          'dimension.startoffsettype' => { :type => 4, :value => 0 },
          'dimension.endoffsetlength' => { :type => 7, :value => 0.125 },
          'dimension.endoffsettype' => { :type => 4, :value => 0 },
        }

        Zip::File.open(layout_path, create: false) do |zipfile|

          require "rexml/document"

          style_manager_filename = 'styleManager.xml'
          xml = zipfile.read(style_manager_filename)

          begin

            # Parse XML
            xdoc = REXML::Document.new(xml)

            # Extract style manager element
            style_manager_elm = xdoc.elements['/styleManager']
            if style_manager_elm

              # Add new 'LinearDimensionTool' default attributes

              style_attributes_elm = REXML::Element.new('e:styleAttributes')

              style_value_elm = REXML::Element.new('t:variant')
              style_value_elm.add_attribute('type', 13)
              style_value_elm.add_element(style_attributes_elm)

              style_elm = REXML::Element.new('t:dicItem')
              style_elm.add_attribute('key', 'LinearDimensionTool')
              style_elm.add_element(style_value_elm)

              style_manager_elm.add_element(style_elm)

              defaults.each { |attribute, type_and_value|

                attribute_value_elm = REXML::Element.new('t:variant')
                attribute_value_elm.add_attribute('type', type_and_value[:type])
                attribute_value_elm.add_text(REXML::Text.new(type_and_value[:value].to_s))

                attribute_elm = REXML::Element.new('t:dicItem')
                attribute_elm.add_attribute('key', attribute)
                attribute_elm.add_element(attribute_value_elm)

                style_attributes_elm.add_element(attribute_elm)

              }

              output = ''
              xdoc.write(output)

              zipfile.get_output_stream(style_manager_filename){ |f| f.puts output }
              zipfile.commit

            end

          rescue REXML::ParseException => error
            # Return nil if an exception is thrown
            puts error.message
          end

        end

        return { :export_path => layout_path }
      end

      { :cancelled => true }
    end

    # -----

    private

    # SketchUp stuffs

    def _draw_part(tmp_definition, part, definition, transformation = nil, material = nil)

      group = tmp_definition.entities.add_group
      group.transformation = transformation
      group.name = part.number.to_s
      group.material = material if @parts_colored

      # Redraw the entire part through one PolygonMesh
      part_mesh = Geom::PolygonMesh.new
      painted_faces = {}
      soft_edges_points = []
      _populate_part_mesh_with_entities(part_mesh, painted_faces, soft_edges_points, definition.entities, nil, material)
      group.entities.fill_from_mesh(part_mesh, true, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE)

      # Add painted meshes
      painted_faces.each do |mesh, material|
        group.entities.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE, material)
      end

      # Remove coplanar edges created by fill_from_mesh and add_faces_from_mesh to reduce exported data
      coplanar_edges = []
      group.entities.grep(Sketchup::Edge).each do |edge|
        edge.faces.each_cons(2) { |pair|
          if pair.first.normal.parallel?(pair.last.normal)
            coplanar_edges << edge
            break
          end
        }
      end
      group.entities.erase_entities(coplanar_edges)

      # Add soft edges
      soft_edges_points.each do |edge_points|
        group.entities.add_edges(edge_points).each { |edge| edge.soft = true }
      end

    end

    def _populate_part_mesh_with_entities(part_mesh, painted_meshes, soft_edges_points, entities, transformation = nil, material = nil)

      entities.each do |entity|

        next unless entity.visible? && _layer_visible?(entity.layer)

        if entity.is_a?(Sketchup::Face)

          points_indices = []

          mesh = entity.mesh(7) # POLYGON_MESH_POINTS (0) | POLYGON_MESH_UVQ_FRONT (1) | POLYGON_MESH_UVQ_BACK (3) | POLYGON_MESH_NORMALS (4)
          mesh.transform!(transformation) unless transformation.nil?

          # If face is painted, do not add it to part_mesh
          if @parts_colored && !entity.material.nil? && entity.material != material
            painted_meshes.store(mesh, entity.material)
          else
            mesh.points.each { |point| points_indices << part_mesh.add_point(point) }
            mesh.polygons.each { |polygon| part_mesh.add_polygon(polygon.map { |index| points_indices[index.abs - 1] }) }
          end

          # Extract soft edges to re-add them later
          entity.edges.each { |edge|
            if edge.soft?
              edge_points = edge.vertices.map { |vertex| vertex.position }
              edge_points.each { |point| point.transform!(transformation) } unless transformation.nil?
              soft_edges_points << edge_points
            end
          }

        elsif entity.is_a?(Sketchup::Group)
          _populate_part_mesh_with_entities(part_mesh, painted_meshes, soft_edges_points, entity.entities, TransformationUtils.multiply(transformation, entity.transformation), material)
        elsif entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening?
          _populate_part_mesh_with_entities(part_mesh, painted_meshes, soft_edges_points, entity.definition.entities, TransformationUtils.multiply(transformation, entity.transformation), material)
        end

      end

    end

    # Layout stuffs

    def _add_formated_text(doc, layer, page, text, anchor, anchor_type, style = nil)
      entity = Layout::FormattedText.new(
        text,
        anchor,
        anchor_type
      )
      doc.add_entity(entity, layer, page)
      if style
        entity_style = entity.style(0)
        entity_style.font_size = style[:font_size] unless style[:font_size].nil?
        entity_style.font_family = style[:font_family] unless style[:font_family].nil?
        entity_style.text_bold = style[:text_bold] unless style[:text_bold].nil?
        entity_style.text_alignment = style[:text_alignment] unless style[:text_alignment].nil?
        entity.apply_style(entity_style)
      end
      entity
    end

    def _add_rectangle(doc, layer, page, upper_left, lower_right, style = nil)
      entity = Layout::Rectangle.new(
        Geom::Bounds2d.new(upper_left, lower_right)
      )
      doc.add_entity(entity, layer, page)
      if style
        entity_style = entity.style
        entity_style.solid_filled = style[:solid_filled] unless style[:solid_filled].nil?
        entity_style.stroke_width = style[:stroke_width] unless style[:stroke_width].nil?
        entity_style.stroke_color = style[:stroke_color] unless style[:stroke_color].nil?
        entity.style = entity_style
      end
      entity
    end

    def _add_connected_label(doc, layer, page, skp, text, target_3d, anchor_3d, style = nil)
      target_2d = skp.model_to_paper_point(target_3d)
      anchor_2d = skp.model_to_paper_point(anchor_3d)
      entity = Layout::Label.new(
        text,
        Layout::Label::LEADER_LINE_TYPE_SINGLE_SEGMENT,
        target_2d,
        anchor_2d,
        Layout::FormattedText::ANCHOR_TYPE_CENTER_LEFT
      )
      doc.add_entity(entity, layer, page)
      if style
        entity_style = entity.style

        text_style = entity_style.get_sub_style(Layout::Style::LABEL_TEXT)
        text_style.font_size = style[:text_font_size] unless style[:text_font_size].nil?
        text_style.solid_filled = style[:text_solid_filled] unless style[:text_solid_filled].nil?
        text_style.fill_color = style[:text_fill_color] unless style[:text_fill_color].nil?
        text_style.text_color = style[:text_text_color] unless style[:text_text_color].nil?
        text_style.text_alignment = style[:text_text_alignment] unless style[:text_text_alignment].nil?
        text_style.stroked = !style[:text_stroke_width].nil?
        text_style.stroke_width = style[:text_stroke_width] unless style[:text_stroke_width].nil?
        text_style.stroke_color = style[:text_stroke_color] unless style[:text_stroke_color].nil?
        entity_style.set_sub_style(Layout::Style::LABEL_TEXT, text_style)

        leader_line_style = entity_style.get_sub_style(Layout::Style::LABEL_LEADER_LINE)
        leader_line_style.stroke_width = style[:leader_line_stroke_width] unless style[:leader_line_stroke_width].nil?
        leader_line_style.start_arrow_type = style[:leader_line_start_arrow_type] unless style[:leader_line_start_arrow_type].nil?
        leader_line_style.start_arrow_size = style[:leader_line_start_arrow_size] unless style[:leader_line_start_arrow_size].nil?
        entity_style.set_sub_style(Layout::Style::LABEL_LEADER_LINE, leader_line_style)

        entity.style = entity_style
      end
      if target_3d == anchor_3d

        # Workaround to "Hide" leader line if target_3d == anchor_3d
        entity_style = entity.style
        leader_line_style = entity_style.get_sub_style(Layout::Style::LABEL_LEADER_LINE)
        leader_line_style.stroke_color = Sketchup::Color.new(0, 0, 0, 0)
        entity_style.set_sub_style(Layout::Style::LABEL_LEADER_LINE, leader_line_style)
        entity.style = entity_style

        # Center text on anchor point
        if Geom::Transformation2d.respond_to?(:translation) # SU 2019+
          entity.transform!(Geom::Transformation2d.translation(Geom::Vector2d.new(anchor_2d.x, anchor_2d.y) - Geom::Vector2d.new(entity.text.bounds.upper_left.x + entity.text.bounds.width / 2, entity.text.bounds.upper_left.y + entity.text.bounds.height / 2)))
        end

      end
      # Connect target to model
      entity.connect(Layout::ConnectionPoint.new(skp, target_3d)) unless target_3d == anchor_3d
      entity
    end

    def _to_layout_length_precision(su_length_precision)
      return 1 if su_length_precision == 0
      "0.#{'1'.ljust(su_length_precision - 1, '0')}".to_f
    end

    def _camera_zoom_to_scale(zoom)
      if zoom > 1
        scale = "#{zoom.round(3)}:1"
      elsif zoom < 1
        scale = "1:#{(1 / zoom).round(3)}"
      else
        scale = '1:1'
      end
      scale
    end

  end

end