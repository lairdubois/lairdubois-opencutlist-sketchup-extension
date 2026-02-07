module Ladb::OpenCutList

  require 'CGI'
  require_relative '../../helper/bounding_box_helper'
  require_relative '../../model/attributes/definition_attributes'
  require_relative '../../utils/axis_utils'

  class CutlistPartUpdateWorker

    include BoundingBoxHelper

    PartData = Struct.new(
        :virtual,
        :definition_id,
        :name,
        :is_dynamic_attributes_name,
        :material_name,
        :cumulable,
        :instance_count_by_part,
        :mass,
        :price,
        :thickness_layer_count,
        :length_increase,
        :width_increase,
        :thickness_increase,
        :description,
        :url,
        :tags,
        :orientation_locked_on_axis,
        :symmetrical,
        :ignore_grain_direction,
        :axes_order,
        :axes_origin_position,
        :edge_material_names,
        :edge_entity_ids,
        :face_material_names,
        :face_entity_ids,
        :face_texture_angles,
        :entity_ids
    )

    def initialize(cutlist,

                   auto_orient: false,
                   parts_data: []

    )

      @cutlist = cutlist

      @auto_orient = auto_orient
      @parts_data = []

      parts_data.each { |part_data|
        @parts_data << PartData.new(
            part_data.fetch('virtual'),
            CGI.unescape(part_data.fetch('definition_id')),
            CGI.unescape(part_data.fetch('name')),
            part_data.fetch('is_dynamic_attributes_name'),
            part_data.fetch('material_name'),
            DefinitionAttributes.valid_cumulable(part_data.fetch('cumulable')),
            part_data.fetch('instance_count_by_part'),
            part_data.fetch('mass'),
            part_data.fetch('price'),
            part_data.fetch('thickness_layer_count'),
            part_data.fetch('length_increase'),
            part_data.fetch('width_increase'),
            part_data.fetch('thickness_increase'),
            part_data.fetch('description'),
            part_data.fetch('url'),
            DefinitionAttributes.valid_tags(part_data.fetch('tags')),
            part_data.fetch('orientation_locked_on_axis'),
            part_data.fetch('symmetrical'),
            part_data.fetch('ignore_grain_direction'),
            part_data.fetch('axes_order', nil),
            part_data.fetch('axes_origin_position', nil),
            part_data.fetch('edge_material_names'),
            part_data.fetch('edge_entity_ids'),
            part_data.fetch('face_material_names'),
            part_data.fetch('face_entity_ids'),
            part_data.fetch('face_texture_angles'),
            part_data.fetch('entity_ids')
        )
      }

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Start a model modification operation
      model.start_operation('OCL Part Update', true, false, true)

      definitions = model.definitions
      @parts_data.each { |part_data|

        if part_data.virtual

          # Virtual part (edge, veneer)

          # Just apply material
          _apply_material(part_data.material_name, part_data.entity_ids, model)

        else

          # Real part

          definition = definitions[part_data.definition_id]
          if definition

            # Update definition's name
            if definition.name != part_data.name && !part_data.is_dynamic_attributes_name
              definition.name = part_data.name
            end

            # Update definition's description
            if definition.description != part_data.description
              definition.description = part_data.description
            end

            # Update definition's attributes
            definition_attributes = DefinitionAttributes.new(definition)
            if part_data.cumulable != definition_attributes.cumulable ||
                part_data.instance_count_by_part != definition_attributes.instance_count_by_part ||
                part_data.mass != definition_attributes.mass ||
                part_data.price != definition_attributes.price ||
                part_data.url != definition_attributes.url ||
                part_data.thickness_layer_count != definition_attributes.thickness_layer_count ||
                part_data.length_increase != definition_attributes.length_increase ||
                part_data.width_increase != definition_attributes.width_increase ||
                part_data.thickness_increase != definition_attributes.thickness_increase ||
                part_data.orientation_locked_on_axis != definition_attributes.orientation_locked_on_axis ||
                part_data.symmetrical != definition_attributes.symmetrical ||
                part_data.ignore_grain_direction != definition_attributes.ignore_grain_direction ||
                part_data.tags != definition_attributes.tags
              definition_attributes.cumulable = part_data.cumulable
              definition_attributes.instance_count_by_part = part_data.instance_count_by_part
              definition_attributes.mass = part_data.mass
              definition_attributes.price = part_data.price
              definition_attributes.url = part_data.url
              definition_attributes.thickness_layer_count = part_data.thickness_layer_count
              definition_attributes.length_increase = part_data.length_increase
              definition_attributes.width_increase = part_data.width_increase
              definition_attributes.thickness_increase = part_data.thickness_increase
              definition_attributes.tags = part_data.tags
              definition_attributes.orientation_locked_on_axis = part_data.orientation_locked_on_axis
              definition_attributes.symmetrical = part_data.symmetrical
              definition_attributes.ignore_grain_direction = part_data.ignore_grain_direction
              definition_attributes.write_to_attributes
            end

            # Transform part axes if axes order exists
            if part_data.axes_order.is_a?(Array) && part_data.axes_order.length == 3

              axes_convertor = {
                  'x' => X_AXIS,
                  'y' => Y_AXIS,
                  'z' => Z_AXIS
              }

              # Convert axes order to Vector3D array
              part_data.axes_order.map! { |axis|
                axes_convertor[axis]
              }

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
              when 'front-min'
                size = Size3d::create_from_bounds(bounds, Scale3d.new, @auto_orient && !part_data.orientation_locked_on_axis)
                case size.oriented_axis(Z_AXIS)
                when X_AXIS
                  origin = Geom::Point3d.new(bounds.max.x , bounds.min.y, bounds.min.z)
                when Y_AXIS
                  origin = Geom::Point3d.new(bounds.min.x , bounds.max.y, bounds.min.z)
                when Z_AXIS
                  origin = Geom::Point3d.new(bounds.min.x , bounds.min.y, bounds.max.z)
                else
                  origin = ORIGIN # Strange axis
                end
              when 'front-center'
                size = Size3d::create_from_bounds(bounds, Scale3d.new, @auto_orient && !part_data.orientation_locked_on_axis)
                case size.oriented_axis(Z_AXIS)
                when X_AXIS
                  origin = Geom::Point3d.new(bounds.max.x , bounds.center.y, bounds.center.z)
                when Y_AXIS
                  origin = Geom::Point3d.new(bounds.center.x , bounds.max.y, bounds.center.z)
                when Z_AXIS
                  origin = Geom::Point3d.new(bounds.center.x , bounds.center.y, bounds.max.z)
                else
                  origin = ORIGIN # Strange axis
                end
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

            # Update materials
            _apply_material(part_data.material_name, part_data.entity_ids, model)
            _apply_material(part_data.edge_material_names['ymin'], part_data.edge_entity_ids['ymin'], model, MaterialAttributes::TYPE_EDGE)
            _apply_material(part_data.edge_material_names['ymax'], part_data.edge_entity_ids['ymax'], model, MaterialAttributes::TYPE_EDGE)
            _apply_material(part_data.edge_material_names['xmin'], part_data.edge_entity_ids['xmin'], model, MaterialAttributes::TYPE_EDGE)
            _apply_material(part_data.edge_material_names['xmax'], part_data.edge_entity_ids['xmax'], model, MaterialAttributes::TYPE_EDGE)
            _apply_material(part_data.face_material_names['zmin'], part_data.face_entity_ids['zmin'], model, MaterialAttributes::TYPE_VENEER, part_data.face_texture_angles['zmin'].nil? ? nil : part_data.face_texture_angles['zmin'].to_i.degrees)
            _apply_material(part_data.face_material_names['zmax'], part_data.face_entity_ids['zmax'], model, MaterialAttributes::TYPE_VENEER, part_data.face_texture_angles['zmax'].nil? ? nil : part_data.face_texture_angles['zmax'].to_i.degrees)

          end

        end

      }

      # Commit model modification operation
      model.commit_operation

    end

    # -----

    def _apply_material(material_name, entity_ids, model, removable_type = nil, angle = nil)  # angle in radians [0..2PI]
      return if entity_ids.nil?

      material = nil
      if material_name.nil? || material_name.empty? || (material = model.materials[material_name])

        entity_ids.each do |entity_id|

          entity = model.find_entity_by_id(entity_id)
          if entity

            if material_name.nil? || material_name.empty?

              current_material = entity.material
              current_material_attributes = MaterialAttributes.new(current_material)

              # Remove current entity material (if removable)
              entity.material = nil if removable_type.nil? || current_material_attributes.type == removable_type

            else

              # Apply only if new material
              if entity.material != material
                entity.material = material
              end

              if !angle.nil? && entity.is_a?(Sketchup::Face) && entity.respond_to?(:clear_texture_position) # SU 2022+

                # Reset all texture transformations
                entity.clear_texture_position(true)

                # Adapt angle if face normal is -Z
                angle = Math::PI - angle if entity.normal.samedirection?(Z_AXIS.reverse)

                if angle > 0

                  points = [
                    entity.edges.first.start.position,
                    entity.edges.first.end.position
                  ]

                  uv_helper = entity.get_UVHelper(true, false)
                  t = Geom::Transformation.rotation(ORIGIN, entity.normal, angle.to_f)

                  mapping = []
                  (0..1).each do |i|
                    mapping << points[i].transform(t)             # Transformed point
                    mapping << uv_helper.get_front_UVQ(points[i]) # UVQ
                  end

                  entity.position_material(entity.material, mapping, true)

                end

              end

            end

          end

        end

      end
    end

  end

end