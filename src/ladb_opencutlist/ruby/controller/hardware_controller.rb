module Ladb::OpenCutList

  require_relative 'controller'
  require_relative '../worker/hardware/hardware_bench_compute_worker'
  require_relative '../worker/hardware/hardware_skp_mesh_worker'
  require_relative '../worker/hardware/hardware_descriptor_save_worker'
  require_relative '../worker/hardware/hardware_descriptor_duplicate_worker'
  require_relative '../worker/hardware/hardware_descriptor_delete_worker'
  require_relative '../worker/hardware/hardware_skp_edit_worker'
  require_relative '../observer/plugin_observer'

  # The hardware editor : a descriptor of the library, seen and checked on a
  # test bench - see HardwareBenchDef.
  class HardwareController < Controller

    # The modal of the editor, and the size it opens at : the bench needs room.
    EDITOR_MODAL_NAME = 'hardware_editor'.freeze
    EDITOR_DIALOG_WIDTH = 1100
    EDITOR_DIALOG_HEIGHT = 760

    def initialize()
      super('hardware')
    end

    def setup_commands

      PLUGIN.register_command('hardware_descriptor_load') do |params|
        descriptor_load_command(**params)
      end
      PLUGIN.register_command('hardware_descriptor_save') do |params|
        descriptor_save_command(**params)
      end
      PLUGIN.register_command('hardware_descriptor_duplicate') do |params|
        descriptor_duplicate_command(**params)
      end
      PLUGIN.register_command('hardware_descriptor_delete') do |params|
        descriptor_delete_command(**params)
      end
      PLUGIN.register_command('hardware_bench_compute') do |params|
        bench_compute_command(**params)
      end
      PLUGIN.register_command('hardware_skp_mesh') do |params|
        skp_mesh_command(**params)
      end
      PLUGIN.register_command('hardware_skp_choose') do |params|
        skp_choose_command
      end
      PLUGIN.register_command('hardware_skp_edit') do |params|
        skp_edit_command(**params)
      end
      PLUGIN.register_command('hardware_editor_resize') do |params|
        editor_resize_command(**params)
      end

      # The editor closed while a part is shaped in SketchUp : the bench leaves
      PLUGIN.add_event_callback(PluginObserver::ON_MODAL_DIALOG_CLOSED) do
        HardwareSkpEditWorker.new(action: 'cancel').run if HardwareSkpEditWorker.editing?
      end

    end

    # Opens the editor on the descriptor of the given ref, or on a new one
    # of the given type - to be written in the given library folder.
    def self.show_editor(ref: nil, type: nil, dir_ref: nil)
      PLUGIN.show_modal_dialog(EDITOR_MODAL_NAME, { :ref => ref, :type => type, :dir_ref => dir_ref }, EDITOR_DIALOG_WIDTH, EDITOR_DIALOG_HEIGHT)
    end

    private

    # -- Commands --

    # The text of the descriptor of the given ref, as written - the editor
    # shows it even if it is invalid.
    def descriptor_load_command(ref:)
      path = PLUGIN.resolve_library_ref(ref)
      return { :errors => [ [ 'core.hardware_editor.error.file_not_found', { :ref => ref } ] ] } unless PLUGIN.library_ref?(ref) && path.is_a?(String) && File.file?(path)
      {
        :ref => ref,
        :text => File.read(path, mode: 'r:UTF-8'),
        :readonly => PLUGIN.library_readonly_ref?(ref),
      }
    rescue SystemCallError => e
      { :errors => [ [ 'core.hardware_editor.error.file_not_readable', { :ref => ref, :error => e.message } ] ] }
    end

    def descriptor_save_command(**params)

      # Setup worker
      worker = HardwareDescriptorSaveWorker.new(**params)

      # Run !
      worker.run

    end

    def descriptor_duplicate_command(**params)

      # Setup worker
      worker = HardwareDescriptorDuplicateWorker.new(**params)

      # Run !
      worker.run

    end

    def descriptor_delete_command(**params)

      # Setup worker
      worker = HardwareDescriptorDeleteWorker.new(**params)

      # Run !
      worker.run

    end

    def bench_compute_command(**params)

      # Setup worker
      worker = HardwareBenchComputeWorker.new(**params)

      # Run !
      worker.run

    end

    def skp_mesh_command(**params)

      # Setup worker
      worker = HardwareSkpMeshWorker.new(**params)

      # Run !
      worker.run

    end

    def skp_edit_command(**params)

      # Setup worker
      worker = HardwareSkpEditWorker.new(**params)

      # Run !
      worker.run

    end

    # The editor gets the given size - smaller while a part is shaped in
    # SketchUp. Returns the size it had.
    def editor_resize_command(width:, height:)
      size = PLUGIN.resize_modal_dialog(width.to_i, height.to_i)
      size.nil? ? {} : { :width => size[0], :height => size[1] }
    end

    # A SKP file picked by the user - to become a part of the descriptor.
    def skp_choose_command
      path = UI.openpanel(PLUGIN.get_i18n_string('core.hardware_editor.choose_skp'), '', 'SketchUp|*.skp||')
      return {} if path.nil?
      return { :errors => [ [ 'core.hardware_editor.error.skp_is_open_model', { :name => File.basename(path) } ] ] } if HardwareSkpMeshWorker.open_model?(Sketchup.active_model, path)
      { :path => path.gsub('\\', '/'), :name => File.basename(path) }
    end

  end

end
