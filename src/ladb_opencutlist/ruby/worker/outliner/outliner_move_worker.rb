module Ladb::OpenCutList

  class OutlinerMoveWorker

    def initialize(outliner_def,

                   id:,
                   target_id:

    )

      @outliner_def = outliner_def

      @id = id
      @target_id = target_id

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node_def = @outliner_def.get_node_def_by_id(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def && node_def.valid?

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?

      target_node_def = @target_id == '0' ? @outliner_def.root_node_def : @outliner_def.get_node_def_by_id(@target_id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless target_node_def && target_node_def.valid?

      target_entity = target_node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if target_entity.is_a?(Sketchup::Entity) && target_entity.deleted? || !target_entity.is_a?(Sketchup::Entity) && !target_entity.is_a?(Sketchup::Model)
      return { :errors => [ 'tab.outliner.error.invalid_target' ] } if target_entity == entity || target_entity.respond_to?(:definition) && target_entity.definition == entity.definition

      # Start a model modification operation
      model.start_operation('OCL Outliner Move', true, false, false)


      # Compute target node transformation
      tt = Sketchup::InstancePath.new(target_node_def.path).transformation
      tti = tt.inverse

      # Extract target entities
      if target_entity.is_a?(Sketchup::ComponentInstance)
        target_entities = target_entity.definition.entities
      else
        target_entities = target_entity.entities
      end

      node_defs = node_def.get_valid_selection_siblings
      node_defs.each do |node_def|

        # Compute node transformation
        t = Sketchup::InstancePath.new(node_def.path).transformation

        # Create a new instance on target
        new_entity = target_entities.add_instance(node_def.entity.definition, tti * t)

        # Copy instance metas
        _copy_instance_metas(node_def.entity, new_entity)

        # Erase original instance
        node_def.entity.erase!

      end

      model.selection.clear
      model.active_path = target_node_def.path if model.respond_to?(:active_path=) && !model.active_path.nil? && (target_node_def.path[0...-1] & model.active_path).empty?


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

    def _copy_instance_metas(src_instance, dst_instance)
      dst_instance.material = src_instance.material
      dst_instance.name = src_instance.name
      dst_instance.layer = src_instance.layer
      dst_instance.casts_shadows = src_instance.casts_shadows?
      dst_instance.receives_shadows = src_instance.receives_shadows?
      dst_instance.locked = src_instance.locked?
      dst_instance.visible = src_instance.visible?
      unless src_instance.attribute_dictionaries.nil?
        src_instance.attribute_dictionaries.each do |attribute_dictionary|
          attribute_dictionary.each do |key, value|
            dst_instance.set_attribute(attribute_dictionary.name, key, value)
          end
        end
      end
    end

  end

end