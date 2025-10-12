module Ladb::OpenCutList

  require_relative '../../model/attributes/material_attributes'
  require_relative '../../model/formula/formula_data'
  require_relative '../../model/formula/formula_wrapper'
  require_relative '../../helper/part_helper'
  require_relative '../../worker/common/common_eval_formula_worker'

  class OutlinerDeepRenamePartsWorker

    include PartHelper

    def initialize(outliner_def,

                   id:,
                   formula:,

                   preview_index: -1  # Apply renaming only if preview_index >= 0

    )

      @outliner_def = outliner_def

      @id = id
      @formula = formula

      @preview_index = preview_index

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

      # Start a model modification operation
      model.start_operation('OCL Outliner Deep Rename', true, false, false) if @preview_index < 0

      index = 0
      node_defs = node_def.get_valid_unlocked_selection_siblings

      d_nps = {} # Definition => NodeDefs, Parts
      fn_populate_dn = lambda { |node_def|
        if node_def.type == OutlinerNodeModelDef::TYPE_PART && !node_def.entity.deleted?
          unless (part = _generate_part_from_path(node_def.path)).nil?
            d_nps[node_def.entity.definition] = [] unless d_nps.has_key?(node_def.entity.definition)
            d_nps[node_def.entity.definition] << [ node_def, part ]
          end
        end
        node_def.children.each do |child_node_def|
          fn_populate_dn.call(child_node_def)
        end
      }
      node_defs.each { |node_def| fn_populate_dn.call(node_def) }

      d_nps.each do |definition, nps|

        n_ns = {} # Name => NodeDefs
        nps.each do |node_def, part|

          group = part.group
          instance_info = part.def.get_one_instance_info

          data = OutlinerInstanceFormulaData.new(

            path: PathFormulaWrapper.new(instance_info.path[0...-1]),
            instance_name: StringFormulaWrapper.new(instance_info.entity.name),
            name: StringFormulaWrapper.new(part.name),
            cutting_length: LengthFormulaWrapper.new(part.def.cutting_length),
            cutting_width: LengthFormulaWrapper.new(part.def.cutting_width),
            cutting_thickness: LengthFormulaWrapper.new(part.def.cutting_size.thickness),
            edge_cutting_length: LengthFormulaWrapper.new(part.def.edge_cutting_length),
            edge_cutting_width: LengthFormulaWrapper.new(part.def.edge_cutting_width),
            bbox_length: LengthFormulaWrapper.new(part.def.size.length),
            bbox_width: LengthFormulaWrapper.new(part.def.size.width),
            bbox_thickness: LengthFormulaWrapper.new(part.def.size.thickness),
            final_area: AreaFormulaWrapper.new(part.def.final_area),
            material: MaterialFormulaWrapper.new(group.def.material, group.def),
            description: StringFormulaWrapper.new(part.description),
            url: StringFormulaWrapper.new(part.url),
            tags: ArrayFormulaWrapper.new(part.tags),
            edge_ymin: EdgeFormulaWrapper.new(
              part.def.edge_materials[:ymin],
              part.def.edge_group_defs[:ymin]
            ),
            edge_ymax: EdgeFormulaWrapper.new(
              part.def.edge_materials[:ymax],
              part.def.edge_group_defs[:ymax]
            ),
            edge_xmin: EdgeFormulaWrapper.new(
              part.def.edge_materials[:xmin],
              part.def.edge_group_defs[:xmin]
            ),
            edge_xmax: EdgeFormulaWrapper.new(
              part.def.edge_materials[:xmax],
              part.def.edge_group_defs[:xmax]
            ),
            face_zmin: VeneerFormulaWrapper.new(
              part.def.veneer_materials[:zmin],
              part.def.veneer_group_defs[:zmin]
            ),
            face_zmax: VeneerFormulaWrapper.new(
              part.def.veneer_materials[:zmax],
              part.def.veneer_group_defs[:zmax]
            ),
            layer: StringFormulaWrapper.new(instance_info.layer.name),

            component_definition: ComponentDefinitionFormulaWrapper.new(instance_info.definition),
            component_instance: ComponentInstanceFormulaWrapper.new(instance_info.entity),

          )

          name = CommonEvalFormulaWorker.new(formula: @formula, data: data).run

          # Check name integrity
          return { :errors => [ name ] } unless name.is_a?(String)

          if @preview_index < 0

            next if name == definition.name || name.empty?

            n_ns[name] = [] unless n_ns.has_key?(name)
            n_ns[name] << node_def

          else

            if index == @preview_index
              return {
                :success => true,
                :preview => {
                  :old => definition.name,
                  :new => name.empty? ? definition.name : name,
                }
              }
            end
            index += 1

          end

        end

        if @preview_index < 0

          # Rename definitions
          n_ns.each do |name, node_defs|
            new_definition = node_defs.first.entity.make_unique.definition
            node_defs.each do |node_def|
              node_def.entity.definition = new_definition
            end
            new_definition.name = name if name != new_definition.name
          end

          # Remove unused definitions
          model.definitions.remove(definition) if definition.count_instances == 0

        end

      end


      # Commit model modification operation
      model.commit_operation if @preview_index < 0

      { :success => true }
    end

    # -----

  end

  class OutlinerInstanceFormulaData < FormulaData

    def initialize(

      path:,
      instance_name:,
      name:,
      cutting_length:,
      cutting_width:,
      cutting_thickness:,
      edge_cutting_length:,
      edge_cutting_width:,
      bbox_length:,
      bbox_width:,
      bbox_thickness:,
      final_area:,
      material:,
      description:,
      url:,
      tags:,
      edge_ymin:,
      edge_ymax:,
      edge_xmin:,
      edge_xmax:,
      face_zmin:,
      face_zmax:,
      layer:,

      component_definition:,
      component_instance:

    )
      @path = path
      @instance_name = instance_name
      @name = name
      @cutting_length = cutting_length
      @cutting_width = cutting_width
      @cutting_thickness = cutting_thickness
      @edge_cutting_length = edge_cutting_length
      @edge_cutting_width = edge_cutting_width
      @bbox_length = bbox_length
      @bbox_width = bbox_width
      @bbox_thickness = bbox_thickness
      @final_area = final_area
      @material = material
      @material_type = material.type
      @material_name = material.name
      @material_description = material.description
      @material_url = material.url
      @description = description
      @url = url
      @tags = tags
      @edge_ymin = edge_ymin
      @edge_ymax = edge_ymax
      @edge_xmin = edge_xmin
      @edge_xmax = edge_xmax
      @face_zmin = face_zmin
      @face_zmax = face_zmax
      @layer = layer
      @component_instance = component_instance
      @component_definition = component_definition
    end

  end

end