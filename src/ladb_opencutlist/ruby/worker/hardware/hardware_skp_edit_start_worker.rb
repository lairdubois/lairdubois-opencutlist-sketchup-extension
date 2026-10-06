module Ladb::OpenCutList

  require_relative 'hardware_skp_mesh_worker'
  require_relative '../../model/hardware/hardware_skp_edit_session'

  # Shapes a SKP part of a descriptor in SketchUp : the panels of the test
  # bench and the part - its placement baked in - laid in the model, the part
  # opened for edit. Its axes are its laying frame. Returns the
  # HardwareSkpEditSession - see HardwareSkpEditFinishWorker.
  class HardwareSkpEditStartWorker

    # Room between the model and the bench, in inches
    MARGIN = 20.0

    # Room around the bench in the view, as a ratio of its bounding sphere
    ZOOM_FACTOR = 1.1

    # Triggered once the part is no longer in the active path
    ON_PART_LEFT = 'on_hardware_skp_edit_part_left'.freeze

    # A refusal to show the user : an i18n key and its params
    class Error < StandardError

      attr_reader :key, :params

      def initialize(key, params = {})
        super(key)
        @key = key
        @params = params
      end

    end

    # source : the ref or absolute path of the SKP file, nil to start empty ;
    # placement : column-major 4x4 matrix to bake in, inches ;
    # transformation : where the part lies on the bench - column-major ;
    # panels : [ { :min, :max } ] of the bench, inches ;
    # view : how the bench is shown - column-major, see
    # HardwareBenchDef#view_transformation ; name : of the part.
    def initialize(source: nil,
                   placement: nil,
                   transformation: nil,
                   panels: [],
                   view: nil,
                   name: nil
    )

      @source = source
      @placement = placement
      @transformation = transformation
      @panels = panels.is_a?(Array) ? panels : []
      @view = view
      @name = name

    end

    # -----

    def run

      model = Sketchup.active_model
      raise Error.new('core.hardware_editor.error.edit_failed', { :error => 'no model' }) if model.nil?

      path = @source.is_a?(String) ? PLUGIN.resolve_library_ref(@source) : nil
      path = nil unless path.is_a?(String) && File.file?(path)
      raise Error.new('core.hardware_editor.error.skp_is_open_model', { :name => File.basename(path) }) if !path.nil? && HardwareSkpMeshWorker.open_model?(model, path)

      # The camera and the Smart Join tool - that steps aside - are given
      # back once the part is done
      view_state = { :camera => _copy_camera(model.active_view.camera) }
      if model.tools.respond_to?(:active_tool) && (active_tool = model.tools.active_tool).is_a?(SmartJoinTool)
        view_state[:smart_join_action] = active_tool.fetch_action
        model.select_tool(nil)
      end

      begin

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
          placeholder = nil
          if path.nil?
            placeholder = definition.entities.add_cpoint(ORIGIN)   # An empty definition doesn't stay - not saved
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

      rescue StandardError
        HardwareSkpEditSession.restore_view(view_state)
        raise
      end

      session = HardwareSkpEditSession.new(
        model: model,
        bench: bench,
        instance: instance,
        placeholder: placeholder,
        definitions: definitions,
        view_state: view_state
      )

      # The part opened for edit
      if model.respond_to?(:active_path=)
        model.active_path = [ bench, instance ]
      else
        model.selection.clear
        model.selection.add(instance)
      end
      _zoom_iso(model.active_view, bench.bounds)

      session
    end

    # -----

    private

    # An iso view - from front left, above - that frames the bounding sphere
    # of the given bounds, ZOOM_FACTOR wider. The projection is kept.
    def _zoom_iso(view, bounds)
      return if bounds.empty?
      target = bounds.center
      radius = bounds.diagonal.to_f / 2 * ZOOM_FACTOR
      direction = Geom::Vector3d.new(1, 1, -1).normalize
      up = direction.cross(Z_AXIS).cross(direction)

      # The narrowest of the view's two angles or sizes holds the sphere
      aspect = view.vpheight > 0 ? view.vpwidth.to_f / view.vpheight : 1.0
      camera = view.camera
      if camera.perspective?
        tan = Math.tan(camera.fov.degrees / 2)
        tan = camera.fov_is_height? ? [ tan, tan * aspect ].min : [ tan, tan / aspect ].min
        distance = radius / Math.sin(Math.atan(tan))
      else
        distance = radius * 2   # Anything outside the sphere
      end

      camera.set(target.offset(direction.reverse, distance), target, up)
      camera.height = radius * 2 / [ aspect, 1.0 ].min unless camera.perspective?
    end

    # The view's camera moves with it : a detached copy.
    def _copy_camera(camera)
      copy = Sketchup::Camera.new(camera.eye, camera.target, camera.up)
      copy.perspective = camera.perspective?
      if camera.perspective?
        copy.fov = camera.fov
      else
        copy.height = camera.height
      end
      copy
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
