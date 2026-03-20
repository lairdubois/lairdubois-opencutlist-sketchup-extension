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
          puts "node: #{node.description}"

          group = model.active_entities.add_group
          group.name = node.description ? node.description : node.class.name
          group.transformation = Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS, Y_AXIS.reverse)

          _process_cabinet_links(group.entities, node)
          _process_container_links(group.entities, node)
          _process_function_unit_links(group.entities, node)

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

    def _process_cabinet_links(entities, o, depth = 0)

      puts "#{'-'.rjust(depth)} #{o.cabinet_links.count} cabinet_links"
      o.cabinet_links.each do |cabinet_link|
        puts "#{' '.rjust(depth)} cabinet_link: #{cabinet_link.description} ref=#{cabinet_link.reference_id}"
        puts "#{' '.rjust(depth)} ↳ cabinet: #{cabinet_link.cabinet}"

        cabinet = cabinet_link.cabinet

        group = entities.add_group
        group.name = cabinet_link.description if cabinet_link.description

        _process_part_links(group.entities, cabinet, depth + 1)
        _process_function_unit_links(group.entities, cabinet, depth + 1)
        _process_container_links(group.entities, cabinet, depth + 1)

      end

    end

    def _process_part_links(entities, o, depth = 0)

      puts "#{'-'.rjust(depth)} #{o.part_links.count} part_links"
      o.part_links.each do |part_link|
        puts "#{' '.rjust(depth)} part_link: ref=#{part_link.reference_id}"
        puts "#{' '.rjust(depth)} ↳ part_link: #{part_link.part}"

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

        _process_inherited_machinings(definition.entities, part, depth + 1)
        _process_machining_links(definition.entities, part, depth + 1)

      end

    end

    def _process_function_unit_links(entities, o, depth = 0)

      puts "#{'-'.rjust(depth)} #{o.function_unit_links.count} function_unit_links"
      o.function_unit_links.each do |function_unit_link|
        puts "#{' '.rjust(depth)} function_unit_link: ref=#{function_unit_link.reference_id}"
        puts "#{' '.rjust(depth)} ↳ function_unit: #{function_unit_link.function_unit}"

        function_unit = function_unit_link.function_unit

        group = entities.add_group
        group.name = function_unit.description ? function_unit.description : function_unit.class.name
        group.transformation = function_unit_link.transformations.to_t

        # _process_article_links(group.entities, function_unit, depth + 1)
        _process_part_links(group.entities, function_unit, depth + 1)
        # _process_component_links(group.entities, function_unit, depth + 1)

      end

    end

    def _process_container_links(entities, o, depth = 0)

      puts "#{'-'.rjust(depth)} #{o.container_links.count} container_links"
      o.container_links.each do |container_link|
        puts "#{' '.rjust(depth)} container_link: ref=#{container_link.reference_id}"
        puts "#{' '.rjust(depth)} ↳ container: #{container_link.container}"

        container = container_link.container

        group = entities.add_group
        group.name = container.description ? container.description : container.class.name
        group.transformation = container_link.transformations.to_t

        _process_function_unit_links(group.entities, container, depth + 1)

      end

    end

    def _process_component_links(entities, o, depth = 0)

      puts "#{'-'.rjust(depth)} #{o.component_links.count} component_links"
      o.component_links.each do |component_link|
        puts "#{' '.rjust(depth)} component_link: ref=#{component_link.reference_id}"
        puts "#{' '.rjust(depth)} ↳ component: #{component_link.component}"

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
                                                                   end
                                                                   definition
                                                                 end

        instance = entities.add_instance(definition, component_link.transformations.to_t * Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS.reverse, Y_AXIS))
        instance.material = 'RED'
        instance.layer = Sketchup.active_model.layers.add('Hardware')

      end

    end

    def _process_article_links(entities, o, depth = 0)

      puts "#{'-'.rjust(depth)} #{o.article_links.count} article_links"
      o.article_links.each do |article_link|
        puts "#{' '.rjust(depth)} article_link: ref=#{article_link.reference_id}"
        puts "#{' '.rjust(depth)} ↳ article: #{article_link.article}"
      end

    end

    def _process_inherited_machinings(entities, o, depth = 0)

      puts "#{'-'.rjust(depth)} #{o.inherited_machinings.count} inherited_machinings"
      o.inherited_machinings.each do |inherited_machining|

        component_link = inherited_machining.component_link
        component = component_link.component

        puts "#{'-'.rjust(depth)} #{inherited_machining.machining_group_link_references.count} machining_group_link_references"
        inherited_machining.machining_group_link_references.each do |machining_group_link_reference|
          puts "#{' '.rjust(depth + 2)} machining_group_link_reference: ref=#{machining_group_link_reference.reference_id}"

          machining_group_link = component.related_machining_group_links.find { |link| link.id == machining_group_link_reference.reference_id }
          machining_group = machining_group_link.machining_group

          puts "#{'-'.rjust(depth + 3)} #{machining_group.machining_links.count} machining_links"
          machining_group.machining_links.each do |machining_link|
            puts "#{' '.rjust(depth + 4)} machining_link: ref=#{machining_link.reference_id}"
            puts "#{' '.rjust(depth + 4)} ↳ machining_link: #{machining_link.machining}"

            machining = machining_link.machining

            _draw_machining(entities, machining, component_link.transformations.to_t * machining_group_link.transformations.to_t * machining_link.transformations.to_t)

          end

        end

        # puts "#{'-'.rjust(depth + 1)} #{component.machining_group_links.count} machining_group_links"
        # component.machining_group_links.each do |machining_group_link|
        #   puts "#{' '.rjust(depth + 2)} machining_group_link: ref=#{machining_group_link.reference_id}"
        #   puts "#{' '.rjust(depth + 2)} ↳ machining_group: #{machining_group_link.machining_group}"
        #
        #   machining_group = machining_group_link.machining_group
        #
        #   puts "#{'-'.rjust(depth + 3)} #{machining_group.machining_links.count} machining_links"
        #   component.machining_links.each do |machining_link|
        #     puts "#{' '.rjust(depth + 4)} machining_link: ref=#{machining_link.reference_id}"
        #     puts "#{' '.rjust(depth + 4)} ↳ machining_link: #{machining_link.machining}"
        #
        #     machining = machining_link.machining
        #
        #     _draw_machining(entities, machining, component_link.transformations.to_t * machining_link.transformations.to_t)
        #
        #   end
        #
        # end
        #
        # puts "#{'-'.rjust(depth + 1)} #{component.machining_links.count} machining_links"
        # component.machining_links.each do |machining_link|
        #   puts "#{' '.rjust(depth + 2)} machining_link: ref=#{machining_link.reference_id}"
        #   puts "#{' '.rjust(depth + 2)} ↳ machining_link: #{machining_link.machining}"
        #
        #   machining = machining_link.machining
        #
        #   _draw_machining(entities, machining, component_link.transformations.to_t * machining_link.transformations.to_t)
        #
        # end

      end

    end

    def _process_machining_links(entities, o, depth = 0)

      puts "#{'-'.rjust(depth)} #{o.machining_links.count} machining_links"
      o.machining_links.each do |machining_link|
        puts "#{' '.rjust(depth)} machining_link: ref=#{machining_link.reference_id}"
        puts "#{' '.rjust(depth)} ↳ machining_link: #{machining_link.machining}"

        machining = machining_link.machining

        _draw_machining(entities, machining, machining_link.transformations.to_t)

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
      group.name = 'MACHINING'
      group.material = 'BLUE'
      group.transformation = transformation
      group.layer = Sketchup.active_model.layers.add('Machining')

      if bxf_machining.is_a?(Bxf::BxfMachiningCut)

        # TODO

      elsif bxf_machining.is_a?(Bxf::BxfMachiningDrilling)

        edges = group.entities.add_circle(ORIGIN, bxf_machining.depth_orientation.to_v, bxf_machining.radius.to_l)
        edges.first.find_faces
        group.entities.grep(Sketchup::Face).first.pushpull(bxf_machining.depth.to_l)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningRounding)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningRabbet)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningGroove)

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

      elsif bxf_machining.is_a?(Bxf::BxfMachiningGlue)

      elsif bxf_machining.is_a?(Bxf::BxfMachiningChamfer)

      end

    end

  end

end
