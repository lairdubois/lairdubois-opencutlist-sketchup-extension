module Ladb::OpenCutList

  require_relative '../../helper/sanitizer_helper'

  class CommonWriteDefinitionWorker

    include SanitizerHelper

    def initialize(definition,

                   folder_path: nil,
                   file_name: 'PART'

    )

      @definition = definition

      @folder_path = folder_path
      @file_name = _sanitize_filename(file_name)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @definition.is_a?(Sketchup::ComponentDefinition)

      # Open save panel if needed
      if @folder_path.nil? || !File.exist?(@folder_path)
        path = UI.savepanel(PLUGIN.get_i18n_string('core.savepanel.export_to_file', { :file_format => 'SKP' }), '', "#{@file_name}.skp")
      else
        path = File.join(@folder_path, "#{@file_name}.skp")
      end
      if path

        # Force "skp" file extension
        path = path + '.skp' unless path.end_with?('.skp')

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