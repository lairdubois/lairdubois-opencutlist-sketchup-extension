# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : everything is drawn 20 m below the origin in an aborted
# operation.
#
# The SketchUp half of the paneling corpus - the geometry itself is checked
# by test/TC_Ladb_Worker_PanelingCompute.rb, on data, with no model :
#   - the SketchUp path : each corpus shape drawn as faces, as is and in a
#     MIRRORED nested group, read back through
#     PanelingMeshDef.from_face_manipulators, gives the same panels as the
#     data ;
#   - the drawing : every named case's panels drawn by
#     SmartReshapePanelingActionHandler.draw_panel are manifold solids, none
#     overlapping (SketchUp's own intersect) - the same verdict as the data
#     checks.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartReshapePaneling.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartReshapePaneling.rb'
#   PanelingLive.run_sketchup              # one line per shape (as is, mirrored)
#   PanelingLive.run_drawn                 # one line per named case
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

require_relative '../TC_Ladb_Worker_PanelingCompute'

module PanelingLive

  OCL = Ladb::OpenCutList
  HANDLER = OCL::SmartReshapePanelingActionHandler

  Z0 = -20000.mm
  OVERLAP_MAX = PanelingRegression::OVERLAP_MAX
  CUBIC_INCH_TO_LITER = PanelingRegression::CUBIC_INCH_TO_LITER

  def self.with_operation
    model = Sketchup.active_model
    model.start_operation('Paneling fixture', true)
    begin
      yield model
    ensure
      model.abort_operation
    end
  end

  # -- SketchUp path --

  MIRROR = Geom::Transformation.scaling(-1, 1, 1)

  # Each shape drawn as SketchUp faces - as is, then in a MIRRORED nested
  # group - read back through PanelingMeshDef.from_face_manipulators, all
  # its faces paneled flat inward : the same panels (corners) as from the
  # data. [ key, failure or nil ]
  def self.sketchup_results(shapes = PanelingRegression::SHAPES)
    shapes.product([ false, true ]).map { |shape, mirrored|
      failure = nil
      with_operation do |model|
        mesh, _ = PanelingRegression.mesh(shape)
        group = model.active_entities.add_group
        group.transformation = Geom::Transformation.translation([ 0, 0, Z0 ])
        container = mirrored ? group.entities.add_group : group
        container.transformation = MIRROR if mirrored
        mesh.faces.each { |face| container.entities.add_face(mesh.loop_points(face)) }
        container.entities.grep(Sketchup::Face).each do |face|
          data_face = mesh.faces.find { |f| mesh.loop_points(f).all? { |p| face.classify_point(p) != Sketchup::Face::PointOutside && face.classify_point(p) != Sketchup::Face::PointNotOnPlane } }
          face.reverse! if data_face && !face.normal.samedirection?(data_face.normal)
        end
        drawing_def = OCL::CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new([ group ]) ], ignore_faces: false, ignore_edges: false).run
        sketchup_mesh = PanelingRegression::MESH.from_face_manipulators(drawing_def.face_manipulators)

        # The data seen through the mirror : points mirrored, loops reversed
        expected_mesh = mirrored ? PanelingRegression::MESH.new(mesh.points.map { |p| p.transform(MIRROR) }, mesh.faces.map { |f| f.loop.reverse }) : mesh

        fn_corners = lambda { |m| PanelingRegression::WORKER.new(m, m.faces.map(&:index), thickness: -PanelingRegression::THICKNESS.mm).run.map { |pd| (pd.gd_polygons + pd.up_polygons).flatten(1).map { |p| p.to_a.map { |v| v.to_mm.round(2) } }.sort } }
        if sketchup_mesh.faces.size != mesh.faces.size || sketchup_mesh.points.size != mesh.points.size
          failure = "#{sketchup_mesh.faces.size} faces, #{sketchup_mesh.points.size} points, expected #{mesh.faces.size}, #{mesh.points.size}"
        elsif fn_corners.call(sketchup_mesh).sort != fn_corners.call(expected_mesh).sort # Both in the group's space
          failure = "panels differ"
        end
      end
      [ "#{shape}#{mirrored ? ' mirrored' : ''}", failure ]
    }
  end

  def self.run_sketchup(shapes = PanelingRegression::SHAPES)
    sketchup_results(shapes).map { |key, failure| "#{key} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"}" }.join("\n")
  end

  # -- Drawing --

  # Each named case's panels drawn : [ name, failure or nil ] - nil when the
  # drawn panels are manifold and apart exactly when the data checks say so
  def self.drawn_results(names = PanelingRegression::CASES.keys)
    names.map { |name|
      spec = PanelingRegression::CASES[name]
      failure = nil
      with_operation do |model|
        mesh, _, panel_defs, face_indices = PanelingRegression.compute(spec)
        data_failure = PanelingRegression.failure(PanelingRegression.check(mesh, panel_defs, face_indices.size, PanelingRegression.thickness(spec[:outward])), spec)

        group = model.active_entities.add_group
        group.transformation = Geom::Transformation.translation([ 0, 0, Z0 ])
        panels = panel_defs.map { |panel_def|
          panel = group.entities.add_group
          HANDLER.draw_panel(panel.entities, panel_def, mesh.faces[panel_def.face_index].normal, spec[:outward])
          panel
        }
        bad = panels.reject(&:manifold?)
        overlaps = []
        (panels - bad).combination(2).each do |a, b|
          next unless a.bounds.intersect(b.bounds).valid?
          intersection = a.copy.intersect(b.copy)
          next unless intersection && intersection.valid?
          volume = intersection.volume * CUBIC_INCH_TO_LITER * 1000
          overlaps << "#{panels.index(a)}/#{panels.index(b)} #{volume.round(2)}cm³" if volume > OVERLAP_MAX
          intersection.erase!
        end
        drawn_failure = if bad.any?
                          "#{bad.size} non manifold"
                        elsif overlaps.any?
                          "overlaps #{overlaps.join(', ')}"
                        end
        failure = "drawn : #{drawn_failure || 'sound'}, data : #{data_failure || 'sound'}" if drawn_failure.nil? != data_failure.nil?
      end
      [ name, failure ]
    }
  end

  def self.run_drawn(names = PanelingRegression::CASES.keys)
    drawn_results(names).map { |name, failure| "#{name} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"}" }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartReshapePaneling < TestUp::TestCase

    def test_sketchup_path
      PanelingLive.sketchup_results.each do |key, failure|
        assert(failure.nil?, "#{key} : #{failure}")
      end
    end

    def test_drawn_panels
      PanelingLive.drawn_results.each do |name, failure|
        assert(failure.nil?, "#{name} : #{failure}")
      end
    end

  end

end
