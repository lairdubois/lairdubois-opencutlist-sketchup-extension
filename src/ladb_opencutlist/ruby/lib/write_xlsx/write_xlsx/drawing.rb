# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative 'package/xml_writer_simple'
require_relative 'utility'

module Ladb::OpenCutList
module Writexlsx
  class Drawing
    include Writexlsx::Utility

    attr_accessor :type, :dimensions, :width, :height, :shape, :anchor, :rel_index, :url_rel_index, :name, :description
    attr_reader :tip, :decorative
    attr_writer :writer, :embedded, :orientation

    def initialize(type, dimensions, width, height, shape, anchor, rel_index = nil, url_rel_index = nil, tip = nil, name = nil, description = nil, decorative = nil)
      @type = type
      @dimensions = dimensions
      @width = width
      @height = height
      @shape = shape
      @anchor = anchor
      @rel_index = rel_index
      @url_rel_index = url_rel_index
      @tip = tip
      @name = name
      @description = description
      @decorative = decorative
    end

    #
    # Write the <xdr:twoCellAnchor> element.
    #
    def write_two_cell_anchor(index)
      attributes      = []

      # Add attribute for images.
      if anchor == 2
        attributes << [:editAs, 'oneCell']
      elsif anchor == 3
        attributes << [:editAs, 'absolute']
      end

      # Add attribute for shapes.
      attributes << [:editAs, shape.edit_as] if shape && shape.edit_as

      @writer.tag_elements('xdr:twoCellAnchor', attributes) do
        # Write the xdr:from element.
        write_from
        # Write the xdr:to element.
        write_to

        if type == 1
          # Graphic frame.

          # Write the xdr:graphicFrame element for charts.
          write_graphic_frame(index, rel_index, name, description, decorative)
        elsif type == 2
          # Write the xdr:pic element.
          write_pic(index)
        else
          # Write the xdr:sp element for shapes.
          write_sp(index, shape)
        end

        # Write the xdr:clientData element.
        write_client_data
      end
    end

    #
    # Write the <xdr:absoluteAnchor> element.
    #
    def write_absolute_anchor(index)
      @writer.tag_elements('xdr:absoluteAnchor') do
        # Different co-ordinates for horizonatal (= 0) and vertical (= 1).
        if ptrue?(@orientation)
          # Write the xdr:pos element.
          write_pos(0, -47625)

          # Write the xdr:ext element.
          write_xdr_ext(6162675, 6124575)
        else

          # Write the xdr:pos element.
          write_pos(0, 0)

          # Write the xdr:ext element.
          write_xdr_ext(9308969, 6078325)
        end

        # Write the xdr:graphicFrame element.
        write_graphic_frame(index, index)

        # Write the xdr:clientData element.
        write_client_data
      end
    end

    #
    # Write the <xdr:from> element.
    #
    def write_from
      col, row, col_offset, row_offset = dimensions

      @writer.tag_elements('xdr:from') do
        # Write the xdr:col element.
        write_col(col)
        # Write the xdr:colOff element.
        write_col_off(col_offset)
        # Write the xdr:row element.
        write_row(row)
        # Write the xdr:rowOff element.
        write_row_off(row_offset)
      end
    end

    #
    # Write the <xdr:to> element.
    #
    def write_to
      col, row, col_offset, row_offset = dimensions[4, 4]

      @writer.tag_elements('xdr:to') do
        # Write the xdr:col element.
        write_col(col)
        # Write the xdr:colOff element.
        write_col_off(col_offset)
        # Write the xdr:row element.
        write_row(row)
        # Write the xdr:rowOff element.
        write_row_off(row_offset)
      end
    end

    #
    # Write the <xdr:col> element.
    #
    def write_col(data)
      @writer.data_element('xdr:col', data)
    end

    #
    # Write the <xdr:colOff> element.
    #
    def write_col_off(data)
      @writer.data_element('xdr:colOff', data)
    end

    #
    # Write the <xdr:row> element.
    #
    def write_row(data)
      @writer.data_element('xdr:row', data)
    end

    #
    # Write the <xdr:rowOff> element.
    #
    def write_row_off(data)
      @writer.data_element('xdr:rowOff', data)
    end

    #
    # Write the <xdr:pos> element.
    #
    def write_pos(x, y)
      attributes = [
        ['x', x],
        ['y', y]
      ]

      @writer.empty_tag('xdr:pos', attributes)
    end

    #
    # Write the <xdr:ext> element.
    #
    def write_xdr_ext(cx, cy)
      attributes = [
        ['cx', cx],
        ['cy', cy]
      ]

      @writer.empty_tag('xdr:ext', attributes)
    end

    #
    # Write the <xdr:graphicFrame> element.
    #
    def write_graphic_frame(
          index, rel_index, name = nil,
          description = nil, decorative = nil, macro = nil
        )
      macro  ||= ''

      attributes = [['macro', macro]]

      @writer.tag_elements('xdr:graphicFrame', attributes) do
        # Write the xdr:nvGraphicFramePr element.
        write_nv_graphic_frame_pr(index, name, description, decorative)
        # Write the xdr:xfrm element.
        write_xfrm
        # Write the a:graphic element.
        write_atag_graphic(rel_index)
      end
    end

    #
    # Write the <xdr:nvGraphicFramePr> element.
    #
    def write_nv_graphic_frame_pr(
          index, name = nil, description = nil, decorative = nil
        )

      name = "Chart #{index}" unless ptrue?(name)

      @writer.tag_elements('xdr:nvGraphicFramePr') do
        # Write the xdr:cNvPr element.
        write_c_nv_pr(index + 1, name, description,
                      nil, nil, decorative)
        # Write the xdr:cNvGraphicFramePr element.
        write_c_nv_graphic_frame_pr
      end
    end

    #
    # Write the <xdr:cNvPr> element.
    #
    def write_c_nv_pr(index, name, description = nil, url_rel_index = nil, tip = nil, decorative = nil)
      attributes = [
        ['id',   index],
        ['name', name]
      ]

      # Add description attribute for images.
      attributes << ['descr', description] if ptrue?(description) && !ptrue?(decorative)

      if ptrue?(url_rel_index) || ptrue?(decorative)
        @writer.tag_elements('xdr:cNvPr', attributes) do
          if ptrue?(url_rel_index)
            # Write the a:hlinkClick element.
            write_a_hlink_click(url_rel_index, tip)
          end
          if ptrue?(decorative)
            # Write the adec:decorative element.
            write_decorative
          end
        end
      else
        @writer.empty_tag('xdr:cNvPr', attributes)
      end
    end

    #
    # Write the <a:hlinkClick> element.
    #
    def write_a_hlink_click(index, tip)
      schema  = 'http://schemas.openxmlformats.org/officeDocument/'
      xmlns_r = "#{schema}2006/relationships"
      r_id    = "rId#{index}"

      attributes = [
        ['xmlns:r', xmlns_r],
        ['r:id', r_id]
      ]

      attributes << ['tooltip', tip] if tip

      @writer.empty_tag('a:hlinkClick', attributes)
    end

    #
    # Write the <adec:decorative> element.
    #
    def write_decorative
      @writer.tag_elements('a:extLst') do
        write_a_uri_ext('{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}')
        write_a16_creation_id
        @writer.end_tag('a:ext')

        write_a_uri_ext('{C183D7F6-B498-43B3-948B-1728B52AA6E4}')
        write_adec_decorative
        @writer.end_tag('a:ext')
      end
    end

    #
    # Write the <a:ext> element.
    #
    def write_a_uri_ext(uri)
      attributes = [
        ['uri', uri]
      ]

      @writer.start_tag('a:ext', attributes)
    end

    #
    # Write the <adec:decorative> element.
    #
    def write_adec_decorative
      xmlns_adec = 'http://schemas.microsoft.com/office/drawing/2017/decorative'
      val        = 1

      attributes = [
        ['xmlns:adec', xmlns_adec],
        ['val',        val]
      ]

      @writer.empty_tag('adec:decorative', attributes)
    end

    #
    # Write the <a16:creationId> element.
    #
    def write_a16_creation_id
      xmlns_a_16 = 'http://schemas.microsoft.com/office/drawing/2014/main'
      id         = '{00000000-0008-0000-0000-000002000000}'

      attributes = [
        ['xmlns:a16', xmlns_a_16],
        ['id',        id]
      ]

      @writer.empty_tag('a16:creationId', attributes)
    end

    #
    # Write the <xdr:cNvGraphicFramePr> element.
    #
    def write_c_nv_graphic_frame_pr
      if @embedded
        @writer.empty_tag('xdr:cNvGraphicFramePr')
      else
        @writer.tag_elements('xdr:cNvGraphicFramePr') do
          # Write the a:graphicFrameLocks element.
          write_a_graphic_frame_locks
        end
      end
    end

    #
    # Write the <a:graphicFrameLocks> element.
    #
    def write_a_graphic_frame_locks
      no_grp = 1

      attributes = [['noGrp', no_grp]]

      @writer.empty_tag('a:graphicFrameLocks', attributes)
    end

    #
    # Write the <xdr:xfrm> element.
    #
    def write_xfrm
      @writer.tag_elements('xdr:xfrm') do
        # Write the xfrmOffset element.
        write_xfrm_offset
        # Write the xfrmOffset element.
        write_xfrm_extension
      end
    end

    #
    # Write the <a:off> xfrm sub-element.
    #
    def write_xfrm_offset
      x    = 0
      y    = 0

      attributes = [
        ['x', x],
        ['y', y]
      ]

      @writer.empty_tag('a:off', attributes)
    end

    #
    # Write the <a:ext> xfrm sub-element.
    #
    def write_xfrm_extension
      x    = 0
      y    = 0

      attributes = [
        ['cx', x],
        ['cy', y]
      ]

      @writer.empty_tag('a:ext', attributes)
    end

    #
    # Write the <a:graphic> element.
    #
    def write_atag_graphic(index)
      @writer.tag_elements('a:graphic') do
        # Write the a:graphicData element.
        write_atag_graphic_data(index)
      end
    end

    #
    # Write the <a:graphicData> element.
    #
    def write_atag_graphic_data(index)
      uri = 'http://schemas.openxmlformats.org/drawingml/2006/chart'

      attributes = [['uri', uri]]

      @writer.tag_elements('a:graphicData', attributes) do
        # Write the c:chart element.
        write_c_chart(index)
      end
    end

    #
    # Write the <c:chart> element.
    #
    def write_c_chart(id)
      schema  = 'http://schemas.openxmlformats.org/'
      xmlns_c = "#{schema}drawingml/2006/chart"
      xmlns_r = "#{schema}officeDocument/2006/relationships"

      attributes = [
        ['xmlns:c', xmlns_c],
        ['xmlns:r', xmlns_r]
      ]
      attributes << r_id_attributes(id)

      @writer.empty_tag('c:chart', attributes)
    end

    #
    # Write the <xdr:clientData> element.
    #
    def write_client_data
      @writer.empty_tag('xdr:clientData')
    end

    #
    # Write the <xdr:sp> element.
    #
    def write_sp(index, shape)
      if shape.connect == 0
        # Add attribute for shapes.
        attributes = [
          [:macro, ''],
          [:textlink, '']
        ]
        @writer.tag_elements('xdr:sp', attributes) do
          # Write the xdr:nvSpPr element.
          write_nv_sp_pr(index, shape)

          # Write the xdr:spPr element.
          write_xdr_sp_pr(shape)

          # Write the xdr:txBody element.
          write_tx_body(shape) if shape.text != 0
        end
      else
        attributes = [[:macro,  '']]
        @writer.tag_elements('xdr:cxnSp', attributes) do
          # Write the xdr:nvCxnSpPr element.
          write_nv_cxn_sp_pr(index, shape)

          # Write the xdr:spPr element.
          write_xdr_sp_pr(shape)
        end
      end
    end

    #
    # Write the <xdr:nvCxnSpPr> element.
    #
    def write_nv_cxn_sp_pr(index, shape)
      @writer.tag_elements('xdr:nvCxnSpPr') do
        shape.name = [shape.type, index].join(' ') unless shape.name
        write_c_nv_pr(shape.id, shape.name)

        @writer.tag_elements('xdr:cNvCxnSpPr') do
          attributes = [[:noChangeShapeType, '1']]
          @writer.empty_tag('a:cxnSpLocks', attributes)

          if shape.start
            attributes = [
              ['id', shape.start],
              ['idx', shape.start_index]
            ]
            @writer.empty_tag('a:stCxn', attributes)
          end

          if shape.end
            attributes = [
              ['id', shape.end],
              ['idx', shape.end_index]
            ]
            @writer.empty_tag('a:endCxn', attributes)
          end
        end
      end
    end

    #
    # Write the <xdr:NvSpPr> element.
    #
    def write_nv_sp_pr(index, shape)
      attributes = []
      attributes << ['txBox', 1] if shape.tx_box

      @writer.tag_elements('xdr:nvSpPr') do
        write_c_nv_pr(shape.id, "#{shape.type} #{index}")

        @writer.tag_elements('xdr:cNvSpPr', attributes) do
          @writer.empty_tag('a:spLocks', [[:noChangeArrowheads, '1']])
        end
      end
    end

    #
    # Write the <xdr:pic> element.
    #
    def write_pic(index)
      col_absolute, row_absolute = dimensions[8, 2]

      @writer.tag_elements('xdr:pic') do
        # Write the xdr:nvPicPr element.
        write_nv_pic_pr(index)
        # Write the xdr:blipFill element.
        write_blip_fill

        # Pictures are rectangle shapes by default.
        pic_shape = Shape.new
        pic_shape.type = 'rect'

        # Write the xdr:spPr element.
        write_sp_pr(pic_shape)
      end
    end

    #
    # Write the <xdr:nvPicPr> element.
    #
    # def write_nv_pic_pr(index, _rel_index, description, url_rel_index, tip, decorative)
    def write_nv_pic_pr(index)
      @writer.tag_elements('xdr:nvPicPr') do
        # Write the xdr:cNvPr element.
        write_c_nv_pr(
          index + 1, "Picture #{index}", description,
          url_rel_index, tip, decorative
        )
        # Write the xdr:cNvPicPr element.
        write_c_nv_pic_pr
      end
    end

    #
    # Write the <xdr:cNvPicPr> element.
    #
    def write_c_nv_pic_pr
      @writer.tag_elements('xdr:cNvPicPr') do
        # Write the a:picLocks element.
        write_a_pic_locks
      end
    end

    #
    # Write the <a:picLocks> element.
    #
    def write_a_pic_locks
      no_change_aspect = 1

      attributes = [['noChangeAspect', no_change_aspect]]

      @writer.empty_tag('a:picLocks', attributes)
    end

    #
    # Write the <xdr:blipFill> element.
    #
    def write_blip_fill
      @writer.tag_elements('xdr:blipFill') do
        # Write the a:blip element.
        write_a_blip(rel_index)
        # Write the a:stretch element.
        write_a_stretch
      end
    end

    #
    # Write the <a:blip> element.
    #
    def write_a_blip(index)
      schema  = 'http://schemas.openxmlformats.org/officeDocument/'
      xmlns_r = "#{schema}2006/relationships"
      r_embed = "rId#{index}"

      attributes = [
        ['xmlns:r', xmlns_r],
        ['r:embed', r_embed]
      ]

      @writer.empty_tag('a:blip', attributes)
    end

    #
    # Write the <a:stretch> element.
    #
    def write_a_stretch
      @writer.tag_elements('a:stretch') do
        # Write the a:fillRect element.
        write_a_fill_rect
      end
    end

    #
    # Write the <a:fillRect> element.
    #
    def write_a_fill_rect
      @writer.empty_tag('a:fillRect')
    end

    #
    # Write the <xdr:spPr> element, for charts.
    #
    def write_sp_pr(shape)
      @writer.tag_elements('xdr:spPr') do
        # Write the a:xfrm element.
        write_a_xfrm
        # Write the a:prstGeom element.
        write_a_prst_geom(shape)
      end
    end

    #
    # Write the <xdr:spPr> element for shapes.
    #
    def write_xdr_sp_pr(shape)
      attributes = [%w[bwMode auto]]

      @writer.tag_elements('xdr:spPr', attributes) do
        # Write the a:xfrm element.
        write_a_xfrm(shape)

        # Write the a:prstGeom element.
        write_a_prst_geom(shape)

        if shape.fill.to_s.bytesize > 1
          # Write the a:solidFill element.
          write_a_solid_fill(shape.fill)
        else
          @writer.empty_tag('a:noFill')
        end

        # Write the a:ln element.
        write_a_ln(shape)
      end
    end

    #
    # Write the <a:xfrm> element.
    #
    def write_a_xfrm(shape = nil)
      attributes = []

      rotation = shape ? shape.rotation : 0
      rotation *= 60000

      attributes << ['rot', rotation] if rotation != 0
      attributes << ['flipH', 1]      if shape && ptrue?(shape.flip_h)
      attributes << ['flipV', 1]      if shape && ptrue?(shape.flip_v)

      @writer.tag_elements('a:xfrm', attributes) do
        # Write the a:off element.
        write_a_off
        # Write the a:ext element.
        write_a_ext(width, height)
      end
    end

    #
    # Write the <a:off> element.
    #
    def write_a_off
      x, y = dimensions[8, 2]

      attributes = [
        ['x', x],
        ['y', y]
      ]

      @writer.empty_tag('a:off', attributes)
    end

    #
    # Write the <a:ext> element.
    #
    def write_a_ext(cx, cy)
      attributes = [
        ['cx', cx],
        ['cy', cy]
      ]

      @writer.empty_tag('a:ext', attributes)
    end

    #
    # Write the <a:prstGeom> element.
    #
    def write_a_prst_geom(shape = {})
      attributes = []
      attributes << ['prst', shape.type] if shape.type

      @writer.tag_elements('a:prstGeom', attributes) do
        # Write the a:avLst element.
        write_a_av_lst(shape)
      end
    end

    #
    # Write the <a:avLst> element.
    #
    def write_a_av_lst(shape = {})
      if shape.adjustments.respond_to?(:empty?)
        adjustments = shape.adjustments
      elsif shape.adjustments.respond_to?(:coerce)
        adjustments = [shape.adjustments]
      elsif !shape.adjustments
        adjustments = []
      end

      if adjustments.respond_to?(:empty?) && !adjustments.empty?
        @writer.tag_elements('a:avLst') do
          i = 0
          adjustments.each do |adj|
            i += 1
            # Only connectors have multiple adjustments.
            suffix = shape.connect == 0 ? '' : i

            # Scale Adjustments: 100,000 = 100%.
            adj_int = (adj * 1000).to_i

            attributes = [
              [:name, "adj#{suffix}"],
              [:fmla, "val #{adj_int}"]
            ]
            @writer.empty_tag('a:gd', attributes)
          end
        end
      else
        @writer.empty_tag('a:avLst')
      end
    end

    #
    # Write the <a:solidFill> element.
    #
    def write_a_solid_fill(rgb = '000000')
      attributes = [['val', rgb]]

      @writer.tag_elements('a:solidFill') do
        @writer.empty_tag('a:srgbClr', attributes)
      end
    end

    #
    # Write the <a:ln> elements.
    #
    def write_a_ln(shape = {})
      weight = shape.line_weight || 0
      attributes = [['w', weight * 9525]]
      @writer.tag_elements('a:ln', attributes) do
        line = shape.line || 0
        if line.to_s.bytesize > 1
          # Write the a:solidFill element.
          write_a_solid_fill(line)
        else
          @writer.empty_tag('a:noFill')
        end

        if shape.line_type != ''
          attributes = [['val', shape.line_type]]
          @writer.empty_tag('a:prstDash', attributes)
        end

        if shape.connect == 0
          attributes = [['lim', 800000]]
          @writer.empty_tag('a:miter', attributes)
        else
          @writer.empty_tag('a:round')
        end

        @writer.empty_tag('a:headEnd')
        @writer.empty_tag('a:tailEnd')
      end
    end

    #
    # Write the <xdr:txBody> element.
    #
    def write_tx_body(shape)
      attributes = [
        [:vertOverflow, "clip"],
        [:wrap,         "square"],
        [:lIns,         "27432"],
        [:tIns,         "22860"],
        [:rIns,         "27432"],
        [:bIns,         "22860"],
        [:anchor,       shape.valign],
        [:upright,      "1"]
      ]
      @writer.tag_elements('xdr:txBody') do
        @writer.empty_tag('a:bodyPr', attributes)
        @writer.empty_tag('a:lstStyle')

        @writer.tag_elements('a:p') do
          rotation = shape.format[:rotation] || 0
          rotation *= 60000

          attributes = [
            [:algn, shape.align],
            [:rtl, rotation]
          ]
          @writer.tag_elements('a:pPr', attributes) do
            attributes = [[:sz, "1000"]]
            @writer.empty_tag('a:defRPr', attributes)
          end

          @writer.tag_elements('a:r') do
            size = shape.format[:size] || 8
            size *= 100

            bold      = shape.format[:bold]      || 0
            italic    = shape.format[:italic]    || 0
            underline = ptrue?(shape.format[:underline]) ? 'sng' : 'none'
            strike    = ptrue?(shape.format[:font_strikeout]) ? 'Strike' : 'noStrike'

            attributes = [
              [:lang,     "en-US"],
              [:sz,       size],
              [:b,        bold],
              [:i,        italic],
              [:u,        underline],
              [:strike,   strike],
              [:baseline, 0]
            ]
            @writer.tag_elements('a:rPr', attributes) do
              color = shape.format[:color]
              if color
                color = shape.palette_color_from_index(color)
                color = color.sub(/^FF/, '')  # Remove leading FF from rgb for shape color.
              else
                color = '000000'
              end

              write_a_solid_fill(color)

              font = shape.format[:font] || 'Calibri'
              attributes = [[:typeface, font]]
              @writer.empty_tag('a:latin', attributes)
              @writer.empty_tag('a:cs', attributes)
            end
            @writer.tag_elements('a:t') do
              @writer.characters(shape.text)
            end
          end
        end
      end
    end
  end

  class Drawings
    include Writexlsx::Utility

    attr_writer :embedded, :orientation

    def initialize
      @writer = Package::XMLWriterSimple.new
      @drawings    = []
      @embedded    = false
      @orientation = false
    end

    def xml_str
      @writer.string
    end

    def set_xml_writer(filename)
      @writer.set_xml_writer(filename)
    end

    #
    # Assemble and write the XML file.
    #
    def assemble_xml_file
      write_xml_declaration do
        # Write the xdr:wsDr element.
        write_drawing_workspace do
          if @embedded
            @drawings.each_with_index do |drawing, index|
              # Write the xdr:twoCellAnchor element.
              drawing.writer = @writer
              drawing.embedded = @embedded
              drawing.write_two_cell_anchor(index + 1)
            end
          else
            # Write the xdr:absoluteAnchor element.
            drawing = Drawing.new(nil, nil, nil, nil, nil, nil)
            drawing.writer = @writer
            drawing.embedded = @embedded
            drawing.orientation = @orientation
            drawing.write_absolute_anchor(1)
          end
        end
      end
    end

    #
    # Add a chart, image or shape sub object to the drawing.
    #
    def add_drawing_object(drawing)
      @drawings << drawing
    end

    private

    #
    # Write the <xdr:wsDr> element.
    #
    def write_drawing_workspace(&block)
      schema = 'http://schemas.openxmlformats.org/drawingml/'
      attributes = [
        ['xmlns:xdr', "#{schema}2006/spreadsheetDrawing"],
        ['xmlns:a',    "#{schema}2006/main"]
      ]

      @writer.tag_elements('xdr:wsDr', attributes, &block)
    end
  end
end
end
