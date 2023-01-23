module Ladb::OpenCutList

  class FaceInfo

    attr_reader :face, :transformation

    def initialize(face, transformation)
      @face = face
      @transformation = transformation
    end

    def get_front_texture_angle

      return 0 if @face.nil? || @face.material.nil? || @face.material.texture.nil?

      tw = @face.material.texture.width
      th = @face.material.texture.height
      uv_helper = @face.get_UVHelper(true, false)
      p0 = Geom::Point3d.new(0, 0)
      p1 = Geom::Point3d.new(1, 0)
      uv0 = uv_helper.get_front_UVQ(p0)
      uv1 = uv_helper.get_front_UVQ(p1)

      uv0.x *= tw
      uv0.y *= th
      uv1.x *= tw
      uv1.y *= th

      v1 = Geom::Vector3d.new((p1 - p0).to_a)
      v2 = Geom::Vector3d.new((uv1 - uv0).to_a)

      v1.x *= -1 unless @face.normal.samedirection?(X_AXIS) || @face.normal.samedirection?(Y_AXIS) || @face.normal.samedirection?(Z_AXIS)

      v1.angle_between(v2)
    end

  end

end