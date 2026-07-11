module Ladb::OpenCutList

  require_relative '../../lib/fiddle/meshy/meshy'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../model/solid/solid_mesh_def'
  require_relative '../../model/solid/solid_boolean_result_def'

  # Boolean operations on solids, powered by the Meshy native lib (Manifold).
  #
  # Pure computation : consumes DrawingDefs — single or arrays, whose face
  # manipulators may span nested sub containers — and produces a
  # SolidBooleanResultDef. No entity is read or written.
  #
  # The whole geometric pipeline (validation, winding, plane canonicalization,
  # snapping, tilted-shared-plane nudging, boolean, decomposition into disjoint
  # bodies) runs in Meshy : the Ruby side only extracts meshes from the drawing
  # defs and carries the face metadata registry (materials, layers, surfaces).
  #
  # Each resulting fragment carries the indices (in the src drawing defs list)
  # of the sources it comes from (SolidFragmentDef#src_indices), so the caller
  # can rebuild every fragment inside its original container.
  class CommonSolidBooleanWorker

    OPERATION_UNION = 'union'.freeze
    OPERATION_SUBTRACTION = 'subtraction'.freeze
    OPERATION_INTERSECTION = 'intersection'.freeze

    Meshy = Fiddle::Meshy

    def initialize(src_drawing_defs, cut_drawing_defs,

                   operation: OPERATION_UNION,
                   validate: true

    )

      @src_drawing_defs = Array(src_drawing_defs)
      @cut_drawing_defs = Array(cut_drawing_defs)

      @operation = operation
      @validate = validate

    end

    # -----

    def run
      result_def = SolidBooleanResultDef.new

      unless (@src_drawing_defs + @cut_drawing_defs).all? { |drawing_def| drawing_def.is_a?(DrawingDef) }
        result_def.errors << [ 'default.error' ]
        return result_def
      end
      unless Meshy.available?
        result_def.errors << [ 'core.error.exception', { :error => "Can't load Meshy" } ]
        return result_def
      end

      # Meshes are extracted in WORLD coordinates : each drawing def may have its
      # own transformation, the world is the only space common to all operands.
      src_mesh_defs = @src_drawing_defs.map { |drawing_def| SolidMeshDef.from_drawing_def(drawing_def) }
      cut_mesh_defs = @cut_drawing_defs.map { |drawing_def| SolidMeshDef.from_drawing_def(drawing_def) }

      # Curves are not propagated through Manifold (provenance is per-triangle only):
      # collect their world-coordinates segments here for geometric re-attribution
      # at rebuild time.
      (src_mesh_defs + cut_mesh_defs).each { |mesh_def| result_def.curve_info_defs.concat(mesh_def.curve_info_defs) }

      # Merge all face info registries into a single one, offsetting ids accordingly,
      # so that fragment face ids can be resolved whatever input mesh they come from.
      # Src id ranges are kept aside to reattribute each fragment to its sources.
      face_info_defs = []
      src_id_ranges = []
      fn_serialize = lambda { |mesh_def, id_ranges = nil|
        id_offset = face_info_defs.length
        meshy_hash = mesh_def.to_meshy_hash(id_offset: id_offset)
        face_info_defs.concat(mesh_def.face_info_defs)
        id_ranges << (id_offset...face_info_defs.length) unless id_ranges.nil?
        meshy_hash
      }

      input = {
        :operation => @operation,
        :validate => @validate,
        :tolerance => SolidMeshDef::TOLERANCE,
        :src_meshes => src_mesh_defs.map { |mesh_def| fn_serialize.call(mesh_def, src_id_ranges) },
        :cut_meshes => cut_mesh_defs.map { |mesh_def| fn_serialize.call(mesh_def) }
      }

      # Debug : entrée réellement envoyée (meshes bruts, AVANT le snapping fait dans Meshy)
      # File.write(File.join(Meshy.lib_dir, 'input.json'), JSON.pretty_generate(input))

      output = Meshy.operate(input)

      # Debug : sortie brute de Manifold, AVANT reconstruction SketchUp
      # File.write(File.join(Meshy.lib_dir, 'output.json'), JSON.pretty_generate(output))

      if output['error']
        result_def.errors << [ 'core.error.exception', { :error => output['error'] } ]
      elsif output['errors'].is_a?(Array)
        output['errors'].each do |error|
          if error['count']
            result_def.errors << [ "core.solid.error.#{error['code']}", { :count => error['count'] } ]
          else
            result_def.errors << [ "core.solid.error.#{error['code']}" ]
          end
        end
      elsif output['fragments'].is_a?(Array)
        output['fragments'].each do |fragment|
          fragment_def = SolidFragmentDef.new(
            fragment['vertices'], fragment['face_indices'], fragment['face_ids'], face_info_defs,
            src_indices: _src_indices(fragment['face_ids'], src_id_ranges)
          )
          result_def.fragment_defs << fragment_def unless fragment_def.empty?
        end
      end

      result_def
    end

    private

    # Indices of the src drawing defs whose faces appear in the given fragment
    # face ids. Faces contributed by cut meshes (the cut imprint) are ignored.
    def _src_indices(face_ids, src_id_ranges)
      return [] unless face_ids.is_a?(Array)
      face_ids.uniq.map { |face_id|
        src_id_ranges.index { |id_range| id_range.cover?(face_id) }
      }.compact.uniq.sort
    end

  end

end