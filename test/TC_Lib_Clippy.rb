require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/lib/clippy/clippy'

class TC_Lib_Clippy < TestUp::TestCase

  def test_clippy

    selection = Sketchup.active_model.selection
    faces = selection.grep(Sketchup::Face)

    subjects = faces.first.loops.map { |loop| Ladb::OpenCutList::Clippy.points_to_path(loop.vertices.map { |vertex| vertex.position }) }
    clips = faces.last.loops.map { |loop| Ladb::OpenCutList::Clippy.points_to_path(loop.vertices.map { |vertex| vertex.position }) }

    solution = Ladb::OpenCutList::Clippy.union(subjects, clips)

    group = Sketchup.active_model.entities.add_group

    solution.each do |path|
      points = Ladb::OpenCutList::Clippy.path_to_points(path)
      face = group.entities.add_face(points)
      group.entities.erase_entities(face) unless Ladb::OpenCutList::Clippy.ccw?(points)
    end

  end

end
