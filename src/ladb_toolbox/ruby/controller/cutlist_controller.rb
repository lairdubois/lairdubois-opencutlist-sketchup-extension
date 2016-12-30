require 'pathname'
require_relative 'controller'
require_relative '../model/size'
require_relative '../model/cutlist'
require_relative '../model/groupdef'
require_relative '../model/partdef'
require_relative '../model/material_usage'

module Ladb
  module Toolbox
    class CutlistController < Controller

      MATERIAL_ORIGIN_UNKNOW = 0
      MATERIAL_ORIGIN_OWNED = 1
      MATERIAL_ORIGIN_INHERITED = 2
      MATERIAL_ORIGIN_CHILD = 3

      def initialize(plugin)
        super(plugin, 'cutlist')
      end

      def setup_commands()

        # Setup toolbox dialog actions
        @plugin.register_command("cutlist_generate") do |settings|
          generate_command(settings)
        end

        @plugin.register_command("cutlist_part_get_thumbnail") do |part_data|
          part_get_thumbnail_command(part_data)
        end

        @plugin.register_command("cutlist_part_update") do |part_data|
          part_update_command(part_data)
        end

      end

      private

      # -- Commands --

      def generate_command(settings)

        # Check settings
        part_number_with_letters = settings['part_number_with_letters']
        part_number_sequence_by_group = settings['part_number_sequence_by_group']
        auto_orient = settings['auto_orient']

        # Retrieve selected entities or all if no selection
        model = Sketchup.active_model
        if model.selection.empty?
          entities = model.active_entities
          use_selection = false
        else
          entities = model.selection
          use_selection = true
        end

        # Fetch components in given entities
        component_paths = []
        path = model.active_path ? model.active_path : []
        entities.each { |entity|
          _fetch_useful_component_paths(entity, component_paths, path)
        }

        filename = Pathname.new(model.path).basename
        page_label = (model.pages and model.pages.selected_page) ? model.pages.selected_page.label : ''

        # Create cut list
        cutlist = Cutlist.new(filename, page_label)

        # Errors
        if component_paths.length == 0
          if use_selection
            cutlist.add_error("tab.cutlist.error.no_component_in_selection")
          else
            cutlist.add_error("tab.cutlist.error.no_component_in_model")
          end
        end

        # Materials usages
        materials = model.materials
        materials.each { |material|
          material_attributes = MaterialAttributes.new(material)
          material_usage = MaterialUsage.new(material.name, material.display_name, material_attributes.type)
          cutlist.set_material_usage(material.name, material_usage)
        }

        # Populate cutlist
        component_paths.each { |component_path|

          component = component_path.last

          material, material_origin = _get_smart_material(component_path)
          definition = component.definition

          material_name = material ? material.name : ''
          material_attributes = MaterialAttributes.new(material)

          if material
            material_usage = cutlist.get_material_usage(material.name)
            if material_usage
              material_usage.use_count += 1
            end
          end

          size = _size_from_bounds(_compute_faces_bounds(definition), auto_orient)
          std_thickness = _find_std_thickness(
              (size.thickness + material_attributes.l_thickness_increase).to_l,
              material_attributes.l_std_thicknesses,
              material_attributes.type == MaterialAttributes::TYPE_HARDWOOD
          )
          raw_size = Size.new(
              (size.length + material_attributes.l_length_increase).to_l,
              (size.width + material_attributes.l_width_increase).to_l,
              std_thickness[:value]
          )

          key = material_name + (material_attributes.type > MaterialAttributes::TYPE_UNKNOW ? ':' + raw_size.thickness.to_s : '')
          group_def = cutlist.get_group_def(key)
          unless group_def

            group_def = GroupDef.new
            group_def.material_name = material_name
            group_def.material_type = material_attributes.type
            group_def.raw_thickness = raw_size.thickness
            group_def.raw_thickness_available = std_thickness[:available]

            cutlist.set_group_def(key, group_def)

          end

          part_def = group_def.get_part_def(definition.name)
          unless part_def

            part_def = PartDef.new(definition.name)
            part_def.name = definition.name
            part_def.raw_size = raw_size
            part_def.size = size
            part_def.material_name = material_name

            group_def.set_part_def(definition.name, part_def)

          end
          unless part_def.material_origins.include? material_origin
            part_def.material_origins.push(material_origin)
          end
          part_def.count += 1
          part_def.add_component_id(component.entityID)

          group_def.part_count += 1

        }

        # Warnings
        if component_paths.length > 0
          if use_selection
            cutlist.add_warning("tab.cutlist.warning.partial_cutlist")
          end
          hardwood_material_count = 0
          plywood_material_count = 0
          cutlist.material_usages.each { |key, material_usage|
            if material_usage.type == MaterialAttributes::TYPE_HARDWOOD
              hardwood_material_count += material_usage.use_count
            elsif material_usage.type == MaterialAttributes::TYPE_PLYWOOD
              plywood_material_count += material_usage.use_count
            end
          }
          if hardwood_material_count == 0 and plywood_material_count == 0
            cutlist.add_warning("tab.cutlist.warning.no_typed_materials_in_#{use_selection ? "selection" : "model"}")
          end
        end

        # Data
        # ----

        data = {
            :errors => cutlist.errors,
            :warnings => cutlist.warnings,
            :filename => cutlist.filename,
            :page_label => cutlist.page_label,
            :material_usages => [],
            :groups => []
        }

        # Sort and browse material usages
        cutlist.material_usages.sort_by { |k, v| [v.display_name.downcase] }.each { |key, material_usage|
          data[:material_usages].push({
                                          :name => material_usage.name,
                                          :display_name => material_usage.display_name,
                                          :type => material_usage.type,
                                          :use_count => material_usage.use_count
                                      })
        }

        # Sort and browse groups
        part_number = part_number_with_letters ? 'A' : '1'
        cutlist.group_defs.sort_by { |k, v| [MaterialAttributes.type_order(v.material_type), v.material_name, -v.raw_thickness] }.each { |key, group_def|

          if part_number_sequence_by_group
            part_number = part_number_with_letters ? 'A' : '1'    # Reset code increment on each group
          end

          group = {
              :id => group_def.id,
              :material_name => group_def.material_name,
              :material_type => group_def.material_type,
              :part_count => group_def.part_count,
              :raw_thickness => group_def.raw_thickness,
              :raw_thickness_available => group_def.raw_thickness_available,
              :raw_area_m2 => 0,
              :raw_volume_m3 => 0,
              :parts => []
          }
          data[:groups].push(group)

          # Sort and browse parts
          group_def.part_defs.sort_by { |k, v| [v.name, v.size.thickness, v.size.length, v.size.width] }.reverse.each { |key, part_def|
            if group_def.material_type != MaterialAttributes::TYPE_UNKNOW
              group[:raw_area_m2] += part_def.raw_size.area_m2 * part_def.count
              if group_def.material_type == MaterialAttributes::TYPE_HARDWOOD
                group[:raw_volume_m3] += part_def.raw_size.volume_m3 * part_def.count
              end
            end
            group[:parts].push({
                                   :id => part_def.id,
                                   :definition_id => part_def.definition_id,
                                   :name => part_def.name,
                                   :length => part_def.size.length,
                                   :width => part_def.size.width,
                                   :thickness => part_def.size.thickness,
                                   :count => part_def.count,
                                   :raw_length => part_def.raw_size.length,
                                   :raw_width => part_def.raw_size.width,
                                   :number => part_number,
                                   :material_name => part_def.material_name,
                                   :material_origins => part_def.material_origins,
                                   :component_ids => part_def.component_ids
                               }
            )
            part_number = part_number.succ
          }

        }

        data
      end

      def part_get_thumbnail_command(part_data)

        data = {
            :thumbnail_file => ''
        }

        # Extract parameters
        definition_id = part_data['definition_id']

        model = Sketchup.active_model
        definitions = model.definitions
        definition = definitions[definition_id]
        if definition

          definition.refresh_thumbnail

          temp_dir = @plugin.temp_dir
          component_thumbnails_dir = File.join(temp_dir, 'components_thumbnails')
          unless Dir.exist?(component_thumbnails_dir)
            Dir.mkdir(component_thumbnails_dir)
          end

          thumbnail_file = File.join(component_thumbnails_dir, "#{definition.guid}.png")
          definition.save_thumbnail(thumbnail_file)

          data[:thumbnail_file] = thumbnail_file
        end

        data
      end

      def part_update_command(part_data)

        # Extract parameters
        definition_id = part_data['definition_id']
        name = part_data['name']
        material_name = part_data['material_name']
        component_ids = part_data['component_ids']

        model = Sketchup.active_model

        # Update definition's name
        definitions = model.definitions
        definition = definitions[definition_id]
        if definition and definition.name != name
          definition.name = name
        end

        # Update component instance material
        materials = model.materials
        if material_name == nil or material_name.empty? or (material = materials[material_name])

          component_ids.each { |component_id|
            entity = model.find_entity_by_id(component_id)
            if entity
              if material_name == nil or material_name.empty?
                entity.material = nil
              elsif entity.material != material
                entity.material = material
              end
            end
          }

        end

      end

      # -- Components utils --

      def _fetch_useful_component_paths(entity, component_paths, path)
        child_face_count = 0
        if entity.visible? and entity.layer.visible?
          if entity.is_a? Sketchup::Group

            # Entity is a group : check its children
            entity.entities.each { |child_entity|
              child_face_count += _fetch_useful_component_paths(child_entity, component_paths, path + [entity ])
            }

          elsif entity.is_a? Sketchup::ComponentInstance

            # Entity is a component : check its children
            entity.definition.entities.each { |child_entity|
              child_face_count += _fetch_useful_component_paths(child_entity, component_paths, path + [entity ])
            }

            # Considere component if it contains faces
            if child_face_count > 0
              bounds = _compute_faces_bounds(entity.definition)
              if bounds.width > 0 and bounds.height > 0 and bounds.depth > 0
                component_paths.push(path + [ entity ])
                child_face_count = 0 # Do not propagate face count to parent
              end
            end

          elsif entity.is_a? Sketchup::Face

            # Entity is a face : return 1
            child_face_count = 1

          end
        end
        child_face_count
      end

      # -- Bounds utils --

      def _compute_faces_bounds(definition)
        bounds = Geom::BoundingBox.new
        definition.entities.each { |entity|
          if entity.is_a? Sketchup::Face
            bounds.add(entity.bounds)
          elsif entity.is_a? Sketchup::Group
            bounds.add(_compute_faces_bounds(entity))
          end
        }
        bounds
      end

      def _size_from_bounds(bounds, auto_orient = true)
        if auto_orient
          ordered = [bounds.width, bounds.height, bounds.depth].sort
          Size.new(ordered[2], ordered[1], ordered[0])
        else
          Size.new(bounds.width, bounds.height, bounds.depth)
        end
      end

      # -- Thickness utils --

      def _find_std_thickness(thickness, std_thicknesses, nearest_highest)
        std_thicknesses.each { |std_thickness|
          if thickness <= std_thickness
            if nearest_highest
              return {
                  :available => true,
                  :value => std_thickness
              }
            else
              return {
                  :available => thickness == std_thickness,
                  :value => thickness
              }
            end
          end
        }
        {
            :available => false,
            :value => thickness
        }
      end

      # -- Material Utils --

      def _get_smart_material(path)
        unless path
          return nil, MATERIAL_ORIGIN_UNKNOW
        end
        entity = path.last
        unless entity
          return nil, MATERIAL_ORIGIN_UNKNOW
        end
        unless entity.is_a? Sketchup::Drawingelement
          return nil, MATERIAL_ORIGIN_UNKNOW
        end
        material = entity.material
        material_origin = MATERIAL_ORIGIN_OWNED
        unless material
          material = _get_dominant_child_material(entity)
          if material
            material_origin = MATERIAL_ORIGIN_CHILD
          else
            material = _get_inherited_material(path)
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
        unless entity
          return nil
        end
        unless entity.is_a? Sketchup::Drawingelement
          return nil
        end
        material = entity.material
        unless material
          material = _get_inherited_material(path.take(path.size() - 1))
        end
        material
      end

    end
  end
end