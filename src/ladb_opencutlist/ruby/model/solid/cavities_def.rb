module Ladb::OpenCutList

  require_relative 'solid_boolean_result_def'
  require_relative 'solid_mesh_def'
  require_relative '../drawing/drawing_def'
  require_relative '../../manipulator/plane_manipulator'
  require_relative '../../worker/common/common_solid_find_cavities_worker'

  # The CAVITIES of a container, as SmartActionHandlerCavitiesHelper
  # #_get_cavities_def detects and keeps them.
  #
  # +own_panel_drawing_defs+ : the APPLIED PANELS the cavities were read
  # BLIND to - see SmartActionHandlerCavitiesHelper#_cavities_own_panel_types. Nothing in the fragments says
  # they are there, which is exactly what they are kept here for.
  #
  # +options_key+ : the reading they were detected with, see
  # SmartActionHandlerCavitiesHelper#_cavities_options_key.
  #
  # +recess_panel_drawing_defs+ : the APPLIED PANELS the openings were made
  # to RECEDE behind - see
  # SmartActionHandlerCavitiesHelper#_cavities_recess_panel_types. The wall a recess
  # leaves is a cap like any opening, and they are what stands behind it.
  #
  # +panel_parts+ : the Part of each panel of +drawing_defs+, by the path of
  # its instance - see #part_of.
  CavitiesDef = Struct.new(:container_path, :result_def, :drawing_defs, :own_panel_drawing_defs, :options_key, :recess_panel_drawing_defs, :panel_parts) do
    def valid?
      result_def.is_a?(SolidBooleanResultDef) && result_def.success?
    end
    # Whether the detection gave up on the container for excess complexity -
    # see CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX.
    def too_complex?
      result_def.is_a?(SolidBooleanResultDef) && result_def.errors.any? { |key, _vars| key == CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX }
    end
    def fragment_defs
      result_def.fragment_defs
    end
    def fragment_defs_for_point(point)
      result_def.fragment_defs_for_point(point)
    end

    # The Part the given panel DrawingDef - a wall #pick_ray landed on - was
    # read from. nil when there is none : no wall, or one of an applied
    # panel, which the cutlist of the cavities leaves out.
    def part_of(drawing_def)
      return nil unless drawing_def.is_a?(DrawingDef) && panel_parts.is_a?(Hash)
      panel_parts[drawing_def.container_path]
    end

    # What a RAY designates in these cavities : [ fragment_def, point,
    # plane_manipulator, drawing_def ] - the compartment it enters, where it
    # first meets a wall of it, that wall read as the picker would have read
    # the face behind it, and the panel it belongs to (nil on a receded
    # opening). nil when it designates none.
    #
    # Picking the cavities rather than the model is what lets a part be
    # fitted in a compartment something else stands in front of - a front panel,
    # a drawer front, anything laid over the opening - without hiding it :
    # the mouths are the cavity's own geometry, and what fills them is not.
    #
    # The ray must ENTER by a mouth, i.e. its first crossing of the
    # compartment must be one of the CAPS the openings stand for (face id
    # 0). That is what keeps a pick READING INTO an opening : aiming at the
    # outside of a carcass crosses no mouth at all - the first thing met is
    # the far side of the panel aimed at - and designates nothing, exactly
    # as it does today.
    def pick_ray(origin, direction)

      picked = nil
      fragment_defs.each do |fragment_def|

        hits = fragment_def.ray_hits(origin, direction)
        next if hits.empty?
        next unless fragment_def.triangle_face_id(hits.first[2]) == 0 || _origin_inside?(fragment_def, origin)   # Entered by something else than a mouth

        # The first WALL met after the mouth - the face the cursor is on, as
        # the picker would have given it if nothing stood in front. One that
        # no panel can be read behind (a cap, or geometry with no
        # provenance) is passed over rather than fatal : the next one along
        # the ray is just as much in the compartment.
        #
        # A cap PAST the mouth is no wall either, unless an applied panel
        # stands behind it : an opening receded to the back of the panel
        # fitted in it is closed by that panel, and aiming at it through the
        # front is aiming at a wall of the compartment.
        point = nil
        plane_manipulator = nil
        drawing_def = nil
        hits.each_with_index do |(_distance, hit_point, triangle_index), hit_index|
          if fragment_def.triangle_face_id(triangle_index).to_i == 0
            next if hit_index == 0   # The mouth the ray came in by, or the eye inside : the wall behind the eye
            plane_manipulator = _recess_plane_manipulator(fragment_def, triangle_index, hit_point)
          else
            plane_manipulator = _wall_plane_manipulator(fragment_def, triangle_index, hit_point)
          end
          next if plane_manipulator.nil?
          point = hit_point
          drawing_def = _wall_drawing_def(fragment_def, triangle_index)
          break
        end
        next if point.nil?   # A cavity crossed through its mouths only : nothing to lean the pick on

        # Compared on the MOUTH, not on the wall : which compartment the
        # user is looking into is settled at its opening, and a shallow one
        # in front of a deep one is the one they see.
        next unless picked.nil? || hits.first[0] < picked[0]
        picked = [ hits.first[0], fragment_def, point, plane_manipulator, drawing_def ]

      end
      return nil if picked.nil?

      picked[1..-1]
    end

    private

    # Whether the ray STARTS inside the given cavity - the camera standing in
    # the compartment it looks at, where there is no mouth left to cross on
    # the way to its walls. Bounds first : the eye is outside every
    # compartment on the vast majority of picks, and that answers those for
    # the price of a box test.
    def _origin_inside?(fragment_def, origin)
      point = origin.is_a?(Geom::Point3d) ? origin : Geom::Point3d.new(origin)
      return false unless fragment_def.bounds.contains?(point)
      fragment_def.contains_point?(point)
    end

    # The wall a ray hit, as the PlaneManipulator a picker would have handed
    # back for the source face behind it : the plane read off the triangle
    # itself - exact, and free of the source face's own extent - carried by
    # the TRANSFORMATION of the panel it comes from, which is what the
    # handlers read the part's own axes on (see
    # #_get_divider_normal_candidates).
    #
    # The panel is found through the triangle's face id : it indexes the
    # operation's face info registry, whose container_def is the panel's own
    # DrawingDef (only a root one bounds a cavity - see
    # SolidBooleanResultDef#fragment_defs_for_face). nil for a wall no panel
    # stands behind, an opening cap included.
    def _wall_plane_manipulator(fragment_def, triangle_index, point)
      return nil unless (drawing_def = _wall_drawing_def(fragment_def, triangle_index)).is_a?(DrawingDef)
      transformation = drawing_def.transformation
      return nil unless transformation.is_a?(Geom::Transformation)
      normal = fragment_def.triangle_normal(triangle_index)
      return nil if normal.nil?

      # Expressed in the panel's own space, since PlaneManipulator brings its
      # plane back to the world through the transformation it is given.
      ti = transformation.inverse
      PlaneManipulator.new([ point.transform(ti), normal.transform(ti) ], transformation)
    end

    # The panel DrawingDef the given triangle of a cavity wall comes from,
    # see #_wall_plane_manipulator. nil for a cap.
    def _wall_drawing_def(fragment_def, triangle_index)
      face_id = fragment_def.triangle_face_id(triangle_index)
      return nil if face_id.nil? || face_id == 0
      face_info_def = fragment_def.face_info_defs[face_id]
      return nil if face_info_def.nil?
      drawing_def = face_info_def.container_def
      drawing_def.is_a?(DrawingDef) ? drawing_def : nil
    end

    # The wall a ray hit on a RECESSED opening, read as #_wall_plane_manipulator
    # reads a panel's : carried by the transformation of the recess panel the
    # hit point lies on - the cap stands against its back. nil when none
    # does : the cap is a real opening.
    def _recess_plane_manipulator(fragment_def, triangle_index, point)
      return nil unless recess_panel_drawing_defs.is_a?(Array)
      normal = fragment_def.triangle_normal(triangle_index)
      return nil if normal.nil?
      margin = SolidMeshDef::TOLERANCE * 10
      recess_panel_drawing_defs.each do |drawing_def|
        next unless drawing_def.is_a?(DrawingDef) && (transformation = drawing_def.transformation).is_a?(Geom::Transformation)
        bounds = drawing_def.bounds
        next if bounds.empty?
        ti = transformation.inverse
        local_point = point.transform(ti)
        next unless (0..2).all? { |axis| local_point[axis] >= bounds.min[axis] - margin && local_point[axis] <= bounds.max[axis] + margin }
        return PlaneManipulator.new([ local_point, normal.transform(ti) ], transformation)
      end
      nil
    end

  end

end
