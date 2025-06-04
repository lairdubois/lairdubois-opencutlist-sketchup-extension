module Ladb::OpenCutList

  require_relative 'controller'
  require_relative '../model/attributes/material_attributes'
  require_relative '../model/attributes/definition_attributes'
  require_relative '../observer/app_observer'
  require_relative '../observer/selection_observer'
  require_relative '../observer/materials_observer'
  require_relative '../observer/model_observer'
  require_relative '../lib/fiddle/packy/packy'

  Packy = Fiddle::Packy

  class CutlistController < Controller

    def initialize()
      super('cutlist')
    end

    def setup_commands

      # Setup opencutlist dialog actions
      PLUGIN.register_command("cutlist_generate") do |settings|
        generate_command(settings)
      end

      PLUGIN.register_command("cutlist_export") do |settings|
        export_command(settings)
      end

      PLUGIN.register_command("cutlist_estimate_start") do |settings|
        estimate_start_command(settings)
      end

      PLUGIN.register_command("cutlist_estimate_advance") do |settings|
        estimate_advance_command
      end

      PLUGIN.register_command("cutlist_estimate_next") do |settings|
        estimate_next_command
      end

      PLUGIN.register_command("cutlist_estimate_cancel") do |settings|
        estimate_cancel_command
      end

      PLUGIN.register_command("cutlist_numbers_save") do |settings|
        numbers_command(settings, false)
      end

      PLUGIN.register_command("cutlist_numbers_reset") do |settings|
        numbers_command(settings, true)
      end

      PLUGIN.register_command("cutlist_highlight_parts") do |settings|
        highlight_parts_command(settings)
      end

      PLUGIN.register_command("cutlist_layout_parts") do |settings|
        layout_parts_command(settings)
      end

      PLUGIN.register_command("cutlist_layout_to_layout") do |settings|
        layout_to_layout_command(settings)
      end

      PLUGIN.register_command("cutlist_part_get_thumbnail") do |part_data|
        part_get_thumbnail_command(part_data)
      end

      PLUGIN.register_command("cutlist_part_update") do |settings|
        part_update_command(settings)
      end

      PLUGIN.register_command("cutlist_write_parts") do |settings|
        write_parts_command(settings)
      end

      PLUGIN.register_command("cutlist_group_cuttingdiagram1d_start") do |settings|
        group_cuttingdiagram1d_start_command(settings)
      end

      PLUGIN.register_command("cutlist_group_cuttingdiagram1d_advance") do
        group_cuttingdiagram1d_advance_command
      end

      PLUGIN.register_command("cutlist_cuttingdiagram1d_write") do |settings|
        cuttingdiagram1d_write_command(settings)
      end

      PLUGIN.register_command("cutlist_group_cuttingdiagram2d_start") do |settings|
        group_cuttingdiagram2d_start_command(settings)
      end

      PLUGIN.register_command("cutlist_group_cuttingdiagram2d_advance") do
        group_cuttingdiagram2d_advance_command
      end

      PLUGIN.register_command("cutlist_cuttingdiagram2d_write") do |settings|
        cuttingdiagram2d_write_command(settings)
      end

      PLUGIN.register_command("cutlist_labels") do |settings|
        labels_command(settings)
      end

      PLUGIN.register_command("cutlist_reset_prices") do
        reset_prices_command
      end


      PLUGIN.register_command("cutlist_group_packing_start") do |settings|
        group_packing_start_command(settings)
      end

      PLUGIN.register_command("cutlist_group_packing_advance") do
        group_packing_advance_command
      end

      PLUGIN.register_command("cutlist_group_packing_cancel") do
        group_packing_cancel_command
      end

      PLUGIN.register_command("cutlist_packing_improve") do |settings|
        packing_improve_command(settings)
      end

      PLUGIN.register_command("cutlist_packing_write") do |settings|
        packing_write_command(settings)
      end

    end

    def setup_event_callbacks

      PLUGIN.add_event_callback([
                                   AppObserver::ON_NEW_MODEL,
                                   AppObserver::ON_OPEN_MODEL,
                                   AppObserver::ON_ACTIVATE_MODEL,
                                   SelectionObserver::ON_SELECTION_BULK_CHANGE,
                                   SelectionObserver::ON_SELECTION_CLEARED,
                                   MaterialsObserver::ON_MATERIAL_CHANGE,
                                   MaterialsObserver::ON_MATERIAL_REMOVE,
                                   ModelObserver::ON_DRAWING_CHANGE,
                               ]) do |params|

        # Invalidate Cutlist if it exists
        @cutlist.invalidate if @cutlist

      end

      PLUGIN.add_event_callback([
                                  AppObserver::ON_QUIT,
                                  'on_tabs_dialog_close'
                                ]) do |params|

        # Cancel all Packy runs
        Packy.optimize_cancel_all

      end
    end

    private

    # -- Commands --

    def generate_command(settings)
      require_relative '../worker/cutlist/cutlist_generate_worker'

      # Invalidate Cutlist if it exists
      @cutlist.invalidate if @cutlist

      # Setup worker
      worker = CutlistGenerateWorker.new(**settings)

      # Run !
      @cutlist = worker.run

      @cutlist.to_hash
    end

    def export_command(settings)
      require_relative '../worker/cutlist/cutlist_export_worker'

      # Setup worker
      worker = CutlistExportWorker.new(@cutlist, **settings)

      # Run !
      worker.run
    end

    def estimate_start_command(settings)
      require_relative '../worker/cutlist/cutlist_estimate_worker'

      # Setup worker
      @estimate_worker = CutlistEstimateWorker.new(@cutlist, **settings)

      # Run !
      @estimate_worker.run
    end

    def estimate_advance_command
      return { :errors => [ 'default.error' ] } unless @estimate_worker

      # Run !
      @estimate_worker.run(:advance)
    end

    def estimate_next_command
      return { :errors => [ 'default.error' ] } unless @estimate_worker

      # Run !
      @estimate_worker.run(:next)
    end

    def estimate_cancel_command
      return { :errors => [ 'default.error' ] } unless @estimate_worker

      # Run !
      @estimate_worker.run(:cancel)
    end

    def numbers_command(settings, reset)
      require_relative '../worker/cutlist/cutlist_numbers_worker'

      # Setup worker
      worker = CutlistNumbersWorker.new(@cutlist, **(settings.merge({ :reset => reset })))

      # Run !
      worker.run
    end

    def highlight_parts_command(settings)
      require_relative '../worker/cutlist/cutlist_highlight_parts_worker'

      # Setup worker
      worker = CutlistHighlightPartsWorker.new(@cutlist, **settings)

      # Run !
      worker.run
    end

    def layout_parts_command(settings)
      require_relative '../worker/cutlist/cutlist_layout_parts_worker'

      # Setup worker
      worker = CutlistLayoutPartsWorker.new(@cutlist, **settings)

      # Run !
      worker.run
    end

    def layout_to_layout_command(settings)
      require_relative '../worker/cutlist/cutlist_layout_to_layout_worker'

      # Setup worker
      worker = CutlistLayoutToLayoutWorker.new(@cutlist, **settings)

      # Run !
      worker.run
    end

    def part_get_thumbnail_command(part_data)
      require_relative '../worker/cutlist/cutlist_get_thumbnail_worker'

      # Setup worker
      worker = CutlistGetThumbnailWorker.new(@cutlist, **part_data)

      # Run !
      worker.run
    end

    def part_update_command(settings)
      require_relative '../worker/cutlist/cutlist_part_update_worker'

      # Setup worker
      worker = CutlistPartUpdateWorker.new(@cutlist, **settings)

      # Run !
      worker.run
    end

    def write_parts_command(settings)
      require_relative '../worker/cutlist/cutlist_write_parts_worker'

      # Setup worker
      worker = CutlistWritePartsWorker.new(@cutlist, **settings)

      # Run !
      worker.run
    end

    def group_cuttingdiagram1d_start_command(settings)
      require_relative '../worker/cutlist/cutlist_cuttingdiagram1d_worker'

      # Setup worker
      @cuttingdiagram1d_worker = CutlistCuttingdiagram1dWorker.new(@cutlist, **settings)

      # Run !
      cuttingdiagram1d = @cuttingdiagram1d_worker.run(true)

      cuttingdiagram1d.to_hash
    end

    def group_cuttingdiagram1d_advance_command
      return { :errors => [ 'default.error' ] } unless @cuttingdiagram1d_worker

      # Run !
      cuttingdiagram1d = @cuttingdiagram1d_worker.run(true)

      if cuttingdiagram1d.bars.length > 0
        @cuttingdiagram1d_worker = nil
        @cuttingdiagram1d = cuttingdiagram1d
      end

      cuttingdiagram1d.to_hash
    end

    def cuttingdiagram1d_write_command(settings)
      require_relative '../worker/cutlist/cutlist_cuttingdiagram1d_write_worker'

      # Setup worker
      worker = CutlistCuttingdiagram1dWriteWorker.new(@cutlist, @cuttingdiagram1d, **settings)

      # Run !
      worker.run
    end

    def group_cuttingdiagram2d_start_command(settings)
      require_relative '../worker/cutlist/cutlist_cuttingdiagram2d_worker'

      # Setup worker
      @cuttingdiagram2d_worker = CutlistCuttingdiagram2dWorker.new(@cutlist, **settings)

      # Run !
      cuttingdiagram2d = @cuttingdiagram2d_worker.run(true)

      cuttingdiagram2d.to_hash
    end

    def group_cuttingdiagram2d_advance_command
      return { :errors => [ 'default.error' ] } unless @cuttingdiagram2d_worker

      # Run !
      cuttingdiagram2d = @cuttingdiagram2d_worker.run(true)

      if cuttingdiagram2d.sheets.length > 0
        @cuttingdiagram2d_worker = nil
        @cuttingdiagram2d = cuttingdiagram2d
      end

      cuttingdiagram2d.to_hash
    end

    def cuttingdiagram2d_write_command(settings)
      require_relative '../worker/cutlist/cutlist_cuttingdiagram2d_write_worker'

      # Setup worker
      worker = CutlistCuttingdiagram2dWriteWorker.new(@cutlist, @cuttingdiagram2d, **settings)

      # Run !
      worker.run
    end

    def labels_command(settings)
      require_relative '../worker/cutlist/cutlist_labels_worker'

      # Setup worker
      worker = CutlistLabelsWorker.new(@cutlist, **settings)

      # Run !
      worker.run
    end

    def reset_prices_command
      require_relative '../worker/cutlist/cutlist_reset_prices_worker'

      # Setup worker
      worker = CutlistResetPricesWorker.new

      # Run !
      worker.run
    end


    def group_packing_start_command(settings)
      require_relative '../worker/cutlist/cutlist_packing_worker'

      # Setup worker
      @packing_worker = CutlistPackingWorker.new(@cutlist, **settings)

      # Run !
      packing = @packing_worker.run(:start)

      @packing = packing unless packing.running

      packing.to_hash
    end

    def group_packing_advance_command
      return { :errors => [ 'default.error' ] } unless @packing_worker

      # Run !
      packing = @packing_worker.run(:advance)

      @packing = packing unless packing.running

      packing.to_hash
    end

    def group_packing_cancel_command
      return { :errors => [ 'default.error' ] } unless @packing_worker

      # Run !
      packing = @packing_worker.run(:cancel)

      @packing = packing unless packing.running

      packing.to_hash
    end

    def packing_improve_command(settings)
      require_relative '../worker/cutlist/cutlist_packing_improve_worker'

      # Setup worker
      worker = CutlistPackingImproveWorker.new(@cutlist, @packing, **settings)

      # Run !
      worker.run
    end

    def packing_write_command(settings)
      require_relative '../worker/cutlist/cutlist_packing_write_worker'

      # Setup worker
      worker = CutlistPackingWriteWorker.new(@cutlist, @packing, **settings)

      # Run !
      worker.run
    end

  end

end