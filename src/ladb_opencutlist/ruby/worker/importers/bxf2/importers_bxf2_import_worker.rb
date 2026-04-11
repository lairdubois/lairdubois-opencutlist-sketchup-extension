module Ladb::OpenCutList

  require_relative '../../../lib/geometrix/geometrix'
  require_relative '../../../model/attributes/material_attributes'

  class ImportersBxf2ImportWorker

    NODE_UP_TRANSFORM = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
    COMPONENT_UP_TRANSFORM = Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS.reverse, Y_AXIS)

    BLUM_COLOR = Sketchup::Color.new('#ff671f').freeze
    WOOD_MATERIAL_COLOR = Sketchup::Color.new(209, 197, 173).freeze
    ALUMINIUM_MATERIAL_COLOR = Sketchup::Color.new(204, 204, 204).freeze
    GLASS_MATERIAL_COLOR = Sketchup::Color.new(196, 232, 254, 0.5).freeze

    attr_reader :bxf_model

    def initialize(bxf_model,

                   part_wood_material_name: nil,
                   part_aluminium_material_name: nil,
                   part_glass_material_name: nil,
                   front_part_layer_name: nil,

                   machining_material_name: nil,
                   machining_layer_name: nil,

                   hardware_material_name: nil,
                   hardware_layer_name: nil

    )

      @bxf_model = bxf_model

      @part_wood_material_name = part_wood_material_name
      @part_aluminium_material_name = part_aluminium_material_name
      @part_glass_material_name = part_glass_material_name
      @front_part_layer_name = front_part_layer_name

      @machining_material_name = machining_material_name
      @machining_layer_name = machining_layer_name

      @hardware_material_name = hardware_material_name
      @hardware_layer_name = hardware_layer_name

    end

    # -----

    def run

      return { :errors => [ 'tab.importers.default.error.no_data' ] } unless @bxf_model.is_a?(Bxf::BxfModel)

      model = Sketchup.active_model
      return { :errors => [ 'tab.importers.default.error.no_model' ] } unless model

      model.select_tool(ImportersBxf2PlaceTool.new(@bxf_model) { |cancelled, transformation = IDENTITY|
        if cancelled

          # Deactivate tool
          model.select_tool(nil)

          # Invoke dialog callback
          PLUGIN.execute_tabs_dialog_command_on_tab('importers_bxf2', 'import_callback', { cancelled: true }.to_json, nil, false)

        else

          # Process importation
          _import_at(transformation) do |cancelled, errors|

            # Deactivate tool
            model.select_tool(nil)

            # Invoke dialog callback
            PLUGIN.execute_tabs_dialog_command_on_tab('importers_bxf2', 'import_callback', { errors: errors }.to_json, nil, !cancelled)

          end

        end
      })

      # Give focus to SketchUp main window
      Sketchup.focus if Sketchup.respond_to?(:focus)

      {
        :errors => []
      }
    end

    # -----

    private

    def _import_at(transformation, &callback)

      model = Sketchup.active_model
      model.start_operation('Import BXF2', false)

        begin

          entities = model.active_entities

          @bxf_model.scene.nodes.each do |node|

            t = transformation * node.transformations.to_t

            _process_cabinet_group_links(node.cabinet_group_links, entities, t)
            _process_cabinet_links(node.cabinet_links, entities, t)
            _process_container_links(node.container_links, entities, t)
            _process_function_unit_links(node.function_unit_links, entities, t)

          end

        rescue Exception => e
          PLUGIN.dump_exception(e)
          model.abort_operation
          callback.call(true, [ [ 'core.error.exception', { :error => e.message } ] ]) if callback
          return
        ensure
          _clear_factories
        end

      model.commit_operation

      callback.call(false, []) if callback

    end

    # -----

    def _clear_factories
      @materials_factory = nil
      @parts_factory = nil
      @components_factory = nil
      @machining_factory = nil
    end

    def _process_cabinet_group_links(cabinet_group_links, entities, transformation = IDENTITY)

      cabinet_group_links.each do |cabinet_group_link|

        cabinet_group = cabinet_group_link.cabinet_group

        group = entities.add_group
        group.name = cabinet_group_link.description if cabinet_group_link.description
        group.transformation = transformation * cabinet_group_link.transformations.to_t

        _process_cabinet_links(cabinet_group.cabinet_links, group.entities)

      end

    end

    def _process_cabinet_links(cabinet_links, entities, transformation = IDENTITY)

      cabinet_links.each do |cabinet_link|

        cabinet = cabinet_link.cabinet

        group = entities.add_group
        group.name = cabinet_link.description if cabinet_link.description
        group.transformation = transformation * cabinet_link.transformations.to_t

        _process_part_links(cabinet.part_links, group.entities)
        _process_container_links(cabinet.container_links, group.entities)
        _process_function_unit_links(cabinet.function_unit_links, group.entities)

      end

    end

    def _process_part_links(part_links, entities)

      part_links.each do |part_link|

        part = part_link.part

        next if part.nil? || part.geometry.nil?

        part_name = part_link.description
        part_name = part.description if part_name.nil? || part_name.empty?
        part_name = PLUGIN.get_i18n_string('default.part_single').capitalize if part_name.nil? || part_name.empty?

        definition = (@parts_factory ||= {})[part] ||= begin

                                                         definition = Sketchup.active_model.definitions.add(part_name)

                                                         # Draw geometry
                                                         if part.geometry.is_a?(Bxf::BxfGeometryBox)
                                                           _draw_box(definition.entities, part.geometry.extent.to_b)
                                                         elsif part.geometry.is_a?(Bxf::BxfGeometryPrism)
                                                           _draw_prism(definition.entities, part.geometry)
                                                         elsif part.geometry.is_a?(Bxf::BxfGeometryCylinder)
                                                           _draw_cylinder(definition.entities, part.geometry)
                                                         end

                                                         da = DefinitionAttributes.new(definition)
                                                         da.orientation_locked_on_axis = true
                                                         da.write_to_attributes

                                                         # Process machinings
                                                         _process_inherited_machinings(part.inherited_machinings, definition.entities)
                                                         _process_machining_group_links(part.machining_group_links, definition.entities)
                                                         _process_machining_links(part.machining_links, definition.entities)

                                                         definition
                                                       end

        instance = entities.add_instance(definition, part_link.transformations.to_t)
        instance.layer = _get_front_part_layer if part.model_key.start_with?('H-FRON')
        instance.material = _get_part_material(part.material)

      end

    end

    def _process_container_links(container_links, entities, transformation = IDENTITY)

      container_links.each do |container_link|

        container = container_link.container

        _process_function_unit_links(container.function_unit_links, entities, transformation * container_link.transformations.to_t)

      end

    end

    def _process_function_unit_links(function_unit_links, entities, transformation = IDENTITY)

      function_unit_links.each do |function_unit_link|

        function_unit = function_unit_link.function_unit

        function_unit_group = entities.add_group
        function_unit_group.name = "#{('A'..'Z').take(function_unit_link.zone.column + 1).last}/#{function_unit_link.zone.row + 1}"
        function_unit_group.definition.description = function_unit.description if function_unit.description
        function_unit_group.transformation = transformation * function_unit_link.transformations.to_t

        article_entities_stacks = {}
        function_unit.article_links.each do |article_link|

          article = article_link.article

          article_link.quantity.times do

            article_group = function_unit_group.entities.add_group
            article_group.name = article.article_number if article.article_number
            article_group.definition.description = article.description if article.description
            article_group.material = _get_hardware_material

            article.component_numbers.each do |component_number|
              (article_entities_stacks[component_number] ||= []) << article_group.entities
            end

          end

        end

        _process_part_links(function_unit.part_links, function_unit_group.entities)
        _process_component_links(function_unit.component_links, function_unit_group.entities, article_entities_stacks)

      end

    end

    def _process_component_links(component_links, entities, article_entities_stacks = {})

      component_links.each do |component_link|

        component = component_link.component
        article = component.article

        # Try to retrieve the entities from the stack of entities for the related article that is currently being processed
        if (stack = article_entities_stacks[component.component_number]) && (article_entities = stack.first)
          stack.rotate!(1)
          component_entities = article_entities
        else
          component_entities = entities
        end

        definition = (@components_factory ||= {})[component] ||= begin

                                                                   component_name = "#{"#{article.article_number}_" if article}#{component.component_number}"
                                                                   definition = Sketchup.active_model.definitions[component_name]
                                                                   if definition.nil?

                                                                     base_path = File.dirname(File.expand_path(@bxf_model.path.to_s))
                                                                     cad_data_path = File.join(base_path, "cadData")
                                                                     file_name = "#{component_name}.dae"
                                                                     file_path = File.join(cad_data_path, file_name)
                                                                     file_path = File.join(cad_data_path, " #{file_name}") unless File.exist?(file_path) # Workaround for configurator bug with space on some files

                                                                     begin

                                                                       # Load component from local DAE file
                                                                       definition = Sketchup.active_model.definitions.import(file_path, {
                                                                         validate_dae: true,
                                                                         merge_coplanar_faces: true
                                                                       })
                                                                       definition.name = component_name

                                                                     rescue Exception => e

                                                                       puts "Error loading component: #{file_path} #{e.message}"

                                                                       # Create a box instead of the component
                                                                       definition = Sketchup.active_model.definitions.add(component_name)
                                                                       _draw_box(definition.entities, Geom::BoundingBox.new.add(
                                                                         [-10.mm, -10.mm, -10.mm],
                                                                         [10.mm, 10.mm, 10.mm]
                                                                       ))

                                                                     end

                                                                     # Process machinings
                                                                     _process_machining_group_links(component.machining_group_links, definition.entities)
                                                                     _process_machining_links(component.machining_links, definition.entities)

                                                                     # Set description if available
                                                                     definition.description = component.description if component.description

                                                                   end

                                                                   definition
                                                                 end

        t = component_link.transformations.to_t

        # Special case for "Cut" machining that is applyed as scale transformation on the instance
        if (cut_machining_link = component.machining_links.find { |link| link.machining.is_a?(Bxf::BxfMachiningCut) })

          cut_machining = cut_machining_link.machining

          orientation_v = cut_machining.orientation.to_v.normalize!
          original_size = cut_machining.original_size.to_l
          final_size = cut_machining.final_size.to_l

          factor = (original_size - final_size) / original_size
          scale_x = 1.0 - (orientation_v.x * factor).abs
          scale_y = 1.0 - (orientation_v.y * factor).abs
          scale_z = 1.0 - (orientation_v.z * factor).abs

          t *= cut_machining_link.transformations.to_t * Geom::Transformation.scaling(scale_x, scale_y, scale_z)

        else

          # Flag component for "no-scale"
          definition.behavior.no_scale_mask = 127 # 1111111 (all disabld)

        end

        instance = component_entities.add_instance(definition, t * COMPONENT_UP_TRANSFORM)
        instance.layer = _get_hardware_layer
        instance.material = _get_hardware_material

      end

    end

    def _process_article_links(article_links, entities)

      article_links.each do |article_link|
      end

    end

    def _process_inherited_machinings(inherited_machinings, entities)

      inherited_machinings.each do |inherited_machining|

        component_link = inherited_machining.component_link
        component = component_link.component

        machining_group_links = inherited_machining.machining_group_link_references.map { |reference| component.related_machining_group_links.find { |link| link.id == reference.reference_id } }
        _process_machining_group_links(machining_group_links, entities, component_link.transformations.to_t)

        machining_links = inherited_machining.machining_link_references.map { |reference| component.related_machining_links.find { |link| link.id == reference.reference_id } }
        _process_machining_links(machining_links, entities, component_link.transformations.to_t)

      end

    end

    def _process_machining_group_links(machining_group_links, entities, transformation = IDENTITY)

      machining_group_links.each do |machining_group_link|

        machining_group = machining_group_link.machining_group

        group = entities.add_group
        group.name = machining_group.model_key if machining_group.model_key
        group.material = _get_machining_material

        if machining_group.is_a?(Bxf::BxfGridMachining)

          column_count = machining_group.column_count
          column_distance = machining_group.column_distance.to_l
          row_count = machining_group.row_count
          row_distance = machining_group.row_distance.to_l

          t0 = transformation * machining_group_link.transformations.to_t

          column_count.times do |column_index|

            x = column_index * column_distance

            row_count.times do |row_index|

              y = row_index * row_distance
              t1 = Geom::Transformation.translation(Geom::Vector3d.new(x, y, 0))

              _process_machining_links(machining_group.machining_links, group.entities, t0 * t1)

            end

          end

        else

          _process_machining_links(machining_group.machining_links, group.entities, transformation * machining_group_link.transformations.to_t)

        end

      end

    end

    def _process_machining_links(machining_links, entities, transformation = IDENTITY)

      machining_links.each do |machining_link|
        _draw_machining(entities, machining_link.machining, transformation * machining_link.transformations.to_t)
      end

    end

    # -- Drawing --

    def _num_segments_by_radius(radius,
                                min_num_segments: 8,
                                max_num_segments: 24,
                                max_segment_length: 2.mm,
                                arc_angle: Geometrix::TWO_PI
    )
      segments = (arc_angle / (2 * Math.asin(max_segment_length / (radius * 2))))
                   .ceil
                   .clamp(min_num_segments, max_num_segments)
      segments += 1 if segments.odd?
      segments
    end

    def _draw_box(entities, bounds)

      kb = Kuix::Bounds3d.new.copy!(bounds)
      kb.get_sliced_quads.each do |quad|
        entities.add_face(quad)
      end

    end

    def _draw_prism(entities, bxf_prism)

      z_value = bxf_cylinder.z_value.to_l

      btm_pts = bxf_prism.base_points.map(&:to_p)
      top_pts = bxf_prism.base_points.map { |p| p.to_p.offset(Z_AXIS, z_value) }

      entities.add_face(btm_pts)
      entities.add_face(top_pts)

      btm_pts.zip(top_pts).each do |btm_pt, top_pt|
        edge = entities.add_line(btm_pt, top_pt)
        edge.find_faces if edge
      end

    end

    def _draw_cylinder(entities, bxf_cylinder)

      radius = bxf_cylinder.radius.to_l
      z_value = bxf_cylinder.z_value.to_l

      num_segments = _num_segments_by_radius(radius)

      b_edges = entities.add_circle(ORIGIN, Z_AXIS, radius, num_segments)
      z_edges = entities.add_circle(ORIGIN.offset(Z_AXIS, z_value), Z_AXIS, radius, num_segments)

      b_face = group.entities.add_face(b_edges)
      b_face.reverse! if b_face.normal.samedirection?(Z_AXIS)
      z_face = group.entities.add_face(z_edges)
      z_face.reverse! unless z_face.normal.samedirection?(Z_AXIS)

      b_edges.zip(z_edges).each do |b_edge, z_edge|
        edge = entities.add_line(b_edge.start.position, z_edge.start.position)
        if edge
          edge.smooth = edge.soft = true
          edge.find_faces
        end
      end

    end

    def _draw_machining(entities, bxf_machining, transformation = IDENTITY)

      if (ref_group = (@machining_factory ||= {})[bxf_machining]).nil?

        group = entities.add_group
        group.transformation = transformation
        group.layer = _get_machining_layer
        group.material = _get_machining_material

        # Keep group as reference
        @machining_factory[bxf_machining] = group

        # Draw content
        if bxf_machining.is_a?(Bxf::BxfMachiningDrilling)

          group.name = 'MACHINING-DRILLING'

          radius = bxf_machining.radius.to_l
          depth = bxf_machining.depth.to_l

          depth_v = bxf_machining.depth_orientation.to_v

          num_segments = _num_segments_by_radius(radius, max_num_segments: 12)

          b_edges = group.entities.add_circle(ORIGIN, depth_v, radius, num_segments)
          z_edges = group.entities.add_circle(ORIGIN.offset(depth_v, depth), depth_v, radius, num_segments)

          b_face = group.entities.add_face(b_edges)
          b_face.reverse! if b_face.normal.samedirection?(depth_v)
          z_face = group.entities.add_face(z_edges)
          z_face.reverse! unless z_face.normal.samedirection?(depth_v)

          b_edges.zip(z_edges).each do |b_edge, z_edge|
            edge = group.entities.add_line(b_edge.start.position, z_edge.start.position)
            if edge
              edge.smooth = edge.soft = true
              edge.find_faces
            end
          end

        elsif bxf_machining.is_a?(Bxf::BxfMachiningRounding)

          group.name = 'MACHINING-ROUNDING'

          radius = bxf_machining.radius.to_l
          length = bxf_machining.length.to_l

          length_v = bxf_machining.length_orientation.to_v

          num_segments = _num_segments_by_radius(radius, min_num_segments: 4, max_num_segments: 12, arc_angle: Geometrix::HALF_PI)

          arc_origin = ORIGIN
                         .offset(X_AXIS, -radius)
                         .offset(Z_AXIS, radius)

          btm_edge1, _ = group.entities.add_arc(arc_origin, X_AXIS, length_v, radius, 0, Geometrix::HALF_PI, num_segments)
          top_edge1, _ = group.entities.add_arc(arc_origin.offset(length_v, length), X_AXIS, length_v, radius, 0, Geometrix::HALF_PI, num_segments)

          btn_vertices = btm_edge1.curve.vertices
          top_vertices = top_edge1.curve.vertices

          group.entities.add_face(btn_vertices.map(&:position) + [ ORIGIN ])
          group.entities.add_face(top_vertices.map(&:position) + [ ORIGIN.offset(length_v, length) ]).reverse!
          group.entities.add_line(ORIGIN, ORIGIN.offset(length_v, length))

          last_index = btn_vertices.size - 1
          btn_vertices.each_with_index do |btm_vertex, index|
            top_vertex = top_vertices[index]
            smooth_soft = index > 0 && index < last_index
            edge = group.entities.add_line(btm_vertex.position, top_vertex.position)
            if edge
              edge.smooth = edge.soft = smooth_soft
              edge.find_faces
            end
          end

        elsif bxf_machining.is_a?(Bxf::BxfMachiningRabbet)

          group.name = 'MACHINING-RABBET'

          radius = bxf_machining.radius.to_l
          length = bxf_machining.length.to_l
          depth = bxf_machining.depth.to_l

          length_v = bxf_machining.length_orientation.to_v
          depth_v = bxf_machining.depth_orientation.to_v
          width_v = length_v.cross(depth_v)

          bounds = Geom::BoundingBox.new
          bounds.add(
            ORIGIN.offset(width_v, -radius), # P0
            ORIGIN.offset(width_v, radius)
                  .offset(depth_v, depth)
                  .offset(length_v, length)  # P2+Z
          )

          _draw_box(group.entities, bounds)

        elsif bxf_machining.is_a?(Bxf::BxfMachiningGroove)

          group.name = 'MACHINING-GROOVE'

          length_v = bxf_machining.length_orientation.to_v
          depth_v = bxf_machining.depth_orientation.to_v
          width_v = length_v.cross(depth_v)

          bounds = Geom::BoundingBox.new
          bounds.add(
            ORIGIN.offset(width_v, -bxf_machining.radius.to_l), # P0
            ORIGIN.offset(width_v, bxf_machining.radius.to_l)
                  .offset(depth_v, bxf_machining.depth.to_l)
                  .offset(length_v, bxf_machining.length.to_l)  # P2+Z
          )

          _draw_box(group.entities, bounds)

        elsif bxf_machining.is_a?(Bxf::BxfMachiningRoundedGroove)

          group.name = 'MACHINING-ROUNDED-GROOVE'

          length_v = bxf_machining.length_orientation.to_v
          depth_v = bxf_machining.depth_orientation.to_v
          width_v = length_v.cross(depth_v)

          bounds = Geom::BoundingBox.new
          bounds.add(
            ORIGIN.offset(width_v, -bxf_machining.radius.to_l), # P0
            ORIGIN.offset(width_v, bxf_machining.radius.to_l)
                  .offset(depth_v, bxf_machining.depth.to_l)
                  .offset(length_v, bxf_machining.length.to_l)  # P2+Z
          )

          _draw_box(group.entities, bounds)

        elsif bxf_machining.is_a?(Bxf::BxfMachiningGlue)

          group.name = 'MACHINING-GLUE'

          length_v = bxf_machining.length_orientation.to_v
          thickness_v = bxf_machining.thickness_orientation.to_v
          width_v = length_v.cross(thickness_v)

          radius = bxf_machining.width.to_l / 2

          bounds = Geom::BoundingBox.new
          bounds.add(
            ORIGIN.offset(width_v, -radius), # P0
            ORIGIN.offset(width_v, radius)
                  .offset(thickness_v, bxf_machining.thickness.to_l)
                  .offset(length_v, bxf_machining.length.to_l)  # P2+Z
          )

          _draw_box(group.entities, bounds)

        elsif bxf_machining.is_a?(Bxf::BxfMachiningChamfer)

          group.name = 'MACHINING-CHAMFER'

          length_v = bxf_machining.length_orientation.to_v
          length = bxf_machining.length.to_l

          pts0 = [
            ORIGIN,
            ORIGIN.offset(bxf_machining.distance1_orientation.to_v, bxf_machining.distance1.to_l),
            ORIGIN.offset(bxf_machining.distance2_orientation.to_v, bxf_machining.distance2.to_l)
          ]
          pts1 = pts0.map { |pt| pt.offset(length_v, length) }

          group.entities.add_face(pts0)
          group.entities.add_face(pts1)
          pts0.zip(pts1).each { |pt0, pt1| group.entities.add_edges(pt0, pt1).each(&:find_faces) }

        end

      else
        group = entities.add_instance(ref_group.definition, transformation)
        group.name = ref_group.name
        group.layer = ref_group.layer
        group.material = ref_group.material
      end

    end

    # -- Materials --

    def _get_part_material(bxf_material)
      return nil unless bxf_material.is_a?(Bxf::BxfMaterial)
      case bxf_material.name
      when 'wood'
        name = @part_wood_material_name
        color = WOOD_MATERIAL_COLOR
        grained = bxf_material.is_a?(Bxf::BxfWoodMaterial) && bxf_material.grain_direction.to_v.valid?   # Not implemented yet in Blum configurators
      when 'aluminium'
        name = @part_aluminium_material_name
        color = ALUMINIUM_MATERIAL_COLOR
        grained = false
      when 'glass'
        name = @part_glass_material_name
        color = GLASS_MATERIAL_COLOR
        grained = false
      else
        name = nil
        color = nil
        grained = false
      end
      return nil unless name.is_a?(String) && !name.empty?
      material = Sketchup.active_model.materials[name]
      if material.nil?

        # Create a new TYPE_SHEET_GOOD material for the part
        material = Sketchup.active_model.materials.add(name)
        material.color = color
        material.alpha = color.alpha / 255.0  if color

        ma = MaterialAttributes.new(material, false, MaterialAttributes::TYPE_SHEET_GOOD)
        ma.grained = grained
        ma.write_to_attributes

      end
      material
    end

    def _get_machining_material
      return nil unless @machining_material_name.is_a?(String) && !@machining_material_name.empty?
      material = Sketchup.active_model.materials[@machining_material_name]
      if material.nil?

        # Create a new TYPE_MACHINING material for the machining
        material = Sketchup.active_model.materials.add(@machining_material_name)
        material.color = '#0068ff'
        ma = MaterialAttributes.new(material)
        ma.type = MaterialAttributes::TYPE_MACHINING
        ma.write_to_attributes

      end
      material
    end

    def _get_hardware_material
      return nil unless @hardware_material_name.is_a?(String) && !@hardware_material_name.empty?
      material = Sketchup.active_model.materials[@hardware_material_name]
      if material.nil?

        # Create a new TYPE_HARWARE material for the component
        material = Sketchup.active_model.materials.add(@hardware_material_name)
        material.color = BLUM_COLOR
        ma = MaterialAttributes.new(material)
        ma.type = MaterialAttributes::TYPE_HARDWARE
        ma.write_to_attributes

      end
      material
    end

    # -- Layers --

    def _get_front_part_layer
      return nil unless @front_part_layer_name.is_a?(String) && !@front_part_layer_name.empty?
      layer = Sketchup.active_model.layers[@front_part_layer_name]
      if layer.nil?

        layer = Sketchup.active_model.layers.add(@front_part_layer_name)
        layer.color = '#05d6a0'

      end
      layer
    end

    def _get_machining_layer
      return nil unless @machining_layer_name.is_a?(String) && !@machining_layer_name.empty?
      layer = Sketchup.active_model.layers[@machining_layer_name]
      if layer.nil?

        layer = Sketchup.active_model.layers.add(@machining_layer_name)
        layer.color = '#0068ff'

      end
      layer
    end

    def _get_hardware_layer
      return nil unless @hardware_layer_name.is_a?(String) && !@hardware_layer_name.empty?
      layer = Sketchup.active_model.layers[@hardware_layer_name]
      if layer.nil?

        layer = Sketchup.active_model.layers.add(@hardware_layer_name)
        layer.color = BLUM_COLOR

      end
      layer
    end

  end

  require_relative '../../../tool/smart_tool'

  class ImportersBxf2PlaceTool < SmartTool

    ACTION_PLACE = 0

    ACTIONS = [
      {
        :action => ACTION_PLACE,
      }
    ].freeze

    attr_reader :bxf_model, :callback

    def initialize(bxf_model, &callback)
      super()

      @bxf_model = bxf_model
      @callback = callback

    end

    def get_stripped_name
      'importers_bxf2'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    # -- Events --

    def onActionChanged(action)

      case action
      when ACTION_PLACE
        set_action_handler(ImportersBxf2PlaceActionHandler.new(self))

      end

      super
    end

    def onViewChanged(view)
      super
      refresh
    end

    def onTransactionUndo(model)
      super
      refresh
    end

  end

  class ImportersBxf2PlaceActionHandler < SmartActionHandler

    def initialize(tool)
      super(ImportersBxf2PlaceTool::ACTION_PLACE, tool)

      @mouse_ip = SmartInputPoint.new(tool)

      @box_bounds = tool.bxf_model.bounds

    end

    # -- STATE --

    def get_state_status(state)
      PLUGIN.get_i18n_string("tool.smart_#{@tool.get_stripped_name}.action_#{@action}_status") + '.'
    end

    # -----

    def onToolCancel(tool, reason, view)
      super
      tool.callback.call(true, nil)
    end

    def onToolMouseMove(tool, flags, x, y, view)
      return true if super

      @mouse_ip.pick(view, x, y)

      tool.clear_all_3d

      _preview(view)

      view.tooltip = @mouse_ip.tooltip
      view.invalidate

    end

    def onToolMouseLeave(tool, view)
      tool.clear_all_3d
      @mouse_ip.clear
      view.tooltip = ''
      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)
      t = _get_transformation
      tool.callback.call(false, t * Geom::Transformation.translation(@mouse_ip.position.transform(t.inverse)))
    end

    # -----

    def draw(view)
      super
      @mouse_ip.draw(view) if @mouse_ip.valid?
    end

    # -----

    private

    def _get_transformation
      Geom::Transformation.axes(ORIGIN.transform(_get_edit_transformation), _get_active_x_axis, _get_active_y_axis, _get_active_z_axis) * ImportersBxf2ImportWorker::NODE_UP_TRANSFORM
    end

    def _preview(view)

      t = _get_transformation
      ti = t.inverse

      p = @mouse_ip.position.transform(ti)

      k_box = Kuix::BoxMotif3d.new
      k_box.bounds.copy!(@box_bounds)
      k_box.bounds.translate!(*p)
      k_box.line_width = 1.0
      k_box.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_box.color = Kuix::COLOR_BLACK
      k_box.transformation = t
      @tool.append_3d(k_box)

      k_box = Kuix::BoxFillMotif3d.new
      k_box.bounds.copy!(@box_bounds)
      k_box.bounds.origin.translate!(*p)
      k_box.color = ColorUtils.color_translucent(ImportersBxf2ImportWorker::BLUM_COLOR, 0.3)
      k_box.transformation = t
      @tool.append_3d(k_box)

    end

  end

end
