module Ladb::OpenCutList

  require_relative '../../helper/bounding_box_helper'
  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../helper/material_attributes_caching_helper'
  require_relative '../../helper/definition_attributes_caching_helper'
  require_relative '../../model/attributes/material_attributes'
  require_relative '../../model/attributes/definition_attributes'
  require_relative '../../model/geom/size3d'
  require_relative '../../model/cutlist/cutlist'
  require_relative '../../model/cutlist/face_info'
  require_relative '../../model/cutlist/instance_info'
  require_relative '../../model/cutlist/material_usage'
  require_relative '../../model/cutlist/group_def'
  require_relative '../../model/cutlist/group'
  require_relative '../../model/cutlist/part_def'
  require_relative '../../model/cutlist/part'
  require_relative '../../utils/transformation_utils'

  class CutlistGenerateWorker

    include BoundingBoxHelper
    include LayerVisibilityHelper
    include MaterialAttributesCachingHelper
    include DefinitionAttributesCachingHelper

    MATERIAL_ORIGIN_UNKNOWN = 0
    MATERIAL_ORIGIN_OWNED = 1
    MATERIAL_ORIGIN_INHERITED = 2
    MATERIAL_ORIGIN_CHILD = 3

    def initialize(

                   auto_orient: true,
                   flipped_detection: true,
                   smart_material: true,
                   dynamic_attributes_name: false,
                   part_number_with_letters: true,
                   part_number_sequence_by_group: true,
                   part_folding: false,
                   group_order_strategy: 'material_type>material_name>-std_width>-std_thickness',
                   part_order_strategy: '-thickness>-length>-width>-count>name>-edge_pattern>tags>thickness_layer_count',
                   hide_descriptions: false,
                   hide_tags: false,
                   hide_final_areas: true,

                   tags_filter: [],
                   edge_material_names_filter: [],
                   veneer_material_names_filter: [],

                   active_entity: nil,
                   active_path: nil,

                   # Unused but present for preset compatibility
                   hide_entity_names: nil,
                   hide_cutting_dimensions: nil,
                   hide_bbox_dimensions: nil,
                   hide_edges: nil,
                   hide_faces: nil,
                   hide_material_colors: nil,
                   minimize_on_highlight: nil,
                   dimension_column_order_strategy: nil,
                   tags: nil,
                   hidden_group_ids: nil

    )

      @auto_orient = auto_orient
      @flipped_detection = flipped_detection
      @smart_material = smart_material
      @dynamic_attributes_name = dynamic_attributes_name
      @part_number_with_letters = part_number_with_letters
      @part_number_sequence_by_group = part_number_sequence_by_group
      @part_folding = part_folding
      @group_order_strategy = group_order_strategy
      @part_order_strategy = part_order_strategy
      @hide_descriptions = hide_descriptions
      @hide_tags = hide_tags
      @hide_final_areas = hide_final_areas

      @tags_filter = tags_filter
      @edge_material_names_filter = edge_material_names_filter
      @veneer_material_names_filter = veneer_material_names_filter

      # Retrieve active entity (if defined)
      @active_entity = active_entity
      @active_path = active_path

      # Setup caches
      @instance_infos_cache = {}
      @group_defs_cache = {}
      @material_usages_cache = {}

      # Reset materials and definitions used UUIDS
      MaterialAttributes::reset_used_uuids
      DefinitionAttributes::reset_used_uuids

    end

    # -----

    def run

      model = Sketchup.active_model

      if @active_entity && @active_path

        # An active entity and its path is defined => use it
        _fetch_useful_instance_infos(@active_entity, @active_path, @auto_orient)

      else

        # Retrieve selected entities or all if no selection
        if model
          path = model.active_path ? model.active_path : []
          if model.selection.empty?
            entities = model.active_entities
            is_entity_selection = false
          else
            entities = model.selection
            is_entity_selection = true
          end
        else
          path = []
          entities = []
          is_entity_selection = false
        end

        # Fetch component instances in given entities
        entities.each { |entity|
          _fetch_useful_instance_infos(entity, path, @auto_orient)
        }

      end

      # Retrieve model infos
      length_unit = DimensionUtils.length_unit
      mass_unit_strippedname = MassUtils.get_strippedname
      currency_symbol = PriceUtils.currency_symbol
      dir, filename = File.split(model && !model.path.empty? ? model.path : PLUGIN.get_i18n_string('default.empty_filename'))
      model_name = model ? model.name : ''
      model_description = model ? model.description : ''
      model_active_path = model ? PathUtils.get_named_path(model.active_path, true, 0) : nil
      page_name = model && model.pages && model.pages.selected_page ? model.pages.selected_page.name : ''
      page_description = model && model.pages && model.pages.selected_page ? model.pages.selected_page.description : ''

      # Create cut list
      cutlist = Cutlist.new(dir, filename, model_name, model_description, model_active_path, page_name, page_description, is_entity_selection, length_unit, mass_unit_strippedname, currency_symbol, @instance_infos_cache.length)

      # Errors & tips
      if @instance_infos_cache.length == 0
        if model
          if entities && entities.length == 0
            cutlist.add_error('tab.cutlist.error.no_entities')
          else
            if is_entity_selection
              cutlist.add_error('tab.cutlist.error.no_component_in_selection')
            else
              cutlist.add_error('tab.cutlist.error.no_component_in_model')
            end
            cutlist.add_tip('tab.cutlist.tip.no_component')
          end
        else
          cutlist.add_error('tab.cutlist.error.no_model')
        end
      end

      # Materials usages
      materials = model ? model.materials : []
      materials.each { |material|
        material_attributes = _get_material_attributes(material)
        material_usage = MaterialUsage.new(material.name, material.display_name, material_attributes.type, material.color, material_attributes.grained, !material.texture.nil?)
        _store_material_usage(material_usage)
      }

      # PHASE 1 - Populate cutlist

      @instance_infos_cache.each do |key, instance_info|

        entity = instance_info.entity

        definition = entity.definition
        definition_attributes = _get_definition_attributes(definition)

        # Populate used tags
        cutlist.add_used_tags(definition_attributes.tags)

        # Tags filter
        unless @tags_filter.empty?
          ok_tags = []
          ko_tags = []
          @tags_filter.each do |value|
            m = /([+-])(.*)/.match(value)
            ok_tags << m[2] if m && m[1] == '+'
            ko_tags << m[2] if m && m[1] == '-'
          end
          if !ok_tags.empty? && !definition_attributes.has_tags(ok_tags) || !ko_tags.empty? && definition_attributes.has_tags(ko_tags)
            cutlist.ignored_instance_count += 1
            next
          end
        end

        material, material_origin = _get_material(instance_info.path, @smart_material)
        material_attributes = _get_material_attributes(material)
        material_name = material ? material.name : ''

        if material

          material_usage = _get_material_usage(material.name)
          if material_usage
            material_usage.use_count += 1
          end

          # Edge and veneer materials filter -> exclude all non-sheet good parts
          if (!@edge_material_names_filter.empty? || !@veneer_material_names_filter.empty?) && material_attributes.type != MaterialAttributes::TYPE_SHEET_GOOD
            cutlist.ignored_instance_count += 1
            next
          end

        end

        # Sanitize definition attributes according to material type
        case material_attributes.type
          when MaterialAttributes::TYPE_UNKNOWN
            definition_attributes.instance_count_by_part = 1
            definition_attributes.cumulable = DefinitionAttributes::CUMULABLE_NONE
            definition_attributes.thickness_layer_count = 1
            definition_attributes.length_increase = 0
            definition_attributes.width_increase = 0
            definition_attributes.thickness_increase = 0
          when MaterialAttributes::TYPE_SOLID_WOOD
            definition_attributes.instance_count_by_part = 1
            definition_attributes.mass = ''
            definition_attributes.price = ''
            definition_attributes.thickness_layer_count = 1
          when MaterialAttributes::TYPE_SHEET_GOOD
            definition_attributes.instance_count_by_part = 1
            definition_attributes.mass = ''
            definition_attributes.price = ''
            definition_attributes.thickness_increase = 0
          when MaterialAttributes::TYPE_DIMENSIONAL
            definition_attributes.instance_count_by_part = 1
            definition_attributes.mass = ''
            definition_attributes.price = ''
            definition_attributes.width_increase = 0
            definition_attributes.thickness_increase = 0
            definition_attributes.thickness_layer_count = 1
          when MaterialAttributes::TYPE_HARDWARE
            definition_attributes.cumulable = DefinitionAttributes::CUMULABLE_NONE
            definition_attributes.thickness_layer_count = 1
            definition_attributes.length_increase = 0
            definition_attributes.width_increase = 0
            definition_attributes.thickness_increase = 0
        end

        # Compute face infos
        x_face_infos, y_face_infos, z_face_infos, content_layers = nil
        if material_attributes.type == MaterialAttributes::TYPE_SOLID_WOOD ||
          material_attributes.type == MaterialAttributes::TYPE_SHEET_GOOD ||
          material_attributes.type == MaterialAttributes::TYPE_DIMENSIONAL

          x_face_infos, y_face_infos, z_face_infos, content_layers = _grab_main_faces_and_layers(definition)

        end

        # Edges and Veneers
        edges_def = nil
        veneers_def = nil
        if material_attributes.type == MaterialAttributes::TYPE_SHEET_GOOD

          # -- Edges --

          # Grab min/max face infos
          xmin_face_infos, xmax_face_infos = _grab_oriented_min_max_face_infos(instance_info, x_face_infos, y_face_infos, z_face_infos, X_AXIS, @flipped_detection && instance_info.flipped ^ instance_info.size.axes_flipped?)
          ymin_face_infos, ymax_face_infos = _grab_oriented_min_max_face_infos(instance_info, x_face_infos, y_face_infos, z_face_infos, Y_AXIS)

          # Grab edge materials
          edge_ymin_materials = _grab_face_typed_materials(ymin_face_infos, MaterialAttributes::TYPE_EDGE)
          edge_ymax_materials = _grab_face_typed_materials(ymax_face_infos, MaterialAttributes::TYPE_EDGE)
          edge_xmin_materials = _grab_face_typed_materials(xmin_face_infos, MaterialAttributes::TYPE_EDGE)
          edge_xmax_materials = _grab_face_typed_materials(xmax_face_infos, MaterialAttributes::TYPE_EDGE)

          edge_ymin_material = edge_ymin_materials.empty? ? nil : edge_ymin_materials.first
          edge_ymax_material = edge_ymax_materials.empty? ? nil : edge_ymax_materials.first
          edge_xmin_material = edge_xmin_materials.empty? ? nil : edge_xmin_materials.first
          edge_xmax_material = edge_xmax_materials.empty? ? nil : edge_xmax_materials.first
          edge_materials = [ edge_ymin_material, edge_ymax_material, edge_xmin_material, edge_xmax_material ].compact.uniq

          # Materials filter
          if !@edge_material_names_filter.empty? && !(@edge_material_names_filter - edge_materials.map { |m| m.display_name }).empty?
            cutlist.ignored_instance_count += 1
            next
          end

          # Increment material usage
          edge_materials.each do |edge_material|
            if (material_usage = _get_material_usage(edge_material.name))
              material_usage.use_count += 1
            end
          end

          # Grab material attributes
          edge_ymin_material_attributes = _get_material_attributes(edge_ymin_material)
          edge_ymax_material_attributes = _get_material_attributes(edge_ymax_material)
          edge_xmin_material_attributes = _get_material_attributes(edge_xmin_material)
          edge_xmax_material_attributes = _get_material_attributes(edge_xmax_material)

          # Compute decrements
          ymin_decrement = edge_ymin_material_attributes.edge_decremented ? edge_ymin_material_attributes.l_thickness : 0
          ymax_decrement = edge_ymax_material_attributes.edge_decremented ? edge_ymax_material_attributes.l_thickness : 0
          xmin_decrement = edge_xmin_material_attributes.edge_decremented ? edge_xmin_material_attributes.l_thickness : 0
          xmax_decrement = edge_xmax_material_attributes.edge_decremented ? edge_xmax_material_attributes.l_thickness : 0
          length_decrement = xmin_decrement + xmax_decrement
          width_decrement = ymin_decrement + ymax_decrement
          edge_decremented = length_decrement > 0 || width_decrement > 0

          # Populate EdgeDef
          edges_def = {
            :ymin_material => edge_ymin_material,
            :ymax_material => edge_ymax_material,
            :xmin_material => edge_xmin_material,
            :xmax_material => edge_xmax_material,
            :ymin_entity_ids => ymin_face_infos.collect { |face_info| face_info.face.entityID },
            :ymax_entity_ids => ymax_face_infos.collect { |face_info| face_info.face.entityID },
            :xmin_entity_ids => xmin_face_infos.collect { |face_info| face_info.face.entityID },
            :xmax_entity_ids => xmax_face_infos.collect { |face_info| face_info.face.entityID },
            :ymin_decrement => ymin_decrement.to_l,
            :ymax_decrement => ymax_decrement.to_l,
            :xmin_decrement => xmin_decrement.to_l,
            :xmax_decrement => xmax_decrement.to_l,
            :length_decrement => length_decrement.to_l,
            :width_decrement => width_decrement.to_l,
            :decremented => edge_decremented,
          }

          # -- Veneers --

          # Grab min/max face infos
          zmin_face_infos, zmax_face_infos = _grab_oriented_min_max_face_infos(instance_info, x_face_infos, y_face_infos, z_face_infos, Z_AXIS)

          # Grab veneer materials
          veneer_zmin_materials = _grab_face_typed_materials(zmin_face_infos, MaterialAttributes::TYPE_VENEER)
          veneer_zmax_materials = _grab_face_typed_materials(zmax_face_infos, MaterialAttributes::TYPE_VENEER)

          veneer_zmin_material = veneer_zmin_materials.empty? ? nil : veneer_zmin_materials.first
          veneer_zmax_material = veneer_zmax_materials.empty? ? nil : veneer_zmax_materials.first
          veneer_materials = [ veneer_zmin_material, veneer_zmax_material ].compact.uniq

          # Materials filter
          if !@veneer_material_names_filter.empty? && !(@veneer_material_names_filter - veneer_materials.map { |m| m.display_name }).empty?
            cutlist.ignored_instance_count += 1
            next
          end

          # Increment material usage
          veneer_materials.each do |veneer_material|
            if (material_usage = _get_material_usage(veneer_material.name))
              material_usage.use_count += 1
            end
          end

          # Grab material attributes
          veneer_zmin_material_attributes = _get_material_attributes(veneer_zmin_material)
          veneer_zmax_material_attributes = _get_material_attributes(veneer_zmax_material)

          # Compute Thickness decrements
          zmin_decrement = veneer_zmin_material_attributes.l_thickness
          zmax_decrement = veneer_zmax_material_attributes.l_thickness
          thickness_decrement = zmin_decrement + zmax_decrement
          veneer_decremented = thickness_decrement > 0

          # Compute texture angles
          veneer_zmin_texture_angle = !veneer_zmin_material_attributes.grained || zmin_face_infos.empty? ? nil : _get_face_texture_angle(zmin_face_infos.first.face, instance_info)
          veneer_zmax_texture_angle = !veneer_zmax_material_attributes.grained || zmax_face_infos.empty? ? nil : _get_face_texture_angle(zmax_face_infos.first.face, instance_info)

          # Populate VeneerDef
          veneers_def = {
            :zmin_material => veneer_zmin_material,
            :zmax_material => veneer_zmax_material,
            :zmin_entity_ids => zmin_face_infos.collect { |face_info| face_info.face.entityID },
            :zmax_entity_ids => zmax_face_infos.collect { |face_info| face_info.face.entityID },
            :zmin_texture_angle => veneer_zmin_texture_angle,
            :zmax_texture_angle => veneer_zmax_texture_angle,
            :zmin_decrement => zmin_decrement.to_l,
            :zmax_decrement => zmax_decrement.to_l,
            :thickness_decrement => thickness_decrement.to_l,
            :decremented => veneer_decremented
          }

        end

        # Compute transformation, scale and sizes

        thickness = instance_info.size.thickness
        thickness = [ thickness - veneers_def[:thickness_decrement], 0 ].max.to_l if veneers_def && veneers_def[:thickness_decrement]
        thickness = (thickness / definition_attributes.thickness_layer_count).to_l if definition_attributes.thickness_layer_count > 1
        size = Size3d.new(instance_info.size.length, instance_info.size.width, thickness, instance_info.size.axes)
        length_increase = material_attributes.l_length_increase + definition_attributes.l_length_increase
        width_increase = material_attributes.l_width_increase + definition_attributes.l_width_increase
        thickness_increase = material_attributes.l_thickness_increase + definition_attributes.l_thickness_increase
        case material_attributes.type
          when MaterialAttributes::TYPE_SOLID_WOOD, MaterialAttributes::TYPE_SHEET_GOOD
            std_thickness_info = _find_std_value(
                (size.thickness + thickness_increase).to_l,
                material_attributes.l_std_thicknesses,
                material_attributes.type == MaterialAttributes::TYPE_SOLID_WOOD
            )
            std_info = {
                :available => std_thickness_info[:available],
                :dimension_stipped_name => 'thickness',
                :dimension => std_thickness_info[:value].to_s.gsub(/~ /, ''), # Remove ~ if it exists
                :dimension_real => DimensionUtils.to_ocl_precision_s(std_thickness_info[:value]),
                :dimension_rounded => DimensionUtils.rounded_by_model_precision?(std_thickness_info[:value]),
                :width => 0,
                :thickness => std_thickness_info[:value],
                :cutting_size => Size3d.new(
                    (size.length + length_increase).to_l,
                    (size.width + width_increase).to_l,
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
                :dimension => std_section_info[:value].to_s.gsub(/~ /, ''), # Remove ~ if it exists
                :dimension_real => std_section_info[:value].to_ocl_precision_s,
                :dimension_rounded => DimensionUtils.rounded_by_model_precision?(std_section_info[:value].width) || DimensionUtils.rounded_by_model_precision?(std_section_info[:value].height),
                :width => std_section_info[:value].width,
                :thickness => std_section_info[:value].height,
                :cutting_size => Size3d.new(
                    (size.length + length_increase).to_l,
                    std_section_info[:value].width,
                    std_section_info[:value].height
                )
            }
          else
            std_info = {
                :available => true,
                :dimension_stipped_name => '',
                :dimension => '',
                :dimension_real => '',
                :dimension_rounded => false,
                :width => 0,
                :thickness => 0,
                :cutting_size => size
            }
        end
        cutting_size = std_info[:cutting_size]

        # Define group

        group_id = GroupDef.generate_group_id(material, material_attributes, std_info)
        group_def = _get_group_def(group_id)
        unless group_def

          group_def = GroupDef.new(group_id)
          group_def.material = material
          group_def.material_attributes = material_attributes
          group_def.std_available = std_info[:available]
          group_def.std_dimension_stipped_name = std_info[:dimension_stipped_name]
          group_def.std_dimension = std_info[:dimension]
          group_def.std_dimension_real = std_info[:dimension_real]
          group_def.std_dimension_rounded = std_info[:dimension_rounded]
          group_def.std_width = std_info[:width]
          group_def.std_thickness = std_info[:thickness]
          group_def.show_cutting_dimensions = length_increase > 0 || width_increase > 0

          _store_group_def(group_def)

        end

        # Define part

        part_id = PartDef.generate_part_id(group_id, definition, definition_attributes, instance_info, @dynamic_attributes_name, @flipped_detection)
        part_def = group_def.get_part_def(part_id)
        unless part_def

          number = nil
          saved_number = definition_attributes.fetch_number(part_id)
          if saved_number
            if @part_number_with_letters
              if saved_number.is_a?(String)
                number = saved_number
              end
            else
              if saved_number.is_a?(Numeric)
                number = saved_number
              end
            end
          end
          if number
            if @part_number_sequence_by_group
              if group_def.include_number? number
                number = nil
              end
            else
              if _group_defs_include_number? number
                number = nil
              end
            end
          end

          part_def = PartDef.new(part_id)
          part_def.definition_id = definition.name
          part_def.number = number
          part_def.saved_number = saved_number
          part_def.name, part_def.is_dynamic_attributes_name = instance_info.read_name(@dynamic_attributes_name)
          part_def.description = definition.description
          part_def.scale = instance_info.scale
          part_def.flipped = @flipped_detection && (definition_attributes.symmetrical ? false : instance_info.flipped)
          part_def.cutting_size = cutting_size
          part_def.size = size
          part_def.material_name = material_name
          part_def.cumulable = definition_attributes.cumulable
          part_def.instance_count_by_part = definition_attributes.instance_count_by_part
          part_def.mass = definition_attributes.mass
          part_def.price = definition_attributes.price
          part_def.url = definition_attributes.url
          part_def.thickness_layer_count = definition_attributes.thickness_layer_count
          part_def.length_increase = definition_attributes.length_increase
          part_def.length_increased = definition_attributes.l_length_increase > 0
          part_def.width_increase = definition_attributes.width_increase
          part_def.width_increased = definition_attributes.l_width_increase > 0
          part_def.thickness_increase = definition_attributes.thickness_increase
          part_def.thickness_increased = definition_attributes.l_thickness_increase > 0
          part_def.tags = definition_attributes.tags
          part_def.orientation_locked_on_axis = definition_attributes.orientation_locked_on_axis
          part_def.symmetrical = definition_attributes.symmetrical
          part_def.ignore_grain_direction = definition_attributes.ignore_grain_direction
          part_def.auto_oriented = size.auto_oriented?

          # Propose cutting dimensions display if the part is flagged as cumulable
          if definition_attributes.cumulable != DefinitionAttributes::CUMULABLE_NONE
            group_def.show_cutting_dimensions = true
          end

          # Compute axes alignment, final area, layers, edges and veneers
          case group_def.material_attributes.type

            when MaterialAttributes::TYPE_SOLID_WOOD

              t_plane_count, t_final_area, t_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Z_AXIS)
              w_plane_count, w_final_area, w_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Y_AXIS)

              part_def.not_aligned_on_axes = !(t_area_ratio >= 0.7 || w_area_ratio >= 0.7)
              part_def.content_layers = content_layers.to_a

            when MaterialAttributes::TYPE_SHEET_GOOD

              t_plane_count, t_final_area, t_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Z_AXIS)

              part_def.final_area = t_final_area
              part_def.not_aligned_on_axes = !(t_plane_count >= 2 && (_face_infos_by_normal(size.oriented_axis(Y_AXIS), x_face_infos, y_face_infos, z_face_infos).length >= 1 || _face_infos_by_normal(size.oriented_axis(X_AXIS), x_face_infos, y_face_infos, z_face_infos).length >= 1))
              part_def.content_layers = content_layers.to_a

              # -- Edges --

              if edges_def

                # Populate edge GroupDefs (use the full instance thickness)
                edge_ymin_group_def = _populate_edge_group_def(edges_def[:ymin_material], instance_info.size.thickness)
                edge_ymax_group_def = _populate_edge_group_def(edges_def[:ymax_material], instance_info.size.thickness)
                edge_xmin_group_def = _populate_edge_group_def(edges_def[:xmin_material], instance_info.size.thickness)
                edge_xmax_group_def = _populate_edge_group_def(edges_def[:xmax_material], instance_info.size.thickness)

                # Populate PartDef
                part_def.set_edge_materials(edges_def[:ymin_material], edges_def[:ymax_material], edges_def[:xmin_material], edges_def[:xmax_material])
                part_def.set_edge_entity_ids(edges_def[:ymin_entity_ids], edges_def[:ymax_entity_ids], edges_def[:xmin_entity_ids], edges_def[:xmax_entity_ids])
                part_def.set_edge_group_defs(edge_ymin_group_def, edge_ymax_group_def, edge_xmin_group_def, edge_xmax_group_def)
                part_def.set_edge_decrements(edges_def[:ymin_decrement], edges_def[:ymax_decrement], edges_def[:xmin_decrement], edges_def[:xmax_decrement])
                part_def.edge_length_decrement = edges_def[:length_decrement]
                part_def.edge_width_decrement = edges_def[:width_decrement]
                part_def.edge_decremented = edges_def[:decremented]

                group_def.show_cutting_dimensions ||= edges_def[:length_decrement] > 0 || edges_def[:width_decrement] > 0
                group_def.edge_decremented ||= edges_def[:length_decrement] > 0 || edges_def[:width_decrement] > 0

              end

              # -- Veneers --

              if veneers_def

                # Populate veneer GroupDefs
                veneer_zmin_group_def = _populate_veneer_group_def(veneers_def[:zmin_material])
                veneer_zmax_group_def = _populate_veneer_group_def(veneers_def[:zmax_material])

                # Populate PartDef
                part_def.set_veneer_materials(veneers_def[:zmin_material], veneers_def[:zmax_material])
                part_def.set_veneer_entity_ids(veneers_def[:zmin_entity_ids], veneers_def[:zmax_entity_ids])
                part_def.set_veneer_texture_angles(veneers_def[:zmin_texture_angle], veneers_def[:zmax_texture_angle])
                part_def.set_veneer_group_defs(veneer_zmin_group_def, veneer_zmax_group_def)
                part_def.face_thickness_decrement = veneers_def[:thickness_decrement]
                part_def.face_decremented = veneers_def[:face_decremented]

                group_def.face_decremented ||= veneers_def[:thickness_decrement] > 0

              end

            when MaterialAttributes::TYPE_DIMENSIONAL

              t_plane_count, t_final_area, t_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Z_AXIS)
              w_plane_count, w_final_area, w_area_ratio = _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, Y_AXIS)

              part_def.not_aligned_on_axes = !(t_area_ratio >= 0.7 && w_area_ratio >= 0.7 && (t_plane_count >= 2 && w_plane_count >= 2))
              part_def.content_layers = content_layers.to_a

            else
              part_def.not_aligned_on_axes = false

          end

          group_def.show_edges ||= part_def.edge_count > 0
          group_def.show_faces ||= part_def.face_count > 0
          group_def.store_part_def(part_def)

          if number

            # Update max_number in group_def
            if group_def.max_number
              if _comparable_number(number) > _comparable_number(group_def.max_number)
                group_def.max_number = number
              end
            else
              group_def.max_number = number
            end

            # Update max_number in cutlist
            if group_def.max_number
              if cutlist.max_number
                if _comparable_number(group_def.max_number) > _comparable_number(cutlist.max_number)
                  cutlist.max_number = group_def.max_number
                end
              else
                cutlist.max_number = group_def.max_number
              end
            end

          end

        end
        part_def.count += definition_attributes.thickness_layer_count
        part_def.add_material_origin(material_origin)
        part_def.add_entity_id(entity.entityID)
        part_def.add_entity_serialized_path(instance_info.serialized_path)
        part_def.add_entity_name(entity.name, instance_info.named_path)
        part_def.store_instance_info(instance_info)

        if group_def.material_attributes.type != MaterialAttributes::TYPE_UNKNOWN && group_def.material_attributes.type != MaterialAttributes::TYPE_HARDWARE
          group_def.total_cutting_length += part_def.cutting_size.length
          group_def.total_cutting_area += part_def.cutting_size.area * definition_attributes.thickness_layer_count
          if group_def.material_attributes.type == MaterialAttributes::TYPE_SHEET_GOOD
            if part_def.final_area.nil?
              group_def.invalid_final_area_part_count += definition_attributes.thickness_layer_count
            else
              group_def.total_final_area += part_def.final_area * definition_attributes.thickness_layer_count
            end
            if part_def.edge_count > 0
              PartDef::EDGES_Y.each { |edge|
                unless (edge_group_def = part_def.edge_group_defs[edge]).nil? || (edge_material = part_def.edge_materials[edge]).nil?
                  edge_material_attributes = _get_material_attributes(edge_material)
                  edge_length = part_def.size.length
                  edge_cutting_length = edge_length + edge_material_attributes.l_length_increase
                  edge_group_def.total_cutting_length += edge_cutting_length
                  edge_group_def.total_cutting_area += edge_cutting_length * edge_group_def.std_width
                  edge_group_def.total_cutting_volume += edge_cutting_length * edge_group_def.std_width * edge_group_def.std_thickness
                  _populate_edge_part_def(part_def, edge, edge_group_def, edge_length, edge_cutting_length.to_l, edge_group_def.std_width, edge_group_def.std_thickness)
                end
              }
              PartDef::EDGES_X.each { |edge|
                unless (edge_group_def = part_def.edge_group_defs[edge]).nil? || (edge_material = part_def.edge_materials[edge]).nil?
                  edge_material_attributes = _get_material_attributes(edge_material)
                  edge_length = part_def.size.width
                  edge_cutting_length = edge_length + edge_material_attributes.l_length_increase
                  edge_group_def.total_cutting_length += edge_cutting_length
                  edge_group_def.total_cutting_area += edge_cutting_length * edge_group_def.std_width
                  edge_group_def.total_cutting_volume += edge_cutting_length * edge_group_def.std_width * edge_group_def.std_thickness
                  _populate_edge_part_def(part_def, edge, edge_group_def, edge_length, edge_cutting_length.to_l, edge_group_def.std_width, edge_group_def.std_thickness)
                end
              }
            end
            if part_def.face_count > 0
              PartDef::VENEERS_Z.each { |veneer|
                unless (veneer_group_def = part_def.veneer_group_defs[veneer]).nil? || (veneer_material = part_def.veneer_materials[veneer]).nil?
                  veneer_material_attributes = _get_material_attributes(veneer_material)
                  if part_def.face_texture_angles[veneer] != 0

                    points = [
                      Geom::Point3d.new(0                           , 0),
                      Geom::Point3d.new(part_def.cutting_size.length, 0),
                      Geom::Point3d.new(part_def.cutting_size.length, part_def.cutting_size.width),
                      Geom::Point3d.new(0                           , part_def.cutting_size.width),
                    ]
                    unless part_def.face_texture_angles[veneer].nil?
                      t = Geom::Transformation.new(Geom::Point3d.new, Z_AXIS, part_def.face_texture_angles[veneer])
                      points.each { |point| point.transform!(t) }
                    end
                    veneer_bounds = (Geom::BoundingBox.new).add(points)

                    veneer_length = veneer_bounds.width
                    veneer_width = veneer_bounds.height
                  else
                    veneer_length = part_def.cutting_size.length
                    veneer_width = part_def.cutting_size.width
                  end
                  veneer_cutting_length = veneer_length + veneer_material_attributes.l_length_increase
                  veneer_cutting_width = veneer_width + veneer_material_attributes.l_width_increase
                  veneer_group_def.total_cutting_length += veneer_cutting_length
                  veneer_group_def.total_cutting_area += veneer_cutting_length * veneer_cutting_width
                  veneer_group_def.total_cutting_volume += veneer_cutting_length * veneer_cutting_width * veneer_group_def.std_thickness
                  _populate_veneer_part_def(part_def, veneer, veneer_group_def, veneer_length, veneer_width, veneer_cutting_length.to_l, veneer_cutting_width.to_l, veneer_group_def.std_thickness)
                end
              }
            end
          end
          if group_def.material_attributes.type == MaterialAttributes::TYPE_SOLID_WOOD || group_def.material_attributes.type == MaterialAttributes::TYPE_SHEET_GOOD || group_def.material_attributes.type == MaterialAttributes::TYPE_DIMENSIONAL
            group_def.total_cutting_volume += part_def.cutting_size.volume * definition_attributes.thickness_layer_count
          end
        end
        group_def.part_count += definition_attributes.thickness_layer_count

      end

      # Compute instance count by part
      @group_defs_cache.each { |key, group_def|
        group_def.part_defs.each { |key, part_def|
          if part_def.instance_count_by_part > 1
            instance_count = part_def.count
            count = ((instance_count * 1.0) / part_def.instance_count_by_part).ceil
            part_def.count = count
            part_def.unused_instance_count = count * part_def.instance_count_by_part - instance_count
            group_def.part_count -= instance_count - count
          end
        }
      }

      # Warnings & tips
      if @instance_infos_cache.length > 0
        @material_usages_cache.each { |key, material_usage|
          if material_usage.type == MaterialAttributes::TYPE_SOLID_WOOD
            cutlist.solid_wood_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_SHEET_GOOD
            cutlist.sheet_good_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_DIMENSIONAL
            cutlist.dimensional_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_EDGE
            cutlist.edge_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_HARDWARE
            cutlist.hardware_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_VENEER
            cutlist.veneer_material_count += material_usage.use_count
          end
        }
        if cutlist.instance_count - cutlist.ignored_instance_count > 0 && cutlist.solid_wood_material_count == 0 && cutlist.sheet_good_material_count == 0 && cutlist.dimensional_material_count == 0 && cutlist.hardware_material_count == 0
          cutlist.add_warning("tab.cutlist.warning.no_typed_materials_in_#{is_entity_selection ? "selection" : "model"}")
          cutlist.add_tip("tab.cutlist.tip.no_typed_materials")
        end
      end

      # PHASE 2

      # Sort material usages and add them to cutlist
      cutlist.add_material_usages(@material_usages_cache.values.sort_by { |v| [ MaterialAttributes.type_order(v.type), v.display_name.downcase ] })

      part_number = cutlist.max_number ? cutlist.max_number.succ : (@part_number_with_letters ? 'A' : 1)

      # Sort and browse groups

      @group_defs_cache.values.sort { |group_def_a, group_def_b| GroupDef::group_order(group_def_a, group_def_b, @group_order_strategy) }.each do |group_def|

        # Exclude empty groupDef
        next if group_def.part_count == 0

        if @part_number_sequence_by_group
          part_number = group_def.max_number ? group_def.max_number.succ : (@part_number_with_letters ? 'A' : 1)    # Reset number increment on each group
        end

        group = Group.new(group_def, cutlist)
        cutlist.add_group(group)

        # Folding
        if @part_folding
          part_defs = []
          group_def.part_defs.values.sort_by { |v| [ v.size.thickness, v.size.length, v.size.width, v.tags, v.final_area.nil? ? 0 : v.final_area, v.cumulable, v.definition_id ] }.each do |part_def|
            if !(folder_part_def = part_defs.last).nil? &&
                ((folder_part_def.definition_id == part_def.definition_id && group_def.material_attributes.type == MaterialAttributes::TYPE_UNKNOWN) || group_def.material_attributes.type > MaterialAttributes::TYPE_UNKNOWN && group_def.material_attributes.type != MaterialAttributes::TYPE_HARDWARE) && # Part with TYPE_UNKNOWN materiel are folded only if they have the same definition | Part with TYPE_HARDWARE doesn't fold
                folder_part_def.size == part_def.size &&
                folder_part_def.cutting_size == part_def.cutting_size &&
                (@hide_descriptions || folder_part_def.description == part_def.description) &&
                (@hide_tags || folder_part_def.tags == part_def.tags) &&
                (@hide_final_areas || ((folder_part_def.final_area.nil? ? 0 : folder_part_def.final_area) - (part_def.final_area.nil? ? 0 : part_def.final_area)).abs < 0.001) &&      # final_area workaround for rounding error
                folder_part_def.edge_material_names == part_def.edge_material_names &&
                folder_part_def.face_material_names == part_def.face_material_names &&
                folder_part_def.cumulable == part_def.cumulable &&
                folder_part_def.ignore_grain_direction == part_def.ignore_grain_direction
              if folder_part_def.children.empty?
                first_child_part_def = part_defs.pop

                folder_part_def = PartDef.new(first_child_part_def.id + '_folder', first_child_part_def.virtual)
                folder_part_def.name = first_child_part_def.name
                folder_part_def.description = first_child_part_def.description
                folder_part_def.count = first_child_part_def.count
                folder_part_def.cutting_size = first_child_part_def.cutting_size
                folder_part_def.size = first_child_part_def.size
                folder_part_def.material_name = first_child_part_def.material_name
                folder_part_def.cumulable = first_child_part_def.cumulable
                folder_part_def.instance_count_by_part = first_child_part_def.instance_count_by_part
                folder_part_def.mass = first_child_part_def.mass
                folder_part_def.price = first_child_part_def.price
                folder_part_def.tags = first_child_part_def.tags
                folder_part_def.ignore_grain_direction = first_child_part_def.ignore_grain_direction
                folder_part_def.edge_count = first_child_part_def.edge_count
                folder_part_def.edge_pattern = first_child_part_def.edge_pattern
                folder_part_def.edge_materials.merge!(first_child_part_def.edge_materials)
                folder_part_def.edge_material_names.merge!(first_child_part_def.edge_material_names)
                folder_part_def.edge_material_colors.merge!(first_child_part_def.edge_material_colors)
                folder_part_def.edge_std_dimensions.merge!(first_child_part_def.edge_std_dimensions)
                folder_part_def.edge_group_defs.merge!(first_child_part_def.edge_group_defs)
                folder_part_def.edge_length_decrement = first_child_part_def.edge_length_decrement
                folder_part_def.edge_width_decrement = first_child_part_def.edge_width_decrement
                folder_part_def.face_count = first_child_part_def.face_count
                folder_part_def.face_pattern = first_child_part_def.face_pattern
                folder_part_def.face_material_names.merge!(first_child_part_def.face_material_names)
                folder_part_def.face_std_dimensions.merge!(first_child_part_def.face_std_dimensions)
                folder_part_def.veneer_group_defs.merge!(first_child_part_def.veneer_group_defs)
                folder_part_def.face_thickness_decrement = first_child_part_def.face_thickness_decrement
                folder_part_def.merge_entity_names(first_child_part_def.entity_names)
                folder_part_def.final_area = first_child_part_def.final_area

                folder_part_def.children.push(first_child_part_def)
                folder_part_def.children_warning_count += 1 if first_child_part_def.not_aligned_on_axes
                folder_part_def.children_warning_count += 1 if first_child_part_def.multiple_content_layers
                folder_part_def.children_warning_count += 1 if first_child_part_def.unused_instance_count > 0

                part_defs.push(folder_part_def)

              end
              folder_part_def.children.push(part_def)
              folder_part_def.merge_instance_infos(part_def.instance_infos)
              folder_part_def.count += part_def.count
              folder_part_def.merge_entity_names(part_def.entity_names)
              folder_part_def.children_warning_count += 1 if part_def.not_aligned_on_axes
              folder_part_def.children_warning_count += 1 if part_def.multiple_content_layers
              folder_part_def.children_warning_count += 1 if part_def.unused_instance_count > 0
            else
              part_defs.push(part_def)
            end
          end
        else
          part_defs = group_def.part_defs.values
        end

        # Sort and browse parts
        part_defs.sort { |part_def_a, part_def_b| PartDef::part_order(part_def_a, part_def_b, @part_order_strategy) }.each do |part_def|

          if part_def.children.empty?

            # Part is single part
            part = Part.new(part_def, group, part_number)
            unless part_def.number
              part_number = part_number.succ
            end

          else

            # Part is folder part
            part = FolderPart.new(part_def, group)

            # Iterate on children
            part_def.children.sort { |part_def_a, part_def_b| PartDef::part_order(part_def_a, part_def_b, @part_order_strategy) }.each { |child_part_def|
              child_part = ChildPart.new(child_part_def, group, part_number, part)
              unless child_part_def.number
                part_number = part_number.succ
              end
              part.add_child(child_part)
            }

          end

          group.add_part(part)
        end

      end

      cutlist
    end

    # -----

    private

    # -- Cache Utils --

    # InstanceInfos

    def _store_instance_info(instance_info)
      @instance_infos_cache[instance_info.serialized_path] = instance_info
    end

    def _get_instance_info(serialized_path)
      return @instance_infos_cache[serialized_path] if @instance_infos_cache.has_key?(serialized_path)
      nil
    end

    # GroupDefs

    def _store_group_def(group_def)
      @group_defs_cache[group_def.id] = group_def
    end

    def _get_group_def(id)
      return @group_defs_cache[id] if @group_defs_cache.has_key?(id)
      nil
    end

    def _group_defs_include_number?(number)
      @group_defs_cache.each { |key, group_def|
        return true if group_def.include_number?(number)
      }
      false
    end

    # MaterialUsage

    def _store_material_usage(material_usage)
      @material_usages_cache[material_usage.name] = material_usage
    end

    def _get_material_usage(name)
      return @material_usages_cache[name] if @material_usages_cache.has_key?(name)
      nil
    end

    # -- Components utils --

    def _fetch_useful_instance_infos(entity, path, auto_orient, face_bounds_cache = {})
      return 0 if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges
      face_count = 0
      if entity.visible? && _layer_visible?(entity.layer, path.empty?)

        if entity.is_a?(Sketchup::Group)

          # Entity is a group : check its children
          entity.entities.each { |child_entity|
            face_count += _fetch_useful_instance_infos(child_entity, path + [ entity ], auto_orient, face_bounds_cache)
          }

        elsif entity.is_a?(Sketchup::ComponentInstance)

          # Exclude special behavior components
          return 0 if entity.definition.behavior.always_face_camera?

          # Entity is a component instance : check its children
          entity.definition.entities.each { |child_entity|
            face_count += _fetch_useful_instance_infos(child_entity, path + [ entity ], auto_orient, face_bounds_cache)
          }

          # Treat cuts_opening behavior component instances as simple group
          return face_count if entity.definition.behavior.cuts_opening?

          # Consider the component instance only if it contains faces
          if face_count > 0

            face_bounds_cache[entity.definition] = _compute_faces_bounds(entity.definition) unless face_bounds_cache.has_key?(entity.definition)
            bounds = face_bounds_cache[entity.definition]
            unless bounds.empty? || [ bounds.width, bounds.height, bounds.depth ].min == 0    # Exclude empty or flat bounds

              # Create the instance info
              instance_info = InstanceInfo.new(path + [ entity ])
              instance_info.size = Size3d.create_from_bounds(bounds, instance_info.scale, auto_orient && !_get_definition_attributes(entity.definition).orientation_locked_on_axis)
              instance_info.definition_bounds = bounds

              # Add instance info to cache
              _store_instance_info(instance_info)

              return 0
            end

          end

        elsif entity.is_a?(Sketchup::Face)

          # Entity is a face : return 1
          return 1

        end
      end
      face_count
    end

    # -- Faces Utils --

    def _grab_main_faces_and_layers(definition_or_group, x_face_infos = [], y_face_infos = [], z_face_infos = [], content_layers = Set[], transformation = nil)
      definition_or_group.entities.each { |entity|
        next if entity.is_a?(Sketchup::Edge)   # Minor Speed imrovement when there's a lot of edges
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Face)
            transformed_normal = transformation.nil? ? entity.normal : entity.normal.transform(transformation)
            if transformed_normal.parallel?(X_AXIS)
              x_face_infos.push(FaceInfo.new(entity, transformation))
            elsif transformed_normal.parallel?(Y_AXIS)
              y_face_infos.push(FaceInfo.new(entity, transformation))
            elsif transformed_normal.parallel?(Z_AXIS)
              z_face_infos.push(FaceInfo.new(entity, transformation))
            end
            content_layers.add(entity.layer)
          elsif entity.is_a?(Sketchup::Group)
            _grab_main_faces_and_layers(entity, x_face_infos, y_face_infos, z_face_infos, content_layers.add(entity.layer), transformation ? transformation * entity.transformation : entity.transformation)
          elsif entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening?
            _grab_main_faces_and_layers(entity.definition, x_face_infos, y_face_infos, z_face_infos, content_layers.add(entity.layer), transformation ? transformation * entity.transformation : entity.transformation)
          end
        end
      }
      [ x_face_infos, y_face_infos, z_face_infos, content_layers ]
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
      [ plane_grouped_face_infos.length, areas.max ]
    end

    def _compute_oriented_final_area_and_ratio(instance_info, x_face_infos, y_face_infos, z_face_infos, axis)

      plane_count, final_area = _compute_largest_final_area(instance_info.size.oriented_axis(axis), x_face_infos, y_face_infos, z_face_infos, instance_info.transformation)
      area = instance_info.size.area_by_axis(axis)
      area_ratio = (final_area.nil? || area.nil?) ? 0 : final_area / area

      [ plane_count, final_area, area_ratio ]
    end

    def _grab_oriented_min_max_face_infos(instance_info, x_face_infos, y_face_infos, z_face_infos, axis, flipped = false)

      min_face_infos = []
      max_face_infos = []
      oriented_axis = instance_info.size.oriented_axis(axis)
      plane_grouped_face_infos = _populate_plane_grouped_face_infos_by_normal(oriented_axis, x_face_infos, y_face_infos, z_face_infos)
      plane_grouped_face_infos.each { |plane, face_infos|
        if instance_info.definition_bounds.min.on_plane?(plane)
          if flipped
            max_face_infos += face_infos
          else
            min_face_infos += face_infos
          end
        elsif instance_info.definition_bounds.max.on_plane?(plane)
          if flipped
            min_face_infos += face_infos
          else
            max_face_infos += face_infos
          end
        end
      }

      [ min_face_infos, max_face_infos ]
    end

    def _grab_face_typed_materials(face_infos, type)

      materials = Set[]
      face_infos.each { |face_info|
        if face_info.face.material && _get_material_attributes(face_info.face.material).type == type
          materials.add(face_info.face.material)
        end
      }

      materials
    end

    def _get_face_texture_angle(face, instance_info)
      return nil if instance_info.size.auto_oriented? || instance_info.size.axes_flipped?   # Angles are disabled
      return nil if face.nil? || !face.respond_to?(:clear_texture_position)                 # SU 2022+
      return 0 if face.material.nil? || face.material.texture.nil?                          # Default angle

      # Returns the angle in radians [0..2PI] between one edge of the face and its UV representation

      p0 = face.edges.first.start.position
      p1 = face.edges.first.end.position

      uv_helper = face.get_UVHelper(true, false)
      uv0 = uv_helper.get_front_UVQ(p0)
      uv1 = uv_helper.get_front_UVQ(p1)

      tw = face.material.texture.width
      th = face.material.texture.height
      uv0.x *= tw
      uv0.y *= th
      uv1.x *= tw
      uv1.y *= th

      v0 = Geom::Vector3d.new((p1 - p0).to_a)
      v1 = Geom::Vector3d.new((uv1 - uv0).to_a)

      angle = v0.angle_between(v1)
      angle *= -1 if face.normal.dot(v0.cross(v1)) > 0
      angle % (2 * Math::PI)
    end

    # -- Std utils --

    def _find_std_value(value, std_values, nearest_highest)
      value_f = DimensionUtils.to_ocl_precision_f(value)
      std_values.each { |std_value|
        std_value_f = DimensionUtils.to_ocl_precision_f(std_value)
        if value_f <= std_value_f
          if nearest_highest
            return {
                :available => true,
                :value => std_value
            }
          else
            return {
                :available => value_f == std_value_f,
                :value => value.to_l  # Force value to be Length type
            }
          end
        end
      }
      {
          :available => false,
          :value => value.to_l  # Force value to be Length type
      }
    end

    def _find_std_section(width, thickness, std_sections)
      width_f = DimensionUtils.to_ocl_precision_f(width)
      thickness_f = DimensionUtils.to_ocl_precision_f(thickness)
      std_sections.each do |std_section|
        std_width_f = DimensionUtils.to_ocl_precision_f(std_section.width)
        std_height_f = DimensionUtils.to_ocl_precision_f(std_section.height)
        if width_f == std_width_f && thickness_f == std_height_f
          return {
              :available => true,
              :value => Section.new(std_section.width, std_section.height)
          }
        end
      end
      {
          :available => false,
          :value => Section.new(width, thickness)
      }
    end

    # -- Material Utils --

    def _get_material(path, smart = true, no_virtual = true)
      unless path
        return nil, MATERIAL_ORIGIN_UNKNOWN
      end
      entity = path.last
      unless entity.is_a?(Sketchup::Drawingelement)
        return nil, MATERIAL_ORIGIN_UNKNOWN
      end
      material = entity.material
      material = nil if no_virtual && MaterialAttributes.is_virtual?(_get_material_attributes(material))
      material_origin = material ? MATERIAL_ORIGIN_OWNED : MATERIAL_ORIGIN_UNKNOWN
      unless material || !smart
        material = _get_dominant_child_material(entity, 0, no_virtual)
        if material
          material_origin = MATERIAL_ORIGIN_CHILD
        else
          material = _get_inherited_material(path[0...-1], no_virtual)
          if material
            material_origin = MATERIAL_ORIGIN_INHERITED
          end
        end
      end
      [ material, material_origin ]
    end

    def _get_dominant_child_material(entity, level = 0, no_virtual = true)
      material = nil
      if entity.is_a?(Sketchup::Group) || (entity.is_a?(Sketchup::ComponentInstance) && (level == 0 || entity.definition.behavior.cuts_opening?))

        materials_type_and_count = {}

        # Entity is a group : check its children
        if entity.is_a?(Sketchup::ComponentInstance)
          entities = entity.definition.entities
        else
          entities = entity.entities
        end
        entities.each do |child_entity|
          child_material = _get_dominant_child_material(child_entity, level + 1, no_virtual)
          next if child_material.nil?
          unless materials_type_and_count.has_key?(child_material)
            materials_type_and_count[child_material] = {
              :type => _get_material_attributes(child_material).type,
              :count => 0
            }
          end
          materials_type_and_count[child_material][:count] += 1
        end

        if materials_type_and_count.length > 0

          # Extract the most used material with priority on its type
          material, _ = materials_type_and_count.sort_by { |k, v| [ -v[:count], MaterialAttributes.type_order(v[:type]) ] }.first

        elsif level > 0

          # Entity is a group or component instance : return entity's material if it isn't virtual
          material = entity.material unless no_virtual && MaterialAttributes.is_virtual?(_get_material_attributes(entity.material))

        end

      elsif entity.is_a?(Sketchup::Face)

        # Entity is a face : return entity's material if it isn't virtual
        material = entity.material unless no_virtual && MaterialAttributes.is_virtual?(_get_material_attributes(entity.material))

      end
      material
    end

    def _get_inherited_material(path, no_virtual = true)
      unless path
        return nil
      end
      entity = path.last
      unless entity.is_a?(Sketchup::Drawingelement)
        return nil
      end
      material = entity.material unless no_virtual && MaterialAttributes.is_virtual?(_get_material_attributes(entity.material))
      unless material
        material = _get_inherited_material(path[0...-1], no_virtual)
      end
      material
    end

    # -- Edge Utils --

    def _populate_edge_group_def(material, thickness)
      return nil if material.nil?

      material_attributes = _get_material_attributes(material)

      std_width_info = _find_std_value(
          (thickness + material_attributes.l_width_increase).to_l,
          material_attributes.l_std_widths,
          true
      )
      std_info = {
          :available => std_width_info[:available],
          :dimension_stipped_name => 'width',
          :dimension => std_width_info[:value].to_s.gsub(/~ /, ''), # Remove ~ if it exists
          :dimension_real => DimensionUtils.to_ocl_precision_s(std_width_info[:value]),
          :dimension_rounded => DimensionUtils.rounded_by_model_precision?(std_width_info[:value]),
          :width => std_width_info[:value],
          :thickness => material_attributes.l_thickness,
      }

      group_id = GroupDef.generate_group_id(material, material_attributes, std_info)
      group_def = _get_group_def(group_id)
      unless group_def

        group_def = GroupDef.new(group_id)
        group_def.material = material
        group_def.material_attributes = material_attributes
        group_def.std_available = std_info[:available]
        group_def.std_dimension_stipped_name = std_info[:dimension_stipped_name]
        group_def.std_dimension = std_info[:dimension]
        group_def.std_dimension_real = std_info[:dimension_real]
        group_def.std_dimension_rounded = std_info[:dimension_rounded]
        group_def.std_width = std_info[:width]
        group_def.std_thickness = std_info[:thickness]
        group_def.show_cutting_dimensions = material_attributes.l_length_increase > 0

        _store_group_def(group_def)

      end

      group_def
    end

    def _populate_edge_part_def(part_def, edge, edge_group_def, length, cutting_length, width, thickness)

      edge_part_id = PartDef.generate_edge_part_id(edge_group_def.id, part_def.id, edge, length, width, thickness)
      edge_part_def = edge_group_def.get_part_def(edge_part_id)
      unless edge_part_def

        edge_part_def = PartDef.new(edge_part_id, true)
        edge_part_def.name = "#{part_def.name}#{part_def.number ? " ( #{part_def.number} ) " : ''} - #{PLUGIN.get_i18n_string("tab.cutlist.tooltip.edge_#{edge}")}"
        edge_part_def.cutting_size = Size3d.new(cutting_length, width, thickness)
        edge_part_def.size = Size3d.new(length, width, thickness)
        edge_part_def.material_name = edge_group_def.material_name
        part_def.edge_entity_ids[edge].each { |entity_id| edge_part_def.add_entity_id(entity_id) }

        edge_group_def.store_part_def(edge_part_def)

      end

      edge_part_def.count += 1
      edge_group_def.part_count += 1

      edge_part_def
    end

    # -- Veneer Utils --

    def _populate_veneer_group_def(material)
      return nil if material.nil?

      material_attributes = _get_material_attributes(material)

      std_thickness_info = _find_std_value(
          material_attributes.l_thickness,
          [ material_attributes.l_thickness ],
          false
      )
      std_info = {
          :available => std_thickness_info[:available],
          :dimension_stipped_name => 'thickness',
          :dimension => std_thickness_info[:value].to_s.gsub(/~ /, ''), # Remove ~ if it exists
          :dimension_real => DimensionUtils.to_ocl_precision_s(std_thickness_info[:value]),
          :dimension_rounded => DimensionUtils.rounded_by_model_precision?(std_thickness_info[:value]),
          :width => 0,
          :thickness => std_thickness_info[:value],
      }

      group_id = GroupDef.generate_group_id(material, material_attributes, std_info)
      group_def = _get_group_def(group_id)
      unless group_def

        group_def = GroupDef.new(group_id)
        group_def.material = material
        group_def.material_attributes = material_attributes
        group_def.std_available = std_info[:available]
        group_def.std_dimension_stipped_name = std_info[:dimension_stipped_name]
        group_def.std_dimension = std_info[:dimension]
        group_def.std_dimension_real = std_info[:dimension_real]
        group_def.std_dimension_rounded = std_info[:dimension_rounded]
        group_def.std_width = std_info[:width]
        group_def.std_thickness = std_info[:thickness]
        group_def.show_cutting_dimensions = material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0

        _store_group_def(group_def)

      end

      group_def
    end

    def _populate_veneer_part_def(part_def, veneer, veneer_group_def, length, width, cutting_length, cutting_width, thickness)

      veneer_part_id = PartDef.generate_veneer_part_id(veneer_group_def.id, part_def.id, veneer, length, width, thickness)
      veneer_part_def = veneer_group_def.get_part_def(veneer_part_id)
      unless veneer_part_def

        veneer_part_def = PartDef.new(veneer_part_id, true)
        veneer_part_def.name = "#{part_def.name}#{part_def.number ? " ( #{part_def.number} ) " : ''} - #{PLUGIN.get_i18n_string("tab.cutlist.tooltip.face_#{veneer}")}"
        veneer_part_def.cutting_size = Size3d.new(cutting_length, cutting_width, thickness)
        veneer_part_def.size = Size3d.new(length, width, thickness)
        veneer_part_def.material_name = veneer_group_def.material_name
        part_def.face_entity_ids[veneer].each { |entity_id| veneer_part_def.add_entity_id(entity_id) }

        veneer_group_def.store_part_def(veneer_part_def)

      end

      veneer_part_def.count += 1
      veneer_group_def.part_count += 1

      veneer_part_def
    end

    # -- Utils --

    def _comparable_number(number, pad = 4)
      return number.rjust(pad) if number.is_a?(String)  # Add space padding to given number if it is a string ('Z' to '   Z') to be able to compare with an other alphabetical number
      number
    end

  end

end
