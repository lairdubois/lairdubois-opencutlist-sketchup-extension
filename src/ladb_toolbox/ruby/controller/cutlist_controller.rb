require 'pathname'
require_relative 'controller'
require_relative '../model/size'
require_relative '../model/cutlist'
require_relative '../model/groupdef'
require_relative '../model/partdef'
require_relative '../model/material_usage'

class CutlistController < Controller

  def initialize(plugin)
    super(plugin, 'cutlist')
  end

  def setup_dialog_actions(dialog)

    # Setup toolbox dialog actions
    dialog.add_action_callback("ladb_cutlist_generate") do |action_context, json_params|

      # Extract parameters
      settings = JSON.parse(json_params)

      # Generate cutlist
      data = generate_cutlist_data(settings)

      # Callback to JS
      execute_js_callback('onCutlistGenerated', data)

    end

    dialog.add_action_callback("ladb_cutlist_part_update") do |action_context, json_params|

      # Extract parameters
      part = JSON.parse(json_params)
      definition_id = part['definition_id']
      name = part['name']
      material_name = part['material_name']
      component_ids = part['component_ids']

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

  end

  private

  def _fetch_leafs(entity, leaf_components)
    child_component_count = 0
    if entity.visible? and entity.layer.visible?
      if entity.is_a? Sketchup::Group
        entity.entities.each { |child_entity|
          child_component_count += _fetch_leafs(child_entity, leaf_components)
        }
      elsif entity.is_a? Sketchup::ComponentInstance
        entity.definition.entities.each { |child_entity|
          child_component_count += _fetch_leafs(child_entity, leaf_components)
        }
        bounds = entity.bounds
        if child_component_count == 0 and bounds.width > 0 and bounds.height > 0 and bounds.depth > 0
          leaf_components.push(entity)
          return 1
        end
      end
    end
    child_component_count
  end

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

  def _size_from_bounds(bounds)
    ordered = [bounds.width, bounds.height, bounds.depth].sort
    Size.new(ordered[2], ordered[1], ordered[0])
  end

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

  public

  def generate_cutlist_data(settings)

    # Check settings
    part_number_with_letters = settings['part_number_with_letters']
    part_number_sequence_by_group = settings['part_number_sequence_by_group']

    # Retrieve selected entities or all if no selection
    model = Sketchup.active_model
    if model.selection.empty?
      entities = model.active_entities
      use_selection = false
    else
      entities = model.selection
      use_selection = true
    end

    # Fetch leaf components in given entities
    leaf_components = []
    entities.each { |entity|
      _fetch_leafs(entity, leaf_components)
    }

    status = Cutlist::STATUS_SUCCESS
    filename = Pathname.new(model.path).basename
    length_unit = Sketchup.active_model.options['UnitsOptions']['LengthUnit']

    # Create cut list
    cutlist = Cutlist.new(status, filename, length_unit)

    # Errors
    if leaf_components.length == 0
      if use_selection
        cutlist.add_error("Auncune instance de composant visible n'a été détectée dans votre sélection")
      else
        cutlist.add_error("Auncune instance de composant visible n'a été détectée sur votre scène")
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
    leaf_components.each { |component|

      material = component.material
      definition = component.definition

      material_name = material ? component.material.name : 'Matière non définie'
      material_attributes = MaterialAttributes.new(material)

      if material
        material_usage = cutlist.get_material_usage(material.name)
        if material_usage
          material_usage.use_count += 1
        end
      end

      size = _size_from_bounds(_compute_faces_bounds(definition))
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

        part_def = PartDef.new(definition.guid)
        part_def.name = definition.name
        part_def.raw_size = raw_size
        part_def.size = size

        group_def.set_part_def(definition.name, part_def)

      end
      part_def.count += 1
      part_def.add_component_id(component.entityID)

      group_def.part_count += 1

    }

    # Warnings
    if leaf_components.length > 0
      hardwood_material_count = 0
      plywood_material_count = 0
      cutlist.material_usages.each { |key, material_usage|
        if material_usage.type == MaterialAttributes::TYPE_HARDWOOD
          hardwood_material_count += material_usage.use_count
        elsif material_usage.type == MaterialAttributes::TYPE_PLYWOOD
          plywood_material_count += material_usage.use_count
        end
      }
      if hardwood_material_count == 0 or plywood_material_count == 0
        cutlist.add_warning("Votre #{use_selection ? "sélection" : "modèle"} n'utilise aucune matière ayant un type défini (<strong>bois massif</strong> ou <strong>bois panneau</strong>)")
      end
      if use_selection
        cutlist.add_warning("Cette fiche de débit est une représentation partielle de votre modèle puisqu'elle n'utilise que les éléments sélectionnés.")
      end
    end

    # Data
    # ----

    data = {
        :status => cutlist.status,
        :errors => cutlist.errors,
        :warnings => cutlist.warnings,
        :filepath => cutlist.filepath,
        :length_unit => cutlist.length_unit,
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
      group_def.part_defs.sort_by { |k, v| [v.size.thickness, v.size.length, v.size.width] }.reverse.each { |key, part_def|
        if group_def.material_type != MaterialAttributes::TYPE_UNKNOW
          group[:raw_area_m2] += part_def.raw_size.area_m2
          if group_def.material_type == MaterialAttributes::TYPE_HARDWOOD
            group[:raw_volume_m3] += part_def.raw_size.volume_m3
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
                                :component_ids => part_def.component_ids,
                                :material_name => group_def.material_name
                            }
        )
        part_number = part_number.succ
      }

    }

    data
  end

end