module Ladb::OpenCutList

  require 'benchmark'
  require 'securerandom'
  require_relative '../../plugin'
  require_relative '../../helper/layer_visibility_helper'

  class CutlistLayoutToLayoutWorker

    include LayerVisibilityHelper

    def initialize(settings, cutlist)

      @parts_matrices = settings.fetch('parts_matrices', nil)
      @target_group_id = settings.fetch('target_group_id', nil)

      @page_width = settings.fetch('page_width', 0).to_l
      @page_height = settings.fetch('page_height', 0).to_l
      @page_header = settings.fetch('page_header', false)
      @parts_colored = settings.fetch('parts_colored', false)
      @parts_opacity = settings.fetch('parts_opacity', 1)
      @pins_text = settings.fetch('pins_text', 0)
      @camera_view = Geom::Vector3d.new(settings.fetch('camera_view', nil))
      @camera_zoom = settings.fetch('camera_zoom', 1)
      @camera_target = Geom::Point3d.new(settings.fetch('camera_target', nil))
      @exploded_model_radius =settings.fetch('exploded_model_radius', 1)

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ [ 'core.error.feature_unavailable', { :version => 2022 } ] ] } if Sketchup.version_number < 2200000000
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      return { :errors => [ 'tab.cutlist.layout.error.no_part' ] } if @parts_matrices.empty?

      # Retrieve target group
      target_group = @cutlist.get_group(@target_group_id)

      # Base document name
      doc_name = "#{@cutlist.model_name.empty? ? File.basename(@cutlist.filename, '.skp') : @cutlist.model_name}#{@cutlist.page_name.empty? ? '' : " - #{@cutlist.page_name}"}#{target_group && target_group.material_type != MaterialAttributes::TYPE_UNKNOWN ? " - #{target_group.material_name} #{target_group.std_dimension}" : ''}"

      # Ask for layout file path
      layout_path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export.title'), @cutlist.dir, _sanitize_filename("#{doc_name}.layout"))
      if layout_path

        # Start model modification operation
        model.start_operation('OpenCutList - Export to Layout', true, false, true)

        dir = File.dirname(layout_path)

        # CREATE SKP FILE

        uuid = SecureRandom.uuid

        skp_path = File.join(dir, "#{File.basename(layout_path, '.layout')}-#{uuid}.skp")

        materials = model.materials
        definitions = model.definitions
        styles = model.styles

        tmp_definition = definitions.add(uuid)

        # Iterate on parts
        @parts_matrices.each do |part_matrix|

          # Retrieve part
          part = @cutlist.get_real_parts([ part_matrix['id'] ]).first

          # Convert three matrix to transformation
          transformation = Geom::Transformation.new(part_matrix['matrix'])

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

        # Workaround to set camera in Layout file : briefly change current model's camera
        camera.perspective = false
        camera.set(Geom::Point3d.new(
          @camera_view.x * @exploded_model_radius + @camera_target.x,
          @camera_view.y * @exploded_model_radius + @camera_target.y,
          @camera_view.z * @exploded_model_radius + @camera_target.z
        ), @camera_target, @camera_view.parallel?(Z_AXIS) ? Y_AXIS : Z_AXIS)

        # Add style
        selected_style = styles.selected_style
        styles.add_style(File.join(__dir__, '..', '..', '..', 'style', @parts_colored ? 'ocl_layout_colored.style' : 'ocl_layout_no_color.style' ), true)

        # Save tmp definition as in skp file
        skp_success = tmp_definition.save_as(skp_path)

        # Restore model's style
        styles.selected_style = selected_style

        # Restore model's camera
        camera.perspective = perspective
        camera.set(eye, target, up)

        # Remove tmp definition
        model.definitions.remove(tmp_definition)

        # Commit model modification operation
        model.commit_operation

        return { :errors => [ 'tab.cutlist.layout.error.failed_to_save_as_skp' ] } unless skp_success

        # CREATE LAYOUT FILE

        doc = Layout::Document.new

        # Set document's page infos
        page_info = doc.page_info
        page_info.width = @page_width
        page_info.height = @page_height
        page_info.top_margin = 0.25
        page_info.right_margin = 0.25
        page_info.bottom_margin = 0.25
        page_info.left_margin = 0.25

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
        doc.precision = 0.000001.ceil(DimensionUtils.instance.length_precision)

        page = doc.pages.first
        layer = doc.layers.first

        # Set page name
        page.name = doc_name

        # Set auto text definitions
        doc.auto_text_definitions.add('OclDate', Layout::AutoTextDefinition::TYPE_DATE_CREATED)
        doc.auto_text_definitions.add('OclLengthUnit', Layout::AutoTextDefinition::TYPE_CUSTOM_TEXT).custom_text = Plugin.instance.get_i18n_string("default.unit_#{DimensionUtils.instance.length_unit}")
        doc.auto_text_definitions.add('OclScale', Layout::AutoTextDefinition::TYPE_CUSTOM_TEXT).custom_text = _camera_zoom_to_scale(@camera_zoom)

        # Add header
        current_y = page_info.top_margin
        if @page_header

          gutter = 0.1
          font_family = 'Verdana'

          draw_text = _create_formated_text(Plugin.instance.get_i18n_string('tab.cutlist.layout.title'), Geom::Point2d.new(page_info.left_margin, current_y), Layout::FormattedText::ANCHOR_TYPE_TOP_LEFT, { :font_family => font_family, :font_size => 18, :text_alignment => Layout::Style::ALIGN_LEFT })
          doc.add_entity(draw_text, layer, page)

          current_y = draw_text.bounds.lower_right.y

          date_and_unit_text = _create_formated_text('<OclDate>  |  <OclLengthUnit>  |  <OclScale>', Geom::Point2d.new(page_info.width - page_info.right_margin, current_y), Layout::FormattedText::ANCHOR_TYPE_BOTTOM_RIGHT, { :font_family => font_family, :font_size => 10, :text_alignment => Layout::Style::ALIGN_RIGHT })
          doc.add_entity(date_and_unit_text, layer, page)

          name_text = _create_formated_text('<PageName>', Geom::Point2d.new(page_info.width / 2, current_y + gutter * 2), Layout::FormattedText::ANCHOR_TYPE_TOP_CENTER, { :font_family => font_family, :font_size => 15, :text_alignment => Layout::Style::ALIGN_CENTER })
          doc.add_entity(name_text, layer, page)
          current_y = name_text.bounds.lower_right.y

          unless @cutlist.model_description.empty?
            model_description_text = _create_formated_text(@cutlist.model_description, Geom::Point2d.new(page_info.width / 2, current_y), Layout::FormattedText::ANCHOR_TYPE_TOP_CENTER, { :font_family => font_family, :font_size => 9, :text_alignment => Layout::Style::ALIGN_CENTER })
            doc.add_entity(model_description_text, layer, page)
            current_y = model_description_text.bounds.lower_right.y
          end

          unless @cutlist.page_description.empty?
            page_description_text = _create_formated_text(@cutlist.page_description, Geom::Point2d.new(page_info.width / 2, current_y), Layout::FormattedText::ANCHOR_TYPE_TOP_CENTER, { :font_family => font_family, :font_size => 9, :text_alignment => Layout::Style::ALIGN_CENTER })
            doc.add_entity(page_description_text, layer, page)
            current_y = page_description_text.bounds.lower_right.y
          end

          rectangle = _create_rectangle(Geom::Point2d.new(page_info.left_margin, draw_text.bounds.lower_right.y + gutter), Geom::Point2d.new(page_info.width - page_info.right_margin, current_y + gutter), { :solid_filled => false })
          doc.add_entity(rectangle, layer, page)
          current_y = rectangle.bounds.lower_right.y + gutter

        end

        # Add SketchUp model entity
        skp = Layout::SketchUpModel.new(skp_path, Geom::Bounds2d.new(
          page_info.left_margin,
          current_y,
          page_info.width - page_info.left_margin - page_info.right_margin,
          page_info.height - current_y - page_info.bottom_margin
        ))
        skp.perspective = false
        skp.render_mode = Layout::SketchUpModel::VECTOR_RENDER
        skp.display_background = false
        skp.scale = @camera_zoom
        skp.preserve_scale_on_resize = true
        doc.add_entity(skp, layer, page)

        # Save Layout file
        begin
          doc.save(layout_path)
        rescue => e
          return { :errors => [ [ 'tab.cutlist.layout.error.failed_to_layout', { :error => e.message } ] ] }
        ensure
          # Delete Skp file
          File.delete(skp_path)
        end

        return {
          :export_path => layout_path
        }
      end

      {
        :cancelled => true
      }
    end

    # -----

    private

    def _draw_part(tmp_definition, part, definition, transformation = nil, material = nil)
      group = tmp_definition.entities.add_group
      group.transformation = transformation
      case @pins_text
      when 1  # PINS_TEXT_NAME
        group.name = part.name
      when 2  # PINS_TEXT_NUMBER_AND_NAME
        group.name = "#{part.number} - #{part.name}"
      else    # PINS_TEXT_NUMBER
        group.name = part.number
      end
      group.material = material if @parts_colored
      group.entities.build { |builder|
        _draw_entities(builder, definition.entities, nil, material)
      }
    end

    def _draw_entities(builder, entities, transformation = nil, material = nil)

      entities.each do |entity|

        next unless entity.visible? && _layer_visible?(entity.layer)

        if entity.is_a?(Sketchup::Face)

          # Extract loops
          outer_loop = entity.outer_loop
          outer_loop_points = []
          inner_loops_points = []
          entity.loops.each { |loop|
            loop_points = loop.vertices.map { |vertex| vertex.position }
            Point3dUtils.transform_points(loop_points, transformation)
            if loop == outer_loop
              outer_loop_points = loop_points
            else
              inner_loops_points << loop_points
            end
          }

          # Draw face
          face = builder.add_face(outer_loop_points, holes: inner_loops_points)
          face.material = entity.material.nil? ? material : entity.material if @parts_colored

          # Add soft and smooth edges
          entity.edges.each { |edge|
            if edge.soft? || edge.smooth?
              edge_points = edge.vertices.map { |vertex| vertex.position }
              Point3dUtils.transform_points(edge_points, transformation)
              e = builder.add_edge(edge_points)
              e.soft = edge.soft?
              e.smooth = edge.smooth?
            end
          }

        elsif entity.is_a?(Sketchup::Group)
          _draw_entities(builder, entity.entities, TransformationUtils.multiply(transformation, entity.transformation), material)
        elsif entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening?
          _draw_entities(builder, entity.definition.entities, TransformationUtils.multiply(transformation, entity.transformation), material)
        end

      end

    end

    def _sanitize_filename(filename)
      filename
        .gsub(/\//, '∕')
        .gsub(/꞉/, '꞉')
    end

    def _create_formated_text(text, anchor, anchor_type, style = nil)
      entity = Layout::FormattedText.new(text, anchor, anchor_type)
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

    def _create_rectangle(upper_left, lower_right, style = nil)
      entity = Layout::Rectangle.new(Geom::Bounds2d.new(upper_left, lower_right))
      if style
        entity_style = entity.style
        entity_style.solid_filled = style[:solid_filled] unless style[:solid_filled].nil?
        entity.style = entity_style
      end
      entity
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