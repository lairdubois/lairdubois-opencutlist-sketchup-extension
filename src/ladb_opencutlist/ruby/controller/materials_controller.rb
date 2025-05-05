module Ladb::OpenCutList

  require_relative 'controller'
  require_relative '../model/attributes/material_attributes'

  class MaterialsController < Controller

    def initialize()
      super('materials')
    end

    def setup_commands

      # Setup opencutlist dialog actions
      PLUGIN.register_command("materials_list") do |settings|
        list_command(settings)
      end
      PLUGIN.register_command("materials_create") do |material_data|
        create_command(material_data)
      end
      PLUGIN.register_command("materials_update") do |material_data|
        update_command(material_data)
      end
      PLUGIN.register_command("materials_duplicate") do |material_data|
        duplicate_command(material_data)
      end
      PLUGIN.register_command("materials_delete") do |material_data|
        delete_command(material_data)
      end
      PLUGIN.register_command("materials_import_from_skm") do ||
        import_from_skm_command
      end
      PLUGIN.register_command("materials_export_to_skm") do |material_data|
        export_to_skm_command(material_data)
      end
      PLUGIN.register_command("materials_get_attributes_command") do |material_data|
        get_attributes_command(material_data)
      end
      PLUGIN.register_command("materials_get_texture_command") do |material_data|
        get_texture_command(material_data)
      end
      PLUGIN.register_command("materials_load_texture_command") do ||
        load_texture_command
      end
      PLUGIN.register_command("materials_export_texture_command") do |settings|
        export_texture_command(settings)
      end
      PLUGIN.register_command("materials_add_std_dimension_command") do |settings|
        add_std_dimension_command(settings)
      end
      PLUGIN.register_command("materials_smart_paint_command") do |settings|
        smart_paint_command(settings)
      end
      PLUGIN.register_command("materials_purge_unused") do ||
        purge_unused_command
      end
      PLUGIN.register_command("materials_reset_prices") do ||
        reset_prices_command
      end

    end

    def setup_event_callbacks

      PLUGIN.add_event_callback([
                                             AppObserver::ON_NEW_MODEL,
                                             AppObserver::ON_OPEN_MODEL,
                                             AppObserver::ON_ACTIVATE_MODEL,
                                             MaterialsObserver::ON_MATERIAL_ADD,
                                             MaterialsObserver::ON_MATERIAL_CHANGE,
                                             MaterialsObserver::ON_MATERIAL_REMOVE,
                                         ]) do |params|

        # Invalidate Cutlist if exists
        @cutlist.invalidate if @cutlist

      end

    end

    private

    # -- Commands --

    def list_command(settings)
      require_relative '../worker/materials/materials_list_worker'

      # Setup worker
      worker = MaterialsListWorker.new(**settings)

      # Run !
      worker.run
    end

    def create_command(material_data)
      require_relative '../worker/materials/materials_create_worker'

      # Setup worker
      worker = MaterialsCreateWorker.new(**material_data)

      # Run !
      worker.run
    end

    def update_command(material_data)
      require_relative '../worker/materials/materials_update_worker'

      # Setup worker
      worker = MaterialsUpdateWorker.new(**material_data)

      # Run !
      worker.run
    end

    def duplicate_command(material_data)
      require_relative '../worker/materials/materials_duplicate_worker'

      # Setup worker
      worker = MaterialsDuplicateWorker.new(**material_data)

      # Run !
      worker.run
    end

    def delete_command(material_data)
      require_relative '../worker/materials/materials_delete_worker'

      # Setup worker
      worker = MaterialsDeleteWorker.new(**material_data)

      # Run !
      worker.run
    end

    def import_from_skm_command
      require_relative '../worker/materials/materials_import_from_skm_worker'

      # Setup worker
      worker = MaterialsImportFromSkmWorker.new

      # Run !
      worker.run
    end

    def export_to_skm_command(material_data)
      require_relative '../worker/materials/materials_export_to_skm_worker'

      # Setup worker
      worker = MaterialsExportToSkmWorker.new(**material_data)

      # Run !
      worker.run
    end

    def get_attributes_command(material_data)
      require_relative '../worker/materials/materials_get_attributes_worker'

      # Setup worker
      worker = MaterialsGetAttributesWorker.new(**material_data)

      # Run !
      worker.run
    end

    def get_texture_command(material_data)
      require_relative '../worker/materials/materials_get_texture_worker'

      # Setup worker
      worker = MaterialsGetTextureWorker.new(**material_data)

      # Run !
      worker.run
    end

    def load_texture_command
      require_relative '../worker/materials/materials_load_texture_worker'

      # Setup worker
      worker = MaterialsLoadTextureWorker.new

      # Run !
      worker.run
    end

    def export_texture_command(settings)
      require_relative '../worker/materials/materials_export_texture_worker'

      # Setup worker
      worker = MaterialsExportTextureWorker.new(**settings)

      # Run !
      worker.run
    end

    def add_std_dimension_command(settings) # Waiting settings = { :material_name => MATERIAL_NAME, :std_dimension => STD_DIMENSION }
      require_relative '../worker/materials/materials_add_std_dimension_worker'

      # Setup worker
      worker = MaterialsAddStdDimensionWorker.new(**settings)

      # Run !
      worker.run
    end

    def smart_paint_command(settings)
      require_relative '../worker/materials/materials_smart_paint_worker'

      # Setup worker
      worker = MaterialsSmartPaintWorker.new(**settings)

      # Run !
      worker.run
    end

    def purge_unused_command
      require_relative '../worker/materials/materials_purge_unused_worker'

      # Setup worker
      worker = MaterialsPurgeUnusedWorker.new

      # Run !
      worker.run
    end

    def reset_prices_command
      require_relative '../worker/materials/materials_reset_prices_worker'

      # Setup worker
      worker = MaterialsResetPricesWorker.new

      # Run !
      worker.run
    end

  end

end