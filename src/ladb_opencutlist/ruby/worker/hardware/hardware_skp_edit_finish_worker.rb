module Ladb::OpenCutList

  require 'fileutils'
  require_relative 'hardware_skp_mesh_worker'
  require_relative '../../model/hardware/hardware_skp_edit_session'

  # Ends a HardwareSkpEditSession : the part shaped in SketchUp is saved into
  # a temporary file - the editor imports it at save - and the session is
  # closed, the bench leaving the model with every definition it brought.
  class HardwareSkpEditFinishWorker

    def initialize(session)

      @session = session

    end

    # -----

    def run

      session = @session
      return _error('core.hardware_editor.error.edit_lost') unless session.valid?
      instance = session.instance

      session.closing = true
      session.close_active

      # The point that kept it while empty, once it isn't
      placeholder = session.placeholder
      if !placeholder.nil? && placeholder.valid? && instance.definition.entities.length > 1
        session.model.start_operation('OCL Hardware Edit', true, false, true)
        placeholder.erase!
        session.model.commit_operation
      end

      dir = File.join(PLUGIN.temp_dir, 'hardware')
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "edit-#{Time.now.strftime('%Y%m%d%H%M%S')}-#{rand(1000000)}.skp")
      if Sketchup.version_number >= 2100000000
        instance.definition.save_as(path, Sketchup::Model::VERSION_2017)
      else
        instance.definition.save_as(path)
      end

      { :path => path }
    rescue StandardError => e
      _error('core.hardware_editor.error.edit_failed', { :error => HardwareSkpMeshWorker.error_message(e) })
    ensure
      session.close
    end

    # -----

    private

    def _error(key, params = {})
      { :errors => [ [ key, params ] ] }
    end

  end

end
