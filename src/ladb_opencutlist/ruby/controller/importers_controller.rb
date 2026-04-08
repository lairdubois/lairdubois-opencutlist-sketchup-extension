module Ladb::OpenCutList

  class ImportersController < Controller

    def initialize(format = '')
      super([ 'importers', format ].compact.join('_'))
    end

  end

  class ImportersBxf2Controller < ImportersController

    def initialize()
      super('bxf2')
    end

    def setup_commands

      # Setup opencutlist dialog actions
      PLUGIN.register_command("importers_bxf2_open") do |settings|
        bxf2_open_command(settings)
      end
      PLUGIN.register_command("importers_bxf2_load") do |settings|
        bxf2_load_command(settings)
      end
      PLUGIN.register_command("importers_bxf2_import") do |settings|
        bxf2_import_command(settings)
      end

    end

    private

    # -- Commands --

    def bxf2_open_command(settings)
      require_relative '../worker/importers/bxf2/importers_bxf2_open_worker'

      # Setup worker
      worker = ImportersBxf2OpenWorker.new(**settings)

      # Run !
      worker.run
    end

    def bxf2_load_command(settings)
      require_relative '../worker/importers/bxf2/importers_bxf2_load_worker'

      # Setup worker
      worker = ImportersBxf2LoadWorker.new(**settings)

      # Run !
      response, @bxf_model = worker.run

      response
    end

    def bxf2_import_command(settings)
      require_relative '../worker/importers/bxf2/importers_bxf2_import_worker'

      # Setup worker
      worker = ImportersBxf2ImportWorker.new(@bxf_model, **settings)

      # Run !
      worker.run
    end

  end

  class ImportersCsvController < ImportersController

    def initialize()
      super('csv')
    end

    def setup_commands

      # Setup opencutlist dialog actions
      PLUGIN.register_command("importers_csv_open") do |settings|
        csv_open_command(settings)
      end
      PLUGIN.register_command("importers_csv_load") do |settings|
        csv_load_command(settings)
      end
      PLUGIN.register_command("importers_csv_import") do |settings|
        csv_import_command(settings)
      end

    end

    private

    # -- Commands --

    def csv_open_command(settings)
      require_relative '../worker/importers/csv/importers_csv_open_worker'

      # Setup worker
      worker = ImportersCsvOpenWorker.new(**settings)

      # Run !
      worker.run
    end

    def csv_load_command(settings)
      require_relative '../worker/importers/csv/importers_csv_load_worker'

      # Setup worker
      worker = ImportersCsvLoadWorker.new(**settings)

      # Run !
      response = worker.run

      # Keep generated parts
      @parts = response[:parts]

      response
    end

    def csv_import_command(settings)
      require_relative '../worker/importers/csv/importers_csv_import_worker'

      # Setup worker
      worker = ImportersCsvImportWorker.new(@parts, **settings)

      # Run !
      worker.run
    end

  end

end