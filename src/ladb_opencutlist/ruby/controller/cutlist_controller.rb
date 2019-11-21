module Ladb::OpenCutList

  require 'pathname'
  require 'csv'
  require 'set'
  require_relative 'controller'
  require_relative '../model/scale3d'
  require_relative '../model/size3d'
  require_relative '../model/face_info'
  require_relative '../model/instance_info'
  require_relative '../model/cutlistdef'
  require_relative '../model/groupdef'
  require_relative '../model/partdef'
  require_relative '../model/material_usage'
  require_relative '../model/material_attributes'
  require_relative '../model/definition_attributes'
  require_relative '../utils/model_utils'
  require_relative '../utils/path_utils'
  require_relative '../utils/transformation_utils'
  require_relative '../utils/dimension_utils'
  require_relative '../tool/highlight_part_tool'
  
  require_relative '../lib/bin_packing_1d/packengine'
  require_relative '../lib/bin_packing_2d/packengine'

  class CutlistController < Controller

    MATERIAL_ORIGIN_UNKNOW = 0
    MATERIAL_ORIGIN_OWNED = 1
    MATERIAL_ORIGIN_INHERITED = 2
    MATERIAL_ORIGIN_CHILD = 3

    EXPORT_OPTION_SOURCE_SUMMARY = 0
    EXPORT_OPTION_SOURCE_CUTLIST = 1
    EXPORT_OPTION_SOURCE_INSTANCES_LIST = 2

    EXPORT_OPTION_COL_SEP_TAB = 0
    EXPORT_OPTION_COL_SEP_COMMA = 1
    EXPORT_OPTION_COL_SEP_SEMICOLON = 2

    EXPORT_OPTION_ENCODING_UTF8 = 0
    EXPORT_OPTION_ENCODING_UTF16LE = 1
    EXPORT_OPTION_ENCODING_UTF16BE = 2

    def initialize()
      super('cutlist')
    end

    def setup_commands()

      # Setup opencutlist dialog actions
      Plugin.instance.register_command("cutlist_generate") do |settings|
        generate_command(settings)
      end

      Plugin.instance.register_command("cutlist_export") do |settings|
        export_command(settings)
      end

      Plugin.instance.register_command("cutlist_numbers_save") do |settings|
        numbers_command(settings, false)
      end

      Plugin.instance.register_command("cutlist_numbers_reset") do |settings|
        numbers_command(settings, true)
      end

      Plugin.instance.register_command("cutlist_highlight_all_parts") do
        highlight_parts_command
      end

      Plugin.instance.register_command("cutlist_highlight_group_parts") do |group_id|
        highlight_parts_command(group_id)
      end

      Plugin.instance.register_command("cutlist_highlight_part") do |part_id|
        highlight_parts_command(nil, part_id)
      end

      Plugin.instance.register_command("cutlist_part_get_thumbnail") do |part_data|
        part_get_thumbnail_command(part_data)
      end

      Plugin.instance.register_command("cutlist_part_update") do |settings|
        part_update_command(settings)
      end

      Plugin.instance.register_command("cutlist_group_cuttingdiagram_1d") do |settings|
        group_cuttingdiagram_1d_command(settings)
      end

      Plugin.instance.register_command("cutlist_group_cuttingdiagram_2d") do |settings|
        group_cuttingdiagram_2d_command(settings)
      end

    end

    private

    # -- Commands --

    def generate_command(settings)

      # Clear previously generated cutlist
      @cutlist = nil

      # Clear layer0 cache
      @layer0 = nil

      # Clear previously generated entity infos
      @instance_infos_cache = {}

      # Setup caches
      @material_attributes_cache = {}     # Cleared after response
      @definition_attributes_cache = {}   # Cleared after response

      # Reset materials UUIDS
      MaterialAttributes::reset_used_uuids

      # [BEGIN] -- Utils definitions --

      # -- Cache Utils --

      def _get_material_attributes(material)
        key = material ? material.name : '$EMPTY$'
        unless @material_attributes_cache.has_key? key
          @material_attributes_cache[key] = MaterialAttributes.new(material, true)
        end
        @material_attributes_cache[key]
      end

      def _get_definition_attributes(definition)
        key = definition ? definition.name : '$EMPTY$'
        unless @definition_attributes_cache.has_key? key
          @definition_attributes_cache[key] = DefinitionAttributes.new(definition)
        end
        @definition_attributes_cache[key]
      end

      # -- Components utils --

      def _fetch_useful_instance_infos(entity, path, auto_orient)
        return 0 if entity.is_a? Sketchup::Edge   # Minor Speed improvement when there's a lot of edges
        face_count = 0
        if entity.visible? and (entity.layer.visible? or (entity.layer.equal?(@layer0) and !path.empty?))   # Layer0 hide entities only on root scene

          if entity.is_a? Sketchup::Group

            # Entity is a group : check its children
            entity.entities.each { |child_entity|
              face_count += _fetch_useful_instance_infos(child_entity, path + [ entity ], auto_orient)
            }

          elsif entity.is_a? Sketchup::ComponentInstance

            # Exclude special behavior components
            if entity.definition.behavior.always_face_camera?
              return 0
            end

            # Entity is a component instance : check its children
            entity.definition.entities.each { |child_entity|
              face_count += _fetch_useful_instance_infos(child_entity, path + [ entity ], auto_orient)
            }

            # Treat cuts_opening behavior component instances as group
            if entity.definition.behavior.cuts_opening?
              return face_count
            end

            # Considere component instance if it contains faces
            if face_count > 0

              bounds = _compute_faces_bounds(entity.definition, nil)
              unless bounds.empty? or [ bounds.width, bounds.height, bounds.depth ].min == 0    # Exclude empty or flat bounds

                # Create the instance info
                instance_info = InstanceInfo.new(path + [ entity ])
                instance_info.size = Size3d.create_from_bounds(bounds, instance_info.scale, auto_orient && !_get_definition_attributes(entity.definition).orientation_locked_on_axis)
                instance_info.definition_bounds = bounds

                # Add instance info to cache
                @instance_infos_cache[instance_info.serialized_path] = instance_info

                return 0
              end
            end

          elsif entity.is_a? Sketchup::Face

            # Entity is a face : return 1
            return 1

          end
        end
        face_count
      end

      # -- Bounds Utils --

      def _compute_faces_bounds(definition_or_group, transformation = nil)
        bounds = Geom::BoundingBox.new
        definition_or_group.entities.each { |entity|
          next if entity.is_a? Sketchup::Edge   # Minor Speed imrovement when there's a lot of edges
          if entity.visible? and (entity.layer.visible? or entity.layer.equal?(@layer0))
            if entity.is_a? Sketchup::Face
              face_bounds = entity.bounds
              if transformation
                min = face_bounds.min.transform(transformation)
                max = face_bounds.max.transform(transformation)
                face_bounds = Geom::BoundingBox.new
                face_bounds.add(min, max)
              end
              bounds.add(face_bounds)
            elsif entity.is_a? Sketchup::Group
              bounds.add(_compute_faces_bounds(entity, transformation ? transformation * entity.transformation : entity.transformation))
            elsif entity.is_a? Sketchup::ComponentInstance and entity.definition.behavior.cuts_opening?
              bounds.add(_compute_faces_bounds(entity.definition, transformation ? transformation * entity.transformation : entity.transformation))
            end
          end
        }
        bounds
      end

      # -- Faces Utils --

      def _grab_main_faces_and_layers(definition_or_group, x_face_infos = [], y_face_infos = [], z_face_infos = [], layers = Set[], transformation = nil)
        definition_or_group.entities.each { |entity|
          next if entity.is_a? Sketchup::Edge   # Minor Speed imrovement when there's a lot of edges
          if entity.visible? and (entity.layer.visible? or entity.layer.equal?(@layer0))
            if entity.is_a? Sketchup::Face
              transformed_normal = transformation.nil? ? entity.normal : entity.normal.transform(transformation)
              if transformed_normal.parallel?(X_AXIS)
                x_face_infos.push(FaceInfo.new(entity, transformation))
              elsif transformed_normal.parallel?(Y_AXIS)
                y_face_infos.push(FaceInfo.new(entity, transformation))
              elsif transformed_normal.parallel?(Z_AXIS)
                z_face_infos.push(FaceInfo.new(entity, transformation))
              end
              layers = layers + Set[ entity.layer ]
            elsif entity.is_a? Sketchup::Group
              _grab_main_faces_and_layers(entity, x_face_infos, y_face_infos, z_face_infos, layers + Set[ entity.layer ], transformation ? transformation * entity.transformation : entity.transformation)
            elsif entity.is_a? Sketchup::ComponentInstance and entity.definition.behavior.cuts_opening?
              _grab_main_faces_and_layers(entity.definition, x_face_infos, y_face_infos, z_face_infos, layers + Set[ entity.layer ], transformation ? transformation * entity.transformation : entity.transformation)
            end
          end
        }
        return x_face_infos, y_face_infos, z_face_infos, layers
      end

      def _face_infos_by_normal(normal, x_face_infos, y_face_infos, z_face_infos)
        case normal
          when X_AXIS
            x_face_infos
          when Y_AXIS
            y_face_infos
          when Z_AXIS
            z_face_infos
          else
            []
        end
      end

      def _populate_plane_grouped_face_infos_by_normal(normal, x_face_infos, y_face_infos, z_face_infos, transformation = nil)

        # Groups faces by plane
        plane_grouped_face_infos = {}
        _face_infos_by_normal(normal, x_face_infos, y_face_infos, z_face_infos).each { |face_info|
          t = TransformationUtils.multiply(transformation, face_info.transformation)
          transformed_plane = t.nil? ? face_info.face.plane : t * face_info.face.plane
          transformed_plane.map! { |v| v.round(4) }   # Round plane values with only 4 digits
          unless plane_grouped_face_infos.has_key?(transformed_plane)
            plane_grouped_face_infos.store(transformed_plane, [])
          end
          plane_grouped_face_infos[transformed_plane].push(face_info)
        }

        plane_grouped_face_infos
      end

      def _compute_largest_final_area(normal, x_face_infos, y_face_infos, z_face_infos, transformation = nil)

        plane_grouped_face_infos = _populate_plane_grouped_face_infos_by_normal(normal, x_face_infos, y_face_infos, z_face_infos, transformation)

        # Compute area of each group
        areas = []
        plane_grouped_face_infos.each do |plane, face_infos|
          areas.push(face_infos.inject(0) { |area, face_info|
            t = TransformationUtils.multiply(transformation, face_info.transformation)
            area + (t.nil? ? face_info.face.area : face_info.face.area(t))
          })
        end

        # Return plane count and max area
        return plane_grouped_face_infos.length, areas.max
      end

      def _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, axis)

        plane_count, final_area = _compute_largest_final_area(instance_info.size.oriented_normal(axis), x_face_infos, y_face_infos, z_face_infos, instance_info.transformation)
        area = instance_info.size.area_by_axis(axis)
        area_ratio = (final_area.nil? or area.nil?) ? 0 : final_area / area

        return plane_count, final_area, area_ratio
      end

      def _grab_oriented_min_max_face_infos(instance_info, x_face_infos, y_face_infos, z_face_infos, axis)

        min_face_infos = []
        max_face_infos = []
        plane_grouped_face_infos = _populate_plane_grouped_face_infos_by_normal(instance_info.size.oriented_normal(axis), x_face_infos, y_face_infos, z_face_infos)
        plane_grouped_face_infos.each { |plane, face_infos|
          if instance_info.definition_bounds.min.on_plane?(plane)
            min_face_infos += face_infos
          elsif instance_info.definition_bounds.max.on_plane?(plane)
            max_face_infos += face_infos
          end
        }

        return min_face_infos, max_face_infos
      end

      def _grab_face_edge_materials(face_infos)

        materials = Set[]
        face_infos.each { |face_info|
          if face_info.face.material && _get_material_attributes(face_info.face.material).type == MaterialAttributes::TYPE_EDGE
            materials.add(face_info.face.material)
          end
        }

        materials
      end

      # -- Std utils --

      def _find_std_value(value, std_values, nearest_highest)
        std_values.each { |std_value|
          if value <= std_value
            if nearest_highest
              return {
                  :available => true,
                  :value => std_value
              }
            else
              return {
                  :available => value == std_value,
                  :value => value
              }
            end
          end
        }
        {
            :available => false,
            :value => value
        }
      end

      def _find_std_section(width, thickness, std_sections)
        std_sections.each { |std_section|
          if width == std_section.width && thickness == std_section.height || width == std_section.height && thickness == std_section.width
            return {
                :available => true,
                :value => std_section
            }
          end
        }
        {
            :available => false,
            :value => Section.new(width, thickness)
        }
      end

      # -- Material Utils --

      def _get_material(path, smart = true)
        unless path
          return nil, MATERIAL_ORIGIN_UNKNOW
        end
        entity = path.last
        unless entity.is_a? Sketchup::Drawingelement
          return nil, MATERIAL_ORIGIN_UNKNOW
        end
        material = entity.material
        material = nil if _get_material_attributes(material).type == MaterialAttributes::TYPE_EDGE
        material_origin = MATERIAL_ORIGIN_OWNED
        unless material or !smart
          material = _get_dominant_child_material(entity)
          material = nil if _get_material_attributes(material).type == MaterialAttributes::TYPE_EDGE
          if material
            material_origin = MATERIAL_ORIGIN_CHILD
          else
            material = _get_inherited_material(path)
            material = nil if _get_material_attributes(material).type == MaterialAttributes::TYPE_EDGE
            if material
              material_origin = MATERIAL_ORIGIN_INHERITED
            end
          end
        end
        return material, material_origin
      end

      def _get_dominant_child_material(entity, level = 0)
        material = nil
        if entity.is_a? Sketchup::Group or (entity.is_a? Sketchup::ComponentInstance and level == 0)

          materials = {}

          # Entity is a group : check its children
          if entity.is_a? Sketchup::ComponentInstance
            entities = entity.definition.entities
          else
            entities = entity.entities
          end
          entities.each { |child_entity|
            child_material = _get_dominant_child_material(child_entity, level + 1)
            if child_material
              unless materials.has_key? child_material.name
                materials[child_material.name] = {
                    :material => child_material,
                    :count => 0
                }
              end
              materials[child_material.name][:count] += 1
            end
          }

          if materials.length > 0
            material = nil
            material_count = 0
            materials.each { |k, v|
              if v[:count] > material_count
                material = v[:material]
                material_count = v[:count]
              end
            }
          else
            material = entity.material
          end

        elsif entity.is_a? Sketchup::Face

          # Entity is a face : return entity's material
          material = entity.material

        end
        material
      end

      def _get_inherited_material(path)
        unless path
          return nil
        end
        entity = path.last
        unless entity.is_a? Sketchup::Drawingelement
          return nil
        end
        material = entity.material
        unless material
          material = _get_inherited_material(path.take(path.size - 1))
        end
        material
      end

      # -- Edge Utils --

      def _populate_edge_group_def(material, part_def, cutlist_def)
        return nil if material.nil?

        material_attributes = _get_material_attributes(material)

        std_width_info = _find_std_value(
            part_def.size.thickness,
            _get_material_attributes(material).l_std_widths,
            true
        )
        std_info = {
            :available => std_width_info[:available],
            :dimension_stipped_name => 'width',
            :dimension => std_width_info[:value].to_s,
            :width => std_width_info[:value],
            :thickness => material_attributes.l_thickness,
        }

        group_id = GroupDef.generate_group_id(material, material_attributes, std_info)
        group_def = cutlist_def.get_group_def(group_id)
        unless group_def

          group_def = GroupDef.new(group_id)
          group_def.material_id = material ? material.entityID : ''
          group_def.material_name = material.name
          group_def.material_display_name = material.display_name
          group_def.material_type = MaterialAttributes::TYPE_EDGE
          group_def.material_color = material.color if material
          group_def.std_available = std_info[:available]
          group_def.std_dimension_stipped_name = std_info[:dimension_stipped_name]
          group_def.std_dimension = std_info[:dimension]
          group_def.std_width = std_info[:width]
          group_def.std_thickness = std_info[:thickness]

          cutlist_def.set_group_def(group_id, group_def)

        end

        group_def
      end

      def _populate_edge_part_def(part_def, edge, edge_group_def, cutting_length, cutting_width, cutting_thickness)

        edge_part_id = PartDef.generate_edge_part_id(part_def.id, edge, cutting_length, cutting_width, cutting_thickness)
        edge_part_def = edge_group_def.get_part_def(edge_part_id)
        unless edge_part_def

          edge_part_def = PartDef.new(edge_part_id)
          edge_part_def.name = "#{part_def.name} - #{Plugin.instance.get_i18n_string("tab.cutlist.tooltip.edge_#{edge}")}"
          edge_part_def.cutting_size = Size3d.new(cutting_length, cutting_width, cutting_thickness)
          edge_part_def.size = Size3d.new(cutting_length, cutting_width, cutting_thickness)
          edge_part_def.material_name = edge_group_def.material_name

          edge_group_def.set_part_def(edge_part_id, edge_part_def)

        end

        edge_part_def.count += 1
        edge_group_def.part_count += 1

        edge_part_def
      end

      # [END] -- Utils definitions --

      # Check settings
      auto_orient = settings['auto_orient']
      smart_material = settings['smart_material']
      dynamic_attributes_name = settings['dynamic_attributes_name']
      part_number_with_letters = settings['part_number_with_letters']
      part_number_sequence_by_group = settings['part_number_sequence_by_group']
      part_folding = settings['part_folding']
      part_order_strategy = settings['part_order_strategy']
      hide_labels = settings['hide_labels']
      hide_final_areas = settings['hide_final_areas']
      labels_filter = settings['labels_filter']
      edge_material_names_filter = settings['edge_material_names_filter']

      # Retrieve selected entities or all if no selection
      model = Sketchup.active_model
      if model
        if model.selection.empty?
          entities = model.active_entities
          use_selection = false
        else
          entities = model.selection
          use_selection = true
        end
        @layer0 = model.layers[0]
      else
        entities = []
        use_selection = false
      end

      # Fetch component instances in given entities
      path = model && model.active_path ? model.active_path : []
      entities.each { |entity|
        _fetch_useful_instance_infos(entity, path, auto_orient)
      }

      # Retrieve model infos
      length_unit = model ? model.options["UnitsOptions"]["LengthUnit"] : nil
      dir, filename = File.split(model && !model.path.empty? ? model.path : Plugin.instance.get_i18n_string('default.empty_filename'))
      page_label = model && model.pages && model.pages.selected_page ? model.pages.selected_page.label : ''

      # Create cut list def
      cutlist_def = CutlistDef.new(length_unit, dir, filename, page_label, @instance_infos_cache.length)

      # Errors & tips
      if @instance_infos_cache.length == 0
        if model
          if entities.length == 0
            cutlist_def.add_error('tab.cutlist.error.no_entities')
            else
              if use_selection
              cutlist_def.add_error('tab.cutlist.error.no_component_in_selection')
            else
              cutlist_def.add_error('tab.cutlist.error.no_component_in_model')
            end
            cutlist_def.add_tip('tab.cutlist.tip.no_component')
          end
        else
          cutlist_def.add_error('tab.cutlist.error.no_model')
        end
      end

      # Materials usages
      materials = model ? model.materials : []
      materials.each { |material|
        material_attributes = _get_material_attributes(material)
        material_usage = MaterialUsage.new(material.name, material.display_name, material_attributes.type, material.color)
        cutlist_def.set_material_usage(material.name, material_usage)
      }

      # Populate cutlist
      @instance_infos_cache.each { |key, instance_info|

        entity = instance_info.entity

        definition = entity.definition
        definition_attributes = _get_definition_attributes(definition)

        # Populate used labels
        cutlist_def.add_used_labels(definition_attributes.labels)

        # Labels filter
        if !labels_filter.empty? and !definition_attributes.has_labels(labels_filter)
          cutlist_def.ignored_instance_count += 1
          next
        end

        material, material_origin = _get_material(instance_info.path, smart_material)
        material_id = material ? material.entityID : ''
        material_name = material ? material.name : ''
        material_display_name = material ? material.display_name : ''
        material_attributes = _get_material_attributes(material)

        if material

          material_usage = cutlist_def.get_material_usage(material.name)
          if material_usage
            material_usage.use_count += 1
          end

          # Edge materials filter -> exclude all non sheet good parts
          if !edge_material_names_filter.empty? and material_attributes.type != MaterialAttributes::TYPE_SHEET_GOOD
            cutlist_def.ignored_instance_count += 1
            next
          end

        end

        # Compute transformation, scale and sizes

        size = instance_info.size
        case material_attributes.type
          when MaterialAttributes::TYPE_SOLID_WOOD, MaterialAttributes::TYPE_SHEET_GOOD
            std_thickness_info = _find_std_value(
                (size.thickness + material_attributes.l_thickness_increase).to_l,
                material_attributes.l_std_thicknesses,
                material_attributes.type == MaterialAttributes::TYPE_SOLID_WOOD
            )
            std_info = {
                :available => std_thickness_info[:available],
                :dimension_stipped_name => 'thickness',
                :dimension => std_thickness_info[:value].to_s,
                :width => 0,
                :thickness => std_thickness_info[:value],
                :cutting_size => Size3d.new(
                    (size.length + material_attributes.l_length_increase).to_l,
                    (size.width + material_attributes.l_width_increase).to_l,
                    std_thickness_info[:value]
                )
            }
          when MaterialAttributes::TYPE_DIMENSIONAL
            std_section_info = _find_std_section(
                size.width,
                size.thickness,
                material_attributes.l_std_sections
            )
            std_info = {
                :available => std_section_info[:available],
                :dimension_stipped_name => 'section',
                :dimension => std_section_info[:value].to_s,
                :width => std_section_info[:value].width,
                :thickness => std_section_info[:value].height,
                :cutting_size => Size3d.new(
                    (size.length + material_attributes.l_length_increase).to_l,
                    std_section_info[:value].width,
                    std_section_info[:value].height
                )
            }
          else
            std_info = {
                :available => true,
                :dimension_stipped_name => '',
                :dimension => '',
                :width => 0,
                :thickness => 0,
                :cutting_size => size
            }
        end
        cutting_size = std_info[:cutting_size]

        # Define group

        group_id = GroupDef.generate_group_id(material, material_attributes, std_info)
        group_def = cutlist_def.get_group_def(group_id)
        unless group_def

          group_def = GroupDef.new(group_id)
          group_def.material_id = material_id
          group_def.material_name = material_name
          group_def.material_display_name = material_display_name
          group_def.material_type = material_attributes.type
          group_def.material_color = material.color if material
          group_def.material_grained = material_attributes.grained
          group_def.std_available = std_info[:available]
          group_def.std_dimension_stipped_name = std_info[:dimension_stipped_name]
          group_def.std_dimension = std_info[:dimension]
          group_def.std_width = std_info[:width]
          group_def.std_thickness = std_info[:thickness]
          group_def.show_cutting_dimensions = material_attributes.type > MaterialAttributes::TYPE_UNKNOW && (material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0)

          cutlist_def.set_group_def(group_id, group_def)

        end

        number = nil
        if definition_attributes.number
          if part_number_with_letters
            if definition_attributes.number.is_a? String
              number = definition_attributes.number
            end
          else
            if definition_attributes.number.is_a? Numeric
              number = definition_attributes.number
            end
          end
        end
        if number
          if part_number_sequence_by_group
            if group_def.include_number? number
              number = nil
            end
          else
            if cutlist_def.include_number? number
              number = nil
            end
          end
        end

        # Define part

        part_id = PartDef.generate_part_id(group_id, definition, instance_info, dynamic_attributes_name)
        part_def = group_def.get_part_def(part_id)
        unless part_def

          part_def = PartDef.new(part_id)
          part_def.definition_id = definition.name
          part_def.number = number
          part_def.saved_number = definition_attributes.number
          part_def.name, part_def.is_dynamic_attributes_name = instance_info.read_name(dynamic_attributes_name)
          part_def.scale = instance_info.scale
          part_def.cutting_size = cutting_size
          part_def.size = size
          part_def.material_name = material_name
          part_def.cumulable = definition_attributes.cumulable
          part_def.orientation_locked_on_axis = definition_attributes.orientation_locked_on_axis
          part_def.labels = definition_attributes.labels
          part_def.auto_oriented = size.auto_oriented

          # Compute axes alignment, final area and edges
          case group_def.material_type

            when MaterialAttributes::TYPE_SOLID_WOOD

              x_face_infos, y_face_infos, z_face_infos, layers = _grab_main_faces_and_layers(definition)
              t_plane_count, t_final_area, t_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Z_AXIS)
              w_plane_count, w_final_area, w_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Y_AXIS)

              part_def.not_aligned_on_axes = !(t_area_ratio >= 0.7 or w_area_ratio >= 0.7)
              part_def.layers = layers

            when MaterialAttributes::TYPE_SHEET_GOOD

              x_face_infos, y_face_infos, z_face_infos, layers = _grab_main_faces_and_layers(definition)
              t_plane_count, t_final_area, t_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Z_AXIS)

              part_def.final_area = t_final_area
              part_def.not_aligned_on_axes = !(t_plane_count >= 2 and (_face_infos_by_normal(size.oriented_normal(Y_AXIS), x_face_infos, y_face_infos, z_face_infos).length >= 1 or _face_infos_by_normal(size.oriented_normal(X_AXIS), x_face_infos, y_face_infos, z_face_infos).length >= 1))
              part_def.layers = layers

              # -- Edges --

              # Grab min/max face infos
              xmin_face_infos, xmax_face_infos = _grab_oriented_min_max_face_infos(instance_info, x_face_infos, y_face_infos, z_face_infos, X_AXIS)
              ymin_face_infos, ymax_face_infos = _grab_oriented_min_max_face_infos(instance_info, x_face_infos, y_face_infos, z_face_infos, Y_AXIS)

              # Grab edge materials
              edge_ymin_materials = _grab_face_edge_materials(ymin_face_infos)
              edge_ymax_materials = _grab_face_edge_materials(ymax_face_infos)
              edge_xmin_materials = _grab_face_edge_materials(xmin_face_infos)
              edge_xmax_materials = _grab_face_edge_materials(xmax_face_infos)

              edge_ymin_material = edge_ymin_materials.empty? ? nil : edge_ymin_materials.first
              edge_ymax_material = edge_ymax_materials.empty? ? nil : edge_ymax_materials.first
              edge_xmin_material = edge_xmin_materials.empty? ? nil : edge_xmin_materials.first
              edge_xmax_material = edge_xmax_materials.empty? ? nil : edge_xmax_materials.first
              edge_materials = [ edge_ymin_material, edge_ymax_material, edge_xmin_material, edge_xmax_material ].compact.uniq

              # Materials filter
              if !edge_material_names_filter.empty? && !(edge_material_names_filter - edge_materials.map { |m| m.display_name }).empty?
                cutlist_def.ignored_instance_count += 1
                next
              end

              # Increment material usage
              edge_materials.each { |edge_material|
                material_usage = cutlist_def.get_material_usage(edge_material.name)
                if material_usage
                  material_usage.use_count += 1
                end
              }

              # Grab material attributes
              edge_ymin_material_attributes = _get_material_attributes(edge_ymin_material)
              edge_ymax_material_attributes = _get_material_attributes(edge_ymax_material)
              edge_xmin_material_attributes = _get_material_attributes(edge_xmin_material)
              edge_xmax_material_attributes = _get_material_attributes(edge_xmax_material)

              # Compute Length and Width decrements
              length_decrement = 0
              length_decrement += edge_xmin_material_attributes.l_thickness if edge_xmin_material_attributes.edge_decremented
              length_decrement += edge_xmax_material_attributes.l_thickness if edge_xmax_material_attributes.edge_decremented
              width_decrement = 0
              width_decrement += edge_ymin_material_attributes.l_thickness if edge_ymin_material_attributes.edge_decremented
              width_decrement += edge_ymax_material_attributes.l_thickness if edge_ymax_material_attributes.edge_decremented
              edge_decremented = edge_xmin_material_attributes.edge_decremented || edge_xmax_material_attributes.edge_decremented || edge_ymin_material_attributes.edge_decremented || edge_ymax_material_attributes.edge_decremented

              # Populate edge GroupDefs
              edge_ymin_group_def = _populate_edge_group_def(edge_ymin_material, part_def, cutlist_def)
              edge_ymax_group_def = _populate_edge_group_def(edge_ymax_material, part_def, cutlist_def)
              edge_xmin_group_def = _populate_edge_group_def(edge_xmin_material, part_def, cutlist_def)
              edge_xmax_group_def = _populate_edge_group_def(edge_xmax_material, part_def, cutlist_def)

              # Populate PartDef
              part_def.set_edge_materials(edge_ymin_material, edge_ymax_material, edge_xmin_material, edge_xmax_material)
              part_def.set_edge_entity_ids(
                  ymin_face_infos.collect { |face_info| face_info.face.entityID },
                  ymax_face_infos.collect { |face_info| face_info.face.entityID },
                  xmin_face_infos.collect { |face_info| face_info.face.entityID },
                  xmax_face_infos.collect { |face_info| face_info.face.entityID }
              )
              part_def.set_edge_group_defs(edge_ymin_group_def, edge_ymax_group_def, edge_xmin_group_def, edge_xmax_group_def)
              part_def.edge_length_decrement = length_decrement.to_l
              part_def.edge_width_decrement = width_decrement.to_l
              part_def.edge_decremented = edge_decremented

              group_def.show_cutting_dimensions ||= length_decrement > 0 || width_decrement > 0
              group_def.edge_decremented ||= length_decrement > 0 || width_decrement > 0

            when MaterialAttributes::TYPE_DIMENSIONAL

              x_face_infos, y_face_infos, z_face_infos, layers = _grab_main_faces_and_layers(definition)
              t_plane_count, t_final_area, t_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Z_AXIS)
              w_plane_count, w_final_area, w_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Y_AXIS)

              part_def.not_aligned_on_axes = !(t_area_ratio >= 0.7 and w_area_ratio >= 0.7 and (t_plane_count >= 2 and w_plane_count >= 2))
              part_def.layers = layers

            else
              part_def.not_aligned_on_axes = false

          end

          group_def.show_edges = part_def.edge_count > 0 || group_def.show_edges
          group_def.set_part_def(part_id, part_def)

          if number

            # Update max_number in group_def
            if group_def.max_number
              if number > group_def.max_number
                group_def.max_number = number
              end
            else
              group_def.max_number = number
            end

            # Update max_number in cutlist_def
            if group_def.max_number
              if cutlist_def.max_number
                if group_def.max_number > cutlist_def.max_number
                  cutlist_def.max_number = group_def.max_number
                end
              else
                cutlist_def.max_number = group_def.max_number
              end
            end

          end

        end
        part_def.count += 1
        part_def.add_material_origin(material_origin)
        part_def.add_entity_id(entity.entityID)
        part_def.add_entity_serialized_path(instance_info.serialized_path)
        part_def.add_entity_name(entity.name)

        if group_def.material_type != MaterialAttributes::TYPE_UNKNOW
          if group_def.material_type == MaterialAttributes::TYPE_DIMENSIONAL
            group_def.total_cutting_length += part_def.cutting_size.length
          end
          if group_def.material_type == MaterialAttributes::TYPE_SOLID_WOOD || group_def.material_type == MaterialAttributes::TYPE_SHEET_GOOD
            group_def.total_cutting_area += part_def.cutting_size.area
          end
          if group_def.material_type == MaterialAttributes::TYPE_SHEET_GOOD
            if part_def.final_area.nil?
              group_def.invalid_final_area_part_count += 1
            else
              group_def.total_final_area += part_def.final_area
            end
            if part_def.edge_count > 0
              PartDef::EDGES_Y.each { |edge|
                unless (edge_group_def = part_def.edge_group_defs[edge]).nil? || (edge_material = part_def.edge_materials[edge]).nil?
                  edge_cutting_length = part_def.size.length + _get_material_attributes(edge_material).l_length_increase
                  edge_group_def.total_cutting_length += edge_cutting_length
                  edge_group_def.total_cutting_area += edge_cutting_length * edge_group_def.std_width
                  edge_group_def.total_cutting_volume += edge_cutting_length * edge_group_def.std_thickness
                  _populate_edge_part_def(part_def, edge, edge_group_def, edge_cutting_length.to_l, edge_group_def.std_width, edge_group_def.std_thickness)
                end
              }
              PartDef::EDGES_X.each { |edge|
                unless (edge_group_def = part_def.edge_group_defs[edge]).nil? || (edge_material = part_def.edge_materials[edge]).nil?
                  edge_cutting_length = part_def.size.width + _get_material_attributes(edge_material).l_length_increase
                  edge_group_def.total_cutting_length += edge_cutting_length
                  edge_group_def.total_cutting_area += edge_cutting_length * edge_group_def.std_width
                  edge_group_def.total_cutting_volume += edge_cutting_length * edge_group_def.std_thickness
                  _populate_edge_part_def(part_def, edge, edge_group_def, edge_cutting_length.to_l, edge_group_def.std_width, edge_group_def.std_thickness)
                end
              }
            end
          end
          group_def.total_cutting_volume += part_def.cutting_size.volume
        end
        group_def.part_count += 1

      }

      # Warnings & tips
      if @instance_infos_cache.length > 0
        if use_selection
          cutlist_def.add_warning("tab.cutlist.warning.partial_cutlist")
        end
        solid_wood_material_count = 0
        sheet_good_material_count = 0
        bar_material_count = 0
        edge_material_count = 0
        cutlist_def.material_usages.each { |key, material_usage|
          if material_usage.type == MaterialAttributes::TYPE_SOLID_WOOD
            solid_wood_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_SHEET_GOOD
            sheet_good_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_DIMENSIONAL
            bar_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_EDGE
            edge_material_count += material_usage.use_count
          end
        }
        if cutlist_def.instance_count - cutlist_def.ignored_instance_count > 0 and solid_wood_material_count == 0 and sheet_good_material_count == 0 and bar_material_count == 0
          cutlist_def.add_warning("tab.cutlist.warning.no_typed_materials_in_#{use_selection ? "selection" : "model"}")
          cutlist_def.add_tip("tab.cutlist.tip.no_typed_materials")
        end
      end

      # Response
      # --------

      response = {
          :errors => cutlist_def.errors,
          :warnings => cutlist_def.warnings,
          :tips => cutlist_def.tips,
          :length_unit => cutlist_def.length_unit,
          :dir => cutlist_def.dir,
          :filename => cutlist_def.filename,
          :page_label => cutlist_def.page_label,
          :instance_count => cutlist_def.instance_count,
          :ignored_instance_count => cutlist_def.ignored_instance_count,
          :used_labels => cutlist_def.used_labels.sort,
          :material_usages => [],
          :groups => []
      }

      # Sort and browse material usages
      cutlist_def.material_usages.sort_by { |k, v| [v.display_name.downcase] }.each { |key, material_usage|
        response[:material_usages].push(material_usage.to_struct)
      }

      part_number = cutlist_def.max_number ? cutlist_def.max_number.succ : (part_number_with_letters ? 'A' : '1')

      # Sort and browse groups

      cutlist_def.group_defs.sort_by { |k, v| [ MaterialAttributes.type_order(v.material_type), v.material_name.empty? ? '~' : v.material_name.downcase, -v.std_width, -v.std_thickness ] }.each { |key, group_def|

        # Exclude empty groupDef
        next if group_def.part_count == 0

        if part_number_sequence_by_group
          part_number = group_def.max_number ? group_def.max_number.succ : (part_number_with_letters ? 'A' : '1')    # Reset code increment on each group
        end

        group = group_def.to_struct
        response[:groups].push(group)

        # Folding
        if part_folding and group_def.material_type > MaterialAttributes::TYPE_UNKNOW   # Only parts with typed material can be grouped
          part_defs = []
          group_def.part_defs.values.sort_by { |v| [ v.size.thickness, v.size.length, v.size.width, v.labels, v.final_area ] }.each { |part_def|
            if !(folder_part_def = part_defs.last).nil? &&
                folder_part_def.size == part_def.size &&
                folder_part_def.cutting_size == part_def.cutting_size &&
                (folder_part_def.labels == part_def.labels || hide_labels) &&
                ((folder_part_def.final_area - part_def.final_area).abs < 0.001 or hide_final_areas) &&      # final_area workaround for rounding error
                folder_part_def.edge_material_names == part_def.edge_material_names
              if folder_part_def.children.empty?
                first_child_part_def = part_defs.pop

                folder_part_def = PartDef.new(first_child_part_def.id + '_folder')
                folder_part_def.name = first_child_part_def.name
                folder_part_def.count = first_child_part_def.count
                folder_part_def.cutting_size = first_child_part_def.cutting_size
                folder_part_def.size = first_child_part_def.size
                folder_part_def.material_name = first_child_part_def.material_name
                folder_part_def.labels = first_child_part_def.labels
                folder_part_def.final_area = first_child_part_def.final_area
                folder_part_def.edge_count = first_child_part_def.edge_count
                folder_part_def.edge_pattern = first_child_part_def.edge_pattern
                folder_part_def.edge_material_names.merge!(first_child_part_def.edge_material_names)
                folder_part_def.edge_std_dimensions.merge!(first_child_part_def.edge_std_dimensions)
                folder_part_def.edge_length_decrement = first_child_part_def.edge_length_decrement
                folder_part_def.edge_width_decrement = first_child_part_def.edge_width_decrement

                folder_part_def.children.push(first_child_part_def)
                folder_part_def.children_warning_count += 1 if first_child_part_def.not_aligned_on_axes
                folder_part_def.children_warning_count += 1 if first_child_part_def.multiple_layers

                part_defs.push(folder_part_def)

              end
              folder_part_def.children.push(part_def)
              folder_part_def.count += part_def.count
              folder_part_def.children_warning_count += 1 if part_def.not_aligned_on_axes
              folder_part_def.children_warning_count += 1 if part_def.multiple_layers
            else
              part_defs.push(part_def)
            end
          }
        else
          part_defs = group_def.part_defs.values
        end

        # Sort and browse parts
        part_defs.sort { |part_def_a, part_def_b| PartDef::part_order(part_def_a, part_def_b, part_order_strategy) }.each { |part_def|

          if part_def.children.empty?

            # Part is simgle part
            part = part_def.to_struct(part_number)
            unless part_def.number
              part_number = part_number.succ
            end

          else

            # Part is folder part
            part = part_def.to_struct(nil)

            # Iterate on children
            part_def.children.sort { |part_def_a, part_def_b| PartDef::part_order(part_def_a, part_def_b, part_order_strategy) }.each { |child_part_def|
              child_part = child_part_def.to_struct(part_number)
              unless child_part_def.number
                part_number = part_number.succ
              end
              part[:children].push(child_part)
            }

            # Folder part takes first child number
            part[:name] = part[:children].first[:name] + ', ...'
            part[:number] = part[:children].first[:number] + '+'
            part[:saved_number] = part[:children].first[:saved_number] + '+' if part[:children].first[:saved_number]

          end

          group[:parts].push(part)
        }

      }

      # Keep generated cutlist
      @cutlist = response

      # Clear caches
      @material_attributes_cache = nil
      @definition_attributes_cache = nil

      response
    end

    def export_command(settings)

      # Check settings
      source = settings['source']
      col_sep = settings['col_sep']
      encoding = settings['encoding']
      hide_entity_names = settings['hide_entity_names']
      hide_labels = settings['hide_labels']
      hide_cutting_dimensions = settings['hide_cutting_dimensions']
      hide_bbox_dimensions = settings['hide_bbox_dimensions']
      hide_untyped_material_dimensions = settings['hide_untyped_material_dimensions']
      hide_final_areas = settings['hide_final_areas']
      hide_edges = settings['hide_edges']
      hidden_group_ids = settings['hidden_group_ids']

      response = {
          :errors => [],
          :export_path => ''
      }

      if @cutlist and @cutlist[:groups]

        # Ask for export file path
        export_path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export.title'), @cutlist[:dir], File.basename(@cutlist[:filename], '.skp') + '.csv')
        if export_path

          begin

            # Convert col_sep
            case col_sep.to_i
              when EXPORT_OPTION_COL_SEP_COMMA
                col_sep = ','
                force_quotes = true
              when EXPORT_OPTION_COL_SEP_SEMICOLON
                col_sep = ';'
                force_quotes = false
              else
                col_sep = "\t"
                force_quotes = false
            end

            # Convert col_sep
            case encoding.to_i
              when EXPORT_OPTION_ENCODING_UTF16LE
                bom = "\xFF\xFE".force_encoding('utf-16le')
                encoding = 'UTF-16LE'
              when EXPORT_OPTION_ENCODING_UTF16BE
                bom = "\xFE\xFF".force_encoding('utf-16be')
                encoding = 'UTF-16BE'
              else
                bom = "\xEF\xBB\xBF"
                encoding = 'UTF-8'
            end

            File.open(export_path, "wb+:#{encoding}") do |f|
              csv_file = CSV.generate({ :col_sep => col_sep, :force_quotes => force_quotes }) do |csv|

                def _sanitize_value_string(value)
                  value.gsub(/^~ /, '') unless value.nil?
                end
                def _format_edge_value(material_name, std_dimension)
                  if material_name
                    return "#{material_name} (#{std_dimension})"
                  end
                  ''
                end

                case source.to_i

                  when EXPORT_OPTION_SOURCE_SUMMARY

                    # Header row
                    header = []
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_type'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_thickness'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.part_count'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_cutting_length'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_cutting_area'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_cutting_volume'))
                    unless hide_final_areas
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.total_final_area'))
                    end

                    csv << header

                    @cutlist[:groups].each { |group|
                      next if hidden_group_ids.include? group[:id]

                      row = []
                      row.push(Plugin.instance.get_i18n_string("tab.materials.type_#{group[:material_type]}"))
                      row.push((group[:material_name] ? group[:material_name] : Plugin.instance.get_i18n_string('tab.cutlist.material_undefined')) + (group[:material_type] > 0 ? ' / ' + group[:std_dimension] : ''))
                      row.push(group[:part_count])
                      row.push(group[:total_cutting_length].nil? ? '' : _sanitize_value_string(group[:total_cutting_length]))
                      row.push(group[:total_cutting_area].nil? ? '' : _sanitize_value_string(group[:total_cutting_area]))
                      row.push(group[:total_cutting_volume].nil? ? '' : _sanitize_value_string(group[:total_cutting_volume]))
                      unless hide_final_areas
                        row.push((group[:total_final_area].nil? or group[:invalid_final_area_part_count] > 0) ? '' : _sanitize_value_string(group[:total_final_area]))
                      end

                      csv << row
                    }

                when EXPORT_OPTION_SOURCE_CUTLIST

                    # Header row
                    header = []
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.number'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.name'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.count'))
                    unless hide_cutting_dimensions
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_length'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_width'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_thickness'))
                    end
                    unless hide_bbox_dimensions
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_length'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_width'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_thickness'))
                    end
                    unless hide_final_areas
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.final_area'))
                    end
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_name'))
                    unless hide_entity_names
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.entity_names'))
                    end
                    unless hide_labels
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.labels'))
                    end
                    unless hide_edges
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymax'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymin'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmin'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmax'))
                    end

                    csv << header

                    # Content rows
                    @cutlist[:groups].each { |group|
                      next if hidden_group_ids.include? group[:id]
                      group[:parts].each { |part|

                        no_cutting_dimensions = group[:material_type] == MaterialAttributes::TYPE_UNKNOW
                        no_dimensions = group[:material_type] == MaterialAttributes::TYPE_UNKNOW && hide_untyped_material_dimensions

                        row = []
                        row.push(part[:number])
                        row.push(part[:name])
                        row.push(part[:count])
                        unless hide_cutting_dimensions
                          row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part[:cutting_length]))
                          row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part[:cutting_width]))
                          row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part[:cutting_thickness]))
                        end
                        unless hide_bbox_dimensions
                          row.push(no_dimensions ? '' : _sanitize_value_string(part[:length]))
                          row.push(no_dimensions ? '' : _sanitize_value_string(part[:width]))
                          row.push(no_dimensions ? '' : _sanitize_value_string(part[:thickness]))
                        end
                        unless hide_final_areas
                          row.push(no_dimensions ? '' : _sanitize_value_string(part[:final_area]))
                        end
                        row.push(group[:material_display_name])
                        unless hide_entity_names
                          row.push(part[:entity_names].nil? ? '' : part[:entity_names].map(&:first).join(','))
                        end
                        unless hide_labels
                          row.push(part[:labels].empty? ? '' : part[:labels].join(','))
                        end
                        unless hide_edges
                          row.push(_format_edge_value(part[:edge_material_names][:ymax], part[:edge_std_dimensions][:ymax]))
                          row.push(_format_edge_value(part[:edge_material_names][:ymin], part[:edge_std_dimensions][:ymin]))
                          row.push(_format_edge_value(part[:edge_material_names][:xmin], part[:edge_std_dimensions][:xmin]))
                          row.push(_format_edge_value(part[:edge_material_names][:xmax], part[:edge_std_dimensions][:xmax]))
                        end

                        csv << row
                      }
                    }

                when EXPORT_OPTION_SOURCE_INSTANCES_LIST

                    # Header row
                    header = []
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.path'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.instance_name'))
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.definition_name'))
                    unless hide_cutting_dimensions
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_length'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_width'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.cutting_thickness'))
                    end
                    unless hide_bbox_dimensions
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_length'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_width'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.bbox_thickness'))
                    end
                    unless hide_final_areas
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.final_area'))
                    end
                    header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_name'))
                    unless hide_labels
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.labels'))
                    end
                    unless hide_edges
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymax'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_ymin'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmin'))
                      header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.edge_xmax'))
                    end

                    csv << header

                    # Content rows
                    @cutlist[:groups].each { |group|
                      next if hidden_group_ids.include? group[:id]
                      next if group[:material_type] == MaterialAttributes::TYPE_EDGE    # Edges don't have instances
                      group[:parts].each { |part|

                        no_cutting_dimensions = group[:material_type] == MaterialAttributes::TYPE_UNKNOW
                        no_dimensions = group[:material_type] == MaterialAttributes::TYPE_UNKNOW && hide_untyped_material_dimensions

                        parts = part[:children].nil? ? [ part ] : part[:children]
                        parts.each { |part|

                          # Ungroup parts
                          part[:entity_serialized_paths].each { |serialized_path|

                            # Retrieve instance info
                            instance_info = @instance_infos_cache[serialized_path]

                            # Compute path with entities names (from root group to final entity)
                            path_names = []
                            instance_info.path.each { |entity|
                              # Uses entityID if instance name is empty
                              path_names.push(entity.name.empty? ? "##{entity.entityID}" : entity.name)
                            }
                            # Pop the instance name to put it in a separated column
                            instance_name = path_names.pop

                            row = []
                            row.push(path_names.join('/'))
                            row.push(instance_name)
                            row.push(part[:name])
                            unless hide_cutting_dimensions
                              row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part[:cutting_length]))
                              row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part[:cutting_width]))
                              row.push(no_cutting_dimensions ? '' : _sanitize_value_string(part[:cutting_thickness]))
                            end
                            unless hide_bbox_dimensions
                              row.push(no_dimensions ? '' : _sanitize_value_string(part[:length]))
                              row.push(no_dimensions ? '' : _sanitize_value_string(part[:width]))
                              row.push(no_dimensions ? '' : _sanitize_value_string(part[:thickness]))
                            end
                            unless hide_final_areas
                              row.push(no_dimensions ? '' : _sanitize_value_string(part[:final_area]))
                            end
                            row.push(group[:material_display_name])
                            unless hide_labels
                              row.push(part[:labels].empty? ? '' : part[:labels].join(','))
                            end
                            unless hide_edges
                              row.push(_format_edge_value(part[:edge_material_names][:ymax], part[:edge_std_dimensions][:ymax]))
                              row.push(_format_edge_value(part[:edge_material_names][:ymin], part[:edge_std_dimensions][:ymin]))
                              row.push(_format_edge_value(part[:edge_material_names][:xmin], part[:edge_std_dimensions][:xmin]))
                              row.push(_format_edge_value(part[:edge_material_names][:xmax], part[:edge_std_dimensions][:xmax]))
                            end

                            csv << row

                          }

                        }

                      }
                    }

                end

              end

              # Write file
              f.write(bom)
              f.write(csv_file)

              # Populate response
              response[:export_path] = export_path.tr("\\", '/')  # Standardize path by replacing \ by /

            end

          rescue => e
            puts e.message
            puts e.backtrace
            response[:errors] << [ 'tab.cutlist.error.failed_to_write_export_file', { :error => e.message } ]
          end

        end

      end

      response
    end

    def numbers_command(settings, reset)
      if @cutlist

        # Check settings
        group_id = settings['group_id']

        model = Sketchup.active_model
        definitions = model ? model.definitions : []

        def _numbers_command_apply_on_part(definitions, part, reset)
          definition = definitions[part[:definition_id]]
          if definition

            definition_attributes = DefinitionAttributes.new(definition)
            definition_attributes.number = reset ? nil : part[:number]
            definition_attributes.write_to_attributes

          end
        end

        @cutlist[:groups].each { |group|

          if group_id && group[:id] != group_id
            next
          end

          group[:parts].each { |part|

            if part[:children].nil?
              _numbers_command_apply_on_part(definitions, part, reset)
            else
              part[:children].each { |child_part|
                _numbers_command_apply_on_part(definitions, child_part, reset)
              }
            end

          }
        }
      end
    end

    def highlight_parts_command(group_id = nil, part_id = nil)

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve cutlist
      return { :errors => [ 'default.error' ] } unless @cutlist

      # Populate entity infos
      instance_infos = []
      displayed_part = nil
      displayed_group = nil
      @cutlist[:groups].each { |group|
        if group_id.nil? or group[:id] == group_id
          group = group
          group[:parts].each { |part|
            if part_id.nil? or part[:id] == part_id
              if part[:children].nil?
                part[:entity_serialized_paths].each { |entity_serialized_path|
                  instance_info = @instance_infos_cache[entity_serialized_path]
                  unless instance_info.nil?
                    instance_infos.push(instance_info)
                  end
                }
              else
                part[:children].each { |child_part|
                  child_part[:entity_serialized_paths].each { |entity_serialized_path|
                    instance_info = @instance_infos_cache[entity_serialized_path]
                    unless instance_info.nil?
                      instance_infos.push(instance_info)
                    end
                  }
                }
              end
              if part[:id] == part_id
                displayed_part = part
                break
              end
            end
            unless part[:children].nil?
              part[:children].each { |child_part|
                if part_id.nil? or child_part[:id] == part_id
                  child_part[:entity_serialized_paths].each { |entity_serialized_path|
                    instance_info = @instance_infos_cache[entity_serialized_path]
                    unless instance_info.nil?
                      instance_infos.push(instance_info)
                    end
                  }
                  if child_part[:id] == part_id
                    displayed_part = part
                    break
                  end
                end
              }
            end
            unless displayed_part.nil?
              break
            end
          }
          if group[:id] == group_id
            displayed_group = group
            break
          end
        end
      }

      if instance_infos.empty?

        # Retrieve cutlist
        return { :errors => [ 'default.error' ] }

      end

      # Compute text infos
      if part_id

        text_line_1 = '[' + displayed_part[:number] + '] ' + displayed_part[:name]
        text_line_2 = displayed_part[:labels].join(' | ')
        text_line_3 = displayed_part[:length].to_s + ' x ' + displayed_part[:width].to_s + ' x ' + displayed_part[:thickness].to_s +
            (displayed_part[:final_area].nil? ? '' : " (#{displayed_part[:final_area]})") +
            ' | ' + instance_infos.length.to_s + ' ' + Plugin.instance.get_i18n_string(instance_infos.length > 1 ? 'default.part_plural' : 'default.part_single') +
            ' | ' + (displayed_part[:material_name].empty? ? Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') : displayed_part[:material_name])

      elsif group_id

        text_line_1 = (displayed_group[:material_name].empty? ? Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') : displayed_group[:material_name] + (displayed_group[:std_dimension].empty? ? '' : ' / ' + displayed_group[:std_dimension]))
        text_line_2 = ''
        text_line_3 = instance_infos.length.to_s + ' ' + Plugin.instance.get_i18n_string(instance_infos.length > 1 ? 'default.part_plural' : 'default.part_single')

      else

        text_line_1 = ''
        text_line_2 = ''
        text_line_3 = instance_infos.length.to_s + ' ' + Plugin.instance.get_i18n_string(instance_infos.length > 1 ? 'default.part_plural' : 'default.part_single')

      end

      # Create and activate highlight part tool
      highlight_tool = HighlightPartTool.new(text_line_1, text_line_2, text_line_3, instance_infos)
      model.select_tool(highlight_tool)

    end

    def part_get_thumbnail_command(part_data)

      response = {
          :thumbnail_file => ''
      }

      model = Sketchup.active_model
      return response unless model

      # Extract parameters
      definition_id = part_data['definition_id']

      definitions = model.definitions
      definition = definitions[definition_id]
      if definition

        definition.refresh_thumbnail

        temp_dir = Plugin.instance.temp_dir
        component_thumbnails_dir = File.join(temp_dir, 'components_thumbnails')
        unless Dir.exist?(component_thumbnails_dir)
          Dir.mkdir(component_thumbnails_dir)
        end

        thumbnail_file = File.join(component_thumbnails_dir, "#{definition.guid}.png")
        definition.save_thumbnail(thumbnail_file)

        response[:thumbnail_file] = thumbnail_file
      end

      response
    end

    def part_update_command(settings)

      def _apply_material(material_name, entity_ids, model)
        unless entity_ids.nil?
          material = nil
          if material_name.nil? or material_name.empty? or (material = model.materials[material_name])

            entity_ids.each { |entity_id|
              entity = ModelUtils::find_entity_by_id(model, entity_id)
              if entity
                if material_name.nil? or material_name.empty?
                  entity.material = nil
                elsif entity.material != material
                  entity.material = material
                end
              end
            }

          end
        end
      end

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Extract parameters
      parts_data = settings['parts_data']

      definitions = model.definitions
      parts_data.each { |part_data|

        definition_id = part_data['definition_id']
        name = part_data['name']
        is_dynamic_attributes_name = part_data['is_dynamic_attributes_name']
        material_name = part_data['material_name']
        cumulable = DefinitionAttributes.valid_cumulable(part_data['cumulable'])
        orientation_locked_on_axis = part_data['orientation_locked_on_axis']
        labels = DefinitionAttributes.valid_labels(part_data['labels'])
        axes_order = part_data['axes_order']
        axes_origin_position = part_data['axes_origin_position']
        edge_material_names = part_data['edge_material_names']
        edge_entity_ids = part_data['edge_entity_ids']
        entity_ids = part_data['entity_ids']

        definition = definitions[definition_id]

        if definition

          # Update definition's name
          if definition.name != name and !is_dynamic_attributes_name
            definition.name = name
          end

          # Update definition's attributes
          definition_attributes = DefinitionAttributes.new(definition)
          if cumulable != definition_attributes.cumulable or orientation_locked_on_axis != definition_attributes.orientation_locked_on_axis or labels != definition_attributes.labels
            definition_attributes.cumulable = cumulable
            definition_attributes.orientation_locked_on_axis = orientation_locked_on_axis
            definition_attributes.labels = labels
            definition_attributes.write_to_attributes
          end

          # Update materials
          _apply_material(material_name, entity_ids, model)
          _apply_material(edge_material_names['ymin'], edge_entity_ids['ymin'], model)
          _apply_material(edge_material_names['ymax'], edge_entity_ids['ymax'], model)
          _apply_material(edge_material_names['xmin'], edge_entity_ids['xmin'], model)
          _apply_material(edge_material_names['xmax'], edge_entity_ids['xmax'], model)

          # Transform part axes if axes order exist
          if axes_order.is_a?(Array) and axes_order.length == 3

            axes_convertor = {
                'x' => X_AXIS,
                'y' => Y_AXIS,
                'z' => Z_AXIS
            }

            # Convert axes order to Vector3D array
            axes_order.map! { |axis|
              axes_convertor[axis]
            }

            # Create transformations
            ti = Geom::Transformation.axes(ORIGIN, axes_order[0], axes_order[1], axes_order[2])
            t = ti.inverse

            # Transform definition's entities
            entities = definition.entities
            entities.transform_entities(t, entities.to_a)

            # Inverse transform definition's instances
            definition.instances.each { |instance|
              instance.transformation *= ti
            }

          end

          # Manage origin if position exist
          if axes_origin_position

            # Compute definition bounds
            bounds = _compute_faces_bounds(definition)

            case axes_origin_position
              when 'min'
                origin = bounds.min
              when 'center'
                origin = bounds.center
              when 'min-center'
                origin = Geom::Point3d.new(bounds.min.x , bounds.center.y, bounds.center.z)
              else
                origin = ORIGIN
            end

            # Create transformations
            ti = Geom::Transformation.axes(origin, X_AXIS, Y_AXIS, Z_AXIS)
            t = ti.inverse

            # Transform definition's entities
            entities = definition.entities
            entities.transform_entities(t, entities.to_a)

            # Inverse transform definition's instances
            definition.instances.each { |instance|
              instance.transformation *= ti
            }

          end

        end

      }

    end

    def group_cuttingdiagram_1d_command(settings)
      if @cutlist

        # Check settings
        group_id = settings['group_id']
        std_bar_length = DimensionUtils.instance.str_to_ifloat(settings['std_bar_length']).to_l.to_f
        scrap_bar_lengths = DimensionUtils.instance.dd_to_ifloats(settings['scrap_bar_lengths'])
        hide_part_list = settings['hide_part_list']
        saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
        trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f
        max_time = settings['max_time'].to_i
        tuning_level = settings['tuning_level'].to_i

        @cutlist[:groups].each { |group|

          if group_id && group[:id] != group_id
            next
          end

          # The dimensions need to be in Sketchup internal units AND float
          options = BinPacking1D::Options.new
          options.std_length = std_bar_length
          options.saw_kerf = saw_kerf # size of saw_kef
          options.trim_size = trimming # size of trim size (both sides)
          options.max_time = max_time # the amount of time in seconds for computing, before aborting
          options.tuning_level = tuning_level # a level 0, 1, 2

          # Create the bin packing engine with given bins and boxes
          e = BinPacking1D::PackEngine.new(options)

          # Add bins from scrap sheets
          scrap_bar_lengths.split(';').each { |scrap_bar_length|
            e.add_bin(scrap_bar_length.to_f)
          }

          # Add bars from parts, give them a unique ID
          group[:parts].each { |part|
            part[:entity_ids].each { |p|
              e.add_box(part[:cutting_length].to_l.to_f, p)
            }
          }

          result, err = e.run

          case err
          when BinPacking1D::ERROR_NONE
            puts('optimal solution found')
          when BinPacking1D::ERROR_SUBOPT
            puts('suboptimal solution found')
          when BinPacking1D::ERROR_NO_BIN
            puts('no bins available')
          when BinPacking1D::ERROR_NO_PARTS
            puts('no parts to pack')
          when BinPacking1D::ERROR_TIME_EXCEEDED
            puts('time exceeded and no solution found')
          when BinPacking1D::ERROR_NOT_IMPLEMENTED
            puts('feature not implemented yet')
          else
            puts('funky error, contact developpers', err)
          end

          # Compute the cutting diagram

          # Response
          # --------

          # Convert inch float value to pixel
          def to_px(inch_value)
            inch_value * 7 # 840px = 120" ~ 3m
          end

          response = {
              :errors => [],
              :warnings => [],
              :tips => [],

              :options => {
                :hide_part_list => hide_part_list,
                :px_saw_kerf => to_px(options.saw_kerf),
                :saw_kerf => options.saw_kerf.to_l.to_s,
              },

              :unplaced_parts => [],
              :summary => {
                :bars => [],
              },
              :bars => [],
          }

          if err > BinPacking1D::ERROR_NONE

            # Engine error -> returns error only

            case err
              when BinPacking1D::ERROR_NO_BIN
                response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_bar'
            end

          else

            # Warnings
            materials = Sketchup.active_model.materials
            material = materials[group[:material_name]]
            material_attributes = MaterialAttributes.new(material)
            if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0 || group[:edge_decremented]
              response[:warnings] << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions'
            end
            if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0
              response[:warnings] << [ 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_increase_1d', { :material_name => group[:material_name], :length_increase => material_attributes.length_increase, :width_increase => material_attributes.width_increase } ]
            end

            # Unplaced parts
            unplaced_parts = {}
            result.unplaced_parts.each { |box|
              part = unplaced_parts[box.data[:number]]
              unless part
                part = {
                    :id => box.data[:id],
                    :number => box.data[:number],
                    :name => box.data[:name],
                    :length => box.data[:length],
                    :cutting_length => box.data[:cutting_length],
                    :count => 0,
                }
                unplaced_parts[box.data[:number]] = part
              end
              part[:count] += 1
            }
            unplaced_parts.sort_by { |k, v| v[:number] }.each { |key, part|
              response[:unplaced_parts].push(part)
            }

            # Bars
            index = 0
            result.bars.each { |bin|

              index += 1
              bar = {
                  :index => index,
                  :px_length => to_px(bin.length),
                  :type => bin.type, # TODO
                  :length => bin.length.to_l.to_s,
                  :efficiency => bin.efficiency,
                  :total_length_cuts => bin.total_length_cuts.to_l.to_s,
                  :parts => bin.parts,
                  :grouped_parts => [],
                  :leftover => bin.leftover,
                  :cuts => bin.cuts,
              }

              puts("result for bar #{index}")
              puts("type: ", bar[:type])
              puts("length: ", bar[:length])
              puts("efficiency [0,1]: ", bar[:efficiency])
              puts("leftover/waste: ", bar[:leftover].to_l.to_s)
              puts("parts: ")
              bar[:parts].each do |p|
                print(p[:length].to_l.to_s, " (", p[:id], ") ")
              end
              puts()

              puts("nb of cuts:", bin.nb_of_cuts)
              bar[:cuts].each do |c|
                print(c.to_l.to_s, " ")
              end
              puts()

              response[:bars].push(bar)

=begin
              # Parts
              grouped_parts = {}
              bin.parts.each { |box|
                bar[:parts].push(
                    {
                        :id => box.data[:id],
                        :number => box.data[:number],
                        :name => box.data[:name],
                        :px_x => to_px(box.x),
                        :px_length => to_px(box.length),
                        :length => box.length.to_l.to_s,
                    }
                )
                grouped_part = grouped_parts[box.data[:id]]
                unless grouped_part
                  grouped_part = {
                      :id => box.data[:id],
                      :number => box.data[:number],
                      :saved_number => box.data[:saved_number],
                      :name => box.data[:name],
                      :count => 0,
                      :length => box.data[:length],
                      :cutting_length => box.data[:cutting_length],
                  }
                  grouped_parts.store(box.data[:id], grouped_part)
                end
                grouped_part[:count] += 1
              }
              sheet[:grouped_parts] = grouped_parts.values.sort_by { |v| [ v[:number] ] }

              # Leftovers
              bin.leftovers.each { |box|
                sheet[:leftovers].push(
                    {
                        :px_x => to_px(box.x),
                        :px_length => to_px(box.length),
                        :length => box.length.to_l.to_s,
                    }
                )
              }

              # Cuts
              bin.cuts.each { |cut|
                sheet[:cuts].push(
                    {
                        :px_x => to_px(cut.x),
                        :px_length => to_px(cut.length),
                        :x => cut.x.to_l.to_s,
                        :length => cut.length.to_l.to_s,
                    }
                )
              }
=end

            }
          end

          return response
        }

      end
    end

    def group_cuttingdiagram_2d_command(settings)
      if @cutlist

        # Check settings
        group_id = settings['group_id']
        std_sheet_length = DimensionUtils.instance.str_to_ifloat(settings['std_sheet_length']).to_l.to_f
        std_sheet_width = DimensionUtils.instance.str_to_ifloat(settings['std_sheet_width']).to_l.to_f
        scrap_sheet_sizes = DimensionUtils.instance.dxd_to_ifloats(settings['scrap_sheet_sizes'])
        grained = settings['grained']
        hide_part_list = settings['hide_part_list']
        saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
        trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f
        presort = BinPacking2D::Packing2D.valid_presort(settings['presort'])
        stacking = BinPacking2D::Packing2D.valid_stacking(settings['stacking'])
        bbox_optimization = BinPacking2D::Packing2D.valid_bbox_optimization(settings['bbox_optimization'])

        @cutlist[:groups].each { |group|

          if group_id && group[:id] != group_id
            next
          end

          # The dimensions need to be in Sketchup internal units AND float
          options = BinPacking2D::Options.new
          options.base_bin_length = std_sheet_length
          options.base_bin_width = std_sheet_width
          options.rotatable = !grained
          options.saw_kerf = saw_kerf
          options.trimming = trimming
          options.stacking = stacking
          options.bbox_optimization = bbox_optimization
          options.presort = presort

          # Create the bin packing engine with given bins and boxes
          e = BinPacking2D::PackEngine.new(options)

          # Add bins from scrap sheets
          scrap_sheet_sizes.split(';').each { |scrap_sheet_size|
            size2d = Size2d.new(scrap_sheet_size)
            e.add_bin(size2d.length.to_f, size2d.width.to_f)
          }

          # Add boxes from parts
          group[:parts].each { |part|
            for i in 1..part[:count]
              e.add_box(part[:cutting_length].to_l.to_f, part[:cutting_width].to_l.to_f, part)
            end
          }

          # Compute the cutting diagram
          result, err = e.run

          # Response
          # --------

          # Convert inch float value to pixel
          def to_px(inch_value)
            inch_value * 7 # 840px = 120" ~ 3m
          end

          response = {
              :errors => [],
              :warnings => [],
              :tips => [],

              :options => {
                :hide_part_list => hide_part_list,
                :px_saw_kerf => to_px(options.saw_kerf),
                :saw_kerf => options.saw_kerf.to_l.to_s,
                :trimming => options.trimming.to_l.to_s,
                :stacking => stacking,
                :bbox_optimization => bbox_optimization,
                :presort => presort,
              },

              :unplaced_parts => [],
              :summary => {
                :sheets => [],
              },
              :sheets => [],
          }

          if err > BinPacking2D::ERROR_NONE

            # Engine error -> returns error only

            case err
              when BinPacking2D::ERROR_NO_BIN
                response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_sheet'
              when BinPacking2D::ERROR_NO_PLACEMENT_POSSIBLE
                response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_placement_possible'
              when BinPacking2D::ERROR_BAD_ERROR
                response[:errors] << 'tab.cutlist.cuttingdiagram.error.bad_error'
            end

          else

            # Errors
            if result.unplaced_boxes.length > 0
              response[:errors] << [ 'tab.cutlist.cuttingdiagram.error.unplaced_parts', { :count => result.unplaced_boxes.length } ]
            end

            # Warnings
            materials = Sketchup.active_model.materials
            material = materials[group[:material_name]]
            material_attributes = MaterialAttributes.new(material)
            if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0 || group[:edge_decremented]
              response[:warnings] << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions'
            end
            if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0
              response[:warnings] << [ 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_increase_2d', { :material_name => group[:material_name], :length_increase => material_attributes.length_increase, :width_increase => material_attributes.width_increase } ]
            end
            if group[:edge_decremented]
              response[:warnings] << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_edge_decrement'
            end

            # Unplaced boxes
            unplaced_parts = {}
            result.unplaced_boxes.each { |box|
              part = unplaced_parts[box.data[:number]]
              unless part
                part = {
                    :id => box.data[:id],
                    :number => box.data[:number],
                    :name => box.data[:name],
                    :length => box.data[:length],
                    :width => box.data[:width],
                    :cutting_length => box.data[:cutting_length],
                    :cutting_width => box.data[:cutting_width],
                    :edge_count => box.data[:edge_count],
                    :edge_pattern => box.data[:edge_pattern],
                    :edge_decrements => box.data[:edge_decrements],
                    :count => 0,
                }
                unplaced_parts[box.data[:number]] = part
              end
              part[:count] += 1
            }
            unplaced_parts.sort_by { |k, v| v[:number] }.each { |key, part|
              response[:unplaced_parts].push(part)
            }

            # Summary
            result.unused_bins.each { |bin|
              response[:summary][:sheets].push(
                  {
                      :type => bin.type,
                      :count => 1,
                      :length => bin.length.to_l.to_s,
                      :width => bin.width.to_l.to_s,
                      :area => DimensionUtils.instance.format_to_readable_area(Size2d.new(bin.length.to_l, bin.width.to_l).area),
                      :is_used => false,
                  }
              )
            }
            summary_sheets = {}
            index = 0
            result.original_bins.each { |bin|
              index += 1
              id = "#{bin.type},#{bin.length},#{bin.width}"
              sheet = summary_sheets[id]
              unless sheet
                sheet = {
                    :index => index,
                    :type => bin.type,
                    :count => 0,
                    :length => bin.length.to_l.to_s,
                    :width => bin.width.to_l.to_s,
                    :area => 0, # Will be converted to string representation after sum
                    :is_used => true,
                }
                summary_sheets[id] = sheet
              end
              sheet[:count] += 1
              sheet[:area] += Size2d.new(bin.length.to_l, bin.width.to_l).area
            }
            summary_sheets.each { |id, sheet|
              sheet[:area] = DimensionUtils.instance.format_to_readable_area(sheet[:area])
            }
            response[:summary][:sheets] += summary_sheets.values

            # Sheets
            index = 0
            result.original_bins.each { |bin|

              index += 1
              sheet = {
                  :index => index,
                  :px_length => to_px(bin.length),
                  :px_width => to_px(bin.width),
                  :type => bin.type,
                  :length => bin.length.to_l.to_s,
                  :width => bin.width.to_l.to_s,
                  :efficiency => bin.efficiency,
                  :total_length_cuts => bin.total_length_cuts.to_l.to_s,

                  :parts => [],
                  :grouped_parts => [],
                  :leftovers => [],
                  :cuts => [],
              }
              response[:sheets].push(sheet)

              # Parts
              grouped_parts = {}
              bin.boxes.each { |box|
                sheet[:parts].push(
                    {
                        :id => box.data[:id],
                        :number => box.data[:number],
                        :name => box.data[:name],
                        :px_x => to_px(box.x),
                        :px_y => to_px(box.y),
                        :px_length => to_px(box.length),
                        :px_width => to_px(box.width),
                        :length => box.length.to_l.to_s,
                        :width => box.width.to_l.to_s,
                        :rotated => box.rotated,
                        :edge_material_names => box.data[:edge_material_names],
                        :edge_std_dimensions => box.data[:edge_std_dimensions],
                    }
                )
                grouped_part = grouped_parts[box.data[:id]]
                unless grouped_part
                  grouped_part = {
                      :id => box.data[:id],
                      :number => box.data[:number],
                      :saved_number => box.data[:saved_number],
                      :name => box.data[:name],
                      :count => 0,
                      :length => box.data[:length],
                      :width => box.data[:width],
                      :cutting_length => box.data[:cutting_length],
                      :cutting_width => box.data[:cutting_width],
                      :edge_count => box.data[:edge_count],
                      :edge_pattern => box.data[:edge_pattern],
                      :edge_decrements => box.data[:edge_decrements],
                  }
                  grouped_parts.store(box.data[:id], grouped_part)
                end
                grouped_part[:count] += 1
              }
              sheet[:grouped_parts] = grouped_parts.values.sort_by { |v| [ v[:number] ] }

              # Leftovers
              bin.leftovers.each { |box|
                sheet[:leftovers].push(
                    {
                        :px_x => to_px(box.x),
                        :px_y => to_px(box.y),
                        :px_length => to_px(box.length),
                        :px_width => to_px(box.width),
                        :length => box.length.to_l.to_s,
                        :width => box.width.to_l.to_s,
                    }
                )
              }

              # Cuts
              bin.cuts.each { |cut|
                sheet[:cuts].push(
                    {
                        :px_x => to_px(cut.x),
                        :px_y => to_px(cut.y),
                        :px_length => to_px(cut.length),
                        :x => cut.x.to_l.to_s,
                        :y => cut.y.to_l.to_s,
                        :length => cut.length.to_l.to_s,
                        :is_horizontal => cut.is_horizontal,
                    }
                )
              }

            }

          end

          return response
        }

      end

    end

  end

end