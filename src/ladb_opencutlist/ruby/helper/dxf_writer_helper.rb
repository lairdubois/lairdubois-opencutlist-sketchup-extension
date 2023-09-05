module Ladb::OpenCutList

  require_relative '../constants'

  module DxfWriterHelper

    def _dxf_write(file, code, value)
      file.puts(code.to_s)
      file.puts(value.to_s)
    end

    def _dxf_write_header(file, version = 'AC1014')

      _dxf_write(file, 999, "OpenCutList #{EXTENSION_VERSION}")
      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'HEADER')
      _dxf_write(file, 9, '$ACADVER')
      _dxf_write(file, 1, version)
      _dxf_write(file, 9, '$HANDSEED')
      _dxf_write(file, 5, 'FFFF')
      _dxf_write(file, 0, 'ENDSEC')

    end

    def _dxf_write_tables(file)

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'TABLES')

      _dxf_write(file, 0, 'TABLE')

      _dxf_write(file, 2, 'LAYER')
      _dxf_write(file, 100, 'AcDbSymbolTableRecord')
      _dxf_write(file, 100, 'AcDbLayerTableRecord')
      _dxf_write(file, 2, 'OCL_SHEET')
      _dxf_write(file, 70, 0)
      _dxf_write(file, 62, 1)

      _dxf_write(file, 0, 'ENDTAB')

      _dxf_write(file, 0, 'ENDSEC')

    end

    def _dxf_write_line(file, x1, y1, x2, y2, layer = 0, layer_color = nil)

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-FCEF5726-53AE-4C43-B4EA-C84EB8686A66

      _dxf_write(file, 0, 'LINE')
      _dxf_write(file, 100, 'AcDbEntity')
      _dxf_write(file, 100, 'AcDbLine')
      _dxf_write(file, 8, layer)
      _dxf_write(file, 10, x1)
      _dxf_write(file, 20, y1)
      _dxf_write(file, 11, x2)
      _dxf_write(file, 21, y2)
      _dxf_write(file, 62, layer_color) if layer_color

    end

    def _dxf_write_rect(file, x, y, width, height, layer = 0, layer_color = nil)

      points = [
        Geom::Point3d.new(x, y, 0),
        Geom::Point3d.new(x + width, y, 0),
        Geom::Point3d.new(x + width, y + height, 0),
        Geom::Point3d.new(x, y + height, 0),
      ]

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-748FC305-F3F2-4F74-825A-61F04D757A50

      _dxf_write(file, 0, 'LWPOLYLINE')
      _dxf_write(file, 100, 'AcDbEntity')
      _dxf_write(file, 100, 'AcDbPolyline')
      _dxf_write(file, 8, layer)
      _dxf_write(file, 90, 4) # 4 = Vertex count
      _dxf_write(file, 70, 1) # 1 = This is a closed polyline (or a polygon mesh closed in the M direction)
      _dxf_write(file, 62, layer_color) if layer_color

      points.each do |point|
        _dxf_write(file, 10, point.x.to_f)
        _dxf_write(file, 20, point.y.to_f)
      end

      _dxf_write(file, 0, 'SEQEND')

    end

  end

end