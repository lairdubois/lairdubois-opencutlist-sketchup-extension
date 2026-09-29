# Library Cleaner — checks and normalizes the hardware SKP files of the
# OpenCutList library.
#
# Each 'library/components/…/<file>.skp' is checked against the descriptors
# referring to it - a part set to true, or a shared path. A file no
# descriptor refers to is an error. A shared file is named after the first
# referring descriptor, by path :
#   - model name = 'ocl-<descriptor id>-<file stem>' (dots become dashes) -
#     the name SketchUp gives to the loaded definition, unique in the library
#     and never clashing with the definitions of the user's model,
#   - no attribute dictionary but the SketchUp internal ones - OpenCutList
#     attributes are written from the descriptor at load time,
#   - no layer : every entity, nested definitions included, on Layer0,
#   - a GUID shared with no other file of the library,
#   - saved in the SketchUp 2017 format.
# Modules ('library/components/modules/') are left untouched.
#
# Needs SketchUp 2021.1+ and an EMPTY untitled model : definitions are loaded
# and removed one file at a time, unused layers purged.
#
# Use the Extensions > OCL Library Cleaner menu, or the Ruby console :
#   Ladb::LibraryCleaner.run                 # lists the issues, writes nothing
#   Ladb::LibraryCleaner.run(dry_run: false) # fixes and saves the files
#   Ladb::LibraryCleaner.run(library_dir: '/path/to/a/library/copy')
# Files are rewritten only when an issue is found. A verification pass
# reloads every file at the end.

require 'json'

module Ladb
  module LibraryCleaner

    PREFERENCES_SECTION = 'ladb_library_cleaner'

    # The library of the OpenCutList repo holding this tool, when loaded from it
    REPO_LIBRARY_DIR = File.expand_path('../../../src/ladb_opencutlist/library', __dir__)

    # Dictionaries SketchUp won't delete (ArgumentError) or rewrites on save
    INTERNAL_DICTIONARIES = %w[SU_DefinitionSet GSU_ContributorsInfo TempShadowInfo].freeze

    TARGET_VERSION_MAJOR = 17

    # -----

    def self.library_dir
      dir = Sketchup.read_default(PREFERENCES_SECTION, 'library_dir')
      dir = REPO_LIBRARY_DIR unless library_dir?(dir)
      library_dir?(dir) ? dir : nil
    end

    def self.library_dir?(dir)
      dir.is_a?(String) && File.directory?(File.join(dir, 'components'))
    end

    def self.empty_model?(model = Sketchup.active_model)
      !model.nil? && model.path.empty? && model.entities.size == 0 && model.definitions.size == 0 && model.layers.size == 1
    end

    # Returns { :report => String, :summary => String, :ok => Boolean } and
    # prints the report to the Ruby console.
    def self.run(dry_run: true, library_dir: self.library_dir)

      raise 'SketchUp 2021.1+ required' if Sketchup.version_number < 2110000000
      raise 'No library folder' unless library_dir?(library_dir)

      model = Sketchup.active_model
      raise 'Open an empty untitled model first (definitions are loaded and removed, layers purged)' unless empty_model?(model)
      layer0 = model.layers[0]
      cleanable = true   # From here on, the model only holds what the run loads

      paths = Dir.glob(File.join(library_dir, 'components', '**', '*.skp')).sort
      paths.reject! { |path| (rel = _rel(path, library_dir)).start_with?('modules/') || File.basename(rel).start_with?('.') || rel.end_with?('~.skp') }

      lines = []
      guids = {}
      ok_count = 0
      error_count = 0
      saved = 0

      referencing = _referencing_descriptors(library_dir)

      paths.each do |path|
        rel = _rel(path, library_dir)

        descriptors = referencing[File.expand_path(path)] || []
        if descriptors.empty?
          lines << "#{rel}\n    ERROR referenced by no descriptor"
          error_count += 1
          next
        end
        json_rel, id = descriptors.find { |_, descriptor_id| descriptor_id.is_a?(String) && !descriptor_id.empty? }
        if id.nil?
          lines << "#{rel}\n    ERROR no id in #{descriptors.map(&:first).join(', ')}"
          error_count += 1
          next
        end
        name = "ocl-#{id}-#{File.basename(rel, '.skp').tr('.', '-')}"
        shared = descriptors.size > 1 ? "shared by #{descriptors.map(&:first).join(', ')}, named after #{json_rel}" : nil

        definition = model.definitions.load(path)
        issues = []

        issues << "name '#{definition.name}' -> '#{name}'" if definition.name != name

        dictionaries = (definition.attribute_dictionaries || []).map(&:name) - INTERNAL_DICTIONARIES
        issues << "attributes #{dictionaries.join(', ')}" unless dictionaries.empty?

        layered = Hash.new(0)
        model.definitions.each { |d| d.entities.each { |e| layered[e.layer.name] += 1 if e.layer && e.layer != layer0 } }
        issues << "layers #{layered.map { |layer_name, count| "#{layer_name} (#{count})" }.join(', ')}" unless layered.empty?
        hidden = model.layers.reject(&:visible?).map(&:name) & layered.keys
        issues << "WARNING hidden layers made visible : #{hidden.join(', ')}" unless hidden.empty?

        issues << "GUID shared with #{guids[definition.guid]}" if guids.key?(definition.guid)

        version = _version_major(path)
        issues << "version #{version} -> #{TARGET_VERSION_MAJOR}" if version != TARGET_VERSION_MAJOR

        if !issues.empty? && !dry_run

          definition.name = name
          dictionaries.each { |dictionary_name| definition.attribute_dictionaries.delete(dictionary_name) }
          model.definitions.each { |d| d.entities.each { |e| e.layer = layer0 if e.layer && e.layer != layer0 } }
          if guids.key?(definition.guid)
            definition.entities.add_cpoint(ORIGIN).erase!   # Any edit gives a new GUID
          end
          raise "Failed to save #{path}" unless definition.save_as(path, Sketchup::Model::VERSION_2017)
          saved += 1

        end
        guids[definition.guid] = rel

        ok_count += 1 if issues.empty?
        lines << "#{rel}\n    #{[ shared, issues.empty? ? 'ok' : issues.join("\n    ") ].compact.join("\n    ")}"

        _clear(model)
      end

      summary = "#{paths.size} files : #{ok_count} ok, #{paths.size - ok_count - error_count} with issues, #{error_count} errors"
      summary += dry_run ? "\nDry run : nothing saved" : "\n#{saved} saved"
      ok = error_count == 0 && (dry_run ? ok_count == paths.size : true)
      unless dry_run
        verification = _verify(model, paths, library_dir)
        ok &&= verification.nil?
        summary += "\nVerification : #{verification.nil? ? 'ok' : "FAILED\n    #{verification.join("\n    ")}"}"
      end

      report = "#{library_dir}\n\n#{lines.join("\n")}\n\n#{summary}"
      puts report   # One single puts : console output is slow

      { :report => report, :summary => summary, :ok => ok }
    ensure
      _clear(model) if cleanable
    end

    # -- UI --

    def self.ui_run(dry_run)
      dir = library_dir
      return unless dir || ui_choose_library_dir
      dir = library_dir

      unless empty_model?
        return unless UI.messagebox("An empty untitled model is required.\n\nOpen a new model ?", MB_YESNO) == IDYES
        Sketchup.file_new
        return UI.messagebox('The active model is still not empty.') unless empty_model?
      end

      unless dry_run
        return unless UI.messagebox("Rewrite the SKP files with issues in :\n#{dir}\n\nThis can't be undone.", MB_OKCANCEL) == IDOK
      end

      result = run(dry_run: dry_run, library_dir: dir)
      UI.messagebox("#{result[:ok] ? 'OK' : 'Issues found'}\n\n#{result[:summary]}\n\nDetails in the Ruby console.")
      SKETCHUP_CONSOLE.show unless result[:ok]
    rescue => e
      UI.messagebox("Library Cleaner failed :\n#{e.message}")
      raise
    end

    def self.ui_choose_library_dir
      dir = UI.select_directory(title: 'OpenCutList library folder (the one holding components/)', directory: library_dir || '')
      return false if dir.nil?
      unless library_dir?(dir)
        UI.messagebox("No components/ folder in :\n#{dir}")
        return false
      end
      Sketchup.write_default(PREFERENCES_SECTION, 'library_dir', dir)
      true
    end

    # -- Internals --

    def self._verify(model, paths, library_dir)
      errors = []
      names = {}
      guids = {}
      paths.each do |path|
        rel = _rel(path, library_dir)
        definition = model.definitions.load(path)
        errors << "#{rel} : name shared with #{names[definition.name]}" if names.key?(definition.name)
        errors << "#{rel} : GUID shared with #{guids[definition.guid]}" if guids.key?(definition.guid)
        errors << "#{rel} : still has layers" if model.layers.size > 1
        errors << "#{rel} : version #{_version_major(path)}" if _version_major(path) != TARGET_VERSION_MAJOR
        names[definition.name] = rel
        guids[definition.guid] = rel
        _clear(model)
      end
      errors.empty? ? nil : errors
    end

    def self._clear(model)
      model.definitions.to_a.each { |d| model.definitions.remove(d) }
      model.layers.purge_unused
    end

    # { <absolute SKP path> => [ [ <descriptor rel path>, <descriptor id> ], … ] }
    # for every SKP a descriptor of the library refers to, descriptors sorted
    # by path : the first one with an id names a shared file.
    def self._referencing_descriptors(library_dir)
      referencing = Hash.new { |h, k| h[k] = [] }
      json_paths = Dir.glob(File.join(library_dir, '**', '*.json')).reject { |p| p.start_with?(File.join(library_dir, 'components') + '/') }.sort
      json_paths.each do |json_path|
        data = JSON.parse(File.read(json_path)) rescue next
        next unless data.is_a?(Hash) && data['components'].is_a?(Hash)
        json_rel = _rel(json_path, library_dir)
        components_dir = File.join(library_dir, 'components', json_rel.sub(/\.json\z/, ''))
        skp_paths = []
        data['components'].each do |slot, component|
          next unless component.is_a?(Hash)
          items = { nil => component }
          items.merge!(component['variants']['items']) if component['variants'].is_a?(Hash) && component['variants']['items'].is_a?(Hash)
          items.each do |variant, item|
            next unless item.is_a?(Hash)
            %w[hardware machining].each do |part|
              value = item[part]
              if value == true
                skp_paths << File.join(components_dir, [ slot, variant, part == 'machining' ? part : nil ].compact.join('.') + '.skp')
              elsif value.is_a?(String) && File.extname(value).downcase == '.skp'
                skp_paths << if value.start_with?('./')
                               File.join(File.dirname(json_path), value)
                             elsif (prefix = %w[$LIB/ $OCL/].find { |p| value.start_with?(p) })
                               File.join(library_dir, value[prefix.length..-1])
                             else
                               File.join(library_dir, 'components', value)   # Shared file
                             end
              end
            end
          end
        end
        skp_paths.map { |p| File.expand_path(p) }.uniq.each { |p| referencing[p] << [ json_rel, data['id'] ] }
      end
      referencing
    end

    def self._version_major(path)
      File.binread(path, 300).delete("\x00")[/\{(\d+)\.[\d.]+\}/, 1].to_i
    end

    def self._rel(path, library_dir)
      path.sub(File.join(library_dir, 'components') + '/', '').sub(library_dir + '/', '')
    end

    # -----

    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins').add_submenu('OCL Library Cleaner')
      menu.add_item('Check') { ui_run(true) }
      menu.add_item('Clean…') { ui_run(false) }
      menu.add_separator
      menu.add_item('Choose Library Folder…') { ui_choose_library_dir }
      file_loaded(__FILE__)
    end

  end
end
