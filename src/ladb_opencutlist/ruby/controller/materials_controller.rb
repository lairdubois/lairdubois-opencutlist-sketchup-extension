module Ladb::OpenCutList

  require_relative 'controller'
  require_relative '../model/attributes/material_attributes'

  class MaterialsController < Controller

    def initialize()
      super('materials')
    end

    def setup_commands()

      # Setup opencutlist dialog actions
      Plugin.instance.register_command("materials_list") do |settings|
        list_command(settings)
      end
      Plugin.instance.register_command("materials_create") do |material_data|
        create_command(material_data)
      end
      Plugin.instance.register_command("materials_update") do |material_data|
        update_command(material_data)
      end
      Plugin.instance.register_command("materials_remove") do |material_data|
        remove_command(material_data)
      end
      Plugin.instance.register_command("materials_import_from_skm") do ||
        import_from_skm_command
      end
      Plugin.instance.register_command("materials_export_to_skm") do |material_data|
        export_to_skm_command(material_data)
      end
      Plugin.instance.register_command("materials_get_attributes_command") do |material_data|
        get_attributes_command(material_data)
      end
      Plugin.instance.register_command("materials_get_texture_command") do |material_data|
        get_texture_command(material_data)
      end
      Plugin.instance.register_command("materials_add_std_dimension_command") do |settings|
        add_std_dimension_command(settings)
      end
      Plugin.instance.register_command("materials_set_current_command") do |settings|
        set_current_command(settings)
      end
      Plugin.instance.register_command("materials_purge_unused") do ||
        purge_unused_command
      end

    end

    def setup_event_callbacks

      Plugin.instance.add_event_callback([
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
      worker = MaterialsListWorker.new(settings)

      # Run !
      worker.run
    end

    def create_command(material_data)
      require_relative '../worker/materials/materials_create_worker'

      # Setup worker
      worker = MaterialsCreateWorker.new(material_data)

      # Run !
      worker.run
    end

    def update_command(material_data)
      require_relative '../worker/materials/materials_update_worker'

      # Setup worker
      worker = MaterialsUpdateWorker.new(material_data)

      # Run !
      worker.run
    end

    def remove_command(material_data)
      require_relative '../worker/materials/materials_remove_worker'

      # Setup worker
      worker = MaterialsRemoveWorker.new(material_data)

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
      worker = MaterialsExportToSkmWorker.new(material_data)

      # Run !
      worker.run
    end

    def get_attributes_command(material_data)
      require_relative '../worker/materials/materials_get_attributes_worker'

      # Setup worker
      worker = MaterialsGetAttributeWorker.new(material_data)

      # Run !
      worker.run
    end

    def get_texture_command(material_data)
      require_relative '../worker/materials/materials_get_texture_worker'

      # Setup worker
      worker = MaterialsGetTextureWorker.new(material_data)

      # Run !
      worker.run
    end

    def add_std_dimension_command(settings) # Waiting settings = { :material_name => MATERIAL_NAME, :std_dimension => STD_DIMENSION }
      require_relative '../worker/materials/materials_add_std_dimension_worker'

      # Setup worker
      worker = MaterialsAddStdDimensionWorker.new(settings)

      # Run !
      worker.run
    end

    def set_current_command(settings)
      require_relative '../worker/materials/materials_set_current_worker'

      # Setup worker
      worker = MaterialsSetCurrentWorker.new(settings)

      # Run !
      worker.run
    end

    def purge_unused_command()
      require_relative '../worker/materials/materials_purge_unused_worker'

      # Setup worker
      worker = MaterialsPurgeUnusedWorker.new

      # Run !
      worker.run
    end

  end

end