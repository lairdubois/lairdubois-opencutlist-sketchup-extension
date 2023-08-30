module Ladb::OpenCutList

  module DxfWriterHelper

    def _dxf_write(file, code, value)
      file.puts(code.to_s)
      file.puts(value.to_s)
    end

    def _dxf_write_line(file, x1, y1, x2, y2, layer = 0, layer_color = nil)

      _dxf_write(file, 0, 'LINE')
      _dxf_write(file, 8, layer)
      _dxf_write(file, 10, x1)
      _dxf_write(file, 20, y1)
      _dxf_write(file, 11, x2)
      _dxf_write(file, 21, y2)

    end

    def _dxf_write_rect(file, x, y, width, height, layer = 0, layer_color = nil)

      points = [
        Geom::Point3d.new(x, y, 0),
        Geom::Point3d.new(x + width, y, 0),
        Geom::Point3d.new(x + width, y + height, 0),
        Geom::Point3d.new(x, y + height, 0),
      ]

      _dxf_write(file, 0, 'LWPOLYLINE')
      _dxf_write(file, 8, layer)
      _dxf_write(file, 90, 4)
      _dxf_write(file, 70, 1) # 1 = This is a closed polyline (or a polygon mesh closed in the M direction)

      points.each do |point|
        _dxf_write(file, 10, point.x.to_f)
        _dxf_write(file, 20, point.y.to_f)
      end

      _dxf_write(file, 0, 'SEQEND')

    end

  end

end