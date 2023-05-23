module Ladb::OpenCutList

  require_relative 'controller'
  require_relative '../model/attributes/material_attributes'

  class OutlinerController < Controller

    def initialize()
      super('materials')
    end

    def setup_commands()

      # Setup opencutlist dialog actions
      Plugin.instance.register_command("outliner_list") do |settings|
        list_command(settings)
      end

    end

    def setup_event_callbacks

      Plugin.instance.add_event_callback([
                                             AppObserver::ON_NEW_MODEL,
                                             AppObserver::ON_OPEN_MODEL,
                                             AppObserver::ON_ACTIVATE_MODEL,
                                         ]) do |params|

        # Invalidate Cutlist if exists
        @cutlist.invalidate if @cutlist

      end

    end

    private

    # -- Commands --

    def list_command(settings)
      require_relative '../worker/outliner/outliner_list_worker'

      # Setup worker
      worker = OutlinerListWorker.new(settings)

      # Run !
      worker.run
    end

  end

end