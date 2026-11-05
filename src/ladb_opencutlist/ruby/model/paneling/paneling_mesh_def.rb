module Ladb::OpenCutList

  # The polyhedral mesh CommonPanelingComputeWorker panels : points, and
  # faces as loops of point indices. Pure geometry - no SketchUp entity -
  # except #from_face_manipulators, which reads it from a decomposition and
  # keeps the way back to the entities.
  #
  # Invariants : each face loop runs counter-clockwise around its normal
  # (outward), two faces sharing an edge share its two point indices. An edge
  # is the sorted pair of its point indices (see #edge_key).
  class PanelingMeshDef

    Face = Struct.new(:index, :loop, :position, :normal) do

      def plane
        [ position, normal ]
      end

    end

    attr_reader :points, :faces, :face_manipulators

    # +loops+ : Array of point index Arrays ; +normals+ / +positions+ : one
    # per loop, the loop's own normal (Newell) / first point if nil.
    # +vertex_edges+ : Hash point index => its edges in a given order (the
    # first edge of a vertex decides the joint of faces sharing only that
    # vertex), else the order the loops meet them.
    def initialize(points, loops, normals: nil, positions: nil, vertex_edges: nil)
      @points = points
      @faces = loops.each_with_index.map { |loop, index|
        normal = normals.nil? ? PanelingMeshDef.loop_normal(points, loop) : normals[index]
        position = positions.nil? ? points[loop.first] : positions[index]
        Face.new(index, loop, position, normal.normalize)
      }

      @edge_faces = {}
      @vertex_faces = {}
      @vertex_edges = {}
      @faces.each do |face|
        face.loop.each_with_index do |vertex, i|
          edge = PanelingMeshDef.edge_key(vertex, face.loop[(i + 1) % face.loop.size])
          (@edge_faces[edge] ||= []) << face
          (@vertex_faces[vertex] ||= []) << face
          edge.each { |v| (@vertex_edges[v] ||= []) << edge unless @vertex_edges[v] && @vertex_edges[v].include?(edge) }
        end
      end
      vertex_edges.each { |vertex, edges| @vertex_edges[vertex] = edges } unless vertex_edges.nil?

      @face_manipulators = nil
      @vertex_indices = nil
    end

    def self.edge_key(a, b)
      a < b ? [ a, b ] : [ b, a ]
    end

    # Newell normal of the loop (not normalized)
    def self.loop_normal(points, loop)
      x = y = z = 0.0
      loop.each_with_index do |index, i|
        p1 = points[index]
        p2 = points[loop[(i + 1) % loop.size]]
        x += (p1.y - p2.y) * (p1.z + p2.z)
        y += (p1.z - p2.z) * (p1.x + p2.x)
        z += (p1.x - p2.x) * (p1.y + p2.y)
      end
      Geom::Vector3d.new(x, y, z)
    end

    # -- Topology --

    def loop_points(face)
      face.loop.map { |index| @points[index] }
    end

    def face_edges(face)
      face.loop.each_with_index.map { |vertex, i| PanelingMeshDef.edge_key(vertex, face.loop[(i + 1) % face.loop.size]) }
    end

    def edge_faces(edge)
      @edge_faces[edge] || []
    end

    def vertex_faces(vertex)
      @vertex_faces[vertex] || []
    end

    def vertex_edges(vertex)
      @vertex_edges[vertex] || []
    end

    def common_edge(vertex_1, vertex_2)
      edge = PanelingMeshDef.edge_key(vertex_1, vertex_2)
      @edge_faces.key?(edge) ? edge : nil
    end

    # +edge+ as a vector, run in +face+'s loop direction
    def edge_direction_in(edge, face)
      loop = face.loop
      loop.each_with_index do |vertex, i|
        next_vertex = loop[(i + 1) % loop.size]
        return @points[vertex].vector_to(@points[next_vertex]) if PanelingMeshDef.edge_key(vertex, next_vertex) == edge
      end
      nil
    end

    # -- SketchUp --

    # The mesh of the outer loops of +face_manipulators+, in their container
    # space : a SketchUp vertex seen through one transformation is one point.
    def self.from_face_manipulators(face_manipulators)
      points = []
      vertex_indices = {}
      loops = []
      fn_index = lambda { |vertex, transformation|
        key = [ vertex, transformation.to_a ]
        vertex_indices[key] ||= begin
          points << vertex.position.transform(transformation)
          points.size - 1
        end
      }
      face_manipulators.each do |fm|
        loop = fm.face.outer_loop.vertices.map { |vertex| fn_index.call(vertex, fm.transformation) }
        loop.reverse! if PanelingMeshDef.loop_normal(points, loop).dot(fm.normal) < 0 # Mirrored instance
        loops << loop
      end

      # SketchUp's vertex edge order
      vertex_edges = {}
      vertex_indices.each do |(vertex, transformation_a), index|
        vertex_edges[index] = vertex.edges.map { |edge|
          other = vertex_indices[[ edge.other_vertex(vertex), transformation_a ]]
          other.nil? ? nil : PanelingMeshDef.edge_key(index, other)
        }.compact
      end

      mesh = PanelingMeshDef.new(points, loops,
                                 normals: face_manipulators.map(&:normal),
                                 positions: face_manipulators.map(&:position),
                                 vertex_edges: vertex_edges)
      mesh.instance_variable_set(:@face_manipulators, face_manipulators.to_a)
      mesh.instance_variable_set(:@vertex_indices, vertex_indices)
      mesh
    end

    # The face index of +face_manipulator+ (from_face_manipulators only)
    def face_index_of(face_manipulator)
      @face_manipulators.nil? ? nil : @face_manipulators.index(face_manipulator)
    end

    # The edge keys of a SketchUp +edge+, one per transformation it is seen
    # through in the mesh (from_face_manipulators only)
    def edge_keys_of(edge)
      return [] if @vertex_indices.nil?
      @vertex_indices.map { |(vertex, transformation_a), a|
        next nil unless vertex == edge.start
        b = @vertex_indices[[ edge.end, transformation_a ]]
        b.nil? ? nil : common_edge(a, b)
      }.compact
    end

  end

end
