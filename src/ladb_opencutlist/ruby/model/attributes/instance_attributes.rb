module Ladb::OpenCutList

  class InstanceAttributes

    attr_accessor :outliner_expanded
    attr_reader :instance

    def initialize(instance)
      @instance = instance
      read_from_attributes
    end

    # -----



    # -----

    def read_from_attributes
      if @instance
        @outliner_expanded = Plugin.instance.get_attribute(@instance, 'outliner.expanded', false)
      end
    end

    def write_to_attributes
      if @instance
        @instance.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'outliner.expanded', @outliner_expanded)
      end
    end

  end

end
