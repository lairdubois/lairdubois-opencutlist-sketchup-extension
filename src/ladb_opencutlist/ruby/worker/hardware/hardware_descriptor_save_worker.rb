module Ladb::OpenCutList

  require 'json'
  require 'fileutils'
  require_relative '../../model/hardware/hardware_descriptor_def'
  require_relative 'hardware_skp_mesh_worker'

  # Writes a descriptor edited in the hardware editor into the user's
  # library : its JSON as written, the SKP files of its parts - picked ones
  # copied, placements baked in - and the folder of its components kept tidy.
  # Renamed, it moves with that folder, and the descriptors that extend it
  # - or whose articles use it - follow. Only '$LIB/…' refs : the OCL library
  # is read only - but to a dev build run from the sources.
  class HardwareDescriptorSaveWorker

    # The name a part file declared true may have : <slot>[.<variant>][.machining].skp,
    # or an article's : <slot>[.<variant>].<key>.skp
    CONVENTION_FILE_PATTERN = /\A[^.\/]+(\.[^.\/]+){0,2}(\.machining)?\.skp\z/i

    # ref : where to write the descriptor - its own file, or a new one that
    #   must not exist yet (new: true) ;
    # from : the ref it had, to rename it - in the same folder ;
    # text : the JSON, as edited ;
    # imports : { <part ref> => <absolute path - or library ref - of the SKP file picked for it> } ;
    # placements : { <part ref> => <column-major 4x4 matrix, inches> } to bake in.
    # Part refs are the ones of 'from' when renamed.
    def initialize(ref:,

                   text:,
                   new: false,
                   from: nil,
                   imports: {},
                   placements: {}
    )

      @ref = ref
      @text = text
      @new = new == true
      @from = @new || from == ref ? nil : from
      # A library ref : that file as it is - an article's renamed with its key
      @imports = imports.is_a?(Hash) ? Hash[imports.map { |k, v| [ k.to_s, PLUGIN.library_ref?(v) ? PLUGIN.resolve_library_ref(v) : v ] }] : {}
      @placements = placements.is_a?(Hash) ? Hash[placements.map { |k, v| [ k.to_s, v ] }] : {}

    end

    # -----

    def run

      return _error('core.hardware_editor.error.readonly') if PLUGIN.library_readonly_ref?(@ref)
      return _error('core.hardware_editor.error.invalid_ref', { :ref => @ref }) unless PLUGIN.library_ref?(@ref) && File.extname(@ref).downcase == '.json'
      path = PLUGIN.resolve_library_ref(@ref)
      return _error('core.hardware_editor.error.invalid_ref', { :ref => @ref }) if path.nil?
      return _error('core.hardware_editor.error.file_exists', { :ref => @ref }) if @new && File.exist?(path)
      return _error('core.hardware_editor.error.file_not_found', { :ref => @ref }) if !@new && @from.nil? && !File.file?(path)

      # Only a valid descriptor is written
      begin
        data = JSON.parse(@text)
      rescue JSON::ParserError => e
        return _error('core.hardware_editor.error.invalid_descriptor', { :error => e.message.lines.first.to_s.strip[0, 80] })
      end
      return _error('core.hardware_editor.error.invalid_descriptor', { :error => 'not an ocl-hardware descriptor' }) unless HardwareDescriptorDef.descriptor?(data)
      descriptor = HardwareDescriptorDef.new(data, path, @ref)
      return _error('core.hardware_editor.error.invalid_descriptor', { :error => descriptor.errors.first }) unless descriptor.valid?

      # Renamed : the file and the folder of its components, if free
      unless @from.nil?
        return _error('core.hardware_editor.error.readonly') if PLUGIN.library_readonly_ref?(@from)
        from_path = PLUGIN.resolve_library_ref(@from)
        return _error('core.hardware_editor.error.invalid_ref', { :ref => @from }) unless PLUGIN.library_ref?(@from) && File.dirname(@from) == File.dirname(@ref) && !from_path.nil?
        return _error('core.hardware_editor.error.file_not_found', { :ref => @from }) unless File.file?(from_path)
        return _error('core.hardware_editor.error.file_exists', { :ref => @ref }) if File.exist?(path) && !File.identical?(path, from_path)
        from_dir_ref = HardwareDescriptorDef.new(data, from_path, @from).components_dir_ref
        dir_ref = descriptor.components_dir_ref
        from_dir = PLUGIN.resolve_library_ref(from_dir_ref)
        dir = PLUGIN.resolve_library_ref(dir_ref)
        return _error('core.hardware_editor.error.file_exists', { :ref => dir_ref }) if File.directory?(from_dir) && File.exist?(dir) && !File.identical?(dir, from_dir)
        @imports = _moved(@imports, from_dir_ref, dir_ref)
        @placements = _moved(@placements, from_dir_ref, dir_ref)
      end

      # The SKP files to write : picked or placed, in the user's library
      skp_refs = (@imports.keys + @placements.keys.select { |ref| _placement(ref) }).uniq
      skp_refs.each do |ref|
        return _error('core.hardware_editor.error.invalid_ref', { :ref => ref }) unless PLUGIN.library_ref?(ref) && !PLUGIN.library_readonly_ref?(ref) && File.extname(ref).downcase == '.skp' && !PLUGIN.resolve_library_ref(ref).nil?
        source = @imports[ref] || PLUGIN.resolve_library_ref(@from.nil? ? ref : _moved_ref(ref, dir_ref, from_dir_ref))
        return _error('core.hardware_editor.error.file_not_found', { :ref => source }) unless source.is_a?(String) && File.file?(source)
      end

      # Renamed : same folder, so a rename - a change of case too
      children = []
      users = []
      unless @from.nil?
        children = HardwareDescriptorDef.children_refs(@from, PLUGIN.library_dir, Plugin::LIBRARY_REF_PREFIX)
        users = HardwareDescriptorDef.users_refs(@from, PLUGIN.library_dir, Plugin::LIBRARY_REF_PREFIX)
        File.rename(from_path, path)
        File.rename(from_dir, dir) if File.directory?(from_dir)
        _move_loaded_definitions(from_dir_ref, dir_ref)
        _move_children(children)
        _move_users(users)
      end

      # The JSON, as written
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, @text, mode: 'w:UTF-8')

      # The SKP files
      written = []
      skp_refs.each do |ref|
        error = _write_skp(descriptor, ref, @imports[ref] || PLUGIN.resolve_library_ref(ref), _placement(ref))
        return _error('core.hardware_editor.error.skp_not_written', { :ref => ref, :error => error }) unless error.nil?
        written << ref
      end
      _forget_loaded_definitions(written)

      removed = _remove_orphan_files(descriptor)

      PLUGIN.trigger_event(PluginObserver::ON_HARDWARE_SAVED, { :ref => @ref })

      { :ref => @ref, :renamed => !@from.nil?, :written => written, :removed => removed, :children => children, :users => users }
    rescue StandardError => e
      _error('core.hardware_editor.error.not_saved', { :error => HardwareSkpMeshWorker.error_message(e) })
    end

    # -----

    private

    def _error(key, params = {})
      { :errors => [ [ key, params ] ] }
    end

    # The placement of the given part ref as a transformation, nil if none - or the identity.
    def _placement(ref)
      matrix = @placements[ref]
      return nil unless matrix.is_a?(Array) && matrix.length == 16 && matrix.all? { |v| v.is_a?(Numeric) }
      identity = [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ]
      return nil if matrix.each_with_index.all? { |v, i| (v - identity[i]).abs < 1e-9 }
      Geom::Transformation.new(matrix.map(&:to_f))
    end

    # Writes the given source SKP at the given part ref, laid by the given
    # placement : loaded, exploded into a new definition - new GUID, no
    # attributes of OCL, no tags - saved, then dropped with the operation.
    # Returns nil, or the error.
    def _write_skp(descriptor, ref, source, placement)
      path = PLUGIN.resolve_library_ref(ref)
      model = Sketchup.active_model
      return 'no model' if model.nil?
      model.start_operation('OCL Hardware Save', true)
      begin
        loaded = HardwareSkpMeshWorker.load_definition(model, source)
        return 'not loaded' if loaded.nil?
        definition = model.definitions.add("ocl-#{descriptor.id}-#{File.basename(path, '.skp').tr('.', '-')}")
        instance = definition.entities.add_instance(loaded, placement || Geom::Transformation.new)
        instance.explode
        _clean(definition, model.layers[0], [])
        FileUtils.mkdir_p(File.dirname(path))
        if Sketchup.version_number >= 2100000000
          definition.save_as(path, Sketchup::Model::VERSION_2017)
        else
          definition.save_as(path)
        end
        nil
      rescue StandardError => e
        HardwareSkpMeshWorker.error_message(e)
      ensure
        model.abort_operation
      end
    end

    # No attributes of OCL - they come from the descriptor - and no tags.
    def _clean(definition, layer0, visited)
      return if visited.include?(definition)
      visited << definition
      definition.attribute_dictionaries.delete(Plugin::ATTRIBUTE_DICTIONARY) if definition.attribute_dictionaries
      definition.entities.each do |entity|
        entity.layer = layer0 if entity.respond_to?(:layer=) && entity.layer != layer0
        _clean(entity.definition, layer0, visited) if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end
    end

    # The given refs, the ones in the from folder moved to the to folder.
    def _moved(refs, from_dir_ref, to_dir_ref)
      Hash[refs.map { |ref, v| [ _moved_ref(ref, from_dir_ref, to_dir_ref), v ] }]
    end

    def _moved_ref(ref, from_dir_ref, to_dir_ref)
      ref.start_with?(from_dir_ref + '/') ? to_dir_ref + ref[from_dir_ref.length..-1] : ref
    end

    # The definitions of the model loaded from files of the from folder
    # follow them to the to folder : they stay found.
    def _move_loaded_definitions(from_dir_ref, to_dir_ref)
      model = Sketchup.active_model
      return if model.nil?
      definitions = model.definitions.select { |d| d.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE).to_s.start_with?(from_dir_ref + '/') }
      return if definitions.empty?
      model.start_operation('OCL Hardware Save', true, false, true)
      definitions.each do |d|
        d.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE, _moved_ref(d.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE), from_dir_ref, to_dir_ref))
      end
      model.commit_operation
    end

    # The definitions of the model loaded from the given files are forgotten
    # by their source : the next use loads the new files - the laid ones stay.
    def _forget_loaded_definitions(refs)
      model = Sketchup.active_model
      return if model.nil? || refs.empty?
      definitions = model.definitions.select { |d| refs.include?(d.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE)) }
      return if definitions.empty?
      model.start_operation('OCL Hardware Save', true, false, true)
      definitions.each { |d| d.delete_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE) }
      model.commit_operation
    end

    # The descriptors that extended the renamed one extend it under its new
    # ref - see "extends" : only that value of their text is rewritten.
    def _move_children(children)
      children.each do |child_ref|
        child_path = PLUGIN.resolve_library_ref(child_ref)
        text = File.read(child_path, mode: 'r:UTF-8')
        File.write(child_path, HardwareDescriptorDef.replace_extends(text, HardwareDescriptorDef.extends_value(@ref, child_ref)), mode: 'w:UTF-8')
      end
    end

    # The descriptors whose articles used the renamed one use it under its
    # new ref - see "use" : only those values of their text are rewritten.
    def _move_users(users)
      users.each do |user_ref|
        user_path = PLUGIN.resolve_library_ref(user_ref)
        text = File.read(user_path, mode: 'r:UTF-8')
        text = HardwareDescriptorDef.replace_uses(text) do |value|
          HardwareDescriptorDef.parent_ref(value, user_ref) == @from ? HardwareDescriptorDef.extends_value(@ref, user_ref) : nil
        end
        File.write(user_path, text, mode: 'w:UTF-8')
      end
    end

    # The files of the components folder named as a part declared true could
    # be - see CONVENTION_FILE_PATTERN - that none is any more : removed, the
    # folder too if left empty. Other files are left. Returns their names.
    def _remove_orphan_files(descriptor)
      dir_ref = descriptor.components_dir_ref
      dir = dir_ref.nil? ? nil : PLUGIN.resolve_library_ref(dir_ref)
      return [] unless dir.is_a?(String) && File.directory?(dir)
      declared = _declared_files(descriptor.own_data['components'])   # Inherited parts live in their parent's folder
      removed = []
      _children(dir).each do |name|
        next unless name =~ CONVENTION_FILE_PATTERN && File.file?(File.join(dir, name))
        next if declared.any? { |d| d.casecmp(name) == 0 }
        File.delete(File.join(dir, name))
        removed << name
      end
      Dir.rmdir(dir) if _children(dir).empty?
      removed
    end

    # Dir.children, Ruby 2.2 compatible
    def _children(dir)
      Dir.entries(dir) - %w[. ..]
    end

    # The file names of the parts - and articles - declared true.
    def _declared_files(components)
      names = []
      return names unless components.is_a?(Hash)
      fn_parts = lambda do |slot, variant, value|
        return unless value.is_a?(Hash)
        HardwareDescriptorDef::PARTS.each do |part|
          names << HardwareDescriptorDef.part_file_name(slot, variant, part) if value[part] == true
        end
      end
      components.each do |slot, value|
        next unless value.is_a?(Hash)
        if value['variants'].is_a?(Hash) && value['variants']['items'].is_a?(Hash)
          value['variants']['items'].each { |variant, item| fn_parts.call(slot, variant, item) }
        else
          fn_parts.call(slot, nil, value)
        end
      end
      HardwareDescriptorDef.each_article(components) do |slot, variant, key, article|
        names << HardwareDescriptorDef.article_file_name(slot, variant, key) if article[HardwareDescriptorDef::ARTICLE_SKP] == true
      end
      names
    end

  end

end
