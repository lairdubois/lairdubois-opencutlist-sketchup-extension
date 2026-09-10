module Ladb::OpenCutList

  require_relative '../data_container'

  # One flat OPENING of a cavity : the plane it lies on, and the closed
  # contours it draws there — the mouth a front panel, a drawer front or a glass
  # pane has to fill.
  #
  # Built by SolidCavityFragmentDef#opening_defs off the cavity's ENVELOPE
  # CAPS (face id 0), the faces that close the cavity flush with the panel
  # edges where no panel does. The cap is a triangle soup ; what is wanted is
  # its outline, so the contours are the NET boundary of those triangles —
  # every edge two of them share is traversed once each way and cancels, the
  # survivors chain into loops. A rectangular mouth comes out as one loop of
  # four points, whatever the tessellation behind it.
  #
  # Several loops mean the mouth is not simply connected : the outer contour
  # plus one loop per island of panel standing inside it (a mullion crossing
  # a glazed front leaves none — it splits the cavity itself, and each
  # compartment gets its own opening). Their winding tells them apart, see
  # #area.
  class SolidCavityOpeningDef < DataContainer

    attr_reader :normal,  # Geom::Vector3d, unit, pointing OUT of the cavity — the direction a front panel opens towards
                :origin,  # Geom::Point3d, a point of the opening plane (WORLD coordinates)
                :loops    # Array<Array<Geom::Point3d>> closed contours (WORLD coordinates), the closing point NOT repeated

    def initialize(normal, origin, loops)
      @normal = normal
      @origin = origin
      @loops = loops
    end

    # -----

    def empty?
      @loops.empty?
    end

    # The opening plane in SketchUp's [ point, vector ] form, ready for
    # Geom::Point3d#project_to_plane and friends.
    def plane
      @plane ||= [ @origin, @normal ]
    end

    # NET area of the opening in square inches : the outer contour minus its
    # islands. A contour wound counterclockwise as seen from OUTSIDE the
    # cavity (i.e. looking down #normal) counts positive, one wound the other
    # way negative — and the cap triangles, being part of the cavity's own
    # outward wound surface, hand the outer contour the former and an island
    # the latter. Memoized.
    def area
      @area ||= @loops.inject(0.0) { |sum, loop_points| sum + signed_area(loop_points) }
    end

    # The OUTER contour : the loop enclosing all the others, i.e. the widest
    # positively wound one (see #area). nil when the opening has no loop at
    # all. Memoized.
    def outer_loop
      return @outer_loop if defined?(@outer_loop)
      @outer_loop = @loops.max_by { |loop_points| signed_area(loop_points) }
    end

    # Signed area of one closed planar contour, in square inches — positive
    # when wound counterclockwise as seen from outside the cavity. Newell's
    # formula projected on #normal : summing the cross products of the
    # successive edge pairs gives a vector along the contour's own normal
    # whose length is twice the area, so no 2D basis has to be chosen and an
    # OBLIQUE opening (a canted front, anything in a rotated assembly) is
    # measured as exactly as an axis aligned one.
    def signed_area(loop_points)
      return 0.0 if loop_points.length < 3

      nx = ny = nz = 0.0
      loop_points.each_with_index do |point, index|
        following = loop_points[(index + 1) % loop_points.length]
        px, py, pz = point.x.to_f, point.y.to_f, point.z.to_f
        fx, fy, fz = following.x.to_f, following.y.to_f, following.z.to_f
        nx += (py - fy) * (pz + fz)
        ny += (pz - fz) * (px + fx)
        nz += (px - fx) * (py + fy)
      end

      (nx * @normal.x + ny * @normal.y + nz * @normal.z) / 2.0
    end

  end

end
