module Ladb::OpenCutList

  module DxfHelper

    def _dxf(file, code, value)
      file.puts(code.to_s)
      file.puts(value.to_s)
    end

    def _dxf_rect(file, x, y, width, height, layer = 0, stroke_color = nil)

      points = [
        Geom::Point3d.new(x, y, 0),
        Geom::Point3d.new(x + width, y, 0),
        Geom::Point3d.new(x + width, y + height, 0),
        Geom::Point3d.new(x, y + height, 0),
      ]

      _dxf(file, 0, 'LWPOLYLINE')
      _dxf(file, 8, layer)
      _dxf(file, 90, 4)
      _dxf(file, 70, 1) # 1 = This is a closed polyline (or a polygon mesh closed in the M direction)

      points.each do |point|
        _dxf(file, 10, point.x.to_f)
        _dxf(file, 20, point.y.to_f)
      end

      _dxf(file, 0, 'SEQEND')

    end

    def _dxf_line(file, x1, y1, x2, y2, layer = 0, stroke_color = nil)

      _dxf(file, 0, 'LINE')
      _dxf(file, 8, layer)
      _dxf(file, 10, x1)
      _dxf(file, 20, y1)
      _dxf(file, 11, x2)
      _dxf(file, 21, y2)

    end

  end

end