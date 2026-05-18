module Ladb::OpenCutList

  class InstanceAttributes

    attr_accessor :is_grain_group,
                  :is_grain_item

    def initialize(instance)
      @instance = instance
      read_from_attributes
    end

    # -----

    def read_from_attributes
      if @instance
        @is_grain_group = PLUGIN.get_attribute(@instance, 'is_grain_group', false)
        @is_grain_item = PLUGIN.get_attribute(@instance, 'is_grain_item', false)
      else
        @is_grain_group = false
        @is_grain_item = false
      end
    end

    def write_to_attributes
      if @instance
        @instance.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'is_grain_group', @is_grain_group)
        @instance.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'is_grain_item', @is_grain_item)
      end
    end

  end

end
