module Ladb::OpenCutList

  class DefinitionAttributes

    CUMULABLE_NONE = 0
    CUMULABLE_LENGTH = 1
    CUMULABLE_WIDTH = 2

    attr_accessor :number,:cumulable, :orientation_locked_on_axis, :labels
    attr_reader :definition

    def initialize(definition)
      @definition = definition
      @number = nil
      @cumulable = CUMULABLE_NONE
      @orientation_locked_on_axis = false
      @labels = ''
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

    def has_labels(labels)
      (labels - @labels.split(';').map(&:strip)).empty?
    end

    # -----

    def read_from_attributes
      if @definition
        @number = Plugin.instance.get_attribute(@definition, 'number', nil)
        @cumulable = Plugin.instance.get_attribute(@definition, 'cumulable', CUMULABLE_NONE)
        @orientation_locked_on_axis = Plugin.instance.get_attribute(@definition, 'orientation_locked_on_axis', false)
        @labels = Plugin.instance.get_attribute(@definition, 'labels', '')
      end
    end

    def write_to_attributes
      if @definition
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'number', @number)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'cumulable', @cumulable)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', @orientation_locked_on_axis)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'labels', @labels)
      end
    end

  end

end