module Ladb
  module Toolbox
    class DefinitionAttributes

      ATTRIBUTE_DICTIONARY = 'ladb_toolbox'

      CUMULABLE_NONE = 0
      CUMULABLE_LENGTH = 1
      CUMULABLE_WIDTH = 2

      attr_accessor :number,:cumulable, :orientation_locked_on_axis
      attr_reader :definition

      def initialize(definition)
        @definition = definition
        @number = nil
        @cumulable = CUMULABLE_NONE
        @orientation_locked_on_axis = false
        read_from_attributes
      end

      # -----

      def self.valid_cumulable(cumulable)
        if cumulable
          i_cumulable = cumulable.to_i
          if i_cumulable < CUMULABLE_NONE or i_cumulable > CUMULABLE_WIDTH
            CUMULABLE_NONE
          end
          i_cumulable
        else
          CUMULABLE_NONE
        end
      end

      # -----

      def read_from_attributes
        if @definition
          @number = @definition.get_attribute(ATTRIBUTE_DICTIONARY, 'number', nil)
          @cumulable = @definition.get_attribute(ATTRIBUTE_DICTIONARY, 'cumulable', CUMULABLE_NONE)
          @orientation_locked_on_axis = @definition.get_attribute(ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', false)
        end
      end

      def write_to_attributes
        if @definition
          @definition.set_attribute(ATTRIBUTE_DICTIONARY, 'number', @number)
          @definition.set_attribute(ATTRIBUTE_DICTIONARY, 'cumulable', @cumulable)
          @definition.set_attribute(ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', @orientation_locked_on_axis)
        end
      end

    end
  end
end