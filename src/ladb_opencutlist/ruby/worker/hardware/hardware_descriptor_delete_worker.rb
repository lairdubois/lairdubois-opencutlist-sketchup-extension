module Ladb::OpenCutList

  require 'fileutils'
  require_relative '../../model/hardware/hardware_descriptor_def'

  # Deletes a descriptor of the user's library : its JSON and the folder of
  # its components - refused while others extend it, or use it in their
  # articles. The shared SKP files stay - others may use them - and so
  # do the parts laid in the model. The actions of SmartJoin that picked it
  # forget it.
  class HardwareDescriptorDeleteWorker

    # The global presets of the SmartJoin actions - see SmartJoinTool
    SMART_JOIN_OPTIONS_DICTIONARY = 'tool_smart_join_options'.freeze
    SMART_JOIN_OPTION_HARDWARE = 'hardware'.freeze

    def initialize(ref:)

      @ref = ref

    end

    # -----

    def run

      return _error('core.hardware_editor.error.readonly') if PLUGIN.library_readonly_ref?(@ref)
      return _error('core.hardware_editor.error.invalid_ref', { :ref => @ref }) unless PLUGIN.library_ref?(@ref) && File.extname(@ref).downcase == '.json'
      path = PLUGIN.resolve_library_ref(@ref)
      return _error('core.hardware_editor.error.file_not_found', { :ref => @ref }) unless path.is_a?(String) && File.file?(path)

      # Never under its children - only the user's library can extend it
      children = HardwareDescriptorDef.children_refs(@ref, PLUGIN.library_dir, Plugin::LIBRARY_REF_PREFIX)
      return _error('core.hardware_editor.error.has_children', { :children => children.map { |ref| File.basename(ref) }.join(', ') }) unless children.empty?
      users = HardwareDescriptorDef.users_refs(@ref, PLUGIN.library_dir, Plugin::LIBRARY_REF_PREFIX)
      return _error('core.hardware_editor.error.has_users', { :users => users.map { |ref| File.basename(ref) }.join(', ') }) unless users.empty?

      # The folder of its components - named after the file, whatever its JSON is
      dir_ref = HardwareDescriptorDef.new({}, path, @ref).components_dir_ref
      dir = dir_ref.nil? ? nil : PLUGIN.resolve_library_ref(dir_ref)

      File.delete(path)
      FileUtils.rm_rf(dir) if dir.is_a?(String) && File.directory?(dir)
      _forget_loaded_definitions(dir_ref) unless dir_ref.nil?
      _forget_picked

      PLUGIN.trigger_event(PluginObserver::ON_HARDWARE_DELETED, { :ref => @ref })

      { :ref => @ref }
    rescue StandardError => e
      _error('core.hardware_editor.error.not_deleted', { :error => e.message })
    end

    # -----

    private

    def _error(key, params = {})
      { :errors => [ [ key, params ] ] }
    end

    # The definitions of the model loaded from its files forget their
    # source : the laid ones stay, as they are.
    def _forget_loaded_definitions(dir_ref)
      model = Sketchup.active_model
      return if model.nil?
      definitions = model.definitions.select { |d| d.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE).to_s.start_with?(dir_ref + '/') }
      return if definitions.empty?
      model.start_operation('OCL Hardware Delete', true, false, true)
      definitions.each { |d| d.delete_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE) }
      model.commit_operation
    end

    # The SmartJoin actions that picked it pick nothing any more.
    def _forget_picked
      (0..5).each do |action|   # SmartJoinTool::ACTION_*
        section = "action_#{action}"
        preset = PLUGIN.get_global_preset(SMART_JOIN_OPTIONS_DICTIONARY, nil, section)
        next unless preset.is_a?(Hash) && preset[SMART_JOIN_OPTION_HARDWARE] == @ref
        preset.store(SMART_JOIN_OPTION_HARDWARE, nil)
        PLUGIN.set_global_preset(SMART_JOIN_OPTIONS_DICTIONARY, preset, nil, section, true)
      end
    end

  end

end
