module Ladb::OpenCutList

  require_relative '../../plugin'

  class LoadGlobalPresetsWorker

    PRESETS_FILE_NAME = 'presets.json'.freeze
    ASSETS_DIR_NAME = 'assets'.freeze

    ZIP_MAGIC = "PK\x03\x04".b.freeze

    class BadFileFormatError < StandardError; end
    class InvalidHexdigestError < StandardError; end

    # -----

    def run

      # Open panel
      path = UI.openpanel(PLUGIN.get_i18n_string('tab.settings.presets.import_global_presets'), '', "OpenCutList Presets|*.oclp;*.json;||")
      if path

        begin

          if _zip?(path)
            data, h_refs = _read_archive(path)
          else
            data = JSON.parse(File.read(path))
            h_refs = {}
          end

          # Check data integrity
          raise BadFileFormatError unless data.is_a?(Hash) && data.has_key?('hexdigest') && data.has_key?('presets')
          raise InvalidHexdigestError unless data['hexdigest'] == Digest::MD5.hexdigest(JSON.dump(data['presets']))

          # TODO cleanup obsolete dectionary ?

          presets = data['presets']

          # Refs are rewritten *after* the integrity check : they point to the
          # files of the archive, now stored in the local library
          _rewrite_refs(presets, h_refs) unless h_refs.empty?

          return presets

        rescue BadFileFormatError
          return { :errors => [ 'tab.settings.presets.error.failed_to_import_bad_file_format' ] }
        rescue InvalidHexdigestError
          return { :errors => [ 'tab.settings.presets.error.failed_to_import_invalid_hexdigest' ] }
        rescue => e
          return { :errors => [ [ 'tab.settings.presets.error.failed_to_import', { :error => e.class } ] ] }
        end

      end

      {
        :cancelled => true
      }
    end

    private

    def _zip?(path)
      File.open(path, 'rb') { |f| f.read(4) } == ZIP_MAGIC
    end

    # Extracts the archive : its files are copied into the asset library, and the
    # '$LIB/…' refs they were exported with are mapped to their local counterpart.
    # Returns [ data, h_refs ].
    def _read_archive(path)
      require_relative '../../lib/rubyzip/zip'

      staging_dir = File.join(PLUGIN.temp_dir, 'presets_import')
      FileUtils.remove_dir(staging_dir, true) if Dir.exist?(staging_dir)
      FileUtils.mkdir_p(staging_dir)

      begin

        data = nil
        h_staged = {}   # archive entry name => extracted file path

        begin

          Zip::File.open(path) do |zip_file|

            entry = zip_file.find_entry(PRESETS_FILE_NAME)
            raise BadFileFormatError if entry.nil?
            data = JSON.parse(zip_file.read(entry))

            zip_file.each do |e|
              next unless e.file? && e.name.start_with?("#{ASSETS_DIR_NAME}/")
              staged_path = File.join(staging_dir, e.name)
              FileUtils.mkdir_p(File.dirname(staged_path))   # The archive holds no directory entry
              e.extract(e.name, destination_directory: staging_dir) { true }   # Zip::Entry#extract guards against path traversal
              h_staged[e.name] = staged_path if File.file?(staged_path)
            end

          end

        rescue Zip::Error, JSON::ParserError
          raise BadFileFormatError
        end

        # Check assets integrity
        if data.is_a?(Hash) && data['assets'].is_a?(Hash)
          data['assets'].each do |entry_name, hexdigest|
            staged_path = h_staged[entry_name]
            raise BadFileFormatError if staged_path.nil?
            raise InvalidHexdigestError unless Digest::MD5.file(staged_path).hexdigest == hexdigest
          end
        end

        # Store the extracted files into the library, at the location the archive
        # carries : it is the one they had in the library they were exported from
        h_refs = {}
        h_staged.each do |entry_name, staged_path|
          relative = entry_name[(ASSETS_DIR_NAME.length + 1)..-1]
          dirname = File.dirname(relative)
          sub_dir = dirname == '.' ? PLUGIN.library_sub_dir_for(relative) : dirname
          library_path = PLUGIN.copy_to_library(staged_path, sub_dir: sub_dir)
          h_refs[Plugin::LIBRARY_REF_PREFIX + relative] = PLUGIN.library_ref_from_path(library_path)
        end

        [ data, h_refs ]

      ensure
        FileUtils.remove_dir(staging_dir, true) if Dir.exist?(staging_dir)
      end
    end

    def _rewrite_refs(value, h_refs)
      case value
      when Hash
        value.each { |k, v| value[k] = _rewrite_refs(v, h_refs) }
        value
      when Array
        value.map! { |v| _rewrite_refs(v, h_refs) }
      when String
        h_refs.fetch(value, value)
      else
        value
      end
    end

  end

end
