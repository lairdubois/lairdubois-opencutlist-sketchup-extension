require_relative 'controller'

class CutlistController < Controller

  def initialize(app)
    super(app)
  end

  def setup_dialog_actions(dialog)

    Setup toolbox dialog actions
    dialog.add_action_callback("ladb_generate_cutlist") do |action_context, json_params|

      params = JSON.parse(json_params)

      # Explode parameters
      callback = params['callback']
      length_increase = params['param']['length_increase'].to_l
      width_increase = params['param']['width_increase'].to_l
      thickness_increase = params['param']['thickness_increase'].to_l

      # Retrieve selected entities or all if no selection
      model = Sketchup.active_model
      if Sketchup.active_model.selection.empty?
        entities = model.active_entities
      else
        entities = model.selection
      end

      # Generate cutlist
      json_data = generate_cutlist(entities, length_increase, width_increase, thickness_increase)

      # Callback to JS
      dialog.execute_script(callback.sub('%PARAM%', json_data))

    end

  end

  private

  def _fetch_leaf_components(entity, leaf_components)
    child_component_count = 0
    if entity.visible? and entity.layer.visible?
      if entity.is_a? Sketchup::Group
        entity.entities.each { |child_entity|
          child_component_count += _fetch_leaf_components(child_entity, leaf_components)
        }
      elsif entity.is_a? Sketchup::ComponentInstance
        entity.definition.entities.each { |child_entity|
          child_component_count += _fetch_leaf_components(child_entity, leaf_components)
        }
        if child_component_count == 0
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
      end
    }
    bounds
  end

  def _dim_from_bounds(bounds)
    ordered = [bounds.width, bounds.height, bounds.depth].sort
    Dim.new(ordered[2], ordered[1], ordered[0])
  end

  def _convert_to_std_thickness(thickness)
    std_thicknesses = ['18mm'.to_l, '27mm'.to_l, '35mm'.to_l, '45mm'.to_l, '65mm'.to_l, '80mm'.to_l, '100mm'.to_l]
    std_thicknesses.each { |std_thickness|
      if thickness <= std_thickness
        return std_thickness;
      end
    }
    thickness
  end

  public

  def generate_cutlist(entities, length_increase, width_increase, thickness_increase)

    # Fetch leaf components in given entities
    leaf_components = []
    entities.each { |entity|
      _fetch_leaf_components(entity, leaf_components)
    }

    # Create cut list
    cutlist = Cutlist.new(Sketchup.active_model.path, Sketchup.active_model.options['UnitsOptions']['LengthUnit'])

    # Populate cutlist
    leaf_components.each { |component|

      material = component.material
      definition = component.definition

      material_name = material ? component.material.name : 'Matière non définie'

      dim = _dim_from_bounds(_compute_faces_bounds(definition))
      raw_dim = Dim.new(
          (dim.length + length_increase).to_l,
          (dim.width + width_increase).to_l,
          _convert_to_std_thickness((dim.thickness + thickness_increase).to_l)
      )

      key = material_name + ':' + raw_dim.thickness.to_s
      group_def = cutlist.get_group_def(key)
      unless group_def

        group_def = GroupDef.new
        group_def.name = material_name
        group_def.raw_thickness = raw_dim.thickness

        cutlist.set_group_def(key, group_def)

      end

      piece_def = group_def.get_piece(definition.name)
      unless piece_def

        piece_def = PieceDef.new
        piece_def.name = definition.name
        piece_def.raw_dim = raw_dim
        piece_def.dim = dim

        group_def.set_piece(definition.name, piece_def)

      end
      piece_def.count += 1
      piece_def.add_component_guid(component.guid)

    }

    cutlist.to_json
  end

end