module Ladb::OpenCutList

  require_relative '../../model/cutlist/part'

  class CutlistNumbersWorker

    def initialize(cutlist,

                   group_id: nil,
                   reset: false

    )

      @cutlist = cutlist

      @group_id = group_id
      @reset = reset

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Start a model modification operation
      model.start_operation('OCL Numbers', true, false, true)

      definitions = model.definitions

      @cutlist.groups.each { |group|

        if @group_id && group.id != @group_id
          next
        end

        # Ignore Edge groups
        if group.material_type == MaterialAttributes::TYPE_EDGE
          next
        end

        group.parts.each { |part|

          if part.is_a?(FolderPart)
            part.children.each { |child_part|
              _apply_on_part(definitions, child_part, @reset)
            }
          else
            _apply_on_part(definitions, part, @reset)
          end

        }
      }

      # Commit model modification operation
      model.commit_operation

    end

    # -----

    private

    def _apply_on_part(definitions, part, reset)
      definition = definitions[part.definition_id]
      if definition

        # Update definition attributes
        definition_attributes = DefinitionAttributes.new(definition)
        definition_attributes.store_number(part.id, reset ? nil : part.number)
        definition_attributes.write_to_attributes

      end
    end

  end

end