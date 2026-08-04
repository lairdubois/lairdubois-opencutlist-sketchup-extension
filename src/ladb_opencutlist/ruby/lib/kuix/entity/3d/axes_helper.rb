module Ladb::OpenCutList::Kuix

  class AxesHelper < Group

    attr_accessor :box_0, :box_x, :box_y, :box_z
    attr_accessor :pixel_size, :pixel_section_size

    def initialize(pixel_length_size = 50, pixel_section_size = 2, color_0 = COLOR_BLACK, color_x = COLOR_X, color_y = COLOR_Y, color_z = COLOR_Z, id = '')
      super(id)

      @pixel_size = pixel_length_size           # Axis length, expressed in pixels
      @pixel_section_size = pixel_section_size  # Axis section, expressed in pixels

      # Bounds are computed at layout time to keep length and section fixed in pixels

      @box_0 = BoxFillMotif3d.new
      @box_0.color = color_0
      append(@box_0)

      @box_x = BoxFillMotif3d.new
      @box_x.color = color_x
      append(@box_x)

      @box_y = BoxFillMotif3d.new
      @box_y.color = color_y
      append(@box_y)

      @box_z = BoxFillMotif3d.new
      @box_z.color = color_z
      append(@box_z)

    end

    # -- LAYOUT --

    def do_layout(transformation)

      # Transformation applied to boxes = parent chain + own
      t = transformation * @transformation
      ta = t.to_a
      tw = ta[15]

      # Scaling factors of the transformation, extracted to be cancelled below.
      # Without this, a scaled container would stretch the boxes.
      fx = Geom::Vector3d.new(ta[0], ta[1], ta[2]).length.to_f / tw
      fy = Geom::Vector3d.new(ta[4], ta[5], ta[6]).length.to_f / tw
      fz = Geom::Vector3d.new(ta[8], ta[9], ta[10]).length.to_f / tw

      unless fx == 0 || fy == 0 || fz == 0

        view = Sketchup.active_model.active_view
        origin = ORIGIN.transform(t)

        # Pixel sizes converted to model sizes at helper's origin
        inch_length = view.pixels_to_model(@pixel_size, origin)
        inch_section = view.pixels_to_model(@pixel_section_size, origin)

        # Sizes expressed in boxes local space
        lx, ly, lz = inch_length / fx, inch_length / fy, inch_length / fz
        sx, sy, sz = inch_section / fx, inch_section / fy, inch_section / fz
        hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0

        @box_0.bounds.origin.set!(-hx, -hy, -hz)
        @box_0.bounds.size.set!(sx, sy, sz)

        @box_x.bounds.origin.set!(hx, -hy, -hz)
        @box_x.bounds.size.set!(lx, sy, sz)

        @box_y.bounds.origin.set!(-hx, hy, -hz)
        @box_y.bounds.size.set!(sx, ly, sz)

        @box_z.bounds.origin.set!(-hx, -hy, hz)
        @box_z.bounds.size.set!(sx, sy, lz)

      end

      super
    end

  end

end
