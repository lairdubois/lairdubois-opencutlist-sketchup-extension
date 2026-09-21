module Ladb::OpenCutList

  require_relative '../data_container'

  # Result of CommonStretchApplyWorker.
  class StretchApplyResultDef < DataContainer

    attr_accessor :selection_path,        # The selection path, possibly remapped to made unique copies
                  :selection_instances    # The stretched instances, possibly remapped to made unique copies

    attr_reader :errors                   # Array of i18n tuples [ key, vars ] ; empty on success

    def initialize(selection_path = nil, selection_instances = nil)
      @selection_path = selection_path
      @selection_instances = selection_instances
      @errors = []
    end

    def success?
      @errors.empty?
    end

  end

end
