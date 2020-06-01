module Ladb::OpenCutList

  require_relative '../../helper/boundingbox_helper'
  require_relative '../../model/attributes/material_attributes'
  require_relative '../../model/attributes/definition_attributes'
  require_relative '../../model/geom/size3d'
  require_relative '../../model/cutlist/cutlist'
  require_relative '../../model/cutlist/face_info'
  require_relative '../../model/cutlist/instance_info'
  require_relative '../../model/cutlist/material_usage'
  require_relative '../../model/cutlist/groupdef'
  require_relative '../../model/cutlist/group'
  require_relative '../../model/cutlist/partdef'
  require_relative '../../model/cutlist/part'
  require_relative '../../utils/transformation_utils'
  require_relative '../../tool/highlight_part_tool'

  class CutlistGenerateWorker

    include BoundingBoxHelper

    MATERIAL_ORIGIN_UNKNOW = 0
    MATERIAL_ORIGIN_OWNED = 1
    MATERIAL_ORIGIN_INHERITED = 2
    MATERIAL_ORIGIN_CHILD = 3

    def initialize(settings)

      @auto_orient = settings['auto_orient']
      @smart_material = settings['smart_material']
      @dynamic_attributes_name = settings['dynamic_attributes_name']
      @part_number_with_letters = settings['part_number_with_letters']
      @part_number_sequence_by_group = settings['part_number_sequence_by_group']
      @part_folding = settings['part_folding']
      @part_order_strategy = settings['part_order_strategy']
      @hide_labels = settings['hide_labels']
      @hide_final_areas = settings['hide_final_areas']
      @labels_filter = settings['labels_filter']
      @edge_material_names_filter = settings['edge_material_names_filter']

      # Setup caches
      @instance_infos_cache = {}
      @group_defs_cache = {}
      @material_usages_cache = {}
      @material_attributes_cache = {}
      @definition_attributes_cache = {}

      # Reset materials UUIDS
      MaterialAttributes::reset_used_uuids

    end

    # -----

    def run

      model = Sketchup.active_model

      # Retrieve selected entities or all if no selection
      if model
        if model.selection.empty?
          entities = model.active_entities
          selection_only = false
        else
          entities = model.selection
          selection_only = true
        end
      else
        entities = []
        selection_only = false
      end

      # Fetch component instances in given entities
      path = model && model.active_path ? model.active_path : []
      entities.each { |entity|
        _fetch_useful_instance_infos(entity, path, @auto_orient)
      }

      # Retrieve model infos
      length_unit = model ? model.options["UnitsOptions"]["LengthUnit"] : nil
      dir, filename = File.split(model && !model.path.empty? ? model.path : Plugin.instance.get_i18n_string('default.empty_filename'))
      page_label = model && model.pages && model.pages.selected_page ? model.pages.selected_page.label : ''

      # Create cut list
      cutlist = Cutlist.new(selection_only, length_unit, dir, filename, page_label, @instance_infos_cache.length)

      # Errors & tips
      if @instance_infos_cache.length == 0
        if model
          if entities.length == 0
            cutlist.add_error('tab.cutlist.error.no_entities')
          else
            if selection_only
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
        material_usage = MaterialUsage.new(material.name, material.display_name, material_attributes.type, material.color)
        _store_material_usage(material_usage)
      }

      # PHASE 1 - Populate cutlist

      @instance_infos_cache.each do |key, instance_info|

        entity = instance_info.entity

        definition = entity.definition
        definition_attributes = _get_definition_attributes(definition)

        # Populate used labels
        cutlist.add_used_labels(definition_attributes.labels)

        # Labels filter
        if !@labels_filter.empty? and !definition_attributes.has_labels(@labels_filter)
          cutlist.ignored_instance_count += 1
          next
        end

        material, material_origin = _get_material(instance_info.path, @smart_material)
        material_id = material ? material.entityID : ''
        material_name = material ? material.name : ''
        material_display_name = material ? material.display_name : ''
        material_attributes = _get_material_attributes(material)

        if material

          material_usage = _get_material_usage(material.name)
          if material_usage
            material_usage.use_count += 1
          end

          # Edge materials filter -> exclude all non sheet good parts
          if !@edge_material_names_filter.empty? and material_attributes.type != MaterialAttributes::TYPE_SHEET_GOOD
            cutlist.ignored_instance_count += 1
            next
          end

        end

        # Compute transformation, scale and sizes

        size = instance_info.size.clone
        length_increased = false
        width_increased = false
        thickness_increased = false
        case material_attributes.type
          when MaterialAttributes::TYPE_SOLID_WOOD, MaterialAttributes::TYPE_SHEET_GOOD
            size.increment_length(definition_attributes.l_length_increase)
            size.increment_width(definition_attributes.l_width_increase)
            length_increased = definition_attributes.l_length_increase > 0
            width_increased = definition_attributes.l_width_increase > 0
            if material_attributes.type == MaterialAttributes::TYPE_SOLID_WOOD
              size.increment_thickness(definition_attributes.l_thickness_increase)
              thickness_increased = definition_attributes.l_thickness_increase > 0
            end
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
            size.increment_length(definition_attributes.l_length_increase)
            length_increased = definition_attributes.l_length_increase > 0
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
        group_def = _get_group_def(group_id)
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

          _store_group_def(group_def)

        end

        # Define part

        part_id = PartDef.generate_part_id(group_id, definition, instance_info, @dynamic_attributes_name)
        part_def = group_def.get_part_def(part_id)
        unless part_def

          number = nil
          saved_number = definition_attributes.fetch_number(part_id)
          if saved_number
            if @part_number_with_letters
              if saved_number.is_a? String
                number = saved_number
              end
            else
              if definition_attributes.number.is_a? Numeric
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
          part_def.scale = instance_info.scale
          part_def.flipped = instance_info.flipped
          part_def.cutting_size = cutting_size
          part_def.size = size
          part_def.material_name = material_name
          part_def.cumulable = definition_attributes.cumulable
          part_def.length_increase = definition_attributes.length_increase
          part_def.width_increase = definition_attributes.width_increase
          part_def.thickness_increase = definition_attributes.thickness_increase
          part_def.orientation_locked_on_axis = definition_attributes.orientation_locked_on_axis
          part_def.labels = definition_attributes.labels
          part_def.length_increased = length_increased
          part_def.width_increased = width_increased
          part_def.thickness_increased = thickness_increased
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
              xmin_face_infos, xmax_face_infos = _grab_oriented_min_max_face_infos(instance_info, x_face_infos, y_face_infos, z_face_infos, X_AXIS, instance_info.flipped)
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
              if !@edge_material_names_filter.empty? && !(@edge_material_names_filter - edge_materials.map { |m| m.display_name }).empty?
                cutlist.ignored_instance_count += 1
                next
              end

              # Increment material usage
              edge_materials.each { |edge_material|
                material_usage = _get_material_usage(edge_material.name)
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
              edge_ymin_group_def = _populate_edge_group_def(edge_ymin_material, part_def)
              edge_ymax_group_def = _populate_edge_group_def(edge_ymax_material, part_def)
              edge_xmin_group_def = _populate_edge_group_def(edge_xmin_material, part_def)
              edge_xmax_group_def = _populate_edge_group_def(edge_xmax_material, part_def)

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
          group_def.store_part_def(part_def)

          if number

            # Update max_number in group_def
            if group_def.max_number
              if number > group_def.max_number
                group_def.max_number = number
              end
            else
              group_def.max_number = number
            end

            # Update max_number in cutlist
            if group_def.max_number
              if cutlist.max_number
                if group_def.max_number > cutlist.max_number
                  cutlist.max_number = group_def.max_number
                end
              else
                cutlist.max_number = group_def.max_number
              end
            end

          end

        end
        part_def.count += 1
        part_def.add_material_origin(material_origin)
        part_def.add_entity_id(entity.entityID)
        part_def.add_entity_serialized_path(instance_info.serialized_path)
        part_def.add_entity_name(entity.name)
        part_def.store_instance_info(instance_info)

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

      end

      # Warnings & tips
      if @instance_infos_cache.length > 0
        solid_wood_material_count = 0
        sheet_good_material_count = 0
        bar_material_count = 0
        edge_material_count = 0
        @material_usages_cache.each { |key, material_usage|
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
        if cutlist.instance_count - cutlist.ignored_instance_count > 0 and solid_wood_material_count == 0 and sheet_good_material_count == 0 and bar_material_count == 0
          cutlist.add_warning("tab.cutlist.warning.no_typed_materials_in_#{selection_only ? "selection" : "model"}")
          cutlist.add_tip("tab.cutlist.tip.no_typed_materials")
        end
      end

      # PHASE 2

      # Sort material usages and add them to cutlist
      cutlist.add_material_usages(@material_usages_cache.values.sort_by { |v| [ v.display_name.downcase ] })

      part_number = cutlist.max_number ? cutlist.max_number.succ : (@part_number_with_letters ? 'A' : '1')

      # Sort and browse groups

      @group_defs_cache.sort_by { |k, v| [ MaterialAttributes.type_order(v.material_type), v.material_name.empty? ? '~' : v.material_name.downcase, -v.std_width, -v.std_thickness ] }.each do |key, group_def|

        # Exclude empty groupDef
        next if group_def.part_count == 0

        if @part_number_sequence_by_group
          part_number = group_def.max_number ? group_def.max_number.succ : (@part_number_with_letters ? 'A' : '1')    # Reset number increment on each group
        end

        group = Group.new(group_def, cutlist)
        cutlist.add_group(group)

        # Folding
        if @part_folding
          part_defs = []
          group_def.part_defs.values.sort_by { |v| [ v.size.thickness, v.size.length, v.size.width, v.labels, v.final_area ] }.each do |part_def|
            if !(folder_part_def = part_defs.last).nil? &&
                folder_part_def.size == part_def.size &&
                folder_part_def.cutting_size == part_def.cutting_size &&
                (folder_part_def.labels == part_def.labels || @hide_labels) &&
                ((folder_part_def.final_area - part_def.final_area).abs < 0.001 or @hide_final_areas) &&      # final_area workaround for rounding error
                folder_part_def.edge_material_names == part_def.edge_material_names &&
                ((folder_part_def.definition_id == part_def.definition_id && group_def.material_type == MaterialAttributes::TYPE_UNKNOW) || group_def.material_type > MaterialAttributes::TYPE_UNKNOW) # Part with untyped materiel are folded only if they have the same definition
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
                folder_part_def.children_length_increased_count += first_child_part_def.count if first_child_part_def.length_increased
                folder_part_def.children_width_increased_count += first_child_part_def.count if first_child_part_def.width_increased
                folder_part_def.children_thickness_increased_count += first_child_part_def.count if first_child_part_def.thickness_increased

                part_defs.push(folder_part_def)

              end
              folder_part_def.children.push(part_def)
              folder_part_def.count += part_def.count
              folder_part_def.children_warning_count += 1 if part_def.not_aligned_on_axes
              folder_part_def.children_warning_count += 1 if part_def.multiple_layers
              folder_part_def.children_length_increased_count += part_def.count if part_def.length_increased
              folder_part_def.children_width_increased_count += part_def.count if part_def.width_increased
              folder_part_def.children_thickness_increased_count += part_def.count if part_def.thickness_increased
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
      if @instance_infos_cache.has_key? serialized_path
        return @instance_infos_cache[serialized_path]
      end
      nil
    end

    # GroupDefs

    def _store_group_def(group_def)
      @group_defs_cache[group_def.id] = group_def
    end

    def _get_group_def(id)
      if @group_defs_cache.has_key? id
        return @group_defs_cache[id]
      end
      nil
    end

    def _group_defs_include_number?(number)
      @group_defs.each { |key, group_def|
        if group_def.include_number? number
          return true
        end
      }
      false
    end

    # MaterialUsage

    def _store_material_usage(material_usage)
      @material_usages_cache[material_usage.name] = material_usage
    end

    def _get_material_usage(name)
      if @material_usages_cache.has_key? name
        return @material_usages_cache[name]
      end
      nil
    end

    # MaterialAttributes

    def _get_material_attributes(material)
      key = material ? material.name : '$EMPTY$'
      unless @material_attributes_cache.has_key? key
        @material_attributes_cache[key] = MaterialAttributes.new(material, true)
      end
      @material_attributes_cache[key]
    end

    # DefinitionAttributes

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
              _store_instance_info(instance_info)

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
      [ x_face_infos, y_face_infos, z_face_infos, layers ]
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

      plane_count, final_area = _compute_largest_final_area(instance_info.size.oriented_normal(axis), x_face_infos, y_face_infos, z_face_infos, instance_info.transformation)
      area = instance_info.size.area_by_axis(axis)
      area_ratio = (final_area.nil? or area.nil?) ? 0 : final_area / area

      [ plane_count, final_area, area_ratio ]
    end

    def _grab_oriented_min_max_face_infos(instance_info, x_face_infos, y_face_infos, z_face_infos, axis, flipped = false)

      min_face_infos = []
      max_face_infos = []
      oriented_normal = instance_info.size.oriented_normal(axis)
      plane_grouped_face_infos = _populate_plane_grouped_face_infos_by_normal(oriented_normal, x_face_infos, y_face_infos, z_face_infos)
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
      [ material, material_origin ]
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

    def _populate_edge_group_def(material, part_def)
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
      group_def = _get_group_def(group_id)
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

        _store_group_def(group_def)

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

        edge_group_def.store_part_def(edge_part_def)

      end

      edge_part_def.count += 1
      edge_group_def.part_count += 1

      edge_part_def
    end

  end

end