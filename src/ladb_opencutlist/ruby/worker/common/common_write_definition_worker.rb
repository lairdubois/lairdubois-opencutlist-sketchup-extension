module Ladb::OpenCutList

  require_relative '../../helper/sanitizer_helper'

  class CommonWriteDefinitionWorker

    include SanitizerHelper

    def initialize(settings)

      @folder_path = settings.fetch('folder_path', nil)
      @file_name = _sanitize_filename(settings.fetch('file_name', nil))
      @definition = settings.fetch('definition', nil)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @definition.is_a?(Sketchup::ComponentDefinition)

      # Open save panel if needed
      if @folder_path.nil? || !File.exist?(@folder_path)
        path = UI.savepanel(Plugin.instance.get_i18n_string('core.savepanel.export_to_file', { :file_format => 'SKP' }), '', "#{@file_name}.skp")
      else
        path = File.join(@folder_path, "#{@file_name}.skp")
      end
      if path

        # Force "skp" file extension
        unless path.end_with?('.skp')
          path = path + '.skp'
        end

        begin

          success = @definition.save_as(path) && File.exist?(path)

          return { :errors => [ [ 'core.error.failed_export_to', { :error => '' } ] ] } unless success
          return { :export_path => path }
        rescue => e
          puts e.inspect
          puts e.backtrace
          return { :errors => [ [ 'core.error.failed_export_to', { :path => path, :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

  end

end