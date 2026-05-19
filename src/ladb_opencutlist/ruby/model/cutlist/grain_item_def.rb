module Ladb::OpenCutList

  require_relative '../data_container'

  class GrainItemDef < DataContainer

    attr_reader :instance_info,
                :part_def

    def initialize(instance_info, part_def)
      @instance_info = instance_info
      @part_def = part_def
    end

  end

end