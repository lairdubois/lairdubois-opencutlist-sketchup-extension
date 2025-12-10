module Ladb::OpenCutList

  class OutlinerDeepMakeUniqueWorker

    def initialize(outliner_def,

                   id:

    )

      @outliner_def = outliner_def

      @id = id

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

      begin

        node_defs = node_def.get_valid_unlocked_selection_siblings

        # Flatten the tree by definition
        d_rps = {}  # Definition => RPaths
        fn_populate_drn = lambda { |rpath, node_def|
          rnode = RNode.new(node_def.entity)
          rnode.parent = rpath.last
          rnode.parent.children << rnode unless rnode.parent.nil?
          rpath = rpath + [ rnode ]
          if node_def.children.empty? # Keep only leaf nodes
            d_rps[node_def.entity.definition] ||= []
            d_rps[node_def.entity.definition] << rpath
          else
            node_def.children.each do |child_node_def|
              fn_populate_drn.call(rpath, child_node_def)
            end
          end
        }
        node_defs.each { |node_def| fn_populate_drn.call([], node_def) }

        # Log flattened tree
        # d_rprns.each do |definition, rpaths|
        #   puts "Definition: #{definition.name}"
        #   rpaths.each do |rpath|
        #     rnode = rpath.last
        #     puts "  #{rnode.entity.name} [#{rnode.entity_pos}] #{rpath.map { |rnode| rnode.entity.name }.join('.')}"
        #   end
        # end

        # Start a model modification operation
        model.start_operation('OCL Outliner Deep Make Unique', true, false, false)


        d_rps.each do |definition, rpaths|

          # Make unique the path if necessary
          rpaths
          .flatten
          .uniq
          .group_by { |rnode| rnode.entity.definition }
          .each do |definition, rnodes|
            next if rnodes.size == rnodes.first.entity.definition.count_used_instances
            if definition.group?
              rnodes.each do |rnode|
                rnode.entity = rnode.entity.make_unique
                new_definition = rnode.entity.definition
                rnode.children.each do |child_rnode|
                  child_rnode.entity = new_definition.entities[child_rnode.entity_pos]
                end
              end
            else
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
          end

        end


        # Commit model modification operation
        model.commit_operation

      rescue => e
        PLUGIN.dump_exception(e)
        return { :errors => [[ 'core.error.exception', { :error => e.message } ]] }
      end

      { :success => true }
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

  end

end