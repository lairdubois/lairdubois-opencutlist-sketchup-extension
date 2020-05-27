module Ladb::OpenCutList

  require_relative '../../helper/boundingbox_helper'
  require_relative '../../model/attributes/definition_attributes'
  require_relative '../../utils/model_utils'
  require_relative '../../utils/axis_utils'

  class CutlistPartUpdateWorker

    include BoundingBoxHelper

    PartData = Struct.new(
        :definition_id,
        :name,
        :is_dynamic_attributes_name,
        :material_name,
        :cumulable,
        :length_increase,
        :width_increase,
        :thickness_increase,
        :orientation_locked_on_axis,
        :labels,
        :axes_order,
        :axes_origin_position,
        :edge_material_names,
        :edge_entity_ids,
        :entity_ids
    )

    def initialize(settings, cutlist)
      @parts_data = []

      parts_data = settings['parts_data']
      parts_data.each { |part_data|
        @parts_data << PartData.new(
            part_data['definition_id'],
            part_data['name'],
            part_data['is_dynamic_attributes_name'],
            part_data['material_name'],
            DefinitionAttributes.valid_cumulable(part_data['cumulable']),
            part_data['length_increase'],
            part_data['width_increase'],
            part_data['thickness_increase'],
            part_data['orientation_locked_on_axis'],
            DefinitionAttributes.valid_labels(part_data['labels']),
            part_data['axes_order'],
            part_data['axes_origin_position'],
            part_data['edge_material_names'],
            part_data['edge_entity_ids'],
            part_data['entity_ids']
        )
      }

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      definitions = model.definitions
      @parts_data.each { |part_data|

        definition = definitions[part_data.definition_id]

        if definition

          # Update definition's name
          if definition.name != part_data.name and !part_data.is_dynamic_attributes_name
            definition.name = part_data.name
          end

          # Update definition's attributes
          definition_attributes = DefinitionAttributes.new(definition)
          if part_data.cumulable != definition_attributes.cumulable ||
              part_data.length_increase != definition_attributes.length_increase ||
              part_data.width_increase != definition_attributes.width_increase ||
              part_data.thickness_increase != definition_attributes.thickness_increase ||
              part_data.orientation_locked_on_axis != definition_attributes.orientation_locked_on_axis ||
              part_data.labels != definition_attributes.labels
            definition_attributes.cumulable = part_data.cumulable
            definition_attributes.length_increase = part_data.length_increase
            definition_attributes.width_increase = part_data.width_increase
            definition_attributes.thickness_increase = part_data.thickness_increase
            definition_attributes.orientation_locked_on_axis = part_data.orientation_locked_on_axis
            definition_attributes.labels = part_data.labels
            definition_attributes.write_to_attributes
          end

          # Update materials
          _apply_material(part_data.material_name, part_data.entity_ids, model)
          _apply_material(part_data.edge_material_names['ymin'], part_data.edge_entity_ids['ymin'], model)
          _apply_material(part_data.edge_material_names['ymax'], part_data.edge_entity_ids['ymax'], model)
          _apply_material(part_data.edge_material_names['xmin'], part_data.edge_entity_ids['xmin'], model)
          _apply_material(part_data.edge_material_names['xmax'], part_data.edge_entity_ids['xmax'], model)

          # Transform part axes if axes order exist
          if part_data.axes_order.is_a?(Array) and part_data.axes_order.length == 3

            axes_convertor = {
                'x' => X_AXIS,
                'y' => Y_AXIS,
                'z' => Z_AXIS
            }

            # Convert axes order to Vector3D array
            part_data.axes_order.map! { |axis|
              axes_convertor[axis]
            }

            # Force axes to be "trihedron"
            if AxisUtils::flipped?(part_data.axes_order[0], part_data.axes_order[1], part_data.axes_order[2])
              part_data.axes_order[1] = part_data.axes_order[1].reverse
            end

            # Create transformations
            ti = Geom::Transformation.axes(ORIGIN, part_data.axes_order[0], part_data.axes_order[1], part_data.axes_order[2])
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
          if part_data.axes_origin_position

            # Compute definition bounds
            bounds = _compute_faces_bounds(definition)

            case part_data.axes_origin_position
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

    # -----

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

  end

end