module Ladb::OpenCutList

  require 'json'

  class DefinitionAttributes

    CUMULABLE_NONE = 0
    CUMULABLE_LENGTH = 1
    CUMULABLE_WIDTH = 2

    attr_accessor :cumulable, :orientation_locked_on_axis, :labels
    attr_reader :definition

    def initialize(definition)
      @definition = definition
      @numbers = {}
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

    def self.valid_labels(labels)
      if labels
        if labels.is_a? Array and !labels.empty?
          return labels.map(&:strip).reject { |label| label.empty? }.uniq.sort
        elsif labels.is_a? String
          return labels.split(';').map(&:strip).reject { |label| label.empty? }.uniq.sort
        end
      end
      return []
    end

    # -----

    def store_number(part_id, number)
      if number.nil?
        @numbers.delete(part_id)
      else
        @numbers.store(part_id, number)
      end
    end

    def fetch_number(part_id)
      @numbers.fetch(part_id, nil)
    end

    # -----

    def has_labels(labels)
      (labels - @labels).empty?
    end

    # -----

    def read_from_attributes
      if @definition
        @numbers = JSON.parse(Plugin.instance.get_attribute(@definition, 'numbers', '{}'))
        @cumulable = Plugin.instance.get_attribute(@definition, 'cumulable', CUMULABLE_NONE)
        @orientation_locked_on_axis = Plugin.instance.get_attribute(@definition, 'orientation_locked_on_axis', false)
        @labels = DefinitionAttributes.valid_labels(Plugin.instance.get_attribute(@definition, 'labels', []))
      end
    end

    def write_to_attributes
      if @definition
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'numbers', @numbers.to_json)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'cumulable', @cumulable)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', @orientation_locked_on_axis)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'labels', @labels)
      end
    end

  end

end