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

                   dry_run: false

    )

      @outliner_def = outliner_def

      @id = id
      @formula = formula

      @dry_run = dry_run

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


      node_defs = node_def.get_valid_unlocked_selection_siblings
      preview = []

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

      d_n_ns = {}
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

          if @dry_run
            name = '' if name == definition.name
          else
            next if name == definition.name || name.empty?
          end

          n_ns[name] = [] unless n_ns.has_key?(name)
          n_ns[name] << node_def

        end

        if @dry_run

          preview += n_ns.keys.map do |name|
            [
              definition.name,  # Old name
              name,             # New name
              n_ns[name].size
            ]
          end

        else

          d_n_ns[definition] = n_ns

        end

      end

      unless @dry_run

        # Build a tree of nodes
        p_rn = {} # Path => RNode
        d_n_ns.each do |definition, n_ns|
          n_ns.each do |name, node_defs|
            node_defs.each do |node_def|
              node_def.path.each_with_index do |entity, index|
                path = node_def.path[0..index]
                unless p_rn.has_key?(path)
                  p_rn[path] = index == node_def.path.size - 1 ? RNodePart.new(entity, name) : RNode.new(entity)
                  unless index == 0
                    parent_path = node_def.path[0..index - 1]
                    p_rn[parent_path].children << p_rn[path]
                    p_rn[path].parent = p_rn[parent_path]
                  end
                end
              end
            end
          end
        end

        # Log tree
        # fn_log_rnode = lambda { |rnode, depth = 0|
        #   pad = "".rjust(depth, " ")
        #   puts "#{pad}#{rnode.entity.name} [#{rnode.entity_pos}] #{" (Rename: #{rnode.name})" if rnode.is_a?(RNodePart)}"
        #   rnode.children.each do |child_rnode|
        #     fn_log_rnode.call(child_rnode, depth + 1)
        #   end
        # }
        # node_defs.each { |node_def| fn_log_rnode.call(p_rn[node_def.path]) }

        # Flatten the tree by definition
        d_n_rprns = {}  # Definition => Name => RPath, RNode
        fn_populate_drn = lambda { |path, rnode|
          if rnode.is_a?(RNodePart)
            d_n_rprns[rnode.entity.definition] = {} unless d_n_rprns.has_key?(rnode.entity.definition)
            d_n_rprns[rnode.entity.definition][rnode.name] = [] unless d_n_rprns[rnode.entity.definition].has_key?(rnode.name)
            d_n_rprns[rnode.entity.definition][rnode.name] << [ path, rnode ]
          end
          rnode.children.each do |child_rnode|
            fn_populate_drn.call(path + [ rnode ], child_rnode)
          end
        }
        node_defs.each { |node_def| fn_populate_drn.call([], p_rn[node_def.path]) }

        # Log flattened tree
        # d_n_rprns.each do |definition, n_rprns|
        #   puts "Definition: #{definition.name}"
        #   n_rprns.each do |name, rprns|
        #     puts "  Name: #{name}"
        #     rprns.each do |rpath, rnode|
        #       puts "   #{rnode.entity.name} [#{rnode.entity_pos}] #{" (Rename: #{rnode.name})" if rnode.is_a?(RNodePart)} #{rpath.map { |rnode| rnode.entity.name }.join('.')}"
        #     end
        #   end
        # end

        # Start a model modification operation
        model.start_operation('OCL Outliner Deep Rename', true, false, false)


        # Make unique and rename definitions
        d_n_rprns.each do |definition, n_rprns|
          n_rprns.each do |name, rprns|

            rpaths, rnodes = rprns.transpose

            next if name == definition.name || name.empty?  # No need to rename

            # Make unique the path if necessary
            rpaths
            .flatten
            .uniq
            .group_by { |rnode| rnode.entity.definition }
            .each do |definition, rnodes|
              next if rnodes.size == rnodes.first.entity.definition.count_used_instances
              new_entity = rnodes.first.entity.make_unique
              new_definition = new_entity.definition
              rnodes.each_with_index do |rnode, index|
                if index == 0
                  rnode.entity = new_entity
                else
                  rnode.entity.definition = new_definition
                end
                rnode.children.each do |child_rnode|
                  child_rnode.entity = new_definition.entities[child_rnode.entity_pos]
                end
              end
            end

            # Make unique part nodes
            new_entity = rnodes.first.entity.make_unique
            new_definition = new_entity.definition
            rnodes.each_with_index do |rnode, index|
              if index == 0
                rnode.entity = new_entity
              else
                rnode.entity.definition = new_definition
              end
              rnode.children.each do |child_rnode|
                child_rnode.entity = new_definition.entities[child_rnode.entity_pos]
              end
            end

            # Rename the new definition
            new_definition.name = name

          end

          # Clean up old definition if no longer used
          model.definitions.remove(definition) if definition.count_used_instances == 0

        end


        # Commit model modification operation
        model.commit_operation

      end

      response = { :success => true }
      response[:preview] = preview.sort_by { |old, new| [ new.nil? || new.empty? ? 1 : 0, old ] } unless preview.empty?
      response
    end

    # -----

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

    # -----

    class RNode

      attr_reader :children,
                  :entity_pos
      attr_accessor :parent,
                    :entity

      def initialize(entity)
        @entity = entity
        @entity_pos = entity.parent.entities.to_a.index(entity)

        @parent = nil
        @children = []

      end

    end

    class RNodePart < RNode

      attr_reader :name

      def initialize(entity, name)
        super(entity)
        @name = name
      end

    end

  end

end