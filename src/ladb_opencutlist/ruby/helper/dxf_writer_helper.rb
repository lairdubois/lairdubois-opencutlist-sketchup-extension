module Ladb::OpenCutList

  require_relative '../constants'

  module DxfWriterHelper

    def _dxf_generate_id
      @_dxf_current_id = 0xfff if @_dxf_current_id.nil?
      @_dxf_current_id += 1
      @_dxf_current_id.to_s(16).upcase
    end

    def _dxf_write(file, code, value)
      file.puts(code.to_s.rjust(3))
      file.puts(value.is_a?(Integer) ? value.to_s.rjust(code >= 90 && code <= 99 ? 9 : 6) : value.to_s)
    end

    def _dxf_write_header_value(file, key, code, value, code2 = nil, value2 = nil, code3 = nil, value3 = nil)
      _dxf_write(file, 9, key)
      _dxf_write(file, code, value)
      _dxf_write(file, code2, value2) if code2
      _dxf_write(file, code3, value3) if code3
    end

    def _dxf_write_id(file, id = nil)
      id = _dxf_generate_id if id.nil?
      _dxf_write(file, 5, id)
      id
    end

    def _dxf_write_owner_id(file, owner_id = '0')
      _dxf_write(file, 330, owner_id)
    end

    def _dxf_write_sub_classes(file, sub_classes = [])
      sub_classes.each do |sub_class|
        _dxf_write(file, 100, sub_class)
      end
    end

    def _dxf_write_header(file, min = Geom::Point3d.new, max = Geom::Point3d.new(1000.0, 1000.0, 1000.0), layer_defs = [])  # layer_defs = [ { :name => NAME, :color => COLOR }, ... ]

      layer_defs = [ { :name => '0'} ] + layer_defs

      _dxf_write(file, 999, "Generator: SketchUp, #{EXTENSION_NAME} Extension, Version #{EXTENSION_VERSION}")

      # HEADER and base blocks

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'HEADER')
        _dxf_write_header_value(file, '$ACADVER', 1, 'AC1014')
        _dxf_write_header_value(file, '$ACADMAINTVER', 70, 9)
        _dxf_write_header_value(file, '$DWGCODEPAGE', 3, 'CNT')
        _dxf_write_header_value(file, '$INSBASE', 10, 0.0,
                                                    20, 0.0,
                                                    30, 0.0)
        _dxf_write_header_value(file, '$EXTMIN', 10, min.x.to_f,
                                                    20, min.y.to_f,
                                                    30, min.z.to_f)
        _dxf_write_header_value(file, '$EXTMAX', 10, max.x.to_f,
                                                    20, max.y.to_f,
                                                    30, max.z.to_f)
        _dxf_write_header_value(file, '$LIMMIN', 10, min.x.to_f,
                                                    20, min.y.to_f)
        _dxf_write_header_value(file, '$LIMMAX', 10, max.x.to_f,
                                                    20, max.y.to_f)
        _dxf_write_header_value(file, '$ORTHOMODE', 70, 0)
        _dxf_write_header_value(file, '$REGENMODE', 70, 1)
        _dxf_write_header_value(file, '$FILLMODE', 70, 1)
        _dxf_write_header_value(file, '$QTEXTMODE', 70, 0)
        _dxf_write_header_value(file, '$MIRRTEXT', 70, 1)
        _dxf_write_header_value(file, '$DRAGMODE', 70, 2)
        _dxf_write_header_value(file, '$LTSCALE', 40, 1.0)
        _dxf_write_header_value(file, '$OSMODE', 70, 37)
        _dxf_write_header_value(file, '$ATTMODE', 70, 1)
        _dxf_write_header_value(file, '$TEXTSIZE', 40, 0.2)
        _dxf_write_header_value(file, '$TRACEWID', 40, 0.05)
        _dxf_write_header_value(file, '$TEXTSTYLE', 7, 'STANDARD')
        _dxf_write_header_value(file, '$CLAYER', 8, '0')
        _dxf_write_header_value(file, '$CELTYPE', 6, 'BYBLOCK')
        _dxf_write_header_value(file, '$CECOLOR', 62, 256)
        _dxf_write_header_value(file, '$CELTSCALE', 40, 1.0)
        _dxf_write_header_value(file, '$DELOBJ', 70, 1)
        _dxf_write_header_value(file, '$DISPSILH', 70, 0)
        _dxf_write_header_value(file, '$DIMSCALE', 40, 1.0)
        _dxf_write_header_value(file, '$DIMASZ', 40, 0.18)
        _dxf_write_header_value(file, '$DIMEXO', 40, 0.0625)
        _dxf_write_header_value(file, '$DIMDLI', 40, 0.38)
        _dxf_write_header_value(file, '$DIMRND', 40, 0.0)
        _dxf_write_header_value(file, '$DIMDLE', 40, 0.0)
        _dxf_write_header_value(file, '$DIMEXE', 40, 0.18)
        _dxf_write_header_value(file, '$DIMTP', 40, 0.0)
        _dxf_write_header_value(file, '$DIMTM', 40, 0.0)
        _dxf_write_header_value(file, '$DIMTXT', 40, 0.18)
        _dxf_write_header_value(file, '$DIMCEN', 40, 0.09)
        _dxf_write_header_value(file, '$DIMTSZ', 40, 0.0)
        _dxf_write_header_value(file, '$DIMTOL', 70, 0)
        _dxf_write_header_value(file, '$DIMLIM', 70, 0)
        _dxf_write_header_value(file, '$DIMTIH', 70, 1)
        _dxf_write_header_value(file, '$DIMTOH', 70, 1)
        _dxf_write_header_value(file, '$DIMSE1', 70, 0)
        _dxf_write_header_value(file, '$DIMSE2', 70, 0)
        _dxf_write_header_value(file, '$DIMTAD', 70, 0)
        _dxf_write_header_value(file, '$DIMZIN', 70, 0)
        _dxf_write_header_value(file, '$DIMBLK', 1, '')
        _dxf_write_header_value(file, '$DIMASO', 70, 1)
        _dxf_write_header_value(file, '$DIMSHO', 70, 1)
        _dxf_write_header_value(file, '$DIMPOST', 1, '')
        _dxf_write_header_value(file, '$DIMAPOST', 1, '')
        _dxf_write_header_value(file, '$DIMALT', 70, 0)
        _dxf_write_header_value(file, '$DIMALTD', 70, 2)
        _dxf_write_header_value(file, '$DIMALTF', 40, 25.4)
        _dxf_write_header_value(file, '$DIMLFAC', 40, 1.0)
        _dxf_write_header_value(file, '$DIMTOFL', 70, 0)
        _dxf_write_header_value(file, '$DIMTVP', 40, 0.0)
        _dxf_write_header_value(file, '$DIMTIX', 70, 0)
        _dxf_write_header_value(file, '$DIMSOXD', 70, 0)
        _dxf_write_header_value(file, '$DIMSAH', 70, 0)
        _dxf_write_header_value(file, '$DIMBLK1', 1, '')
        _dxf_write_header_value(file, '$DIMBLK2', 1, '')
        _dxf_write_header_value(file, '$DIMSTYLE', 2, 'STANDARD')
        _dxf_write_header_value(file, '$DIMCLRD', 70, 0)
        _dxf_write_header_value(file, '$DIMCLRE', 70, 0)
        _dxf_write_header_value(file, '$DIMCLRT', 70, 0)
        _dxf_write_header_value(file, '$DIMTFAC', 40, 1.0)
        _dxf_write_header_value(file, '$DIMGAP', 40, 0.09)
        _dxf_write_header_value(file, '$DIMJUST', 70, 0)
        _dxf_write_header_value(file, '$DIMSD1', 70, 0)
        _dxf_write_header_value(file, '$DIMSD2', 70, 0)
        _dxf_write_header_value(file, '$DIMTOLJ', 70, 1)
        _dxf_write_header_value(file, '$DIMTZIN', 70, 0)
        _dxf_write_header_value(file, '$DIMALTZ', 70, 0)
        _dxf_write_header_value(file, '$DIMALTTZ', 70, 0)
        _dxf_write_header_value(file, '$DIMFIT', 70, 5)
        _dxf_write_header_value(file, '$DIMUPT', 70, 0)
        _dxf_write_header_value(file, '$DIMUNIT', 70, 2)
        _dxf_write_header_value(file, '$DIMDEC', 70, 4)
        _dxf_write_header_value(file, '$DIMTDEC', 70, 4)
        _dxf_write_header_value(file, '$DIMALTU', 70, 2)
        _dxf_write_header_value(file, '$DIMALTTD', 70, 2)
        _dxf_write_header_value(file, '$DIMTXSTY', 7, 'STANDARD')
        _dxf_write_header_value(file, '$DIMAUNIT', 70, 0)
        _dxf_write_header_value(file, '$LUNITS', 70, 2)
        _dxf_write_header_value(file, '$LUPREC', 70, 4)
        _dxf_write_header_value(file, '$SKETCHINC', 40, 0.1)
        _dxf_write_header_value(file, '$FILLETRAD', 40, 0.0)
        _dxf_write_header_value(file, '$AUNITS', 70, 0)
        _dxf_write_header_value(file, '$AUPREC', 70, 0)
        _dxf_write_header_value(file, '$MENU', 1, '.')
        _dxf_write_header_value(file, '$ELEVATION', 40, 0.0)
        _dxf_write_header_value(file, '$PELEVATION', 40, 0.0)
        _dxf_write_header_value(file, '$THICKNESS', 40, 0.0)
        _dxf_write_header_value(file, '$LIMCHECK', 70, 0)
        _dxf_write_header_value(file, '$CHAMFERA', 40, 0.0)
        _dxf_write_header_value(file, '$CHAMFERB', 40, 0.0)
        _dxf_write_header_value(file, '$CHAMFERC', 40, 0.0)
        _dxf_write_header_value(file, '$CHAMFERD', 40, 0.0)
        _dxf_write_header_value(file, '$SKPOLY', 70, 0)
        _dxf_write_header_value(file, '$TDCREATE', 40, DateTime.now.jd.to_f)
        _dxf_write_header_value(file, '$TDUPDATE', 40, DateTime.now.jd.to_f)
        _dxf_write_header_value(file, '$TDINDWG', 40, '0.0000000116')
        _dxf_write_header_value(file, '$TDUSRTIMER', 40, '0.0000000116')
        _dxf_write_header_value(file, '$USRTIMER', 70, 1)
        _dxf_write_header_value(file, '$ANGBASE', 50, 0.0)
        _dxf_write_header_value(file, '$ANGDIR', 70, 0)
        _dxf_write_header_value(file, '$PDMODE', 70, 0)
        _dxf_write_header_value(file, '$PDSIZE', 40, 0.0)
        _dxf_write_header_value(file, '$PLINEWID', 40, 0.0)
        _dxf_write_header_value(file, '$COORDS', 70, 1)
        _dxf_write_header_value(file, '$SPLFRAME', 70, 0)
        _dxf_write_header_value(file, '$SPLINETYPE', 70, 6)
        _dxf_write_header_value(file, '$SPLINESEGS', 70, 8)
        _dxf_write_header_value(file, '$ATTDIA', 70, 0)
        _dxf_write_header_value(file, '$ATTREQ', 70, 1)
        _dxf_write_header_value(file, '$HANDLING', 70, 1)
        _dxf_write_header_value(file, '$HANDSEED', 5, 'FFFF')
        _dxf_write_header_value(file, '$SURFTAB1', 70, 6)
        _dxf_write_header_value(file, '$SURFTAB2', 70, 6)
        _dxf_write_header_value(file, '$SURFTYPE', 70, 6)
        _dxf_write_header_value(file, '$SURFU', 70, 6)
        _dxf_write_header_value(file, '$SURFV', 70, 6)
        _dxf_write_header_value(file, '$UCSNAME', 2, '')
        _dxf_write_header_value(file, '$UCSORG', 10, 0.0,
                                                    20, 0.0,
                                                    30, 0.0)
        _dxf_write_header_value(file, '$UCSXDIR', 10, 1.0,
                                                    20, 0.0,
                                                    30, 0.0)
        _dxf_write_header_value(file, '$UCSYDIR', 10, 0.0,
                                                    20, 1.0,
                                                    30, 0.0)
        _dxf_write_header_value(file, '$PUCSNAME', 2, '')
        _dxf_write_header_value(file, '$PUCSORG', 10, 0.0,
                                                    20, 0.0,
                                                    30, 0.0)
        _dxf_write_header_value(file, '$PUCSXDIR', 10, 1.0,
                                                    20, 0.0,
                                                    30, 0.0)
        _dxf_write_header_value(file, '$PUCSYDIR', 10, 0.0,
                                                    20, 1.0,
                                                    30, 0.0)
        _dxf_write_header_value(file, '$USERI1', 70, 0)
        _dxf_write_header_value(file, '$USERI2', 70, 0)
        _dxf_write_header_value(file, '$USERI3', 70, 0)
        _dxf_write_header_value(file, '$USERI4', 70, 0)
        _dxf_write_header_value(file, '$USERI5', 70, 0)
        _dxf_write_header_value(file, '$USERR1', 40, 0.0)
        _dxf_write_header_value(file, '$USERR2', 40, 0.0)
        _dxf_write_header_value(file, '$USERR3', 40, 0.0)
        _dxf_write_header_value(file, '$USERR4', 40, 0.0)
        _dxf_write_header_value(file, '$USERR5', 40, 0.0)
        _dxf_write_header_value(file, '$WORLDVIEW', 70, 1)
        _dxf_write_header_value(file, '$SHADEDGE', 70, 3)
        _dxf_write_header_value(file, '$SHADEDIF', 70, 70)
        _dxf_write_header_value(file, '$TILEMODE', 70, 1)
        _dxf_write_header_value(file, '$MAXACTVP', 70, 64)
        _dxf_write_header_value(file, '$PINSBASE', 10, 0.0,
                                                    20, 0.0,
                                                    30, 0.0)
        _dxf_write_header_value(file, '$PLIMCHECK', 70, 0)
        _dxf_write_header_value(file, '$PEXTMIN', 10, '1.000000000000000E+20',
                                                    20, '1.000000000000000E+20',
                                                    30, '1.000000000000000E+20')
        _dxf_write_header_value(file, '$PEXTMAX', 10, '-1.000000000000000E+20',
                                                    20, '-1.000000000000000E+20',
                                                    30, '-1.000000000000000E+20')
        _dxf_write_header_value(file, '$PLIMMIN', 10, 0.0,
                                                    20, 0.0)
        _dxf_write_header_value(file, '$PLIMMAX', 10, 12.0,
                                                    20, 9.0)
        _dxf_write_header_value(file, '$UNITMODE', 70, 0)
        _dxf_write_header_value(file, '$VISRETAIN', 70, 1)
        _dxf_write_header_value(file, '$PLINEGEN', 70, 0)
        _dxf_write_header_value(file, '$PSLTSCALE', 70, 1)
        _dxf_write_header_value(file, '$TREEDEPTH', 70, 3020)
        _dxf_write_header_value(file, '$PICKSTYLE', 70, 1)
        _dxf_write_header_value(file, '$CMLSTYLE', 2, 'STANDARD')
        _dxf_write_header_value(file, '$CMLJUST', 70, 0)
        _dxf_write_header_value(file, '$CMLSCALE', 40, 1.0)
        _dxf_write_header_value(file, '$PROXYGRAPHICS', 70, 1)
        _dxf_write_header_value(file, '$MEASUREMENT', 70, 0)
      _dxf_write(file, 0, 'ENDSEC')

      # CLASSES

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'CLASSES')

      _dxf_write(file, 0, 'ENDSEC')

      # TABLES

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'TABLES')


        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'VPORT')
        id = _dxf_write_id(file)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbSymbolTable' ])
        _dxf_write(file, 70, 1)

          _dxf_write(file, 0, 'VPORT')
          _dxf_write_id(file)
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbViewportTableRecord' ])
          _dxf_write(file, 2, '*ACTIVE')
          _dxf_write(file, 70, 0)
          _dxf_write(file, 10, 0.0)
          _dxf_write(file, 20, 0.0)
          _dxf_write(file, 11, 1.0)
          _dxf_write(file, 21, 1.0)
          _dxf_write(file, 12, 10.42990654205607)
          _dxf_write(file, 22, 4.5)
          _dxf_write(file, 13, 0.0)
          _dxf_write(file, 23, 0.0)
          _dxf_write(file, 14, 0.5)
          _dxf_write(file, 24, 0.5)
          _dxf_write(file, 15, 0.5)
          _dxf_write(file, 25, 0.5)
          _dxf_write(file, 16, 0.0)
          _dxf_write(file, 26, 0.0)
          _dxf_write(file, 36, 1.0)
          _dxf_write(file, 17, 0.0)
          _dxf_write(file, 27, 0.0)
          _dxf_write(file, 37, 0.0)
          _dxf_write(file, 40, 9.0)
          _dxf_write(file, 41, 1.972972972850329)
          _dxf_write(file, 42, 50.0)
          _dxf_write(file, 43, 0.0)
          _dxf_write(file, 44, 0.0)
          _dxf_write(file, 50, 0.0)
          _dxf_write(file, 51, 0.0)
          _dxf_write(file, 71, 0)
          _dxf_write(file, 72, 100)
          _dxf_write(file, 73, 1)
          _dxf_write(file, 74, 3)
          _dxf_write(file, 75, 0)
          _dxf_write(file, 76, 0)
          _dxf_write(file, 77, 0)
          _dxf_write(file, 78, 0)

        _dxf_write(file, 0, 'ENDTAB')


        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'LTYPE')
        id = _dxf_write_id(file)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbSymbolTable' ])
        _dxf_write(file, 70, 1)

          _dxf_write(file, 0, 'LTYPE')
          _dxf_write_id(file)
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbLinetypeTableRecord' ])
          _dxf_write(file, 2, 'BYBLOCK')
          _dxf_write(file, 70, 0)
          _dxf_write(file, 3, '')
          _dxf_write(file, 72, 65)
          _dxf_write(file, 73, 0)
          _dxf_write(file, 40, 0.0)

          _dxf_write(file, 0, 'LTYPE')
          _dxf_write_id(file)
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbLinetypeTableRecord' ])
          _dxf_write(file, 2, 'BYLAYER')
          _dxf_write(file, 70, 0)
          _dxf_write(file, 3, '')
          _dxf_write(file, 72, 65)
          _dxf_write(file, 73, 0)
          _dxf_write(file, 40, 0.0)

          _dxf_write(file, 0, 'LTYPE')
          _dxf_write_id(file)
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbLinetypeTableRecord' ])
          _dxf_write(file, 2, 'CONTINUOUS')
          _dxf_write(file, 70, 0)
          _dxf_write(file, 3, 'Solid line')
          _dxf_write(file, 72, 65)
          _dxf_write(file, 73, 0)
          _dxf_write(file, 40, 0.0)

        _dxf_write(file, 0, 'ENDTAB')


        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'LAYER')
        id = _dxf_write_id(file)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbSymbolTable' ])
        _dxf_write(file, 70, layer_defs.length)

          layer_defs.each do |layer_def|
            _dxf_write(file, 0, 'LAYER')
            _dxf_write_id(file)
            _dxf_write_owner_id(file, id)
            _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbLayerTableRecord' ])
            _dxf_write(file, 2, layer_def[:name])
            _dxf_write(file, 70, 0)
            _dxf_write(file, 62, layer_def[:color] ? layer_def[:color] : 7 )  # Docs : https://ezdxf.mozman.at/docs/concepts/aci.html
            _dxf_write(file, 6, 'CONTINUOUS')
          end

        _dxf_write(file, 0, 'ENDTAB')


        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'STYLE')
        id = _dxf_write_id(file)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbSymbolTable' ])
        _dxf_write(file, 70, 1)

          _dxf_write(file, 0, 'STYLE')
          standard_style_id = _dxf_write_id(file)
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbTextStyleTableRecord' ])
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
        _dxf_write_id(file)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbSymbolTable' ])
        _dxf_write(file, 70, 0)
        _dxf_write(file, 0, 'ENDTAB')


        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'UCS')
        _dxf_write_id(file)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbSymbolTable' ])
        _dxf_write(file, 70, 0)
        _dxf_write(file, 0, 'ENDTAB')


        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'APPID')
        id = _dxf_write_id(file)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbSymbolTable' ])
        _dxf_write(file, 70, 2)

          _dxf_write(file, 0, 'APPID')
          _dxf_write_id(file)
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbRegAppTableRecord' ])
          _dxf_write(file, 2, 'ACAD')
          _dxf_write(file, 70, 0)

          _dxf_write(file, 0, 'APPID')
          _dxf_write_id(file)
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbRegAppTableRecord' ])
          _dxf_write(file, 2, 'ACAD_MLEADERVER')
          _dxf_write(file, 70, 0)

        _dxf_write(file, 0, 'ENDTAB')


        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'DIMSTYLE')
        id = _dxf_write_id(file)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbSymbolTable' ])
        _dxf_write(file, 70, 1)

          _dxf_write(file, 0, 'DIMSTYLE')
          _dxf_write(file, 105, '10')
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbDimStyleTableRecord' ])
          _dxf_write(file, 2, 'STANDARD')
          _dxf_write(file, 70, 0)
          _dxf_write(file, 3, '')
          _dxf_write(file, 4, '')
          _dxf_write(file, 5, '')
          _dxf_write(file, 6, '')
          _dxf_write(file, 7, '')
          _dxf_write(file, 40, 1.0)
          _dxf_write(file, 41, 0.18)
          _dxf_write(file, 42, 0.0625)
          _dxf_write(file, 43, 0.38)
          _dxf_write(file, 44, 0.18)
          _dxf_write(file, 45, 0.0)
          _dxf_write(file, 46, 0.0)
          _dxf_write(file, 47, 0.0)
          _dxf_write(file, 48, 0.0)
          _dxf_write(file, 140, 0.18)
          _dxf_write(file, 141, 0.09)
          _dxf_write(file, 142, 0.0)
          _dxf_write(file, 143, 25.4)
          _dxf_write(file, 144, 1.0)
          _dxf_write(file, 145, 0.0)
          _dxf_write(file, 146, 1.0)
          _dxf_write(file, 147, 0.09)
          _dxf_write(file, 71, 0)
          _dxf_write(file, 72, 0)
          _dxf_write(file, 73, 1)
          _dxf_write(file, 74, 1)
          _dxf_write(file, 75, 0)
          _dxf_write(file, 76, 0)
          _dxf_write(file, 77, 0)
          _dxf_write(file, 78, 0)
          _dxf_write(file, 170, 0)
          _dxf_write(file, 171, 2)
          _dxf_write(file, 172, 0)
          _dxf_write(file, 173, 0)
          _dxf_write(file, 174, 0)
          _dxf_write(file, 175, 0)
          _dxf_write(file, 176, 0)
          _dxf_write(file, 177, 0)
          _dxf_write(file, 178, 0)
          _dxf_write(file, 270, 2)
          _dxf_write(file, 271, 4)
          _dxf_write(file, 272, 4)
          _dxf_write(file, 273, 2)
          _dxf_write(file, 274, 2)
          _dxf_write(file, 340, standard_style_id)
          _dxf_write(file, 275, 0)
          _dxf_write(file, 280, 0)
          _dxf_write(file, 281, 0)
          _dxf_write(file, 282, 0)
          _dxf_write(file, 283, 1)
          _dxf_write(file, 284, 0)
          _dxf_write(file, 285, 0)
          _dxf_write(file, 286, 0)
          _dxf_write(file, 287, 3)
          _dxf_write(file, 288, 0)

        _dxf_write(file, 0, 'ENDTAB')


        _dxf_write(file, 0, 'TABLE')
        _dxf_write(file, 2, 'BLOCK_RECORD')
        id = _dxf_write_id(file)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbSymbolTable' ])
        _dxf_write(file, 70, 2)

          _dxf_write(file, 0, 'BLOCK_RECORD')
          @_dxf_model_space_id = _dxf_write_id(file)
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbBlockTableRecord' ])
          _dxf_write(file, 2, '*MODEL_SPACE')

          _dxf_write(file, 0, 'BLOCK_RECORD')
          paper_space_id = _dxf_write_id(file)
          _dxf_write_owner_id(file, id)
          _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbBlockTableRecord' ])
          _dxf_write(file, 2, '*PAPER_SPACE')

        _dxf_write(file, 0, 'ENDTAB')


      _dxf_write(file, 0, 'ENDSEC')

      # BLOCKS

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'BLOCKS')

        _dxf_write(file, 0, 'BLOCK')
        id = _dxf_write_id(file)
        _dxf_write_owner_id(file, @_dxf_model_space_id)
        _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
        _dxf_write(file, 8, '0')
        _dxf_write_sub_classes(file, [ 'AcDbBlockBegin' ])
        _dxf_write(file, 2, '*MODEL_SPACE')
        _dxf_write(file, 70, 0)
        _dxf_write(file, 10, 0.0)
        _dxf_write(file, 20, 0.0)
        _dxf_write(file, 30, 0.0)
        _dxf_write(file, 3, '*MODEL_SPACE')
        _dxf_write(file, 1, '')
        _dxf_write(file, 0, 'ENDBLK')
        _dxf_write_id(file)
        _dxf_write_owner_id(file, @_dxf_model_space_id)
        _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
        _dxf_write(file, 8, '0')
        _dxf_write_sub_classes(file, [ 'AcDbBlockEnd' ])

        _dxf_write(file, 0, 'BLOCK')
        id = _dxf_write_id(file)
        _dxf_write_owner_id(file, paper_space_id)
        _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
        _dxf_write(file, 67, 1)
        _dxf_write(file, 8, '0')
        _dxf_write_sub_classes(file, [ 'AcDbBlockBegin' ])
        _dxf_write(file, 2, '*PAPER_SPACE')
        _dxf_write(file, 70, 0)
        _dxf_write(file, 10, 0.0)
        _dxf_write(file, 20, 0.0)
        _dxf_write(file, 30, 0.0)
        _dxf_write(file, 3, '*PAPER_SPACE')
        _dxf_write(file, 1, '')
        _dxf_write(file, 0, 'ENDBLK')
        _dxf_write_id(file)
        _dxf_write_owner_id(file, paper_space_id)
        _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
        _dxf_write(file, 67, 1)
        _dxf_write(file, 8, '0')
        _dxf_write_sub_classes(file, [ 'AcDbBlockEnd' ])

      _dxf_write(file, 0, 'ENDSEC')

    end

    def _dxf_write_footer(file)

      # OBJECTS

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'OBJECTS')

        id_dic1 = _dxf_generate_id
        id_dic2 = _dxf_generate_id

        _dxf_write(file, 0, 'DICTIONARY')
        _dxf_write_id(file, id_dic1)
        _dxf_write_owner_id(file)
        _dxf_write_sub_classes(file, [ 'AcDbDictionary' ])
        _dxf_write(file, 3, 'ACAD_GROUP')
        _dxf_write(file, 350, id_dic2)

        _dxf_write(file, 0, 'DICTIONARY')
        _dxf_write_id(file, id_dic2)
        _dxf_write_owner_id(file, id_dic1)
        _dxf_write_sub_classes(file, [ 'AcDbDictionary' ])
        _dxf_write(file, 281, 1)

      _dxf_write(file, 0, 'ENDSEC')


      _dxf_write(file, 0, 'EOF')

    end

    # -----

    def _dxf_write_line(file, x1, y1, x2, y2, layer = 0)

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-FCEF5726-53AE-4C43-B4EA-C84EB8686A66

      _dxf_write(file, 0, 'LINE')
      _dxf_write_id(file)
      _dxf_write_owner_id(file, @_dxf_model_space_id)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbLine' ])
      _dxf_write(file, 10, x1)
      _dxf_write(file, 20, y1)
      _dxf_write(file, 30, 0.0)
      _dxf_write(file, 11, x2)
      _dxf_write(file, 21, y2)
      _dxf_write(file, 31, 0.0)

    end

    def _dxf_write_ellipse(file, cx, cy, vx, vy, vr, as = 0, ae = 2 * Math::PI, layer = 0)

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-107CB04F-AD4D-4D2F-8EC9-AC90888063AB

      # Workaround to be sure that full ellipse is clockwise
      if (as + ae).abs >= Math::PI * 2
        as = 0.0
        ae = Math::PI * 2
      end

      _dxf_write(file, 0, 'ELLIPSE')
      _dxf_write_id(file)
      _dxf_write_owner_id(file, @_dxf_model_space_id)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbEllipse' ])
      _dxf_write(file, 10, cx)
      _dxf_write(file, 20, cy)
      _dxf_write(file, 30, 0.0)
      _dxf_write(file, 11, vx)
      _dxf_write(file, 21, vy)
      _dxf_write(file, 31, 0.0)
      _dxf_write(file, 210, 0.0)
      _dxf_write(file, 220, 0.0)
      _dxf_write(file, 230, 1.0)
      _dxf_write(file, 40, vr)
      _dxf_write(file, 41, as)
      _dxf_write(file, 42, ae)

    end

    def _dxf_write_polygon(file, points, layer = 0)

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-748FC305-F3F2-4F74-825A-61F04D757A50

      _dxf_write(file, 0, 'LWPOLYLINE')
      _dxf_write_id(file)
      _dxf_write_owner_id(file, @_dxf_model_space_id)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbPolyline' ])
      _dxf_write(file, 90, points.length) # Vertex count
      _dxf_write(file, 70, 1) # 1 = Closed

      points.each do |point|

        _dxf_write(file, 10, point.x.to_f)
        _dxf_write(file, 20, point.y.to_f)

      end

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

  end

end