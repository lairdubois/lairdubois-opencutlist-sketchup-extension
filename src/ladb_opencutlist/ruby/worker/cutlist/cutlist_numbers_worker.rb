module Ladb::OpenCutList

  class CutlistNumbersWorker

    def initialize(options)
      @options = options
    end

    # -----

    def run(cutlist, reset)
      return unless cutlist

      model = Sketchup.active_model
      definitions = model ? model.definitions : []

      cutlist.groups.each { |group|

        if @options.group_id && group.id != @options.group_id
          next
        end

        group.parts.each { |part|

          if part.is_a?(FolderPart)
            part.children.each { |child_part|
              _apply_on_part(definitions, child_part, reset)
            }
          else
            _apply_on_part(definitions, part, reset)
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