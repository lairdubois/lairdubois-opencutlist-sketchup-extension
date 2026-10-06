module Ladb::OpenCutList

  # The geometry of SKP files - the parts of a hardware descriptor - for the
  # test bench of the editor : triangles and hard edges, in inches, in the
  # file's own frame. A file is loaded in an operation aborted right after :
  # the model keeps nothing. Kept per file and modification time.
  class HardwareSkpMeshWorker

    @@meshes = {}

    # Is the given file the one of the given model ? SketchUp can't load a
    # model into itself - nor a copy of it : same GUID.
    def self.open_model?(model, path)
      !model.nil? && !model.path.empty? && File.expand_path(model.path) == File.expand_path(path.gsub('\\', '/'))
    end

    # Loads the given SKP file into the definitions of the given model - to
    # be called in an operation aborted afterwards. Returns the definition.
    def self.load_definition(model, path)
      path = path.gsub('\\', '/')
      Sketchup.version_number >= 2100000000 ? model.definitions.load(path, allow_newer: true) : model.definitions.load(path)
    end

    # The message of the given error, as UTF-8 : SketchUp's may be Latin-1.
    def self.error_message(error)
      message = error.message.dup
      message.force_encoding('UTF-8')
      message = message.force_encoding('ISO-8859-1').encode('UTF-8') unless message.valid_encoding?
      message
    end

    # refs : '$LIB/…' / '$OCL/…' refs or absolute paths.
    def initialize(refs:)

      @refs = refs.is_a?(Array) ? refs.select { |ref| ref.is_a?(String) } : []

    end

    # -----

    def run

      meshes = {}
      @refs.uniq.each do |ref|
        path = PLUGIN.resolve_library_ref(ref)
        unless path.is_a?(String) && File.file?(path) && File.extname(path).downcase == '.skp'
          meshes[ref] = { :error => 'not_found' }
          next
        end
        key = [ path, File.mtime(path).to_i ]
        mesh = @@meshes[key]
        if mesh.nil?
          mesh = _load(path)
          @@meshes[key] = mesh unless mesh.key?(:error)
        end
        meshes[ref] = mesh
      end

      { :meshes => meshes }
    end

    # -----

    private

    def _load(path)
      model = Sketchup.active_model
      return { :error => 'no_model' } if model.nil?
      return { :error => 'open_model' } if self.class.open_model?(model, path)
      model.start_operation('OCL Hardware Mesh', true)
      begin
        definition = self.class.load_definition(model, path)
        faces = []
        edges = []
        _grab(definition.entities, Geom::Transformation.new, faces, edges)
        return { :error => 'empty' } if faces.empty?
        { :faces => faces, :edges => edges }
      rescue StandardError => e
        { :error => 'not_loaded', :message => self.class.error_message(e) }
      ensure
        model.abort_operation
      end
    end

    def _grab(entities, transformation, faces, edges)
      entities.each do |entity|
        next unless entity.visible?
        case entity
        when Sketchup::Face
          mesh = entity.mesh(0)   # Points only
          points = mesh.points.map { |point| point.transform(transformation) }
          mesh.polygons.each do |polygon|
            polygon.each do |index|
              point = points[index.abs - 1]
              faces.push(point.x.to_f, point.y.to_f, point.z.to_f)
            end
          end
        when Sketchup::Edge
          next if entity.soft? || entity.hidden? || entity.faces.empty?
          entity.vertices.each do |vertex|
            point = vertex.position.transform(transformation)
            edges.push(point.x.to_f, point.y.to_f, point.z.to_f)
          end
        when Sketchup::Group, Sketchup::ComponentInstance
          _grab(entity.definition.entities, transformation * entity.transformation, faces, edges)
        end
      end
    end

  end

end
