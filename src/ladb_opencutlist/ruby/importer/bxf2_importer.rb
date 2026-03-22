module Ladb::OpenCutList

  require_relative '../lib/rubybxf/bxf'
  require_relative '../model/attributes/material_attributes'

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

      @materials_factory = nil
      @parts_factory = nil
      @components_factory = nil

      @file_path = file_path

      SKETCHUP_CONSOLE.clear

      model = Sketchup.active_model
      model.start_operation('Import BXF2', false)

      begin

        bxf_model = Bxf::BxfModel.load(file_path)
        bxf_model.scene.nodes.each do |node|

          entities = model.active_entities
          transformation = Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS, Y_AXIS.reverse) * node.transformations.to_t

          _process_cabinet_group_links(node.cabinet_group_links, entities, transformation)
          _process_cabinet_links(node.cabinet_links, entities, transformation)
          _process_container_links(node.container_links, entities, transformation)
          _process_function_unit_links(node.function_unit_links, entities, transformation)

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
        part_name = 'PART' if part_name.nil? || part_name.empty?

        definition = (@parts_factory ||= {})[part] ||= begin
                                                         definition = Sketchup.active_model.definitions.add(part_name)
                                                         _draw_box(definition.entities, part.geometry.extent.to_b)
                                                         definition
                                                       end

        instance = entities.add_instance(definition, part_link.transformations.to_t)
        instance.material = (@materials_factory ||= {})['part'] ||= begin
                                                                      m = Sketchup.active_model.materials['PANEL']
                                                                      if m.nil?
                                                                        m = Sketchup.active_model.materials.add('PANEL')
                                                                        m.color = 'white'
                                                                        ma = MaterialAttributes.new(m)
                                                                        ma.type = MaterialAttributes::TYPE_SHEET_GOOD
                                                                        ma.write_to_attributes
                                                                      end
                                                                      m
                                                                    end

        _process_inherited_machinings(part.inherited_machinings, definition.entities)
        _process_machining_group_links(part.machining_group_links, definition.entities, IDENTITY)
        _process_machining_links(part.machining_links, definition.entities, IDENTITY)

      end

    end

    def _process_container_links(container_links, entities, transformation = IDENTITY)

      container_links.each do |container_link|
        _process_function_unit_links(container_link.container.function_unit_links, entities, transformation * container_link.transformations.to_t)
      end

    end

    def _process_function_unit_links(function_unit_links, entities, transformation = IDENTITY)

      function_unit_links.each do |function_unit_link|

        function_unit = function_unit_link.function_unit

        group = entities.add_group
        group.name = function_unit.description if function_unit.description
        group.transformation = transformation * function_unit_link.transformations.to_t

        # _process_article_links(function_unit.article_links, group.entities)
        _process_part_links(function_unit.part_links, group.entities)
        _process_component_links(function_unit.component_links, group.entities)

      end

    end

    def _process_component_links(component_links, entities)

      component_links.each do |component_link|

        component = component_link.component
        article = component.article

        definition = (@components_factory ||= {})[component] ||= begin
                                                                   component_name = "#{"#{article.article_number}_" if article}#{component.component_number}"
                                                                   definition = Sketchup.active_model.definitions[component_name]
                                                                   if definition.nil?
                                                                     begin
                                                                       base_path = File.dirname(File.expand_path(@file_path))
                                                                       file_name = "#{component_name}.dae"
                                                                       file_path = File.join(base_path, "cadData", file_name)
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
                                                                     definition.description = article.description if article && article.description
                                                                   end
                                                                   definition
                                                                 end

        instance = entities.add_instance(definition, component_link.transformations.to_t * Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS.reverse, Y_AXIS))
        instance.layer = Sketchup.active_model.layers.add('OCL_HARDWARE')
        instance.material = (@materials_factory ||= {})['Hardware'] ||= begin
                                                                          m = Sketchup.active_model.materials['HARDWARE']
                                                                          if m.nil?
                                                                            m = Sketchup.active_model.materials.add('HARDWARE')
                                                                            m.color = 'white'
                                                                            ma = MaterialAttributes.new(m)
                                                                            ma.type = MaterialAttributes::TYPE_HARDWARE
                                                                            ma.write_to_attributes
                                                                          end
                                                                          m
                                                                        end

        _process_machining_group_links(component.machining_group_links, definition.entities)
        _process_machining_links(component.machining_links, definition.entities)

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

    def _process_machining_links(machining_links, entities, transformation = IDENTITY)

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

      edges = entities.add_circle(ORIGIN, Z_AXIS, bxf_cylinder.radius.to_l, 16)
      edges.first.find_faces
      group.entities.grep(Sketchup::Face).first.pushpull(bxf_cylinder.z_value.to_l)

    end

    def _draw_machining(entities, bxf_machining, transformation = IDENTITY)

      group = entities.add_group
      group.transformation = transformation
      group.layer = Sketchup.active_model.layers.add('OCL_MACHINING')
      group.material = (@materials_factory ||= {})['Machining'] ||= begin
                                                                      m = Sketchup.active_model.materials['MACHINING']
                                                                      if m.nil?
                                                                        m = Sketchup.active_model.materials.add('MACHINING')
                                                                        m.color = 'blue'
                                                                      end
                                                                      m
                                                                    end

      if bxf_machining.is_a?(Bxf::BxfMachiningCut)

        group.name = 'MACHINING-CUT'

        # TODO

        puts "TODO: BxfMachiningCut"

      elsif bxf_machining.is_a?(Bxf::BxfMachiningDrilling)

        group.name = 'MACHINING-DRILLING'

        edges = group.entities.add_circle(ORIGIN, bxf_machining.depth_orientation.to_v, bxf_machining.radius.to_l, 16)
        edges.first.find_faces
        group.entities.grep(Sketchup::Face).first.pushpull(bxf_machining.depth.to_l)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningRounding)

        group.name = 'MACHINING-ROUNDING'

        # TODO

        puts "TODO: BxfMachiningRounding"

      elsif bxf_machining.is_a?(Bxf::BxfMachiningRabbet)

        group.name = 'MACHINING-RABBET'

        length_v = bxf_machining.length_orientation.to_v
        depth_v = bxf_machining.depth_orientation.to_v
        width_v = length_v.cross(depth_v)

        bounds = Geom::BoundingBox.new
        bounds.add(ORIGIN
                     .offset(width_v, bxf_machining.radius.to_l)
        )
        bounds.add(ORIGIN
                     .offset(width_v, -bxf_machining.radius.to_l)
                     .offset(length_v, bxf_machining.length.to_l)
        )
        bounds.add(ORIGIN
                     .offset(depth_v, bxf_machining.depth.to_l)
        )

        _draw_box(group.entities, bounds)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningGroove)

        group.name = 'MACHINING-GROOVE'

        length_v = bxf_machining.length_orientation.to_v
        depth_v = bxf_machining.depth_orientation.to_v
        width_v = length_v.cross(depth_v)

        bounds = Geom::BoundingBox.new
        bounds.add(ORIGIN
                     .offset(width_v, bxf_machining.radius.to_l)
        )
        bounds.add(ORIGIN
                     .offset(width_v, -bxf_machining.radius.to_l)
                     .offset(length_v, bxf_machining.length.to_l)
        )
        bounds.add(ORIGIN
                     .offset(depth_v, bxf_machining.depth.to_l)
        )

        _draw_box(group.entities, bounds)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningRoundedGroove)

        group.name = 'MACHINING-ROUNDED-GROOVE'

        length_v = bxf_machining.length_orientation.to_v
        depth_v = bxf_machining.depth_orientation.to_v
        width_v = length_v.cross(depth_v)

        bounds = Geom::BoundingBox.new
        bounds.add(ORIGIN
                     .offset(width_v, bxf_machining.radius.to_l)
        )
        bounds.add(ORIGIN
                     .offset(width_v, -bxf_machining.radius.to_l)
                     .offset(length_v, bxf_machining.length.to_l)
        )
        bounds.add(ORIGIN
                     .offset(depth_v, bxf_machining.depth.to_l)
        )

        puts 'TODO: BxfMachiningRoundedGroove'

      elsif bxf_machining.is_a?(Bxf::BxfMachiningGlue)

        group.name = 'MACHINING-GLUE'

        length_v = bxf_machining.length_orientation.to_v
        thickness_v = bxf_machining.thickness_orientation.to_v
        width_v = length_v.cross(thickness_v)

        radius = bxf_machining.width.to_l / 2

        bounds = Geom::BoundingBox.new
        bounds.add(ORIGIN
                     .offset(width_v, radius)
        )
        bounds.add(ORIGIN
                     .offset(width_v, -radius)
                     .offset(length_v, bxf_machining.length.to_l)
        )
        bounds.add(ORIGIN
                     .offset(thickness_v, bxf_machining.thickness.to_l)
        )

        _draw_box(group.entities, bounds)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningChamfer)

        group.name = 'MACHINING-CHAMFER'

        pts0 = [
          ORIGIN,
          ORIGIN.offset(bxf_machining.distance1_orientation.to_v, bxf_machining.distance1.to_l),
          ORIGIN.offset(bxf_machining.distance2_orientation.to_v, bxf_machining.distance1.to_l)
        ]
        pts1 = pts0.map { |pt| pt.offset(bxf_machining.length_orientation.to_v, bxf_machining.length.to_l)}

        group.entities.add_face(pts0)
        group.entities.add_face(pts1)
        pts0.zip(pts1).each { |pt0, pt1| group.entities.add_edges(pt0, pt1).each(&:find_faces) }

      end

    end

  end

end
