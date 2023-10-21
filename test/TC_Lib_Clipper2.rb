require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/lib/clippy/clippy'

class TC_Lib_Clippy < TestUp::TestCase

  def test_clipper

    Ladb::OpenCutList::Clippy.clear

    selection = Sketchup.active_model.selection
    faces = selection.grep(Sketchup::Face)

    faces.first.loops.each do |loop|
      coords = Ladb::OpenCutList::Clippy.points_to_coords(loop.vertices.map { |vertex| vertex.position })
      Ladb::OpenCutList::Clippy.append_subject(coords)
    end

    faces.last.loops.each do |loop|
      coords = Ladb::OpenCutList::Clippy.points_to_coords(loop.vertices.map { |vertex| vertex.position })
      Ladb::OpenCutList::Clippy.append_clip(coords)
    end

    solution = Ladb::OpenCutList::Clippy.compute_union

    group = Sketchup.active_model.entities.add_group

    solution.each do |coords|
      points = Ladb::OpenCutList::Clippy.coords_to_points(coords)
      face = group.entities.add_face(points)
      group.entities.erase_entities(face) unless Ladb::OpenCutList::Clippy.ccw?(points)
    end

  end

end
