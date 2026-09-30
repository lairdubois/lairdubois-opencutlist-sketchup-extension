module Ladb::OpenCutList

  require 'fileutils'
  require_relative '../../model/hardware/hardware_descriptor_def'

  # Copies a descriptor of the OCL library into the user's one, at the same
  # place - '$OCL/hinges/blum/x.json' -> '$LIB/hinges/blum/x.json' - with its
  # SKP files : its components folder and the shared files its parts name,
  # at the same place too, since a part can't point to another library. Its
  # parent - see "extends" - stays the OCL one : only its ref is rewritten.
  class HardwareDescriptorDuplicateWorker

    def initialize(ref:)
      @ref = ref
    end

    # -----

    def run

      return _error('core.hardware_editor.error.invalid_ref', { :ref => @ref }) unless PLUGIN.library_bundled_ref?(@ref)
      descriptor = HardwareDescriptorDef.load(@ref)
      return _error('core.hardware_editor.error.file_not_found', { :ref => @ref }) if descriptor.nil?

      target_ref = _user_ref(@ref)
      target_path = PLUGIN.resolve_library_ref(target_ref)
      return _error('core.hardware_editor.error.file_exists', { :ref => target_ref }) if File.exist?(target_path)

      # Its SKP files : never over existing ones
      copied = []
      dir_ref = descriptor.components_dir_ref
      unless dir_ref.nil?
        dir = PLUGIN.resolve_library_ref(dir_ref)
        if File.directory?(dir)
          Dir.glob(File.join(dir, '**', '*.skp')).each do |source|
            copied << _copy(source, File.join(PLUGIN.resolve_library_ref(_user_ref(dir_ref)), source[(dir.length + 1)..-1]))
          end
        end
      end
      _shared_files(descriptor.own_data['components']).each do |relative|
        source = File.join(PLUGIN.bundled_library_dir, HardwareDescriptorDef::COMPONENTS_DIR_NAME, relative)
        next unless File.file?(source)
        copied << _copy(source, File.join(PLUGIN.library_dir, HardwareDescriptorDef::COMPONENTS_DIR_NAME, relative))
      end

      FileUtils.mkdir_p(File.dirname(target_path))
      text = File.read(PLUGIN.resolve_library_ref(@ref), mode: 'r:UTF-8')
      # Its parent stays the OCL one
      parent_ref = HardwareDescriptorDef.parent_ref(descriptor.own_data[HardwareDescriptorDef::EXTENDS], @ref)
      text = HardwareDescriptorDef.replace_extends(text, parent_ref) unless parent_ref.nil?
      File.write(target_path, text, mode: 'w:UTF-8')

      PLUGIN.trigger_event(PluginObserver::ON_HARDWARE_SAVED, { :ref => target_ref })

      { :ref => target_ref, :copied => copied.compact }
    rescue StandardError => e
      _error('core.hardware_editor.error.not_saved', { :error => e.message })
    end

    # -----

    private

    def _error(key, params = {})
      { :errors => [ [ key, params ] ] }
    end

    def _user_ref(bundled_ref)
      Plugin::LIBRARY_REF_PREFIX + bundled_ref[Plugin::LIBRARY_BUNDLED_REF_PREFIX.length..-1]
    end

    # Copies the given file where it doesn't exist yet. Returns its name, nil if it did.
    def _copy(source, target)
      return nil if File.exist?(target)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target)
      File.basename(target)
    end

    # The shared files the parts name - "<path>.skp", relative to the
    # components folder of the library.
    def _shared_files(value, files = [])
      case value
      when Hash
        value.each do |key, v|
          if HardwareDescriptorDef::PARTS.include?(key) && v.is_a?(String) && File.extname(v).downcase == '.skp' && !v.start_with?('./') && !PLUGIN.library_ref?(v)
            files << v
          else
            _shared_files(v, files)
          end
        end
      when Array
        value.each { |v| _shared_files(v, files) }
      end
      files.uniq
    end

  end

end
