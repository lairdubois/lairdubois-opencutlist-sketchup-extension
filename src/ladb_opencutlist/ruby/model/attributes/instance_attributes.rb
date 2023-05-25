module Ladb::OpenCutList

  class InstanceAttributes

    attr_accessor :outliner_expended
    attr_reader :instance

    def initialize(instance)
      @instance = instance
      read_from_attributes
    end

    # -----



    # -----

    def read_from_attributes()
      if @instance
        @outliner_expended = Plugin.instance.get_attribute(@instance, 'outliner_expended', false)
      end
    end

    def write_to_attributes
      if @instance
        @instance.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'outliner_expended', @outliner_expended)
      end
    end

  end

end
