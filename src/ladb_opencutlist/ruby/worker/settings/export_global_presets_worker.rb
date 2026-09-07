module Ladb::OpenCutList

  require_relative '../../plugin'

  class ExportGlobalPresetsWorker

    PRESETS_FILE_NAME = 'presets.json'.freeze
    ASSETS_DIR_NAME = 'assets'.freeze

    # Only these files are embedded into the archive. A wider rule (any preset
    # value pointing to an existing file) would also ship unrelated documents,
    # like the last export path of an other tab.
    ASSET_EXTNAMES = %w[.skp .skm].freeze

    def initialize(

                   paths_filter: ''

    )

      @paths_filter = paths_filter

    end

    # -----

    def run

      # Filter global presets
      filtred_presets = {}
      global_presets = PLUGIN.get_global_presets
      global_presets.each do |dictionary, dh|
        dictionary = dictionary.to_s
        dh.each do |section, sh|
          section = section.to_s
          sh.each do |name, values|
            name = name.to_s
            if @paths_filter.include?("#{dictionary}|#{section}|#{name}")
              filtred_presets[dictionary] = {} unless filtred_presets[dictionary]
              filtred_presets[dictionary][section] = {} unless filtred_presets[dictionary][section]
              filtred_presets[dictionary][section][name] = values
            end
          end
        end
      end

      # Deep copy : the refs rewriting below must not alter the stored presets
      filtred_presets = JSON.parse(JSON.dump(filtred_presets))

      # Collect the files referenced by the presets and rewrite their refs
      h_assets = {}   # archive entry name => source file path
      _process_value(filtred_presets, h_assets)

      # Presets referencing files are exported as an archive, the others stay a
      # plain and readable .json file
      extname = h_assets.empty? ? '.json' : '.oclp'

      path = UI.savepanel(PLUGIN.get_i18n_string('tab.settings.presets.export_global_presets'), '', "OpenCutListPresets#{extname}")
      if path

        # Force file extension
        path = path + extname unless path.downcase.end_with?(extname)

        begin

          if h_assets.empty?
            File.write(path, JSON.dump(_wrap(filtred_presets)))
          else
            _write_archive(path, filtred_presets, h_assets)
          end

        rescue => e
          return { :errors => [ [ 'tab.settings.presets.error.failed_to_export', { :error => e.message } ] ] }
        end

        return {
          :success => true,
          :assets_count => h_assets.length
        }
      end

      {
        :cancelled => true
      }
    end

    private

    # Walks the preset values and replaces each asset file ref by a portable
    # '$LIB/…' ref, collecting the files to embed along the way.
    def _process_value(value, h_assets)
      case value
      when Hash
        value.each { |k, v| value[k] = _process_value(v, h_assets) }
        value
      when Array
        value.map! { |v| _process_value(v, h_assets) }
      when String
        _process_ref(value, h_assets)
      else
        value
      end
    end

    def _process_ref(ref, h_assets)
      return ref unless ASSET_EXTNAMES.include?(File.extname(ref).downcase)

      is_library_ref = PLUGIN.library_ref?(ref)
      path = is_library_ref ? PLUGIN.resolve_library_ref(ref) : ref
      return ref if path.nil? || !File.file?(path)

      # Same file already collected, through an other ref
      entry = h_assets.key(path)
      if entry.nil?

        # A file of the library keeps its location, an external file takes the
        # one it will have once stored : the archive carries the library layout,
        # so the import needs no folder of its own
        relative = is_library_ref ? ref[Plugin::LIBRARY_REF_PREFIX.length..-1] : File.join(PLUGIN.library_sub_dir_for(path), File.basename(path))

        entry = "#{ASSETS_DIR_NAME}/#{relative}"
        unless h_assets[entry].nil?
          # Name clash between two different files
          extname = File.extname(relative)
          basename = relative[0...(relative.length - extname.length)]
          index = 2
          loop do
            entry = "#{ASSETS_DIR_NAME}/#{basename} (#{index})#{extname}"
            break if h_assets[entry].nil?
            index += 1
          end
        end

        h_assets[entry] = path

      end

      Plugin::LIBRARY_REF_PREFIX + entry[(ASSETS_DIR_NAME.length + 1)..-1]
    end

    # Wraps data with hexdigests for integrity control
    def _wrap(presets, h_assets = {})
      data = {
        :hexdigest => Digest::MD5.hexdigest(JSON.dump(presets)),
        :presets => presets
      }
      unless h_assets.empty?
        data[:assets] = h_assets.inject({}) { |hash, (entry, path)| hash[entry] = Digest::MD5.file(path).hexdigest; hash }
      end
      data
    end

    def _write_archive(path, presets, h_assets)
      require_relative '../../lib/rubyzip/zip'

      FileUtils.rm_f(path)   # An existing archive would be appended to, not replaced

      Zip::File.open(path, create: true) do |zip_file|
        zip_file.get_output_stream(PRESETS_FILE_NAME) { |f| f.write(JSON.dump(_wrap(presets, h_assets))) }
        h_assets.each { |entry, source_path| zip_file.add(entry, source_path) }
      end
    end

  end

end
