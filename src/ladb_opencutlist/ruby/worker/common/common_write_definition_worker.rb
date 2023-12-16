module Ladb::OpenCutList

  require_relative '../../helper/sanitizer_helper'

  class CommonWriteDefinitionWorker

    include SanitizerHelper

    def initialize(settings)

      @file_name = _sanitize_filename(settings.fetch('file_name', nil))
      @definition = settings.fetch('definition', nil)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @definition.is_a?(Sketchup::ComponentDefinition)

      last_dir = Plugin.instance.read_default(Plugin::SETTINGS_KEY_COMPONENTS_LAST_DIR, nil)
      if last_dir && File.directory?(last_dir) && File.exist?(last_dir)
        dir = last_dir
      else

        # Try to use SU Components dir
        components_dir = Sketchup.find_support_file('Components', '')
        if File.directory?(components_dir)

          # Join with OpenCutList subdir and create it if it dosen't exist
          dir = File.join(components_dir, 'OpenCutList')
          unless File.directory?(dir)
            FileUtils.mkdir_p(dir)
          end

        else
          dir = File.dirname(model.path)
        end

      end

      dir = dir.gsub(/ /, '%20') if Plugin.instance.platform_is_mac

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('core.savepanel.export_to_file', { :file_format => 'SKP' }), dir, "#{@file_name}.skp")
      if path

        # Save last dir
        Plugin.instance.write_default(Plugin::SETTINGS_KEY_COMPONENTS_LAST_DIR, File.dirname(path))

        # Force "skp" file extension
        unless path.end_with?('.skp')
          path = path + '.skp'
        end

        begin
          success = @definition.save_as(path) && File.exist?(path)
          return { :errors => [ [ 'core.error.failed_export_to', { :error => '' } ] ] } unless success
          return { :export_path => path }
        rescue => e
          return { :errors => [ [ 'core.error.failed_export_to', { :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

  end

end