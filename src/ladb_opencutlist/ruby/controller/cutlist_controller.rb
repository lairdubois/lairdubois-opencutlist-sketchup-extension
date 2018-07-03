module Ladb::OpenCutList

  require 'pathname'
  require 'csv'
  require_relative 'controller'
  require_relative '../model/scale3d'
  require_relative '../model/size3d'
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
  
  require_relative '../lib/bin_packing_2d/packengine'

  class CutlistController < Controller

    MATERIAL_ORIGIN_UNKNOW = 0
    MATERIAL_ORIGIN_OWNED = 1
    MATERIAL_ORIGIN_INHERITED = 2
    MATERIAL_ORIGIN_CHILD = 3

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

      Plugin.instance.register_command("cutlist_part_get_thumbnail") do |part_data|
        part_get_thumbnail_command(part_data)
      end

      Plugin.instance.register_command("cutlist_part_highlight") do |part_data|
        part_highlight_command(part_data)
      end

      Plugin.instance.register_command("cutlist_part_update") do |part_data|
        part_update_command(part_data)
      end

      Plugin.instance.register_command("cutlist_group_update") do |group_data|
        group_update_command(group_data)
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

      # Clear previously generated entity infos
      @instance_infos_cache = {}

      # Setup caches
      @material_attributes_cache = {}     # Cleared after response
      @definition_attributes_cache = {}   # Cleared after response

      # [BEGIN] -- Utils definitions --

      # -- Cache Utils --

      def _get_material_attributes(material)
        key = material ? material.name : '$EMPTY$'
        unless @material_attributes_cache.has_key? key
          @material_attributes_cache[key] = MaterialAttributes.new(material)
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
        face_count = 0
        if entity.visible? and (entity.layer.visible? or (entity.is_a? Sketchup::Face and entity.layer.name == 'Layer0'))
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

              bounds = _compute_faces_bounds(entity.definition)
              unless bounds.empty?

                # Create the instance info
                instance_info = InstanceInfo.new(path + [entity ])
                instance_info.size = Size3d.create_from_bounds(bounds, instance_info.scale, auto_orient && !_get_definition_attributes(entity.definition).orientation_locked_on_axis)

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
          if entity.visible? and (entity.layer.visible? or (entity.is_a? Sketchup::Face and entity.layer.name == 'Layer0'))
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

      # -- Std utils --

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
        unless entity.is_a? Sketchup::Drawingelement
          return nil
        end
        material = entity.material
        unless material
          material = _get_inherited_material(path.take(path.size - 1))
        end
        material
      end

      # [END] -- Utils definitions --

      # Check settings
      auto_orient = settings['auto_orient']
      smart_material = settings['smart_material']
      part_number_with_letters = settings['part_number_with_letters']
      part_number_sequence_by_group = settings['part_number_sequence_by_group']
      part_order_strategy = settings['part_order_strategy']

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
      dir, filename = File.split(model ? model.path : '')
      page_label = model && model.pages && model.pages.selected_page ? model.pages.selected_page.label : ''

      # Create cut list def
      cutlist_def = CutlistDef.new(length_unit, dir, filename, page_label)

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
        material_usage = MaterialUsage.new(material.name, material.display_name, material_attributes.type)
        cutlist_def.set_material_usage(material.name, material_usage)
      }

      # Populate cutlist
      @instance_infos_cache.each { |key, instance_info|

        entity = instance_info.entity

        definition = entity.definition
        definition_attributes = _get_definition_attributes(definition)

        material, material_origin = _get_material(instance_info.path, smart_material)
        material_id = material ? material.entityID : ''
        material_name = material ? material.name : ''
        material_attributes = _get_material_attributes(material)

        if material
          material_usage = cutlist_def.get_material_usage(material.name)
          if material_usage
            material_usage.use_count += 1
          end
        end

        # Compute transformation, scale and sizes

        size = instance_info.size
        case material_attributes.type
          when MaterialAttributes::TYPE_SOLID_WOOD, MaterialAttributes::TYPE_SHEET_GOOD
            std_thickness_info = _find_std_thickness(
                (size.thickness + material_attributes.l_thickness_increase).to_l,
                material_attributes.l_std_thicknesses,
                material_attributes.type == MaterialAttributes::TYPE_SOLID_WOOD
            )
            std_info = {
                :available => std_thickness_info[:available],
                :availability_mesage => std_thickness_info[:available] ? '' : 'tab.cutlist.not_available_thickness',
                :dimension => std_thickness_info[:value].to_s,
                :width => 0,
                :thickness => std_thickness_info[:value],
                :raw_size => Size3d.new(
                    (size.length + material_attributes.l_length_increase).to_l,
                    (size.width + material_attributes.l_width_increase).to_l,
                    std_thickness_info[:value]
                )
            }
          when MaterialAttributes::TYPE_BAR
            std_section_info = _find_std_section(
                size.width,
                size.thickness,
                material_attributes.l_std_sections
            )
            std_info = {
                :available => std_section_info[:available],
                :availability_mesage => std_section_info[:available] ? '' : 'tab.cutlist.not_available_section',
                :dimension => std_section_info[:value].to_s,
                :width => std_section_info[:value].width,
                :thickness => std_section_info[:value].height,
                :raw_size => Size3d.new(
                    (size.length + material_attributes.l_length_increase).to_l,
                    std_section_info[:value].width,
                    std_section_info[:value].height
                )
            }
          else
            std_info = {
                :available => true,
                :availability_mesage => '',
                :dimension => '',
                :width => 0,
                :thickness => 0,
                :raw_size => size
            }
        end
        raw_size = std_info[:raw_size]

        # Define group

        group_id = GroupDef.generate_group_id(material, material_attributes, std_info)
        group_def = cutlist_def.get_group_def(group_id)
        unless group_def

          group_def = GroupDef.new(group_id)
          group_def.material_id = material_id
          group_def.material_name = material_name
          group_def.material_type = material_attributes.type
          group_def.std_dimension = std_info[:dimension]
          group_def.std_available = std_info[:available]
          group_def.std_availability_message = std_info[:availability_mesage]
          group_def.std_width = std_info[:width]
          group_def.std_thickness = std_info[:thickness]
          group_def.show_raw_dimensions = material_attributes.type > MaterialAttributes::TYPE_UNKNOW && (material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0)

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

        part_id = PartDef.generate_part_id(group_id, definition, size)
        part_def = group_def.get_part_def(part_id)
        unless part_def

          part_def = PartDef.new(part_id)
          part_def.definition_id = definition.name
          part_def.number = number
          part_def.saved_number = definition_attributes.number
          part_def.name = definition.name
          part_def.scale = instance_info.scale
          part_def.raw_size = raw_size
          part_def.size = size
          part_def.material_name = material_name
          part_def.cumulable = definition_attributes.cumulable
          part_def.orientation_locked_on_axis = definition_attributes.orientation_locked_on_axis

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
          if group_def.material_type == MaterialAttributes::TYPE_BAR
            group_def.raw_length += (cutlist_def.is_metric? ? part_def.raw_size.length.to_m : part_def.raw_size.length)
          end
          if group_def.material_type == MaterialAttributes::TYPE_SOLID_WOOD || group_def.material_type == MaterialAttributes::TYPE_SHEET_GOOD
            group_def.raw_area += (cutlist_def.is_metric? ? part_def.raw_size.area_m2 : part_def.raw_size.area)
          end
          if group_def.material_type == MaterialAttributes::TYPE_SOLID_WOOD
            group_def.raw_volume += (cutlist_def.is_metric? ? part_def.raw_size.volume_m3 : part_def.raw_size.volume)
          end
        end
        group_def.part_count += 1

      }

      # Warnings & tips
      if @instance_infos_cache.length > 0
        if use_selection
          cutlist_def.add_warning("tab.cutlist.warning.partial_cutlist")
        end
        hardwood_material_count = 0
        plywood_material_count = 0
        bar_material_count = 0
        cutlist_def.material_usages.each { |key, material_usage|
          if material_usage.type == MaterialAttributes::TYPE_SOLID_WOOD
            hardwood_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_SHEET_GOOD
            plywood_material_count += material_usage.use_count
          elsif material_usage.type == MaterialAttributes::TYPE_BAR
            bar_material_count += material_usage.use_count
          end
        }
        if hardwood_material_count == 0 and plywood_material_count == 0 and bar_material_count == 0
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
          :is_metric => cutlist_def.is_metric?,
          :dir => cutlist_def.dir,
          :filename => cutlist_def.filename,
          :page_label => cutlist_def.page_label,
          :material_usages => [],
          :groups => []
      }

      # Sort and browse material usages
      cutlist_def.material_usages.sort_by { |k, v| [v.display_name.downcase] }.each { |key, material_usage|
        response[:material_usages].push(
            {
                :name => material_usage.name,
                :display_name => material_usage.display_name,
                :type => material_usage.type,
                :use_count => material_usage.use_count
            })
      }

      part_number = cutlist_def.max_number ? cutlist_def.max_number.succ : (part_number_with_letters ? 'A' : '1')

      # Sort and browse groups
      cutlist_def.group_defs.sort_by { |k, v| [ MaterialAttributes.type_order(v.material_type), v.material_name.downcase, -v.std_width, -v.std_thickness ] }.each { |key, group_def|

        if part_number_sequence_by_group
          part_number = group_def.max_number ? group_def.max_number.succ : (part_number_with_letters ? 'A' : '1')    # Reset code increment on each group
        end

        group = {
            :id => group_def.id,
            :material_id => group_def.material_id,
            :material_name => group_def.material_name,
            :material_type => group_def.material_type,
            :part_count => group_def.part_count,
            :std_dimension => group_def.std_dimension,
            :std_width => group_def.std_width,
            :std_thickness => group_def.std_thickness,
            :std_available => group_def.std_available,
            :std_availability_message => group_def.std_availability_message,
            :raw_length => group_def.raw_length,
            :raw_area => group_def.raw_area,
            :raw_volume => group_def.raw_volume,
            :show_raw_dimensions => group_def.show_raw_dimensions,
            :parts => []
        }
        response[:groups].push(group)

        # Sort and browse parts
        group_def.part_defs.values.sort { |part_def_a, part_def_b| PartDef::part_order(part_def_a, part_def_b, part_order_strategy) }.each { |part_def|
          group[:parts].push(
              {
                  :id => part_def.id,
                  :definition_id => part_def.definition_id,
                  :name => part_def.name,
                  :resized => !part_def.scale.identity?,
                  :length => part_def.size.length.to_s,
                  :width => part_def.size.width.to_s,
                  :thickness => part_def.size.thickness.to_s,
                  :count => part_def.count,
                  :raw_length => part_def.raw_size.length.to_s,
                  :raw_width => part_def.raw_size.width.to_s,
                  :raw_thickness => part_def.raw_size.thickness.to_s,
                  :cumulative_raw_length => part_def.cumulative_raw_length.to_s,
                  :cumulative_raw_width => part_def.cumulative_raw_width.to_s,
                  :number => part_def.number ? part_def.number : part_number,
                  :saved_number => part_def.saved_number,
                  :material_name => part_def.material_name,
                  :material_origins => part_def.material_origins,
                  :cumulable => part_def.cumulable,
                  :orientation_locked_on_axis => part_def.orientation_locked_on_axis,
                  :entity_ids => part_def.entity_ids,
                  :entity_serialized_paths => part_def.entity_serialized_paths,
                  :entity_names => part_def.entity_names.sort,
                  :contains_blank_entity_names => part_def.contains_blank_entity_names
              }
          )
          unless part_def.number
            part_number = part_number.succ
          end
        }

        # Compute imperial group's raw dimensions
        unless cutlist_def.is_metric?
          group[:raw_length] = group[:raw_length].to_feet
          group[:raw_area] = group[:raw_area] / 144
          group[:raw_volume] = group[:raw_volume] / 144
        end

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
      col_sep = settings['col_sep']
      encoding = settings['encoding']
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

                # Header row
                header = []
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.name'))
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.count'))
                unless hide_raw_dimensions
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.raw_length'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.raw_width'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.raw_thickness'))
                end
                unless hide_final_dimensions
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.length'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.width'))
                  header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.thickness'))
                end
                header.push(Plugin.instance.get_i18n_string('tab.cutlist.export.material_name'))

                csv << header

                def sanitize_length_string(length)
                  length.gsub(/^~ /, '')
                end

                # Content rows
                @cutlist[:groups].each { |group|
                  next if hidden_group_ids.include? group[:id]
                  group[:parts].each { |part|

                    no_raw_dimensions = group[:material_type] == MaterialAttributes::TYPE_UNKNOW
                    no_dimensions = group[:material_type] == MaterialAttributes::TYPE_UNKNOW && hide_untyped_material_dimensions

                    row = []
                    row.push(part[:name])
                    row.push(part[:count])
                    unless hide_raw_dimensions
                      row.push(no_raw_dimensions ? '' : sanitize_length_string(part[:raw_length]))
                      row.push(no_raw_dimensions ? '' : sanitize_length_string(part[:raw_width]))
                      row.push(no_raw_dimensions ? '' : sanitize_length_string(part[:raw_thickness]))
                    end
                    unless hide_final_dimensions
                      row.push(no_dimensions ? '' : sanitize_length_string(part[:length]))
                      row.push(no_dimensions ? '' : sanitize_length_string(part[:width]))
                      row.push(no_dimensions ? '' : sanitize_length_string(part[:thickness]))
                    end
                    row.push(part[:material_name])

                    csv << row
                  }
                }

              end

              # Write file
              f.write(bom)
              f.write(csv_file)

              # Populate response
              response[:export_path] = export_path.tr("\\", '/')  # Standardize path by replacing \ by /

            end

          rescue
            response[:errors] << 'tab.cutlist.error.failed_to_write_export_file'
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

        @cutlist[:groups].each { |group|

          if group_id && group[:id] != group_id
            next
          end

          group[:parts].each { |part|

            definition = definitions[part[:definition_id]]
            if definition

              definition_attributes = DefinitionAttributes.new(definition)
              definition_attributes.number = reset ? nil : part[:number]
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

    def part_highlight_command(part_data)

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Extract parameters
      name = part_data['name']
      length = part_data['length']
      width = part_data['width']
      thickness = part_data['thickness']
      material_name = part_data['material_name']
      entity_serialized_paths = part_data['entity_serialized_paths']

      # Populate entity infos
      instance_infos = []
      entity_serialized_paths.each { |entity_serialized_path|
        instance_info = @instance_infos_cache[entity_serialized_path]
        unless instance_info.nil?
          instance_infos.push(instance_info)
        end
      }

      unless instance_infos.empty?

        # Compute text infos
        text_line_1 = name
        text_line_2 = length.to_s + ' x ' + width.to_s + ' x ' + thickness.to_s +
            ' | ' + instance_infos.length.to_s + ' ' + Plugin.instance.get_i18n_string(instance_infos.length > 1 ? 'default.part_plural' : 'default.part_single') +
            ' | ' + (material_name.empty? ? Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') : material_name)

        # Create and activate highlight part tool
        highlight_tool = HighlightPartTool.new(text_line_1, text_line_2, instance_infos)
        model.select_tool(highlight_tool)

      end

    end

    def part_update_command(part_data)

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Extract parameters
      definition_id = part_data['definition_id']
      name = part_data['name']
      material_name = part_data['material_name']
      cumulable = DefinitionAttributes.valid_cumulable(part_data['cumulable'])
      orientation_locked_on_axis = part_data['orientation_locked_on_axis']
      entity_ids = part_data['entity_ids']

      definitions = model.definitions
      definition = definitions[definition_id]

      if definition

        # Update definition's name
        if definition.name != name
          definition.name = name
        end

        # Update definition's attributes
        definition_attributes = DefinitionAttributes.new(definition)
        if cumulable != definition_attributes.cumulable or orientation_locked_on_axis != definition_attributes.orientation_locked_on_axis
          definition_attributes.cumulable = cumulable
          definition_attributes.orientation_locked_on_axis = orientation_locked_on_axis
          definition_attributes.write_to_attributes
        end

        # Update component instance material
        materials = model.materials
        if material_name.nil? or material_name.empty? or (material = materials[material_name])

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

    def group_update_command(group_data)

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Extract parameters
      material_name = group_data['material_name']
      parts = group_data['parts']

      materials = model.materials

      # Update component instance material
      if material_name.nil? or material_name.empty? or (material = materials[material_name])

        parts.each { |part_data|
          entity_ids = part_data['entity_ids']
          entity_ids.each { |component_id|
            entity = ModelUtils::find_entity_by_id(model, component_id)
            if entity
              if material_name.nil? or material_name.empty?
                entity.material = nil
              elsif entity.material != material
                entity.material = material
              end
            end
          }
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
              e.add_box(part[:raw_length].to_l.to_f, part[:raw_width].to_l.to_f, part)
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
                :grained => grained,
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
            if material_attributes.l_length_increase > 0 or material_attributes.l_width_increase > 0
              response[:warnings] << [ 'tab.cutlist.cuttingdiagram.warning.raw_dimensions', { :material_name => group[:material_name], :length_increase => material_attributes.length_increase, :width_increase => material_attributes.width_increase } ]
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
                    :length => box.length.to_l.to_s,
                    :width => box.width.to_l.to_s,
                    :count => 0,
                }
                unplaced_parts[box.data[:number]] = part
              end
              part[:count] += 1
            }
            unplaced_parts.each { |key, part|
              response[:unplaced_parts].push(part)
            }

            # Summary
            result.unused_bins.each {|bin|
              response[:summary][:sheets].push(
                  {
                      :type => bin.type,
                      :count => 1,
                      :length => bin.length.to_l.to_s,
                      :width => bin.width.to_l.to_s,
                      :area => @cutlist[:is_metric] ? Size2d.new(bin.length.to_l, bin.width.to_l).area_m2 : Size2d.new(bin.length.to_l, bin.width.to_l).area / 144,
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
                    :area => 0,
                    :is_used => true,
                }
                summary_sheets[id] = sheet
              end
              sheet[:count] += 1
              sheet[:area] += @cutlist[:is_metric] ? Size2d.new(bin.length.to_l, bin.width.to_l).area_m2 : Size2d.new(bin.length.to_l, bin.width.to_l).area / 144
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
                  :leftovers => [],
                  :cuts => [],
              }
              response[:sheets].push(sheet)

              # Parts
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
                    }
                )
              }

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