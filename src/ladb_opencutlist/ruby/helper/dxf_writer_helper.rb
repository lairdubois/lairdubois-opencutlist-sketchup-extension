module Ladb::OpenCutList

  require_relative '../constants'

  module DxfWriterHelper

    def _dxf_write(file, code, value)
      file.puts(code.to_s.rjust(3))
      file.puts(value.is_a?(Integer) ? value.to_s.rjust(6) : value.to_s)
    end

    def _dxf_write_header(file, min = Geom::Point3d.new, max = Geom::Point3d.new(1000.0, 1000.0, 1000.0), layer_defs = [])  # layer_defs = [ { :name => NAME, :color => COLOR }, ... ]

      layer_defs = [ { :name => '0'} ] + layer_defs

      _dxf_write(file, 999, "Created from OpenCutList #{EXTENSION_VERSION}")

      # HEADER

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'HEADER')
        _dxf_write(file, 9, '$ACADVER')
        _dxf_write(file, 1, 'AC1004')
        _dxf_write(file, 9, '$INSBASE')
        _dxf_write(file, 10, 0.0)
        _dxf_write(file, 20, 0.0)
        _dxf_write(file, 30, 0.0)
        _dxf_write(file, 9, '$EXTMIN')
        _dxf_write(file, 10, min.x.to_f)
        _dxf_write(file, 20, min.y.to_f)
        _dxf_write(file, 30, min.z.to_f)
        _dxf_write(file, 9, '$EXTMAX')
        _dxf_write(file, 10, max.x.to_f)
        _dxf_write(file, 20, max.y.to_f)
        _dxf_write(file, 30, max.z.to_f)
        _dxf_write(file, 9, '$LIMMIN')
        _dxf_write(file, 10, min.x.to_f)
        _dxf_write(file, 20, min.y.to_f)
        _dxf_write(file, 9, '$LIMMAX')
        _dxf_write(file, 10, max.x.to_f)
        _dxf_write(file, 20, max.y.to_f)
        _def_write_header_value(file, '$ORTHOMODE', 70, 0)
        _def_write_header_value(file, '$REGENMODE', 70, 1)
        _def_write_header_value(file, '$FILLMODE', 70, 1)
        _def_write_header_value(file, '$QTEXTMODE', 70, 0)
        _def_write_header_value(file, '$DRAGMODE', 70, 2)
        _def_write_header_value(file, '$LTSCALE', 40, 1.0)
        _def_write_header_value(file, '$OSMODE', 70, 37)
        _def_write_header_value(file, '$ATTMODE', 70, 1)
        _def_write_header_value(file, '$TEXTSIZE', 40, 0.2)
        _def_write_header_value(file, '$TRACEWID', 40, 0.05)
        _def_write_header_value(file, '$TEXTSTYLE', 7, 'STANDARD')
        _def_write_header_value(file, '$CLAYER', 8, '0')
        _def_write_header_value(file, '$CELTYPE', 6, 'BYBLOCK')
        _def_write_header_value(file, '$CECOLOR', 62, 256)
        _def_write_header_value(file, '$DIMSCALE', 40, 1.0)
        _def_write_header_value(file, '$DIMASZ', 40, 0.18)
        _def_write_header_value(file, '$DIMEXO', 40, 0.0625)
        _def_write_header_value(file, '$DIMDLI', 40, 0.38)
        _def_write_header_value(file, '$DIMRND', 40, 0.0)
        _def_write_header_value(file, '$DIMDLE', 40, 0.0)
        _def_write_header_value(file, '$DIMEXE', 40, 0.18)
        _def_write_header_value(file, '$DIMTP', 40, 0.0)
        _def_write_header_value(file, '$DIMTM', 40, 0.0)
        _def_write_header_value(file, '$DIMTXT', 40, 0.18)
        _def_write_header_value(file, '$DIMCEN', 40, 0.09)
        _def_write_header_value(file, '$DIMTSZ', 40, 0.0)
        _def_write_header_value(file, '$DIMTOL', 70, 0)
        _def_write_header_value(file, '$DIMLIM', 70, 0)
        _def_write_header_value(file, '$DIMTIH', 70, 1)
        _def_write_header_value(file, '$DIMTOH', 70, 1)
        _def_write_header_value(file, '$DIMSE1', 70, 0)
        _def_write_header_value(file, '$DIMSE2', 70, 0)
        _def_write_header_value(file, '$DIMTAD', 70, 0)
        _def_write_header_value(file, '$DIMZIN', 70, 0)
        _def_write_header_value(file, '$DIMBLK', 1, '')
        _def_write_header_value(file, '$DIMASO', 70, 1)
        _def_write_header_value(file, '$DIMSHO', 70, 1)
        _def_write_header_value(file, '$DIMPOST', 1, '')
        _def_write_header_value(file, '$DIMAPOST', 1, '')
        _def_write_header_value(file, '$DIMALT', 70, 0)
        _def_write_header_value(file, '$DIMALTD', 70, 2)
        _def_write_header_value(file, '$DIMALTF', 40, 25.4)
        _def_write_header_value(file, '$DIMLFAC', 40, 1.0)
        _def_write_header_value(file, '$DIMTOFL', 70, 0)
        _def_write_header_value(file, '$DIMTVP', 40, 0.0)
        _def_write_header_value(file, '$DIMTIX', 70, 0)
        _def_write_header_value(file, '$DIMSOXD', 70, 0)
        _def_write_header_value(file, '$DIMSAH', 70, 0)
        _def_write_header_value(file, '$DIMBLK1', 1, '')
        _def_write_header_value(file, '$DIMBLK2', 1, '')
        _def_write_header_value(file, '$LUNITS', 70, 2)
        _def_write_header_value(file, '$LUPREC', 70, 4)
        _def_write_header_value(file, '$SKETCHINC', 40, 0.1)
        _def_write_header_value(file, '$FILLETRAD', 40, 0.0)
        _def_write_header_value(file, '$AUNITS', 70, 0)
        _def_write_header_value(file, '$AUPREC', 70, 0)
        _def_write_header_value(file, '$MENU', 1, '.')
        _def_write_header_value(file, '$ELEVATION', 40, 0.0)
        _def_write_header_value(file, '$THICKNESS', 40, 0.0)
        _def_write_header_value(file, '$LIMCHECK', 70, 0)
        _def_write_header_value(file, '$CHAMFERA', 40, 0.0)
        _def_write_header_value(file, '$CHAMFERB', 40, 0.0)
        _def_write_header_value(file, '$SKPOLY', 70, 0)
        _def_write_header_value(file, '$TDCREATE', 40,  DateTime.now.jd.to_f)
        _def_write_header_value(file, '$TDUPDATE', 40, DateTime.now.jd.to_f)
        _def_write_header_value(file, '$TDINDWG', 40, '0.0000000116')
        _def_write_header_value(file, '$TDUSRTIMER', 40, '0.0000000116')
        _def_write_header_value(file, '$USRTIMER', 70, 1)
        _def_write_header_value(file, '$ANGBASE', 50, 0.0)
        _def_write_header_value(file, '$ANGDIR', 70, 0)
        _def_write_header_value(file, '$PDMODE', 70, 0)
        _def_write_header_value(file, '$PDSIZE', 40, 0.0)
        _def_write_header_value(file, '$PLINEWID', 40, 0.0)
        _def_write_header_value(file, '$COORDS', 70, 1)
        _def_write_header_value(file, '$SPLFRAME', 70, 0)
        _def_write_header_value(file, '$SPLINETYPE', 70, 6)
        _def_write_header_value(file, '$SPLINESEGS', 70, 8)
        _def_write_header_value(file, '$ATTDIA', 70, 0)
        _def_write_header_value(file, '$ATTREQ', 70, 1)
        _def_write_header_value(file, '$SURFTAB1', 70, 6)
        _def_write_header_value(file, '$SURFTAB2', 70, 6)
        _def_write_header_value(file, '$SURFTYPE', 70, 6)
        _def_write_header_value(file, '$SURFU', 70, 6)
        _def_write_header_value(file, '$SURFV', 70, 6)
        _def_write_header_value(file, '$UCSNAME', 2, '')
        _dxf_write(file, 9, '$UCSORG')
        _dxf_write(file, 10, 0.0)
        _dxf_write(file, 20, 0.0)
        _dxf_write(file, 30, 0.0)
        _dxf_write(file, 9, '$UCSXDIR')
        _dxf_write(file, 10, 1.0)
        _dxf_write(file, 20, 0.0)
        _dxf_write(file, 30, 0.0)
        _dxf_write(file, 9, '$UCSYDIR')
        _dxf_write(file, 10, 0.0)
        _dxf_write(file, 20, 1.0)
        _dxf_write(file, 30, 0.0)
        _def_write_header_value(file, '$USERI1', 70, 0)
        _def_write_header_value(file, '$USERI2', 70, 0)
        _def_write_header_value(file, '$USERI3', 70, 0)
        _def_write_header_value(file, '$USERI4', 70, 0)
        _def_write_header_value(file, '$USERI5', 70, 0)
        _def_write_header_value(file, '$USERR1', 40, 0.0)
        _def_write_header_value(file, '$USERR2', 40, 0.0)
        _def_write_header_value(file, '$USERR3', 40, 0.0)
        _def_write_header_value(file, '$USERR4', 40, 0.0)
        _def_write_header_value(file, '$USERR5', 40, 0.0)
        _def_write_header_value(file, '$WORLDVIEW', 70, 1)
      _dxf_write(file, 0, 'ENDSEC')

      # TABLES

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'TABLES')

        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'LTYPE')
        _dxf_write(file, 70, 1)
        _dxf_write(file, 0, 'LTYPE')
        _dxf_write(file, 2, 'CONTINUOUS')
        _dxf_write(file, 70, 0)
        _dxf_write(file, 3, 'Solid line')
        _dxf_write(file, 72, 65)
        _dxf_write(file, 73, 0)
        _dxf_write(file, 40, 0.0)
        _dxf_write(file, 0, 'ENDTAB')

        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'LAYER')
        _dxf_write(file, 70, layer_defs.length)
        layer_defs.each do |layer_def|
          _dxf_write(file, 0, 'LAYER')
          _dxf_write(file, 2, layer_def[:name])
          _dxf_write(file, 70, 0)
          _dxf_write(file, 62, layer_def[:color] ? layer_def[:color] : 7 )  # Docs : https://ezdxf.mozman.at/docs/concepts/aci.html
          _dxf_write(file, 6, 'CONTINUOUS')
        end
        _dxf_write(file, 0, 'ENDTAB')

        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'STYLE')
        _dxf_write(file, 70, 1)
        _dxf_write(file, 0, 'STYLE')
        _dxf_write(file, 2, 'STANDARD')
        _dxf_write(file, 70, 0)
        _dxf_write(file, 40, 0.0)
        _dxf_write(file, 41, 1.0)
        _dxf_write(file, 50, 0.0)
        _dxf_write(file, 71, 0)
        _dxf_write(file, 42, 0.2)
        _dxf_write(file, 3, 'txt')
        _dxf_write(file, 4, '')
        _dxf_write(file, 0, 'ENDTAB')

        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'VIEW')
        _dxf_write(file, 70, 0)
        _dxf_write(file, 0, 'ENDTAB')

      _dxf_write(file, 0, 'ENDSEC')

      # BLOCKS

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'BLOCKS')
      _dxf_write(file, 0, 'ENDSEC')

    end

    def _def_write_header_value(file, key, code, value)
      _dxf_write(file, 9, key)
      _dxf_write(file, code, value)
    end

    def _dxf_write_line(file, x1, y1, x2, y2, layer = 0)

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-FCEF5726-53AE-4C43-B4EA-C84EB8686A66

      _dxf_write(file, 0, 'LINE')
      _dxf_write(file, 8, layer)
      _dxf_write(file, 10, x1)
      _dxf_write(file, 20, y1)
      _dxf_write(file, 11, x2)
      _dxf_write(file, 21, y2)

    end

    def _dxf_write_circle(file, cx, cy, r, layer = 0)

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-8663262B-222C-414D-B133-4A8506A27C18

      _dxf_write(file, 0, 'CIRCLE')
      _dxf_write(file, 8, layer)
      _dxf_write(file, 10, cx)
      _dxf_write(file, 20, cy)
      _dxf_write(file, 40, r)

    end

    def _dxf_write_rect(file, x, y, width, height, layer = 0)

      points = [
        Geom::Point3d.new(x, y),
        Geom::Point3d.new(x + width, y),
        Geom::Point3d.new(x + width, y + height),
        Geom::Point3d.new(x, y + height),
      ]

      _dxf_write_polygon(file, points, layer)

    end

    def _dxf_write_polygon(file, points, layer = 0)

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-ABF6B778-BE20-4B49-9B58-A94E64CEFFF3

      _dxf_write(file, 0, 'POLYLINE')
      _dxf_write(file, 8, layer)
      _dxf_write(file, 66, 1) # Deprecated
      _dxf_write(file, 70, 1) # 1 = Closed

      points.each do |point|

        _dxf_write(file, 0, 'VERTEX')
        _dxf_write(file, 8, layer)
        _dxf_write(file, 10, point.x.to_f)
        _dxf_write(file, 20, point.y.to_f)

      end

      _dxf_write(file, 0, 'SEQEND')
      _dxf_write(file, 8, layer)

    end

  end

end