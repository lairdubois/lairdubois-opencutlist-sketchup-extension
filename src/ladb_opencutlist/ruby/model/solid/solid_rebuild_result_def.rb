module Ladb::OpenCutList

  require_relative '../data_container'

  # Result of a solid rebuilt from construction lines : the created container
  # and what the rebuild had to say about it, or i18n error tuples on failure.
  #
  # The counters are the diagnosis the caller reports to the user : a drawing
  # that does not close leaves naked edges, one whose loops overlap leaves non
  # manifold ones, and both are legitimate outcomes of a rebuild — the worker
  # only fails when there is nothing to build at all.
  class SolidRebuildResultDef < DataContainer

    attr_reader :errors,               # Array of i18n tuples [ key, vars ] ; empty on success
                :created_entities,     # Array<Sketchup::Entity> containers created to hold the result ; empty when it landed in the caller's own target entities

                :faces,                # Array<Sketchup::Face> the rebuild built, wherever it landed
                :edges                 # Array<Sketchup::Edge> ditto — erasing those takes the faces with them, which is how a caller undoes the rebuild

    attr_accessor :container,          # Sketchup::Group holding the result, nil when the caller provided its own target entities

                  :cline_count,        # Construction lines collected from the sources
                  :ignored_count,      # Of those, the ones no segment could be made of (infinite ones in :ignore mode, degenerate ones)
                  :clipped_count,      # Of those, the infinite / semi infinite ones clipped to the drawing bounds
                  :split_count,        # Transversal crossings found and split (SketchUp only splits at vertices, see the worker doc)

                  :edge_count,         # Edges left in the result
                  :face_count,         # Faces left in the result
                  :inner_face_count,   # Faces the shell walk did not reach : removed, or kept when keep_inner_faces
                  :pruned_edge_count,  # Face less edges removed

                  :shell_count,        # Connected face components found
                  :naked_edge_count,   # Edges bounding a single face : the drawing does not close there
                  :non_manifold_edge_count,  # Edges bounding 3 faces or more, after the inner faces were removed
                  :reversed_face_count,      # Faces the orientation pass had to reverse

                  :volume              # Enclosed volume in cubic inches, by the divergence theorem over the oriented faces ; meaningful when #closed?

    def initialize
      @errors = []
      @created_entities = []

      @faces = []
      @edges = []

      @container = nil

      @cline_count = 0
      @ignored_count = 0
      @clipped_count = 0
      @split_count = 0

      @edge_count = 0
      @face_count = 0
      @inner_face_count = 0
      @pruned_edge_count = 0

      @shell_count = 0
      @naked_edge_count = 0
      @non_manifold_edge_count = 0
      @reversed_face_count = 0

      @volume = 0.0
    end

    def success?
      @errors.empty?
    end

    # True when every face edge is shared by exactly two faces : the rebuilt
    # geometry encloses a volume, and #volume means something.
    def closed?
      @face_count > 0 && @naked_edge_count == 0 && @non_manifold_edge_count == 0
    end

  end

end
