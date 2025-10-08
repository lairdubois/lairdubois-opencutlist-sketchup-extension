module Ladb::OpenCutList

  require_relative '../../model/attributes/material_attributes'
  require_relative '../../model/formula/formula_data'
  require_relative '../../model/formula/formula_wrapper'
  require_relative '../../worker/common/common_eval_formula_worker'

  class OutlinerDeepRenameWorker

    def initialize(outliner_def,

                   id:,
                   formula:

    )

      @outliner_def = outliner_def

      @id = id
      @formula = formula

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node_def = @outliner_def.get_node_def_by_id(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?
      return { :errors => [ 'default.error' ] } unless entity.respond_to?(:explode)

      # Start model modification operation
      model.start_operation('OCL Outliner Deep Rename', true, false, false)


      if node_def.selected
        node_defs = node_def.parent.children.map { |child_node_def| child_node_def if child_node_def.selected }.compact
      else
        node_defs = [ node_def ]
      end

      dn = {} # Definition => NodeDefs
      fn_populate_dn = lambda { |node_def|
        if node_def.type == OutlinerNodeModelDef::TYPE_PART && !node_def.entity.deleted?
          dn[node_def.entity.definition] = [] unless dn.has_key?(node_def.entity.definition)
          dn[node_def.entity.definition] << node_def
        end
        node_def.children.each do |child_node_def|
          fn_populate_dn.call(child_node_def)
        end
      }
      node_defs.each { |node_def| fn_populate_dn.call(node_def) }

      dn.each do |definition, node_defs|

        ni = {} # NodeDef => Instances
        node_defs.each do |node_def|

          data = InstanceFormulaData.new(

            path: PathFormulaWrapper.new(node_def.path[0...-1]),
            name: StringFormulaWrapper.new(node_def.entity.name),
            component_definition: ComponentDefinitionFormulaWrapper.new(node_def.entity.definition),
            component_instance: ComponentInstanceFormulaWrapper.new(node_def.entity),

          )

          name = CommonEvalFormulaWorker.new(formula: @formula, data: data).run

          ni[name] = [] unless ni.has_key?(name)
          ni[name] << node_def.entity

        end

        ni.each do |name, instances|
          new_definition = instances.first.make_unique.definition
          instances.each do |instance|
            instance.definition = new_definition
          end
          new_definition.name = name
        end

        model.definitions.remove(definition) if definition.count_instances == 0

      end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

  class InstanceFormulaData < FormulaData

    def initialize(

      path:,
      name:,

      component_definition:,
      component_instance:

    )
      @path = path
      @name = name
      @component_instance = component_instance
      @component_definition = component_definition
    end

  end

end