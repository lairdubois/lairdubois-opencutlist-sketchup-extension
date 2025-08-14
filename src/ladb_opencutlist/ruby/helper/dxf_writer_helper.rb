module Ladb::OpenCutList

  require_relative '../constants'
  require_relative '../utils/dimension_utils'
  require_relative '../lib/geometrix/geometrix'

  module DxfWriterHelper

    DXF_STRUCTURE_LAYER = 1
    DXF_STRUCTURE_LAYER_AND_BLOCK = 2

    DXF_ACI_COLORS = [
      [ 0, 0, 0 ],
      [ 255, 0, 0 ],
      [ 255, 255, 0 ],
      [ 0, 255, 0 ],
      [ 0, 255, 255 ],
      [ 0, 0, 255 ],
      [ 255, 0, 255 ],
      [ 255, 255, 255 ],
      [ 65, 65, 65 ],
      [ 128, 128, 128 ],
      [ 255, 0, 0 ],
      [ 255, 170, 170 ],
      [ 189, 0, 0 ],
      [ 189, 126, 126 ],
      [ 129, 0, 0 ],
      [ 129, 86, 86 ],
      [ 104, 0, 0 ],
      [ 104, 69, 69 ],
      [ 79, 0, 0 ],
      [ 79, 53, 53 ],
      [ 255, 63, 0 ],
      [ 255, 191, 170 ],
      [ 189, 46, 0 ],
      [ 189, 141, 126 ],
      [ 129, 31, 0 ],
      [ 129, 96, 86 ],
      [ 104, 25, 0 ],
      [ 104, 78, 69 ],
      [ 79, 19, 0 ],
      [ 79, 59, 53 ],
      [ 255, 127, 0 ],
      [ 255, 212, 170 ],
      [ 189, 94, 0 ],
      [ 189, 157, 126 ],
      [ 129, 64, 0 ],
      [ 129, 107, 86 ],
      [ 104, 52, 0 ],
      [ 104, 86, 69 ],
      [ 79, 39, 0 ],
      [ 79, 66, 53 ],
      [ 255, 191, 0 ],
      [ 255, 234, 170 ],
      [ 189, 141, 0 ],
      [ 189, 173, 126 ],
      [ 129, 96, 0 ],
      [ 129, 118, 86 ],
      [ 104, 78, 0 ],
      [ 104, 95, 69 ],
      [ 79, 59, 0 ],
      [ 79, 73, 53 ],
      [ 255, 255, 0 ],
      [ 255, 255, 170 ],
      [ 189, 189, 0 ],
      [ 189, 189, 126 ],
      [ 129, 129, 0 ],
      [ 129, 129, 86 ],
      [ 104, 104, 0 ],
      [ 104, 104, 69 ],
      [ 79, 79, 0 ],
      [ 79, 79, 53 ],
      [ 191, 255, 0 ],
      [ 234, 255, 170 ],
      [ 141, 189, 0 ],
      [ 173, 189, 126 ],
      [ 96, 129, 0 ],
      [ 118, 129, 86 ],
      [ 78, 104, 0 ],
      [ 95, 104, 69 ],
      [ 59, 79, 0 ],
      [ 73, 79, 53 ],
      [ 127, 255, 0 ],
      [ 212, 255, 170 ],
      [ 94, 189, 0 ],
      [ 157, 189, 126 ],
      [ 64, 129, 0 ],
      [ 107, 129, 86 ],
      [ 52, 104, 0 ],
      [ 86, 104, 69 ],
      [ 39, 79, 0 ],
      [ 66, 79, 53 ],
      [ 63, 255, 0 ],
      [ 191, 255, 170 ],
      [ 46, 189, 0 ],
      [ 141, 189, 126 ],
      [ 31, 129, 0 ],
      [ 96, 129, 86 ],
      [ 25, 104, 0 ],
      [ 78, 104, 69 ],
      [ 19, 79, 0 ],
      [ 59, 79, 53 ],
      [ 0, 255, 0 ],
      [ 170, 255, 170 ],
      [ 0, 189, 0 ],
      [ 126, 189, 126 ],
      [ 0, 129, 0 ],
      [ 86, 129, 86 ],
      [ 0, 104, 0 ],
      [ 69, 104, 69 ],
      [ 0, 79, 0 ],
      [ 53, 79, 53 ],
      [ 0, 255, 63 ],
      [ 170, 255, 191 ],
      [ 0, 189, 46 ],
      [ 126, 189, 141 ],
      [ 0, 129, 31 ],
      [ 86, 129, 96 ],
      [ 0, 104, 25 ],
      [ 69, 104, 78 ],
      [ 0, 79, 19 ],
      [ 53, 79, 59 ],
      [ 0, 255, 127 ],
      [ 170, 255, 212 ],
      [ 0, 189, 94 ],
      [ 126, 189, 157 ],
      [ 0, 129, 64 ],
      [ 86, 129, 107 ],
      [ 0, 104, 52 ],
      [ 69, 104, 86 ],
      [ 0, 79, 39 ],
      [ 53, 79, 66 ],
      [ 0, 255, 191 ],
      [ 170, 255, 234 ],
      [ 0, 189, 141 ],
      [ 126, 189, 173 ],
      [ 0, 129, 96 ],
      [ 86, 129, 118 ],
      [ 0, 104, 78 ],
      [ 69, 104, 95 ],
      [ 0, 79, 59 ],
      [ 53, 79, 73 ],
      [ 0, 255, 255 ],
      [ 170, 255, 255 ],
      [ 0, 189, 189 ],
      [ 126, 189, 189 ],
      [ 0, 129, 129 ],
      [ 86, 129, 129 ],
      [ 0, 104, 104 ],
      [ 69, 104, 104 ],
      [ 0, 79, 79 ],
      [ 53, 79, 79 ],
      [ 0, 191, 255 ],
      [ 170, 234, 255 ],
      [ 0, 141, 189 ],
      [ 126, 173, 189 ],
      [ 0, 96, 129 ],
      [ 86, 118, 129 ],
      [ 0, 78, 104 ],
      [ 69, 95, 104 ],
      [ 0, 59, 79 ],
      [ 53, 73, 79 ],
      [ 0, 127, 255 ],
      [ 170, 212, 255 ],
      [ 0, 94, 189 ],
      [ 126, 157, 189 ],
      [ 0, 64, 129 ],
      [ 86, 107, 129 ],
      [ 0, 52, 104 ],
      [ 69, 86, 104 ],
      [ 0, 39, 79 ],
      [ 53, 66, 79 ],
      [ 0, 63, 255 ],
      [ 170, 191, 255 ],
      [ 0, 46, 189 ],
      [ 126, 141, 189 ],
      [ 0, 31, 129 ],
      [ 86, 96, 129 ],
      [ 0, 25, 104 ],
      [ 69, 78, 104 ],
      [ 0, 19, 79 ],
      [ 53, 59, 79 ],
      [ 0, 0, 255 ],
      [ 170, 170, 255 ],
      [ 0, 0, 189 ],
      [ 126, 126, 189 ],
      [ 0, 0, 129 ],
      [ 86, 86, 129 ],
      [ 0, 0, 104 ],
      [ 69, 69, 104 ],
      [ 0, 0, 79 ],
      [ 53, 53, 79 ],
      [ 63, 0, 255 ],
      [ 191, 170, 255 ],
      [ 46, 0, 189 ],
      [ 141, 126, 189 ],
      [ 31, 0, 129 ],
      [ 96, 86, 129 ],
      [ 25, 0, 104 ],
      [ 78, 69, 104 ],
      [ 19, 0, 79 ],
      [ 59, 53, 79 ],
      [ 127, 0, 255 ],
      [ 212, 170, 255 ],
      [ 94, 0, 189 ],
      [ 157, 126, 189 ],
      [ 64, 0, 129 ],
      [ 107, 86, 129 ],
      [ 52, 0, 104 ],
      [ 86, 69, 104 ],
      [ 39, 0, 79 ],
      [ 66, 53, 79 ],
      [ 191, 0, 255 ],
      [ 234, 170, 255 ],
      [ 141, 0, 189 ],
      [ 173, 126, 189 ],
      [ 96, 0, 129 ],
      [ 118, 86, 129 ],
      [ 78, 0, 104 ],
      [ 95, 69, 104 ],
      [ 59, 0, 79 ],
      [ 73, 53, 79 ],
      [ 255, 0, 255 ],
      [ 255, 170, 255 ],
      [ 189, 0, 189 ],
      [ 189, 126, 189 ],
      [ 129, 0, 129 ],
      [ 129, 86, 129 ],
      [ 104, 0, 104 ],
      [ 104, 69, 104 ],
      [ 79, 0, 79 ],
      [ 79, 53, 79 ],
      [ 255, 0, 191 ],
      [ 255, 170, 234 ],
      [ 189, 0, 141 ],
      [ 189, 126, 173 ],
      [ 129, 0, 96 ],
      [ 129, 86, 118 ],
      [ 104, 0, 78 ],
      [ 104, 69, 95 ],
      [ 79, 0, 59 ],
      [ 79, 53, 73 ],
      [ 255, 0, 127 ],
      [ 255, 170, 212 ],
      [ 189, 0, 94 ],
      [ 189, 126, 157 ],
      [ 129, 0, 64 ],
      [ 129, 86, 107 ],
      [ 104, 0, 52 ],
      [ 104, 69, 86 ],
      [ 79, 0, 39 ],
      [ 79, 53, 66 ],
      [ 255, 0, 63 ],
      [ 255, 170, 191 ],
      [ 189, 0, 46 ],
      [ 189, 126, 141 ],
      [ 129, 0, 31 ],
      [ 129, 86, 96 ],
      [ 104, 0, 25 ],
      [ 104, 69, 78 ],
      [ 79, 0, 19 ],
      [ 79, 53, 59 ],
      [ 51, 51, 51 ],
      [ 80, 80, 80 ],
      [ 105, 105, 105 ],
      [ 130, 130, 130 ],
      [ 190, 190, 190 ],
      [ 255, 255, 255 ]
    ]

    DXF_TEXT_HALIGN_LEFT = 0
    DXF_TEXT_HALIGN_CENTER = 1
    DXF_TEXT_HALIGN_RIGHT = 2

    DXF_TEXT_VALIGN_BASE_LINE = 0
    DXF_TEXT_VALIGN_BOTTOM = 1
    DXF_TEXT_VALIGN_MIDDLE = 2
    DXF_TEXT_VALIGN_TOP = 3

    def _dxf_get_unit_factor(su_unit)

      case su_unit
      when DimensionUtils::INCHES
        unit_factor = 1.0
      when DimensionUtils::FEET
        unit_factor = 1.0.to_l.to_feet
      when DimensionUtils::YARD
        unit_factor = 1.0.to_l.to_yard
      when DimensionUtils::MILLIMETER
        unit_factor = 1.0.to_l.to_mm
      when DimensionUtils::CENTIMETER
        unit_factor = 1.0.to_l.to_cm
      when DimensionUtils::METER
        unit_factor = 1.0.to_l.to_m
      else
        unit_factor = DimensionUtils.length_to_model_unit_float(1.0.to_l)
      end

      unit_factor
    end

    def _dxf_convert_unit(su_unit)

      case su_unit
      when DimensionUtils::INCHES
        dxf_unit = 1
      when DimensionUtils::FEET
        dxf_unit = 2
      when DimensionUtils::YARD
        dxf_unit = 10
      when DimensionUtils::MILLIMETER
        dxf_unit = 4
      when DimensionUtils::CENTIMETER
        dxf_unit = 5
      when DimensionUtils::METER
        dxf_unit = 6
      else
        dxf_unit = 0
      end

      dxf_unit
    end

    def _dxf_convert_color_to_aci(color, default = 7)
      return color if color.is_a?(Integer) && color >= 0 && color <= 255
      return default unless color.is_a?(Sketchup::Color)
      match_index = 0
      match_dist = 195076 # Max dist 255**2 + 255**2 + 255**2 + 1
      DXF_ACI_COLORS.each_with_index do |aci_color, index|
        dist = (aci_color[0] - color.red)**2 + (aci_color[1] - color.green)**2 + (aci_color[2] - color.blue)**2
        if dist < match_dist
          match_index = index
          match_dist = dist
        end
      end
      match_index
    end

    def _dxf_generate_id
      @_dxf_current_id = 0xfff if @_dxf_current_id.nil?
      @_dxf_current_id += 1
      @_dxf_current_id.to_s(16).upcase
    end

    def _dxf_sanitize_identifier(name)
      name.to_s.gsub(/[\s<>\/\\“:;?*|=‘.]/, '_').upcase
    end

    # -----

    def _dxf_write(file, code, value)
      file.puts(code.to_s.rjust(3))
      if value.is_a?(Integer)
        file.puts(value.to_s.rjust(code >= 90 && code <= 99 ? 9 : 6))
      elsif value.is_a?(Float)
        value = value.round(11)
        value = 0.0 if value == 0 # Avoid -0.0
        file.puts(value.to_s)
      else
        file.puts(value.to_s)
      end
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

    def _dxf_write_section(file, name)
      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, name)
      yield if block_given?
      _dxf_write(file, 0, 'ENDSEC')
    end

    def _dxf_write_start(file)
      _dxf_write(file, 999, "Generator: SketchUp, #{EXTENSION_NAME} Extension, Version #{EXTENSION_VERSION}")
    end

    def _dxf_write_end(file)
      _dxf_write(file, 0, 'EOF')
    end

    # -- SECTIONS

    # HEADER

    def _dxf_write_section_header(file, su_unit, min = Geom::Point3d.new, max = Geom::Point3d.new(1000.0, 1000.0, 1000.0))

      _dxf_write_section(file, 'HEADER') do

        _dxf_write_header_value(file, '$ACADVER', 1, 'AC1014')
        _dxf_write_header_value(file, '$ACADMAINTVER', 70, 9)
        _dxf_write_header_value(file, '$DWGCODEPAGE', 3, 'CNT')
        _dxf_write_header_value(file, '$INSBASE', 10, 0.0,
                                20, 0.0,
                                30, 0.0)
        _dxf_write_header_value(file, '$INSUNITS', 70, _dxf_convert_unit(su_unit))
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

      end

    end

    # CLASSES

    def _dxf_write_section_classes(file)

      _dxf_write_section(file, 'CLASSES')

    end

    # TABLES

    def _dxf_write_section_tables(file, vport_min = Geom::Point3d.new, vport_max = Geom::Point3d.new(1000.0, 1000.0, 1000.0), layer_defs = [])  # layer_defs = [ DxfLayerDef, ... ]

      layer_defs = [ DxfLayerDef.new('0', nil) ] + layer_defs

      _dxf_write_section(file, 'TABLES') do

        # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-8CE7CC87-27BD-4490-89DA-C21F516415A9

        vport_center = Geom::Point3d.new(vport_min.x + (vport_max.x - vport_min.x) / 2, vport_min.y + (vport_max.y - vport_min.y) / 2)

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
          _dxf_write(file, 10, vport_min.x.to_f)
          _dxf_write(file, 20, vport_min.y.to_f)
          _dxf_write(file, 11, vport_max.x.to_f)
          _dxf_write(file, 21, vport_max.y.to_f)
          _dxf_write(file, 12, vport_center.x.to_f)
          _dxf_write(file, 22, vport_center.y.to_f)
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
            _dxf_write(file, 2, layer_def.name)
            _dxf_write(file, 70, 0)
            _dxf_write(file, 62, _dxf_convert_color_to_aci(layer_def.color))  # Docs : https://ezdxf.mozman.at/docs/concepts/aci.html
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

          @_dxf_model_space_id = _dxf_write_section_tables_block_record(file, '*MODEL_SPACE', id)
          @_dxf_paper_space_id = _dxf_write_section_tables_block_record(file, '*PAPER_SPACE', id)

          yield(id) if block_given?

        _dxf_write(file, 0, 'ENDTAB')

      end

    end

    def _dxf_write_section_tables_block_record(file, name, owner_id)

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-A1FD1934-7EF5-4D35-A4B0-F8AE54A9A20A

      _dxf_write(file, 0, 'BLOCK_RECORD')
      id = _dxf_write_id(file)
      _dxf_write_owner_id(file, owner_id)
      _dxf_write_sub_classes(file, [ 'AcDbSymbolTableRecord', 'AcDbBlockTableRecord' ])
      _dxf_write(file, 2, name)

      id
    end

    # BLOCKS

    def _dxf_write_section_blocks(file)

      _dxf_write_section(file, 'BLOCKS') do

        _dxf_write_section_blocks_block(file, '*MODEL_SPACE', @_dxf_model_space_id)
        _dxf_write_section_blocks_block(file, '*PAPER_SPACE', @_dxf_paper_space_id)

        yield if block_given?

      end

    end

    def _dxf_write_section_blocks_block(file, name, owner_id, layer = '0')

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-66D32572-005A-4E23-8B8B-8726E8C14302

      _dxf_write(file, 0, 'BLOCK')
      _dxf_write_id(file)
      _dxf_write_owner_id(file, owner_id)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbBlockBegin' ])
      _dxf_write(file, 2, name)
      _dxf_write(file, 70, 0)
      _dxf_write(file, 10, 0.0)
      _dxf_write(file, 20, 0.0)
      _dxf_write(file, 30, 0.0)
      _dxf_write(file, 3, name)
      _dxf_write(file, 1, '')
      yield if block_given?
      _dxf_write(file, 0, 'ENDBLK')
      _dxf_write_id(file)
      _dxf_write_owner_id(file, owner_id)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 67, 1)
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbBlockEnd' ])

    end

    # ENTITIES

    def _dxf_write_section_entities(file)

      _dxf_write_section(file, 'ENTITIES') do

        yield if block_given?

      end

    end

    # OBJECTS

    def _dxf_write_section_objects(file)

      _dxf_write_section(file, 'OBJECTS') do

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

      end

    end

    # -- BASE GEOMETRY

    def _dxf_write_point(file, x, y, layer = '0')

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-FCEF5726-53AE-4C43-B4EA-C84EB8686A66

      _dxf_write(file, 0, 'POINT')
      _dxf_write_id(file)
      _dxf_write_owner_id(file, @_dxf_model_space_id)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbPoint' ])
      _dxf_write(file, 10, x)
      _dxf_write(file, 20, y)
      _dxf_write(file, 30, 0.0)

    end

    def _dxf_write_line(file, x1, y1, x2, y2, layer = '0')

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

    def _dxf_write_arc(file, cx, cy, r, as = 0, ae = Geometrix::TWO_PI, layer = '0')

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-0B14D8F1-0EBA-44BF-9108-57D8CE614BC8

      _dxf_write(file, 0, 'ARC')
      _dxf_write_id(file)
      _dxf_write_owner_id(file, @_dxf_model_space_id)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbCircle' ])
      _dxf_write(file, 10, cx)
      _dxf_write(file, 20, cy)
      _dxf_write(file, 30, 0.0)
      _dxf_write(file, 40, r)
      _dxf_write_sub_classes(file, [ 'AcDbArc' ])
      _dxf_write(file, 50, as)
      _dxf_write(file, 51, ae)
      _dxf_write(file, 210, 0.0)
      _dxf_write(file, 220, 0.0)
      _dxf_write(file, 230, 1.0)

    end

    def _dxf_write_circle(file, cx, cy, r, layer = '0')

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-8663262B-222C-414D-B133-4A8506A27C18

      _dxf_write(file, 0, 'CIRCLE')
      _dxf_write_id(file)
      _dxf_write_owner_id(file, @_dxf_model_space_id)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbCircle' ])
      _dxf_write(file, 10, cx)
      _dxf_write(file, 20, cy)
      _dxf_write(file, 30, 0.0)
      _dxf_write(file, 40, r)

    end

    def _dxf_write_ellipse(file, cx, cy, vx, vy, vr, as = 0, ae = Geometrix::TWO_PI, layer = '0')

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-107CB04F-AD4D-4D2F-8EC9-AC90888063AB

      if as > ae && ae < 0
        ae = ae + Geometrix::TWO_PI  # Force end angle to be greater than start angle. Some DXF readers prefer that.
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

    def _dxf_write_polyline(file, vertices, closed = false, layer = '0')  # vertices = Array of DxfVertexDef

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-748FC305-F3F2-4F74-825A-61F04D757A50

      _dxf_write(file, 0, 'LWPOLYLINE')
      _dxf_write_id(file)
      _dxf_write_owner_id(file, @_dxf_model_space_id)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbPolyline' ])
      _dxf_write(file, 90, vertices.length) # Vertex count
      _dxf_write(file, 70, closed ? 1 : 0) # 1 = Closed

      vertices.each do |vertex|

        _dxf_write(file, 10, vertex.x)
        _dxf_write(file, 20, vertex.y)
        _dxf_write(file, 42, vertex.bulge)

      end

    end

    def _dxf_write_polygon(file, points, layer = '0')

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

    def _dxf_write_rect(file, x, y, width, height, layer = '0')

      points = [
        Geom::Point3d.new(x, y),
        Geom::Point3d.new(x + width, y),
        Geom::Point3d.new(x + width, y + height),
        Geom::Point3d.new(x, y + height),
      ]

      _dxf_write_polygon(file, points, layer)

    end

    def _dxf_write_text(file, x, y, height, text, ar = 0, halign = DXF_TEXT_HALIGN_LEFT, valign = DXF_TEXT_VALIGN_BASE_LINE, layer = '0')

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-62E5383D-8A14-47B4-BFC4-35824CAE8363

      _dxf_write(file, 0, 'TEXT')
      _dxf_write_id(file)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbText' ])
      _dxf_write(file, 10, x)
      _dxf_write(file, 20, y)
      _dxf_write(file, 30, 0.0)
      _dxf_write(file, 40, height)
      _dxf_write(file, 50, ar)
      _dxf_write(file, 1, text.to_s)
      _dxf_write(file, 72, halign)
      _dxf_write(file, 11, x)
      _dxf_write(file, 21, y)
      _dxf_write(file, 31, 0.0)
      _dxf_write_sub_classes(file, [ 'AcDbText' ])
      _dxf_write(file, 73, valign)

    end

    def _dxf_write_label(file, rx, ry, rw, rh, text, tw, th, tx = 0, ty = 0, angle = 0, layer = nil)
      text = text.to_s
      return unless text.length > 0

      tx = rx + rw / 2.0 + tx
      ty = ry + rh / 2.0 + ty
      theight = [ 60.0, th / 2, tw / text.length ].min
      angle = angle % 180

      _dxf_write_text(file, tx , ty, theight, text, angle, DXF_TEXT_HALIGN_CENTER, DXF_TEXT_VALIGN_MIDDLE, layer)

    end

    # -- INSERT GEOMETRY

    def _dxf_write_insert(file, name, x = 0.0, y = 0.0, z = 0.0, scale_x = 1.0, scale_y = 1.0, scale_z = 1.0, angle = 0.0, layer = '0')

      # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-28FA4CFB-9D5E-4880-9F11-36C97578252F

      _dxf_write(file, 0, 'INSERT')
      _dxf_write_id(file)
      _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
      _dxf_write(file, 8, layer)
      _dxf_write_sub_classes(file, [ 'AcDbBlockReference' ])
      _dxf_write(file, 2, name)
      _dxf_write(file, 10, x)
      _dxf_write(file, 20, y)
      _dxf_write(file, 30, z)
      _dxf_write(file, 41, scale_x)
      _dxf_write(file, 42, scale_y)
      _dxf_write(file, 43, scale_z)
      _dxf_write(file, 50, angle)

    end

    # -- CUSTOM GEOMETRY

    def _dxf_get_projection_layer_def_identifier(layer_def, unit_transformation, prefix = nil)

      require_relative '../model/drawing/drawing_projection_def'

      return '' unless layer_def.is_a?(DrawingProjectionLayerDef)
      a = [ prefix, 'DEPTH', ('%0.03f' % [ Geom::Point3d.new(layer_def.depth, 0).transform(unit_transformation).x ]).rjust(8, '_') ]
      a << 'OUTER' if layer_def.type_outer?
      a << 'HOLES' if layer_def.type_holes?
      a << 'PATH' if layer_def.type_path?
      a << layer_def.name if layer_def.has_name?
      _dxf_sanitize_identifier(a.compact.join('_'))
    end

    def _dxf_get_projection_def_depth_layer_defs(projection_def,
                                                 color: nil,
                                                 depths_color: nil,
                                                 holes_color: nil,
                                                 paths_color: nil,
                                                 unit_transformation: IDENTITY,
                                                 prefix: nil)

      require_relative '../model/drawing/drawing_projection_def'

      return [] unless projection_def.is_a?(DrawingProjectionDef)

      dxf_layer_defs = []
      projection_def.layer_defs.each do |layer_def|

        layer_name = _dxf_get_projection_layer_def_identifier(layer_def, unit_transformation, prefix)
        if layer_def.type_path?
          layer_color = layer_def.has_color? ? layer_def.color : paths_color
        elsif layer_def.type_holes?
          layer_color = holes_color
        elsif layer_def.type_outer?
          layer_color = color
        else
          layer_color = if depths_color
                          depths_color
                        else
                          color ? ColorUtils.color_lighten(color, (layer_def.depth / (projection_def.max_depth > 0 ? projection_def.max_depth : 1) * 0.8)) : nil
                        end
        end

        dxf_layer_defs.push(DxfLayerDef.new(layer_name, layer_color))

      end

      dxf_layer_defs
    end

    def _dxf_write_projection_def_block_record(file, projection_def, name, owner_id)

      require_relative '../model/drawing/drawing_projection_def'

      return unless projection_def.is_a?(DrawingProjectionDef)

      _dxf_write_section_tables_block_record(file, name, owner_id)

    end

    def _dxf_write_projection_def_block(file, name, projection_def,
                                        smoothing: false,
                                        transformation: IDENTITY,
                                        unit_transformation: IDENTITY,
                                        layer: '0')

      require_relative '../model/drawing/drawing_projection_def'

      return unless projection_def.is_a?(DrawingProjectionDef)

      _dxf_write_section_blocks_block(file, name, @_dxf_model_space_id) do
        _dxf_write_projection_def_geometry(file, projection_def,
                                           smoothing: smoothing,
                                           transformation: transformation,
                                           unit_transformation: unit_transformation,
                                           layer: layer)
        yield if block_given?
      end

    end

    def _dxf_write_projection_def_geometry(file, projection_def,
                                           smoothing: false,
                                           transformation: IDENTITY,
                                           unit_transformation: IDENTITY,
                                           layer: '0')

      require_relative '../model/drawing/drawing_projection_def'

      return unless projection_def.is_a?(DrawingProjectionDef)

      projection_def.layer_defs.sort_by { |v| [v.type_path? ? 1 : 0, -v.depth ] }.each do |layer_def| # Path's layers always on top
        _dxf_write_projection_layer_def_geometry(file, layer_def,
                                                 smoothing: smoothing,
                                                 transformation: transformation,
                                                 layer: _dxf_get_projection_layer_def_identifier(layer_def, unit_transformation, layer))
      end

    end

    def _dxf_write_projection_layer_def_geometry(file, layer_def,
                                                 smoothing: false,
                                                 transformation: IDENTITY,
                                                 layer: '0')

      require_relative '../model/drawing/drawing_projection_def'

      return unless layer_def.is_a?(DrawingProjectionLayerDef)

      require_relative '../utils/transformation_utils'

      flipped = TransformationUtils.flipped?(transformation)

      layer_def.poly_defs.each do |poly_def|

        if smoothing && poly_def.curve_def

          if poly_def.curve_def.circle?

            # Simplify circle drawing

            portion = poly_def.curve_def.portions.first
            center = portion.ellipse_def.center.transform(transformation)
            radius = Geom::Vector3d.new(portion.ellipse_def.xradius, 0, 0).transform(transformation).length

            cx = center.x.to_f
            cy = center.y.to_f
            r = radius.to_f

            _dxf_write_circle(file, cx, cy, r, layer)

          elsif poly_def.curve_def.ellipse?

            # Simplify ellipse drawing

            portion = poly_def.curve_def.portions.first
            center = portion.ellipse_def.center.transform(transformation)
            xaxis = portion.ellipse_def.xaxis.transform(transformation)

            cx = center.x.to_f
            cy = center.y.to_f
            vx = xaxis.x.to_f
            vy = xaxis.y.to_f
            vr = portion.ellipse_def.yradius / portion.ellipse_def.xradius
            as = 0.0
            ae = 2.0 * Math::PI

            _dxf_write_ellipse(file, cx, cy, vx, vy, vr, as, ae, layer)

          else

            vertices = []

            # Extract loop portions
            poly_def.curve_def.portions.each { |portion|

              start_point = portion.start_point.transform(transformation)

              x = start_point.x.to_f
              y = start_point.y.to_f

              if portion.is_a?(Geometrix::ArcCurvePortionDef)

                if portion.ellipse_def.circular?

                  # Circular arc

                  if flipped
                    start_angle = portion.end_angle
                    end_angle = portion.start_angle
                    ccw = !portion.ccw?
                  else
                    start_angle = portion.start_angle
                    end_angle = portion.end_angle
                    ccw = portion.ccw?
                  end

                  if ccw
                    start_angle -= Geometrix::TWO_PI if start_angle > end_angle
                  else
                    start_angle += Geometrix::TWO_PI if start_angle < end_angle
                  end

                  if start_angle < 0 && end_angle < 0
                    start_angle += Geometrix::TWO_PI
                    end_angle += Geometrix::TWO_PI
                  end

                  bulge = Math.tan((end_angle - start_angle) / 4.0)

                  vertices << DxfVertexDef.new(x, y, bulge)

                else

                  # Elliptical arc -> convert to circular arcs

                  start_angle = portion.start_angle
                  end_angle = portion.end_angle
                  start_angle, end_angle = end_angle, start_angle unless portion.ccw?

                  approximated_ellipse_def = Geometrix::EllipseApproximator.approximate_ellipse_def(portion.ellipse_def, start_angle, end_angle)
                  if approximated_ellipse_def

                    apx_portions = approximated_ellipse_def.portions
                    apx_portions = apx_portions.reverse unless portion.ccw?
                    apx_portions.each do |apx_portion|

                      apx_start_point = apx_portion.start_point.transform(transformation)
                      apx_end_point = apx_portion.end_point.transform(transformation)
                      apx_start_point, apx_end_point = apx_end_point, apx_start_point unless portion.ccw?
                      apx_circle_center = apx_portion.circle_def.center.transform(transformation)

                      bulge = Math.tan((apx_start_point - apx_circle_center).angle_between(apx_end_point - apx_circle_center) / 4.0)
                      bulge *= -1 unless (flipped ? !portion.ccw? : portion.ccw?)

                      vertices << DxfVertexDef.new(x, y, bulge)

                      # Prepare for the next vertex
                      x = apx_end_point.x.to_f
                      y = apx_end_point.y.to_f

                    end

                  end

                end

              else

                # Segment

                vertices << DxfVertexDef.new(x, y, 0)

              end

            }

            unless poly_def.curve_def.closed?

              end_point = poly_def.curve_def.portions.last.end_point.transform(transformation)

              x = end_point.x.to_f
              y = end_point.y.to_f

              vertices << DxfVertexDef.new(x, y, 0)

            end

            _dxf_write_polyline(file, vertices, poly_def.curve_def.closed?, layer)

          end

        else

          # Extract loop points from vertices (quicker)
          _dxf_write_polyline(file, poly_def.points.map { |point| point.transform(transformation) }.map { |point| DxfVertexDef.new(point.x.to_f, point.y.to_f, 0) }, poly_def.curve_def.closed?, layer)

        end

      end

    end

    # -----

    DxfLayerDef = Struct.new(:name, :color)
    DxfVertexDef = Struct.new(:x, :y, :bulge)

  end

end