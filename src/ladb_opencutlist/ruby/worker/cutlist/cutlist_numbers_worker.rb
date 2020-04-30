module Ladb::OpenCutList

  class CutlistNumbersWorker

    def initialize(settings, cutlist, reset)
      @group_id = settings['group_id']

      @cutlist = cutlist
      @reset = reset

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      definitions = model.definitions

      @cutlist.groups.each { |group|

        if @group_id && group.id != @group_id
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

    end

    # -----

    private

    def _apply_on_part(definitions, part, reset)
      definition = definitions[part.definition_id]
      if definition

        definition_attributes = DefinitionAttributes.new(definition)
        definition_attributes.number = reset ? nil : part.number
        definition_attributes.write_to_attributes

      end
    end

  end

end