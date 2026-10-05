module Ladb::OpenCutList

  require_relative 'controller'
  require_relative '../worker/hardware/hardware_bench_compute_worker'
  require_relative '../worker/hardware/hardware_skp_mesh_worker'
  require_relative '../worker/hardware/hardware_descriptor_save_worker'
  require_relative '../worker/hardware/hardware_descriptor_duplicate_worker'
  require_relative '../worker/hardware/hardware_descriptor_delete_worker'
  require_relative '../worker/hardware/hardware_skp_edit_worker'
  require_relative '../observer/plugin_observer'
  require_relative '../utils/dimension_utils'

  # The hardware editor : a descriptor of the library, seen and checked on a
  # test bench - see HardwareBenchDef.
  class HardwareController < Controller

    # The modal of the editor, and the size it opens at : the bench needs room.
    EDITOR_MODAL_NAME = 'hardware_editor'.freeze
    EDITOR_DIALOG_WIDTH = 1100
    EDITOR_DIALOG_HEIGHT = 760

    # Where the connectors an article can use are browsed from - and their
    # counterpart in the shipped library
    CONNECTORS_LIBRARY_REF = '$LIB/connectors'.freeze

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
      PLUGIN.register_command('hardware_library_list') do |params|
        library_list_command(**params)
      end
      PLUGIN.register_command('hardware_float_to_length') do |params|
        float_to_length_command(params)
      end

      # The editor closed while a part is shaped in SketchUp : the bench leaves
      PLUGIN.add_event_callback(PluginObserver::ON_MODAL_DIALOG_CLOSED) do
        HardwareSkpEditWorker.new(action: 'cancel').run if HardwareSkpEditWorker.editing?
      end

    end

    # Opens the editor on the descriptor of the given ref, or on a new one
    # of the given type - to be written in the given library folder.
    # length_unit : the one of a new descriptor, the model's - see
    # HardwareDescriptorDef "length_unit".
    def self.show_editor(ref: nil, type: nil, dir_ref: nil)
      PLUGIN.show_modal_dialog(EDITOR_MODAL_NAME, { :ref => ref, :type => type, :dir_ref => dir_ref, :length_unit => _model_length_unit }, EDITOR_DIALOG_WIDTH, EDITOR_DIALOG_HEIGHT)
    end

    # The model's length unit, one of LengthExpressionUtils::LENGTH_UNITS.
    def self._model_length_unit
      {
        DimensionUtils::INCHES => 'in',
        DimensionUtils::FEET => 'ft',
        DimensionUtils::YARD => 'yd',
        DimensionUtils::MILLIMETER => 'mm',
        DimensionUtils::CENTIMETER => 'cm',
        DimensionUtils::METER => 'm',
      }[DimensionUtils.length_unit] || 'mm'
    end
    private_class_method :_model_length_unit

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

    # The editor gets the given size and position - smaller and in a corner
    # while a part is shaped in SketchUp. Returns the size and position it had.
    def editor_resize_command(width:, height:, left: nil, top: nil)
      size = PLUGIN.modal_dialog_get_size
      return {} if size.nil?
      position = PLUGIN.modal_dialog_get_position
      PLUGIN.modal_dialog_set_size(width.to_i, height.to_i)
      PLUGIN.modal_dialog_set_position(left.to_i, top.to_i) unless left.nil? || top.nil? || position.nil?  # Only moved if it can be put back
      response = { :width => size[0], :height => size[1] }
      response.merge!({ :left => position[0], :top => position[1] }) unless position.nil?
      response
    end

    # The given inch floats, by key, as lengths in model units - at the
    # OpenCutList precision, without trailing zeros (12,500 mm -> 12,5 mm).
    def float_to_length_command(params)
      lengths = {}
      params.each do |key, f|
        lengths[key] = DimensionUtils.to_ocl_precision_s(f.to_f.to_l)
                                     .sub(/([.,]\d*?)0+(\D*)\z/) { "#{$1}#{$2}" }
                                     .sub(/[.,](\D*)\z/) { $1 }
      end
      lengths
    end

    # The given folder of the connectors library - both libraries' roots when
    # none - : its sub folders and the concrete connectors it holds, each
    # with the "use" a descriptor of the given ref writes to name it.
    def library_list_command(dir_ref: nil, ref: nil)
      roots = [ PLUGIN.bundled_library_ref(CONNECTORS_LIBRARY_REF), CONNECTORS_LIBRARY_REF ]
      fn_root_name = lambda { |r| PLUGIN.get_i18n_string("core.library.#{PLUGIN.library_bundled_ref?(r) ? 'bundled' : 'user'}") }
      unless roots.any? { |root| dir_ref == root || dir_ref.is_a?(String) && dir_ref.start_with?("#{root}/") }
        return {
          :dir_ref => nil,
          :dirs => roots.map { |r| { :ref => r, :name => fn_root_name.call(r) } },
          :files => [],
        }
      end
      root = roots.find { |r| dir_ref == r || dir_ref.start_with?("#{r}/") }
      names = dir_ref == root ? [] : dir_ref[(root.length + 1)..-1].split('/')
      {
        :dir_ref => dir_ref,
        :parent_ref => dir_ref == root ? nil : File.dirname(dir_ref),
        # The folders to it, from the root
        :path => [ { :ref => root, :name => fn_root_name.call(root) } ] + names.each_with_index.map { |name, index| { :ref => ([ root ] + names[0..index]).join('/'), :name => name } },
        :dirs => PLUGIN.list_library_dirs(dir_ref).map { |r| { :ref => r, :name => File.basename(r) } },
        :files => PLUGIN.list_library_files(dir_ref, '.json').map { |r|
          descriptor = HardwareDescriptorDef.load(r)
          next nil if descriptor.nil? || descriptor.type != HardwareDescriptorDef::TYPE_CONNECTOR || descriptor.abstract?
          { :ref => r, :name => descriptor.name, :use => HardwareDescriptorDef.extends_value(r, ref.is_a?(String) ? ref : CONNECTORS_LIBRARY_REF), :valid => descriptor.valid? }
        }.compact,
      }
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
