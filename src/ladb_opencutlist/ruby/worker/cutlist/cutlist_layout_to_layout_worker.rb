module Ladb::OpenCutList

  require_relative '../../plugin'
  require_relative '../../helper/layer_visibility_helper'

  class CutlistLayoutToLayoutWorker

    include LayerVisibilityHelper

    def initialize(settings, cutlist)

      @part_ids = settings.fetch('part_ids', nil)

      @page_width = settings.fetch('page_width', 0).to_l
      @page_height = settings.fetch('page_height', 0).to_l
      @parts_colored = settings.fetch('parts_colored', false)
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

      materials = model.materials

      ####

      layout_dir = File.join(Plugin.instance.temp_dir, 'layout')
      unless Dir.exist?(layout_dir)
        Dir.mkdir(layout_dir)
      end

      # CREATE SKP FILE

      skp_file = File.join(layout_dir, 'ocl.skp')

      model = Sketchup.active_model
      tmp_definition = model.definitions.add('TMP')

      parts.each do |part|

        part.def.instance_infos.each do |serialized_path, instance_info|

          material = materials[part.material_name]
          material_color = @parts_colored && material ? material.color : nil

          _draw_part(tmp_definition, part, instance_info.entity.definition, instance_info.transformation, material_color)

        end

      end

      view = model.active_view
      camera = view.camera
      eye = camera.eye
      target = camera.target
      up = camera.up

      camera.set(Geom::Point3d.new(
        @camera_view.x * @exploded_model_radius + @camera_target.x,
        @camera_view.y * @exploded_model_radius + @camera_target.y,
        @camera_view.z * @exploded_model_radius + @camera_target.z
      ), @camera_target, Z_AXIS)
      tmp_definition.save_as(skp_file)
      camera.set(eye, target, up)

      model.definitions.remove(tmp_definition)

      # CREATE LAUOUT FILE

      layout_file = File.join(layout_dir, 'ocl.layout')

      doc = Layout::Document.new
      page_info = doc.page_info
      page_info.width = @page_width
      page_info.height = @page_height
      page = doc.pages.first
      layer = doc.layers.first

      bounds = Geom::Bounds2d.new(
        page_info.left_margin,
        page_info.top_margin,
        page_info.width - page_info.left_margin - page_info.right_margin,
        page_info.height - page_info.top_margin - page_info.bottom_margin
      )
      skp = Layout::SketchUpModel.new(skp_file, bounds)
      skp.perspective = false
      skp.render_mode = Layout::SketchUpModel::VECTOR_RENDER
      skp.display_background = false
      skp.scale = @camera_zoom
      doc.add_entity(skp, layer, page)

      status = doc.save(layout_file)

      {
        :export_path => layout_file
      }
    end

    # -----

    private

    def _draw_part(tmp_definition, part, definition, transformation = nil, color = nil)
      group = tmp_definition.entities.add_group
      group.transformation = transformation
      group.name = "#{part.number} - #{part.name}"
      _draw_entities(group, definition.entities, color)
    end

    def _draw_entities(container, entities, color = nil)

      entities.each do |entity|

        next unless entity.visible? && _layer_visible?(entity.layer)

        if entity.is_a?(Sketchup::Face)
          points = entity.vertices.map { |vertex| vertex.position }
          face = container.entities.add_face(points)
          face.material = entity.material.nil? ? color : entity.material.color if @parts_colored
        elsif entity.is_a?(Sketchup::Group)
          group = container.entities.add_group
          group.transformation = entity.transformation
          _draw_entities(group, entity.entities)
        end

      end

    end

  end

end