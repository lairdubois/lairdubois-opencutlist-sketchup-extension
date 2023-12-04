require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/lib/clippy/clippy'

class TC_Lib_Clippy < TestUp::TestCase

  def test_clippy

    selection = Sketchup.active_model.selection
    faces = selection.grep(Sketchup::Face)

    subjects = faces.first.loops.map { |loop| Ladb::OpenCutList::Clippy.points_to_rpath(loop.vertices.map { |vertex| vertex.position }) }
    clips = faces.last.loops.map { |loop| Ladb::OpenCutList::Clippy.points_to_rpath(loop.vertices.map { |vertex| vertex.position }) }

    solution = Ladb::OpenCutList::Clippy.execute_union(subjects, clips)

    group = Sketchup.active_model.entities.add_group

    solution.each do |rpath|
      points = Ladb::OpenCutList::Clippy.rpath_to_points(rpath)
      face = group.entities.add_face(points)
      group.entities.erase_entities(face) unless Ladb::OpenCutList::Clippy.is_rpath_positive?(rpath)
    end

  end

end
