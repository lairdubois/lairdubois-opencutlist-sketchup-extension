require 'pathname'
require 'digest'
require 'csv'
require_relative 'controller'
require_relative '../model/size'
require_relative '../model/cutlistdef'
require_relative '../model/groupdef'
require_relative '../model/partdef'
require_relative '../model/material_usage'
require_relative '../model/material_attributes'
require_relative '../model/definition_attributes'

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

        @plugin.register_command("cutlist_export") do |settings|
          export_command(settings)
        end

        @plugin.register_command("cutlist_numbers_save") do |settings|
          numbers_save
        end

        @plugin.register_command("cutlist_numbers_reset") do |settings|
          numbers_reset
        end

        @plugin.register_command("cutlist_part_get_thumbnail") do |part_data|
          part_get_thumbnail_command(part_data)
        end

        @plugin.register_command("cutlist_part_update") do |part_data|
          part_update_command(part_data)
        end

        @plugin.register_command("cutlist_group_update") do |group_data|
          group_update_command(group_data)
        end

      end

      private

      # -- Commands --

      def generate_command(settings)

        # Clear previously generated cutlist
        @cutlist = nil

        # Check settings
        auto_orient = settings['auto_orient']
        smart_material = settings['smart_material']
        part_number_with_letters = settings['part_number_with_letters']
        part_number_sequence_by_group = settings['part_number_sequence_by_group']
        part_order_strategy = settings['part_order_strategy']

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

        dir, filename = File.split(model.path)
        page_label = (model.pages and model.pages.selected_page) ? model.pages.selected_page.label : ''

        # Create cut list def
        cutlist_def = CutlistDef.new(dir, filename, page_label)

        # Errors & tips
        if component_paths.length == 0
          if model.entities.length == 0
            cutlist_def.add_error("tab.cutlist.error.no_entities")
            else
              if use_selection
              cutlist_def.add_error("tab.cutlist.error.no_component_in_selection")
            else
              cutlist_def.add_error("tab.cutlist.error.no_component_in_model")
            end
            cutlist_def.add_tip("tab.cutlist.tip.no_component")
          end
        end

        # Materials usages
        materials = model.materials
        materials.each { |material|
          material_attributes = MaterialAttributes.new(material)
          material_usage = MaterialUsage.new(material.name, material.display_name, material_attributes.type)
          cutlist_def.set_material_usage(material.name, material_usage)
        }

        # Populate cutlist
        component_paths.each { |component_path|

          entity = component_path.last

          material, material_origin = _get_material(component_path, smart_material)
          definition = entity.definition

          definition_attributes = DefinitionAttributes.new(definition)

          material_name = material ? material.name : ''
          material_attributes = MaterialAttributes.new(material)

          if material
            material_usage = cutlist_def.get_material_usage(material.name)
            if material_usage
              material_usage.use_count += 1
            end
          end

          size = _size_from_bounds(_compute_faces_bounds(definition), auto_orient && !definition_attributes.orientation_locked_on_axis)
          std_thickness = _find_std_thickness(
              (size.thickness + material_attributes.l_thickness_increase).to_l,
              material_attributes.l_std_thicknesses,
              material_attributes.type == MaterialAttributes::TYPE_SOLID_WOOD
          )
          raw_size = Size.new(
              (size.length + material_attributes.l_length_increase).to_l,
              (size.width + material_attributes.l_width_increase).to_l,
              std_thickness[:value]
          )

         group_id = Digest::SHA1.hexdigest("#{material_name}#{material_attributes.type > MaterialAttributes::TYPE_UNKNOW ? ':' + raw_size.thickness.to_s : ''}")
          group_def = cutlist_def.get_group_def(group_id)
          unless group_def

            group_def = GroupDef.new(group_id)
            group_def.material_name = material_name
            group_def.material_type = material_attributes.type
            group_def.raw_thickness = raw_size.thickness
            group_def.raw_thickness_available = std_thickness[:available]

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

          part_def = group_def.get_part_def(definition.name)
          unless part_def

            part_def = PartDef.new
            part_def.definition_id = definition.name
            part_def.number = number
            part_def.saved_number = definition_attributes.number
            part_def.name = definition.name
            part_def.raw_size = raw_size
            part_def.size = size
            part_def.material_name = material_name
            part_def.cumulable = definition_attributes.cumulable
            part_def.orientation_locked_on_axis = definition_attributes.orientation_locked_on_axis

            group_def.set_part_def(definition.name, part_def)

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
          unless part_def.material_origins.include? material_origin
            part_def.material_origins.push(material_origin)
          end
          part_def.count += 1
          part_def.add_entity_id(entity.entityID)

          group_def.part_count += 1

        }

        # Warnings & tips
        if component_paths.length > 0
          if use_selection
            cutlist_def.add_warning("tab.cutlist.warning.partial_cutlist")
          end
          hardwood_material_count = 0
          plywood_material_count = 0
          cutlist_def.material_usages.each { |key, material_usage|
            if material_usage.type == MaterialAttributes::TYPE_SOLID_WOOD
              hardwood_material_count += material_usage.use_count
            elsif material_usage.type == MaterialAttributes::TYPE_SHEET_GOOD
              plywood_material_count += material_usage.use_count
            end
          }
          if hardwood_material_count == 0 and plywood_material_count == 0
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
            :dir => cutlist_def.dir,
            :filename => cutlist_def.filename,
            :page_label => cutlist_def.page_label,
            :material_usages => [],
            :groups => []
        }

        # Sort and browse material usages
        cutlist_def.material_usages.sort_by { |k, v| [v.display_name.downcase] }.each { |key, material_usage|
          response[:material_usages].push({
                                          :name => material_usage.name,
                                          :display_name => material_usage.display_name,
                                          :type => material_usage.type,
                                          :use_count => material_usage.use_count
                                      })
        }

        part_number = cutlist_def.max_number ? cutlist_def.max_number.succ : (part_number_with_letters ? 'A' : '1')

        # Sort and browse groups
        cutlist_def.group_defs.sort_by { |k, v| [MaterialAttributes.type_order(v.material_type), v.material_name.downcase, -v.raw_thickness] }.each { |key, group_def|

          if part_number_sequence_by_group
            part_number = group_def.max_number ? group_def.max_number.succ : (part_number_with_letters ? 'A' : '1')    # Reset code increment on each group
          end

          group = {
              :id => group_def.id,
              :material_name => group_def.material_name,
              :material_type => group_def.material_type,
              :part_count => group_def.part_count,
              :raw_thickness => group_def.raw_thickness.to_s,
              :raw_thickness_available => group_def.raw_thickness_available,
              :raw_area_m2 => 0,
              :raw_volume_m3 => 0,
              :parts => []
          }
          response[:groups].push(group)

          # Sort and browse parts
          group_def.part_defs.values.sort { |part_def_a, part_def_b| PartDef::part_order(part_def_a, part_def_b, part_order_strategy) }.each { |part_def|
            if group_def.material_type != MaterialAttributes::TYPE_UNKNOW
              group[:raw_area_m2] += part_def.raw_size.area_m2 * part_def.count
              if group_def.material_type == MaterialAttributes::TYPE_SOLID_WOOD
                group[:raw_volume_m3] += part_def.raw_size.volume_m3 * part_def.count
              end
            end
            group[:parts].push({
                                   :id => part_def.id,
                                   :definition_id => part_def.definition_id,
                                   :name => part_def.name,
                                   :length => part_def.size.length.to_s,
                                   :width => part_def.size.width.to_s,
                                   :thickness => part_def.size.thickness.to_s,
                                   :count => part_def.count,
                                   :raw_length => part_def.raw_size.length.to_s,
                                   :raw_width => part_def.raw_size.width.to_s,
                                   :cumulative_raw_length => part_def.cumulative_raw_length.to_s,
                                   :cumulative_raw_width => part_def.cumulative_raw_width.to_s,
                                   :number => part_def.number ? part_def.number : part_number,
                                   :saved_number => part_def.saved_number,
                                   :material_name => part_def.material_name,
                                   :material_origins => part_def.material_origins,
                                   :cumulable => part_def.cumulable,
                                   :orientation_locked_on_axis => part_def.orientation_locked_on_axis,
                                   :entity_ids => part_def.entity_ids
                               }
            )
            unless part_def.number
              part_number = part_number.succ
            end
          }

        }

        # Keep generated cutlist
        @cutlist = response

        response
      end

      def export_command(settings)

        # Check settings
        hide_raw_dimensions = settings['hide_raw_dimensions']
        hide_final_dimensions = settings['hide_final_dimensions']
        hide_untyped_material_dimensions = settings['hide_untyped_material_dimensions']
        hidden_group_ids = settings['hidden_group_ids']

        response = {
            :warnings => [],
            :errors => [],
            :export_path => ''
        }

        if @cutlist and @cutlist[:groups]

          # Ask for export file path
          export_path = UI.savepanel(@plugin.get_i18n_string('tab.cutlist.export.title'), @cutlist[:dir], File.basename(@cutlist[:filename], '.skp') + '.csv')
          if export_path

            begin

              File.open(export_path, "w+:UTF-16LE:UTF-8") do |f|
                csv_file = CSV.generate({ :col_sep => "\t" }) do |csv|

                  # Header row
                  header = []
                  header.push(@plugin.get_i18n_string('tab.cutlist.export.name'))
                  unless hide_raw_dimensions
                    header.push(@plugin.get_i18n_string('tab.cutlist.export.raw_length'))
                    header.push(@plugin.get_i18n_string('tab.cutlist.export.raw_width'))
                    header.push(@plugin.get_i18n_string('tab.cutlist.export.raw_thickness'))
                  end
                  unless hide_final_dimensions
                    header.push(@plugin.get_i18n_string('tab.cutlist.export.length'))
                    header.push(@plugin.get_i18n_string('tab.cutlist.export.width'))
                    header.push(@plugin.get_i18n_string('tab.cutlist.export.thickness'))
                  end
                  header.push(@plugin.get_i18n_string('tab.cutlist.export.count'))
                  header.push(@plugin.get_i18n_string('tab.cutlist.export.material_name'))

                  csv << header

                  # Content rows
                  @cutlist[:groups].each { |group|
                    next if hidden_group_ids.include? group[:id]
                    group[:parts].each { |part|

                      no_raw_dimensions = group[:material_type] == MaterialAttributes::TYPE_UNKNOW
                      no_dimensions = group[:material_type] == MaterialAttributes::TYPE_UNKNOW && hide_untyped_material_dimensions

                      row = []
                      row.push(part[:name])
                      unless hide_raw_dimensions
                        row.push(no_raw_dimensions ? '' : part[:raw_length])
                        row.push(no_raw_dimensions ? '' : part[:raw_width])
                        row.push(no_raw_dimensions ? '' : group[:raw_thickness])
                      end
                      unless hide_final_dimensions
                        row.push(no_dimensions ? '' : part[:length])
                        row.push(no_dimensions ? '' : part[:width])
                        row.push(no_dimensions ? '' : part[:thickness])
                      end
                      row.push(part[:count])
                      row.push(part[:material_name])

                      csv << row
                    }
                  }

                end

                # Write file
                f.write "\xEF\xBB\xBF" # Byte Order Mark
                f.write(csv_file)

                # Populate response
                response[:export_path] = export_path.tr("\\", '/')  # Standardize path by replacing \ by /

              end

            rescue
              response[:errors].push('tab.cutlist.error.failed_to_write_export_file')
            end

          end

        end

        response
      end

      def numbers_save
        if @cutlist

          model = Sketchup.active_model
          definitions = model.definitions

          @cutlist[:groups].each { |group|
            group[:parts].each { |part|

              definition = definitions[part[:definition_id]]
              if definition

                definition_attributes = DefinitionAttributes.new(definition)
                definition_attributes.number = part[:number]
                definition_attributes.write_to_attributes

              end

            }
          }
        end
      end

      def numbers_reset
        if @cutlist

          model = Sketchup.active_model
          definitions = model.definitions

          @cutlist[:groups].each { |group|
            group[:parts].each { |part|

              definition = definitions[part[:definition_id]]
              if definition

                definition_attributes = DefinitionAttributes.new(definition)
                definition_attributes.number = nil
                definition_attributes.write_to_attributes

              end

            }
          }
        end
      end

      def part_get_thumbnail_command(part_data)

        response = {
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

          response[:thumbnail_file] = thumbnail_file
        end

        response
      end

      def part_update_command(part_data)

        # Extract parameters
        definition_id = part_data['definition_id']
        name = part_data['name']
        material_name = part_data['material_name']
        cumulable = DefinitionAttributes.valid_cumulable(part_data['cumulable'])
        orientation_locked_on_axis = part_data['orientation_locked_on_axis']
        entity_ids = part_data['entity_ids']

        model = Sketchup.active_model

        # Update definition's name
        definitions = model.definitions
        definition = definitions[definition_id]
        if definition and definition.name != name
          definition.name = name
        end

        definition_attributes = DefinitionAttributes.new(definition)
        if cumulable != definition_attributes.cumulable or orientation_locked_on_axis != definition_attributes.orientation_locked_on_axis
          definition_attributes.cumulable = cumulable
          definition_attributes.orientation_locked_on_axis = orientation_locked_on_axis
          definition_attributes.write_to_attributes
        end

        # Update component instance material
        materials = model.materials
        if material_name == nil or material_name.empty? or (material = materials[material_name])

          entity_ids.each { |entity_id|
            entity = model.find_entity_by_id(entity_id)
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

      def group_update_command(group_data)

        # Extract parameters
        id = group_data['id']
        material_name = group_data['material_name']
        parts = group_data['parts']

        model = Sketchup.active_model

        # Update component instance material
        materials = model.materials
        if material_name == nil or material_name.empty? or (material = materials[material_name])

          parts.each { |part_data|
            entity_ids = part_data['entity_ids']
            entity_ids.each { |component_id|
              entity = model.find_entity_by_id(component_id)
              if entity
                if material_name == nil or material_name.empty?
                  entity.material = nil
                elsif entity.material != material
                  entity.material = material
                end
              end
            }
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
              child_face_count += _fetch_useful_component_paths(child_entity, component_paths, path + [ entity ])
            }

          elsif entity.is_a? Sketchup::ComponentInstance

            # Entity is a component : check its children
            entity.definition.entities.each { |child_entity|
              child_face_count += _fetch_useful_component_paths(child_entity, component_paths, path + [ entity ])
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

      def _get_material(path, smart = true)
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
        unless material or !smart
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