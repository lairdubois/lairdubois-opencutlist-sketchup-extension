module Ladb::OpenCutList

  require_relative '../lib/rubybxf/bxf'

  class Bxf2Importer < Sketchup::Importer

    def description
      "OpenCutList BXF2 (*.bxf2)"
    end

    def file_extension
      "bxf2"
    end

    def id
      "fr.lairdubois.opencutlist.importers.bxf2"
    end

    def supports_options?
      false
    end

    def load_file(file_path, status)

      @file_path = file_path

      SKETCHUP_CONSOLE.clear

      model = Sketchup.active_model
      model.start_operation('Import BXF2', false)

      begin

        bxf_model = Bxf::BxfModel.load(file_path)
        bxf_model.scene.nodes.each do |node|

          group = model.active_entities.add_group
          group.name = node.description ? node.description : node.class.name
          group.transformation = Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS, Y_AXIS.reverse)

          _process_cabinet_links(group.entities, node.cabinet_links)
          _process_container_links(group.entities, node.container_links)
          _process_function_unit_links(group.entities, node.function_unit_links)

        end

      rescue Exception => e
        PLUGIN.dump_exception(e)
        Sketchup.active_model.abort_operation
        return Sketchup::Importer::ImportFail
      end

      Sketchup.active_model.commit_operation

      Sketchup::Importer::ImportSuccess
    end

    private

    def _process_cabinet_links(entities, cabinet_links, depth = 0)

      cabinet_links.each do |cabinet_link|

        cabinet = cabinet_link.cabinet

        group = entities.add_group
        group.name = cabinet_link.description if cabinet_link.description

        _process_part_links(group.entities, cabinet.part_links, depth + 1)
        _process_function_unit_links(group.entities, cabinet.function_unit_links, depth + 1)
        _process_container_links(group.entities, cabinet.container_links, depth + 1)

      end

    end

    def _process_part_links(entities, part_links, depth = 0)

      part_links.each do |part_link|

        part = part_link.part

        next if part.nil? || part.geometry.nil?

        part_name = part_link.description
        part_name = part.description if part_name.nil? || part_name.empty?
        part_name = 'PART' if part_name.nil? || part_name.empty?

        definition = (@parts_factory ||= {})[part] ||= begin
                                                         definition = Sketchup.active_model.definitions.add(part_name)
                                                         _draw_box(definition.entities, part.geometry.extent.to_b)
                                                         definition
                                                       end

        instance = entities.add_instance(definition, part_link.transformations.to_t)
        instance.layer = Sketchup.active_model.layers.add('Part')

        _process_inherited_machinings(definition.entities, part.inherited_machinings, depth + 1)
        _process_machining_group_links(definition.entities, part.machining_group_links, IDENTITY, depth + 1)
        _process_machining_links(definition.entities, part.machining_links, IDENTITY, depth + 1)

      end

    end

    def _process_function_unit_links(entities, function_unit_links, depth = 0)

      function_unit_links.each do |function_unit_link|

        function_unit = function_unit_link.function_unit

        group = entities.add_group
        group.name = function_unit.description ? function_unit.description : function_unit.class.name
        group.transformation = function_unit_link.transformations.to_t

        # _process_article_links(group.entities, function_unit.article_links, depth + 1)
        _process_part_links(group.entities, function_unit.part_links, depth + 1)
        _process_component_links(group.entities, function_unit.component_links, depth + 1)

      end

    end

    def _process_container_links(entities, container_links, depth = 0)

      container_links.each do |container_link|

        container = container_link.container

        group = entities.add_group
        group.name = container.description ? container.description : container.class.name
        group.transformation = container_link.transformations.to_t

        _process_function_unit_links(group.entities, container.function_unit_links, depth + 1)

      end

    end

    def _process_component_links(entities, component_links, depth = 0)

      component_links.each do |component_link|

        component = component_link.component
        article = component.article

        definition = (@components_factory ||= {})[component] ||= begin
                                                                   component_name = "#{article.article_number}_#{component.component_number}"
                                                                   definition = Sketchup.active_model.definitions[component_name]
                                                                   if definition.nil?
                                                                     begin
                                                                       base_path = File.dirname(File.expand_path(@file_path))
                                                                       file_path = File.join(base_path, "cadData", "#{component_name}.dae")
                                                                       definition = Sketchup.active_model.definitions.import(file_path, {
                                                                         validate_dae: true,
                                                                         merge_coplanar_faces: true
                                                                       })
                                                                       definition.name = component_name
                                                                     rescue Exception => e
                                                                       puts "Error loading component: #{file_path} #{e.message}"
                                                                       definition = Sketchup.active_model.definitions.add(component_name)
                                                                       _draw_box(definition.entities, Geom::BoundingBox.new.add(
                                                                         [-10.mm, -10.mm, -10.mm],
                                                                         [10.mm, 10.mm, 10.mm]
                                                                       ))
                                                                     end
                                                                     definition.description = article.description if article.description
                                                                   end
                                                                   definition
                                                                 end

        instance = entities.add_instance(definition, component_link.transformations.to_t * Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS.reverse, Y_AXIS))
        instance.layer = Sketchup.active_model.layers.add('Hardware')
        instance.material = 'WHITE'

      end

    end

    def _process_article_links(entities, article_links, depth = 0)

      article_links.each do |article_link|
      end

    end

    def _process_inherited_machinings(entities, inherited_machinings, depth = 0)

      inherited_machinings.each do |inherited_machining|

        component_link = inherited_machining.component_link
        component = component_link.component

        machining_group_links = inherited_machining.machining_group_link_references.map { |reference| component.related_machining_group_links.find { |link| link.id == reference.reference_id } }
        _process_machining_group_links(entities, machining_group_links, component_link.transformations.to_t, depth + 1)

        machining_links = inherited_machining.machining_link_references.map { |reference| component.related_machining_links.find { |link| link.id == reference.reference_id } }
        _process_machining_links(entities, machining_links, component_link.transformations.to_t, depth + 1)

      end

    end

    def _process_machining_group_links(entities, machining_group_links, transformation = IDENTITY, depth = 0)

      machining_group_links.each do |machining_group_link|

        machining_group = machining_group_link.machining_group

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

              machining_group.machining_links.each do |machining_link|
                _draw_machining(entities, machining_link.machining, t0 * machining_link.transformations.to_t * t1)
              end

            end

          end

        else

          machining_group.machining_links.each do |machining_link|
            _draw_machining(entities, machining_link.machining, transformation * machining_group_link.transformations.to_t * machining_link.transformations.to_t)
          end

        end

      end

    end

    def _process_machining_links(entities, machining_links, transformation = IDENTITY, depth = 0)

      machining_links.each do |machining_link|
        _draw_machining(entities, machining_link.machining, transformation * machining_link.transformations.to_t)
      end

    end

    # -- Drawing --

    def _draw_box(entities, bounds)

      kb = Kuix::Bounds3d.new.copy!(bounds)
      entities.add_face(kb.get_quad(Kuix::Bounds3d::RIGHT))
      entities.add_face(kb.get_quad(Kuix::Bounds3d::TOP))
      entities.add_face(kb.get_quad(Kuix::Bounds3d::BACK))
      entities.add_face(kb.get_quad(Kuix::Bounds3d::LEFT))
      entities.add_face(kb.get_quad(Kuix::Bounds3d::BOTTOM))
      entities.add_face(kb.get_quad(Kuix::Bounds3d::FRONT))

    end

    def _draw_prism(entities, bxf_prism)

      face = entities.add_face(bxf_prism.base_points.map(&:to_p))
      face.pushpull(-bxf_prism.z_value.to_l)

    end

    def _draw_cylinder(entities, bxf_cylinder)

      edges = entities.add_circle(ORIGIN, Z_AXIS, bxf_cylinder.radius.to_l)
      face, _ = edges.first.find_faces
      face.pushpull(-bxf_cylinder.z_value.to_l)

    end

    def _draw_machining(entities, bxf_machining, transformation = IDENTITY)

      group = entities.add_group
      group.material = 'BLUE'
      group.transformation = transformation
      group.layer = Sketchup.active_model.layers.add('Machining')

      if bxf_machining.is_a?(Bxf::BxfMachiningCut)

        group.name = 'MACHINING-CUT'

        # TODO

        puts "TODO: BxfMachiningCut"

      elsif bxf_machining.is_a?(Bxf::BxfMachiningDrilling)

        group.name = 'MACHINING-DRILLING'

        edges = group.entities.add_circle(ORIGIN, bxf_machining.depth_orientation.to_v, bxf_machining.radius.to_l, 12)
        edges.first.find_faces
        group.entities.grep(Sketchup::Face).first.pushpull(bxf_machining.depth.to_l)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningRounding)

        group.name = 'MACHINING-ROUNDING'

        # TODO

        puts "TODO: BxfMachiningRounding"

      elsif bxf_machining.is_a?(Bxf::BxfMachiningRabbet)

        group.name = 'MACHINING-RABBET'

        x_axis = bxf_machining.length_orientation.to_v
        z_axis = bxf_machining.depth_orientation.to_v
        y_axis = x_axis.cross(z_axis)

        bounds = Geom::BoundingBox.new
        bounds.add(ORIGIN
                     .offset(y_axis, bxf_machining.radius.to_l)
        )
        bounds.add(ORIGIN
                     .offset(y_axis, -bxf_machining.radius.to_l)
                     .offset(x_axis, bxf_machining.length.to_l)
        )
        bounds.add(ORIGIN
                     .offset(z_axis, bxf_machining.depth.to_l)
        )

        _draw_box(group.entities, bounds)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningGroove)

        group.name = 'MACHINING-GROOVE'

        x_axis = bxf_machining.length_orientation.to_v
        z_axis = bxf_machining.depth_orientation.to_v
        y_axis = x_axis.cross(z_axis)

        bounds = Geom::BoundingBox.new
        bounds.add(ORIGIN
                     .offset(y_axis, bxf_machining.radius.to_l)
        )
        bounds.add(ORIGIN
                     .offset(y_axis, -bxf_machining.radius.to_l)
                     .offset(x_axis, bxf_machining.length.to_l)
        )
        bounds.add(ORIGIN
                     .offset(z_axis, bxf_machining.depth.to_l)
        )

        _draw_box(group.entities, bounds)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningRoundedGroove)

        group.name = 'MACHINING-ROUNDED-GROOVE'

        # TODO

        puts 'TODO: BxfMachiningRoundedGroove'

      elsif bxf_machining.is_a?(Bxf::BxfMachiningGlue)

        group.name = 'MACHINING-GLUE'

        x_axis = bxf_machining.length_orientation.to_v
        z_axis = bxf_machining.thickness_orientation.to_v
        y_axis = x_axis.cross(z_axis)

        radius = bxf_machining.width.to_l / 2

        bounds = Geom::BoundingBox.new
        bounds.add(ORIGIN
                     .offset(y_axis, radius)
        )
        bounds.add(ORIGIN
                     .offset(y_axis, -radius)
                     .offset(x_axis, bxf_machining.length.to_l)
        )
        bounds.add(ORIGIN
                     .offset(z_axis, bxf_machining.thickness.to_l)
        )

        _draw_box(group.entities, bounds)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningChamfer)

        group.name = 'MACHINING-CHAMFER'

        # TODO

        puts 'TODO: BxfMachiningChamfer'

      end

    end

  end

end
