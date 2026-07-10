module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative 'solid_mesh_def'

  # Result of a boolean operation : fragments on success, i18n error tuples otherwise.
  class SolidBooleanResultDef < DataContainer

    attr_reader :errors,            # Array of i18n tuples [ key, vars ] ; empty on success
                :fragment_defs,     # Array<SolidFragmentDef>
                :curve_info_defs,   # Array<SolidCurveInfoDef> collected from all operands
                :created_entities   # Entities holding the result, filled by the apply phase

    def initialize
      @errors = []
      @fragment_defs = []
      @curve_info_defs = []
      @created_entities = []
    end

    def success?
      @errors.empty?
    end

  end

  # One resulting solid body, in WORLD coordinates.
  # Manifold may output several disjoint bodies (e.g. a subtraction that splits
  # the source in two) : one SolidFragmentDef each.
  class SolidFragmentDef < DataContainer

    attr_reader :vertices,        # Array<Float> flat [ x, y, z, ... ]
                :face_indices,    # Array<Integer> flat, 3 per triangle
                :face_ids,        # Array<Integer> 1 per triangle -> index in @face_info_defs, or nil if no provenance
                :face_info_defs,  # Array<SolidFaceInfoDef> shared registry of the operation
                :src_indices      # Array<Integer> indices (in the operation src list) of the sources this fragment comes from ; empty if unknown

    def initialize(vertices, face_indices, face_ids, face_info_defs, src_indices: [])
      @vertices = vertices
      @face_indices = face_indices
      @face_ids = face_ids.is_a?(Array) && face_ids.length == face_indices.length / 3 ? face_ids : nil
      @face_info_defs = face_info_defs
      @src_indices = src_indices
    end

    # -----

    def empty?
      @face_indices.nil? || @face_indices.empty?
    end

    def triangle_count
      @face_indices.length / 3
    end

    def vertex_count
      @vertices.length / 3
    end

    def points
      @points ||= @vertices.each_slice(3).map { |coords| Geom::Point3d.new(coords) }
    end

    # Yields [ SolidFaceInfoDef or nil, Array of triangles (Array<Geom::Point3d>) ],
    # one batch per original face. Triangles without provenance are batched under nil.
    def each_triangle_batch
      pts = points
      batches = {}
      @face_indices.each_slice(3).with_index do |indices, triangle_index|
        face_info_def = @face_ids.nil? ? nil : @face_info_defs[@face_ids[triangle_index]]
        (batches[face_info_def] ||= []) << indices.map { |index| pts[index] }
      end
      batches.each { |face_info_def, triangles| yield face_info_def, triangles }
    end

  end

end
