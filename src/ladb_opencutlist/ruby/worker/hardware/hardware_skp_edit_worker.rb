module Ladb::OpenCutList

  require 'fileutils'
  require_relative 'hardware_skp_mesh_worker'

  # Shapes a SKP part of a descriptor in SketchUp : the panels of the test
  # bench and the part - its placement baked in - laid in the model, the part
  # opened for edit. Its axes are its laying frame. Finished, the part is
  # saved into a temporary file - the editor imports it at save - and the
  # bench leaves the model with every definition it brought.
  class HardwareSkpEditWorker

    # Room between the model and the bench, in inches
    MARGIN = 20.0

    @@session = nil

    def self.editing?
      !@@session.nil?
    end

    # action : 'start', 'finish' or 'cancel' ;
    # source : the ref or absolute path of the SKP file, nil to start empty ;
    # placement : column-major 4x4 matrix to bake in, inches ;
    # transformation : where the part lies on the bench - column-major ;
    # panels : [ { :min, :max } ] of the bench, inches ;
    # view : how the bench is shown - column-major, see
    # HardwareBenchDef#view_transformation ; name : of the part.
    def initialize(action:, source: nil, placement: nil, transformation: nil, panels: [], view: nil, name: nil)
      @action = action
      @source = source
      @placement = placement
      @transformation = transformation
      @panels = panels.is_a?(Array) ? panels : []
      @view = view
      @name = name
    end

    # -----

    def run
      case @action
      when 'start'
        _start
      when 'finish'
        _finish
      when 'cancel'
        _cleanup
        {}
      else
        {}
      end
    rescue StandardError => e
      _cleanup
      _error('core.hardware_editor.error.edit_failed', { :error => HardwareSkpMeshWorker.error_message(e) })
    end

    # -----

    private

    def _error(key, params = {})
      { :errors => [ [ key, params ] ] }
    end

    def _start

      _cleanup   # One at a time

      model = Sketchup.active_model
      return _error('core.hardware_editor.error.edit_failed', { :error => 'no model' }) if model.nil?

      path = @source.is_a?(String) ? PLUGIN.resolve_library_ref(@source) : nil
      path = nil unless path.is_a?(String) && File.file?(path)
      return _error('core.hardware_editor.error.skp_is_open_model', { :name => File.basename(path) }) if !path.nil? && HardwareSkpMeshWorker.open_model?(model, path)

      definitions = model.definitions.to_a
      model.start_operation('OCL Hardware Edit', true)
      begin

        # The bench, beside the model
        bench = model.entities.add_group
        bench.name = 'OCL Hardware Bench'
        @panels.each do |panel|
          _add_box(bench.entities, panel['min'], panel['max'])
        end

        # The part : a new definition - the file's content laid by its placement
        definition = model.definitions.add(@name.is_a?(String) && !@name.empty? ? @name : 'Part')
        if path.nil?
          definition.entities.add_cpoint(ORIGIN)   # An empty definition doesn't stay
        else
          loaded = HardwareSkpMeshWorker.load_definition(model, path)
          raise 'not loaded' if loaded.nil?
          definition.entities.add_instance(loaded, _transformation(@placement)).explode
          _make_unique(definition.entities)   # Shared by GUID with the model's own ones
        end
        instance = bench.entities.add_instance(definition, _transformation(@transformation))
        bench.transform!(_transformation(@view))   # Its frame turned as the editor shows it

        others = Geom::BoundingBox.new
        model.entities.each { |entity| others.add(entity.bounds) unless entity == bench || !entity.respond_to?(:bounds) }
        bench.transform!(Geom::Transformation.translation(Geom::Vector3d.new(others.max.x - bench.bounds.min.x + MARGIN, 0, 0))) unless others.empty?

        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end

      @@session = {
        :model => model,
        :bench => bench,
        :instance => instance,
        :definitions => definitions,
      }

      # The part opened for edit
      if model.respond_to?(:active_path=)
        model.active_path = [ bench, instance ]
      else
        model.selection.clear
        model.selection.add(instance)
      end
      model.active_view.zoom(bench)

      {}
    end

    def _finish
      session = @@session
      return _error('core.hardware_editor.error.edit_lost') if session.nil?
      instance = session[:instance]
      unless instance.valid? && session[:model] == Sketchup.active_model
        _cleanup
        return _error('core.hardware_editor.error.edit_lost')
      end

      _close_active(session[:model])

      dir = File.join(PLUGIN.temp_dir, 'hardware')
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "edit-#{Time.now.strftime('%Y%m%d%H%M%S')}-#{rand(1000000)}.skp")
      if Sketchup.version_number >= 2100000000
        instance.definition.save_as(path, Sketchup::Model::VERSION_2017)
      else
        instance.definition.save_as(path)
      end

      _cleanup

      { :path => path }
    end

    # The bench leaves the model, with every definition it brought.
    def _cleanup
      session = @@session
      @@session = nil
      return if session.nil?
      model = session[:model]
      return unless model.valid?
      _close_active(model)
      model.start_operation('OCL Hardware Edit', true)
      session[:bench].erase! if session[:bench].valid?
      if model.definitions.respond_to?(:remove)
        added = model.definitions.to_a - session[:definitions]
        added.each { |definition| model.definitions.remove(definition) if definition.valid? && definition.instances.empty? }
      end
      model.commit_operation
    end

    def _close_active(model)
      if model.respond_to?(:active_path=)
        model.active_path = nil unless model.active_path.nil?
      else
        model.close_active until model.active_path.nil?
      end
    end

    def _transformation(matrix)
      return Geom::Transformation.new unless matrix.is_a?(Array) && matrix.length == 16 && matrix.all? { |v| v.is_a?(Numeric) }
      Geom::Transformation.new(matrix.map(&:to_f))
    end

    # A box - a group - between the given corners.
    def _add_box(entities, min, max)
      return unless min.is_a?(Array) && max.is_a?(Array) && min.length == 3 && max.length == 3
      x0, y0, z0 = min.map(&:to_f)
      x1, y1, z1 = max.map(&:to_f)
      return if x1 - x0 <= 0 || y1 - y0 <= 0 || z1 - z0 <= 0
      group = entities.add_group
      face = group.entities.add_face([ x0, y0, z0 ], [ x1, y0, z0 ], [ x1, y1, z0 ], [ x0, y1, z0 ])
      face.reverse! if face.normal.z < 0
      face.pushpull(z1 - z0)
      group
    end

    # The groups and components of the given entities - and theirs - get
    # their own definitions.
    def _make_unique(entities, visited = [])
      entities.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        entity.make_unique
        definition = entity.definition
        next if visited.include?(definition)
        visited << definition
        _make_unique(definition.entities, visited)
      end
    end

  end

end
