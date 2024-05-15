module Ladb::OpenCutList

  class ImporterController < Controller

    def initialize()
      super('importer')
    end

    def setup_commands

      # Setup opencutlist dialog actions
      PLUGIN.register_command("importer_open") do
        open_command
      end
      PLUGIN.register_command("importer_load") do |settings|
        load_command(settings)
      end
      PLUGIN.register_command("importer_import") do |settings|
        import_command(settings)
      end

    end

    private

    # -- Commands --

    def open_command
      require_relative '../worker/importer/importer_open_worker'

      # Setup worker
      worker = ImporterOpenWorker.new

      # Run !
      worker.run
    end

    def load_command(settings)
      require_relative '../worker/importer/importer_load_worker'

      # Setup worker
      worker = ImporterLoadWorker.new(**settings)

      # Run !
      response = worker.run

      # Keep generated parts
      @parts = response[:parts]

      response
    end

    def import_command(settings)
      require_relative '../worker/importer/importer_import_worker'

      # Setup worker
      worker = ImporterImportWorker.new(@parts, **settings)

      # Run !
      worker.run
    end

  end

end