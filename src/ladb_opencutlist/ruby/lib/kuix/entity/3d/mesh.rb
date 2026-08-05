module Ladb::OpenCutList::Kuix

  class Mesh < Entity3d

    attr_accessor :background_color
    attr_accessor :on_top
    attr_reader :cull_face
    attr_reader :offset

    def initialize(id = nil)
      super(id)

      @background_color = nil
      @on_top = false
      @cull_face = CULL_FACE_NONE
      @offset = 0

      @triangles = [] # Array<Geom::Point3d>
      @quads = [] # Array<Geom::Point3d>

      @_triangle_points = []
      @_quad_points = []

      # Per primitive [ nx, ny, nz, ox, oy, oz ] used by the face culling - see #_compute_cull_data
      @_triangle_cull_data = nil
      @_quad_cull_data = nil

      # Culled points cached for the last camera - see #_cull_points
      @_cull_camera_key = nil
      @_culled_triangle_points = nil
      @_culled_quad_points = nil

    end

    def add_triangles(triangles) # Array<Geom::Point3d>
      raise 'Points count must be a multiple of 3' if triangles.length % 3 != 0
      @triangles.concat(triangles)
    end

    def add_quads(quads) # Array<Geom::Point3d>
      raise 'Points count must be a multiple of 4' if quads.length % 4 != 0
      @quads.concat(quads)
    end

    # -- PROPERTIES --

    # Drawing a translucent CLOSED volume blends its near and its far walls on the
    # same pixels : the alpha accumulates and the tint darkens where the walls
    # overlap. SketchUp exposes no face culling for the geometry drawn by a tool,
    # so it is done here : CULL_FACE_BACK keeps only the primitives facing the
    # camera, which leaves a single layer per pixel on a convex volume. Expects a
    # consistently OUTWARD wound mesh.
    def cull_face=(value)
      return if @cull_face == value
      @cull_face = value
      invalidate
    end

    # Two meshes drawn on the same surface are coplanar : the depth test settles
    # them arbitrarily and they z-fight. Moving each primitive away along its own
    # normal by a small distance (in inches, world space) breaks the tie. On a
    # consistently OUTWARD wound closed volume this is a uniform inflation of the
    # shell : the offset mesh strictly encloses the other one, so it wins from
    # every point of view. Unlike #on_top, the depth test still applies : the mesh
    # stays hidden behind the geometry that should occlude it.
    def offset=(value)
      return if @offset == value
      @offset = value
      invalidate
    end

    # -- LAYOUT --

    def do_layout_content(transformation)
      if transformation.identity?
        @_triangle_points = @triangles
        @_quad_points = @quads
      else
        @_triangle_points = @triangles.map { |point| point.transform(transformation) }
        @_quad_points = @quads.map { |point| point.transform(transformation) }
      end
      if @offset != 0 || @cull_face != CULL_FACE_NONE
        # A mirror transformation (negative determinant) reverses the winding of the
        # transformed points : re-reverse the normals computed from them so they keep
        # pointing outward.
        flipped = transformation.xaxis.cross(transformation.yaxis).dot(transformation.zaxis) < 0
      end
      if @offset != 0
        # Fresh arrays : @_triangle_points and @_quad_points can be the source arrays
        # themselves (identity transformation), they must never be offset in place.
        @_triangle_points = _offset_points(@_triangle_points, 3, flipped)
        @_quad_points = _offset_points(@_quad_points, 4, flipped)
      end
      @extents.add(@_triangle_points) unless @_triangle_points.empty?
      @extents.add(@_quad_points) unless @_quad_points.empty?
      if @cull_face == CULL_FACE_NONE
        @_triangle_cull_data = nil
        @_quad_cull_data = nil
      else
        @_triangle_cull_data = _compute_cull_data(@_triangle_points, 3, flipped)
        @_quad_cull_data = _compute_cull_data(@_quad_points, 4, flipped)
      end
      @_cull_camera_key = nil
      super
    end

    # -- RENDER --

    def paint_content(graphics)
      if @cull_face == CULL_FACE_NONE
        triangle_points = @_triangle_points
        quad_points = @_quad_points
      else
        _cull_points(graphics.view)
        triangle_points = @_culled_triangle_points
        quad_points = @_culled_quad_points
      end
      if @on_top
        begin
          graphics.set_drawing_color(@background_color) if @background_color.is_a?(Sketchup::Color)
          graphics.view.draw2d(GL_TRIANGLES, triangle_points.map { |point| graphics.view.screen_coords(point) })
        end unless triangle_points.empty?
        begin
          graphics.set_drawing_color(@background_color) if @background_color.is_a?(Sketchup::Color)
          graphics.view.draw2d(GL_QUADS, quad_points.map { |point| graphics.view.screen_coords(point) })
        end unless quad_points.empty?
      else
        graphics.draw_triangles(
          points: triangle_points,
          fill_color: @background_color
        ) unless triangle_points.empty?
        graphics.draw_quads(
          points: quad_points,
          fill_color: @background_color
        ) unless quad_points.empty?
      end
      super
    end

    # -----

    private

    # Moves each primitive away from the mesh by @offset along its own normal - see #offset=
    # Returns a new Array<Geom::Point3d>, the input array is left untouched.
    def _offset_points(points, stride, flipped)
      return points if points.empty?
      offset = @offset.to_f
      offset_points = []
      index = 0
      while index < points.length
        pa = points[index]
        pb = points[index + 1]
        pc = points[index + 2]
        ax = pa.x.to_f
        ay = pa.y.to_f
        az = pa.z.to_f
        ux = pb.x.to_f - ax
        uy = pb.y.to_f - ay
        uz = pb.z.to_f - az
        vx = pc.x.to_f - ax
        vy = pc.y.to_f - ay
        vz = pc.z.to_f - az
        nx = uy * vz - uz * vy
        ny = uz * vx - ux * vz
        nz = ux * vy - uy * vx
        if flipped
          nx = -nx
          ny = -ny
          nz = -nz
        end
        length = Math.sqrt(nx * nx + ny * ny + nz * nz)
        if length == 0.0 # Degenerated primitive : no normal to move it along
          offset_points.concat(points[index, stride])
        else
          f = offset / length
          dx = nx * f
          dy = ny * f
          dz = nz * f
          stride.times do |i|
            point = points[index + i]
            offset_points << Geom::Point3d.new(point.x.to_f + dx, point.y.to_f + dy, point.z.to_f + dz)
          end
        end
        index += stride
      end
      offset_points
    end

    # Precomputes, for each primitive, its (non normalized - only the sign of the dot
    # product matters) normal and its first vertex. Returns a flat Array<Float>,
    # 6 values per primitive, or nil if there's nothing to cull.
    def _compute_cull_data(points, stride, flipped)
      return nil if points.empty?
      data = []
      index = 0
      while index < points.length
        pa = points[index]
        pb = points[index + 1]
        pc = points[index + 2]
        ax = pa.x.to_f
        ay = pa.y.to_f
        az = pa.z.to_f
        ux = pb.x.to_f - ax
        uy = pb.y.to_f - ay
        uz = pb.z.to_f - az
        vx = pc.x.to_f - ax
        vy = pc.y.to_f - ay
        vz = pc.z.to_f - az
        nx = uy * vz - uz * vy
        ny = uz * vx - ux * vz
        nz = ux * vy - uy * vx
        if flipped
          nx = -nx
          ny = -ny
          nz = -nz
        end
        data << nx << ny << nz << ax << ay << az
        index += stride
      end
      data
    end

    # Refreshes @_culled_triangle_points / @_culled_quad_points for the current
    # camera. Memoized : the result only changes when the camera moves.
    def _cull_points(view)

      camera = view.camera
      perspective = camera.perspective?
      reference = perspective ? camera.eye : camera.direction
      camera_key = [ perspective, reference.x.to_f, reference.y.to_f, reference.z.to_f ]

      return if @_cull_camera_key == camera_key
      @_cull_camera_key = camera_key

      keep_front = @cull_face == CULL_FACE_BACK
      rx = reference.x.to_f
      ry = reference.y.to_f
      rz = reference.z.to_f

      @_culled_triangle_points = _cull_primitives(@_triangle_points, 3, @_triangle_cull_data, keep_front, perspective, rx, ry, rz)
      @_culled_quad_points = _cull_primitives(@_quad_points, 4, @_quad_cull_data, keep_front, perspective, rx, ry, rz)

    end

    # Keeps only the primitives facing the camera (keep_front) or facing away from it.
    # (rx, ry, rz) is the camera eye in perspective projection, its direction otherwise.
    def _cull_primitives(points, stride, data, keep_front, perspective, rx, ry, rz)
      return points if data.nil?
      culled = []
      index = 0
      offset = 0
      while index < points.length
        if perspective
          dx = data[offset + 3] - rx
          dy = data[offset + 4] - ry
          dz = data[offset + 5] - rz
        else
          dx = rx
          dy = ry
          dz = rz
        end
        dot = data[offset] * dx + data[offset + 1] * dy + data[offset + 2] * dz
        culled.concat(points[index, stride]) if dot != 0.0 && ((dot < 0.0) == keep_front) # dot == 0.0 : degenerated or edge on primitive, it paints nothing
        index += stride
        offset += 6
      end
      culled
    end

  end

end
