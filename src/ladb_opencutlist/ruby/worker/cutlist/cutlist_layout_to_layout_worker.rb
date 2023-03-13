module Ladb::OpenCutList

  require 'benchmark'
  require 'securerandom'
  require_relative '../../plugin'
  require_relative '../../helper/layer_visibility_helper'

  class CutlistLayoutToLayoutWorker

    include LayerVisibilityHelper

    def initialize(settings, cutlist)

      @part_ids = settings.fetch('part_ids', nil)
      @target_group_id = settings.fetch('target_group_id', nil)

      @page_width = settings.fetch('page_width', 0).to_l
      @page_height = settings.fetch('page_height', 0).to_l
      @parts_colored = settings.fetch('parts_colored', false)
      @pins_text = settings.fetch('pins_text', 0)
      @camera_view = Geom::Point3d.new(settings.fetch('camera_view', nil))
      @camera_zoom = settings.fetch('camera_zoom', 1)
      @camera_target = Geom::Point3d.new(settings.fetch('camera_target', nil))
      @exploded_model_radius =settings.fetch('exploded_model_radius', 1)

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve parts
      parts = @cutlist.get_real_parts(@part_ids)
      return { :errors => [ 'tab.cutlist.layout.error.no_part' ] } if parts.empty?

      # Retrieve target group
      target_group = @cutlist.get_group(@target_group_id)

      ####

      Benchmark.bm do |x|

        # Ask for layout file path
        layout_path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export.title'), @cutlist.dir, _sanitize_filename("#{@cutlist.model_name.empty? ? File.basename(@cutlist.filename, '.skp') : @cutlist.model_name}#{@cutlist.page_name.empty? ? '' : " - #{@cutlist.page_name}"}#{target_group && target_group.material_type != MaterialAttributes::TYPE_UNKNOWN ? " - #{target_group.material_name} #{target_group.std_dimension}" : ''}.layout"))
        if layout_path

          dir = File.dirname(layout_path)

          # CREATE SKP FILE

          uuid = SecureRandom.uuid

          skp_path = File.join(dir, "#{File.basename(layout_path, '.layout')}-#{uuid}.skp")

          materials = model.materials
          tmp_definition = model.definitions.add(uuid)

          x.report('DRAW') {
            parts.each do |part|

              part.def.instance_infos.each do |serialized_path, instance_info|

                material = materials[part.material_name]
                material_color = @parts_colored && material ? material.color : 0xffffff

                _draw_part(tmp_definition, part, instance_info.entity.definition, instance_info.transformation, material_color)

              end

            end
          }

          view = model.active_view
          camera = view.camera
          eye = camera.eye
          target = camera.target
          up = camera.up

          # Workaround to set camera in Layout file : briefly change current model's camera
          camera.set(Geom::Point3d.new(
            @camera_view.x * @exploded_model_radius + @camera_target.x,
            @camera_view.y * @exploded_model_radius + @camera_target.y,
            @camera_view.z * @exploded_model_radius + @camera_target.z
          ), @camera_target, Z_AXIS)

          # Save tmp definition as in skp file
          skp_success = tmp_definition.save_as(skp_path)

          # Restore model's camera
          camera.set(eye, target, up)

          # Remove tmp definition
          model.definitions.remove(tmp_definition)

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

          # Add SketchUp model entity
          skp = Layout::SketchUpModel.new(skp_path, Geom::Bounds2d.new(
            page_info.left_margin,
            page_info.top_margin,
            page_info.width - page_info.left_margin - page_info.right_margin,
            page_info.height - page_info.top_margin - page_info.bottom_margin
          ))
          skp.perspective = false
          skp.render_mode = Layout::SketchUpModel::VECTOR_RENDER
          skp.display_background = false
          skp.scale = @camera_zoom
          doc.add_entity(skp, layer, page)

          # Save Layout file
          begin
            doc.save(layout_path)
          rescue => e
            return { :errors => [ [ 'tab.cutlist.layout.error.failed_to_layout', { :error => e.message } ] ] }
          end

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

    def _draw_part(tmp_definition, part, definition, transformation = nil, color = nil)
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
      group.entities.build { |builder|
        _draw_entities(builder, definition.entities, nil, color)
      }
    end

    def _draw_entities(builder, entities, transformation = nil, color = nil)

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
          face.material = entity.material.nil? ? color : entity.material.color if @parts_colored

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
          _draw_entities(builder, entity.entities, TransformationUtils.multiply(transformation, entity.transformation))
        elsif entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening?
          _draw_entities(builder, entity.definition.entities, TransformationUtils.multiply(transformation, entity.transformation))
        end

      end

    end

    def _sanitize_filename(filename)
      filename
        .gsub(/\//, '∕')
        .gsub(/꞉/, '꞉')
    end

  end

end