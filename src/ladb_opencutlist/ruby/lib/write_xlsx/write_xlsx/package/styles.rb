# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class Styles
      include Writexlsx::Utility

      def initialize
        @writer = Package::XMLWriterSimple.new
        @xf_formats        = nil
        @palette           = []
        @font_count        = 0
        @num_formats       = []
        @border_count      = 0
        @fill_count        = 0
        @custom_colors     = []
        @dxf_formats       = []
        @has_hyperlink     = 0
        @hyperlink_font_id = 0
        @has_comments      = false
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_style_sheet { write_style_sheet_base }
        end
      end

      #
      # Pass in the Format objects and other properties used to set the styles.
      #
      def set_style_properties(
            xf_formats, palette, font_count, num_formats, border_count,
            fill_count, custom_colors, dxf_formats, has_comments
          )
        @xf_formats    = xf_formats
        @palette       = palette
        @font_count    = font_count
        @num_formats   = num_formats
        @border_count  = border_count
        @fill_count    = fill_count
        @custom_colors = custom_colors
        @dxf_formats   = dxf_formats
        @has_comments  = has_comments
      end

      #
      # Convert from an Excel internal colour index to a XML style #RRGGBB index
      # based on the default or user defined values in the Workbook palette.
      #
      def palette_color(index)
        if index.to_s =~ /^#([0-9A-F]{6})$/i
          "FF#{::Regexp.last_match(1).upcase}"
        elsif index == 0x40
          "Automatic"
        else
          "FF#{palette_color_from_index(index)}"
        end
      end

      #
      # Write the <styleSheet> element.
      #
      def write_style_sheet(&block)
        attributes = [['xmlns', XMLWriterSimple::XMLNS]]

        @writer.tag_elements('styleSheet', attributes, &block)
      end

      #
      # Write the <numFmts> element.
      #
      def write_num_fmts
        count = @num_formats.size

        return if count == 0

        attributes = [['count', count]]

        @writer.tag_elements('numFmts', attributes) do
          # Write the numFmts elements.
          index = 164
          @num_formats.each do |num_format|
            write_num_fmt(index, num_format)
            index += 1
          end
        end
      end

      FORMAT_CODES = {
        0  => 'General',
        1  => '0',
        2  => '0.00',
        3  => '#,##0',
        4  => '#,##0.00',
        5  => '($#,##0_);($#,##0)',
        6  => '($#,##0_);[Red]($#,##0)',
        7  => '($#,##0.00_);($#,##0.00)',
        8  => '($#,##0.00_);[Red]($#,##0.00)',
        9  => '0%',
        10 => '0.00%',
        11 => '0.00E+00',
        12 => '# ?/?',
        13 => '# ??/??',
        14 => 'm/d/yy',
        15 => 'd-mmm-yy',
        16 => 'd-mmm',
        17 => 'mmm-yy',
        18 => 'h:mm AM/PM',
        19 => 'h:mm:ss AM/PM',
        20 => 'h:mm',
        21 => 'h:mm:ss',
        22 => 'm/d/yy h:mm',
        37 => '(#,##0_);(#,##0)',
        38 => '(#,##0_);[Red](#,##0)',
        39 => '(#,##0.00_);(#,##0.00)',
        40 => '(#,##0.00_);[Red](#,##0.00)',
        41 => '_(* #,##0_);_(* (#,##0);_(* "-"_);_(@_)',
        42 => '_($* #,##0_);_($* (#,##0);_($* "-"_);_(@_)',
        43 => '_(* #,##0.00_);_(* (#,##0.00);_(* "-"??_);_(@_)',
        44 => '_($* #,##0.00_);_($* (#,##0.00);_($* "-"??_);_(@_)',
        45 => 'mm:ss',
        46 => '[h]:mm:ss',
        47 => 'mm:ss.0',
        48 => '##0.0E+0',
        49 => '@'
      }

      #
      # Write the <numFmt> element.
      #
      def write_num_fmt(num_fmt_id, format_code)
        # Set the format code for built-in number formats.
        format_code = FORMAT_CODES[num_fmt_id] || 'General' if num_fmt_id < 164

        attributes = [
          ['numFmtId',   num_fmt_id],
          ['formatCode', format_code]
        ]

        @writer.empty_tag('numFmt', attributes)
      end

      #
      # Write the <fonts> element.
      #
      def write_fonts
        count = @font_count

        if @has_comments
          # Add an extra font for comments.
          count += 1
        end

        write_format_elements('fonts', count) do
          write_font_base
        end
      end

      def write_font_base
        @xf_formats.each do |format|
          next unless format.has_font?

          format.write_font(@writer, self)
          @has_hyperlink     = 1 if ptrue?(format.hyperlink)
          @hyperlink_font_id = format.font_index unless ptrue?(@hyperlink_font_id)
        end
        write_comment_font if @has_comments
      end

      #
      # Write the <font> element used for comments.
      #
      def write_comment_font
        @writer.tag_elements('font') do
          @writer.empty_tag('sz', [['val', 8]])
          write_color('indexed', 81)
          @writer.empty_tag('name',   [%w[val Tahoma]])
          @writer.empty_tag('family', [['val', 2]])
        end
      end

      #
      # Write the <fills> element.
      #
      def write_fills
        attributes = [['count', @fill_count]]

        @writer.tag_elements('fills', attributes) do
          write_fills_base
        end
      end

      def write_fills_base
        # Write the default fill element.
        write_default_fill('none')
        write_default_fill('gray125')

        # Write the fill elements for format objects that have them.
        @xf_formats.each do |format|
          write_fill(format) if format.has_fill?
        end
      end

      #
      # Write the <fill> element for the default fills.
      #
      def write_default_fill(pattern_type)
        @writer.tag_elements('fill') do
          @writer.empty_tag('patternFill', [['patternType', pattern_type]])
        end
      end

      PATTERNS = %w[
        none
        solid
        mediumGray
        darkGray
        lightGray
        darkHorizontal
        darkVertical
        darkDown
        darkUp
        darkGrid
        darkTrellis
        lightHorizontal
        lightVertical
        lightDown
        lightUp
        lightGrid
        lightTrellis
        gray125
        gray0625
      ]

      #
      # Write the <fill> element.
      #
      def write_fill(format, dxf_format = nil)
        # Special handling for pattern only case.
        if pattern_only_case?(format, dxf_format)
          write_default_fill(PATTERNS[format.pattern])
        else
          @writer.tag_elements('fill') do
            write_fill_base(format, dxf_format)
          end
        end
      end

      def pattern_only_case?(format, dxf_format)
        bg_color, fg_color = bg_and_fg_color(format, dxf_format)

        !ptrue?(fg_color) && !ptrue?(bg_color) && ptrue?(format.pattern)
      end

      def write_fill_base(format, dxf_format)
        # The "none" pattern is handled differently for dxf formats.
        attributes = if dxf_format && format.pattern <= 1
                       []
                     else
                       [['patternType', PATTERNS[format.pattern]]]
                     end

        @writer.tag_elements('patternFill', attributes) do
          write_pattern_fill(format, dxf_format)
        end
      end

      def write_pattern_fill(format, dxf_format)
        bg_color, fg_color = bg_and_fg_color(format, dxf_format)

        if fg_color && fg_color != 0 && fg_color != 0x40  # 'Automatic'
          @writer.empty_tag('fgColor', [['rgb', palette_color(fg_color)]])
        end

        if bg_color && bg_color != 0
          if bg_color != 0x40 # 'Automatic'
            @writer.empty_tag('bgColor', [['rgb', palette_color(bg_color)]])
          end
        elsif !dxf_format && format.pattern <= 1
          @writer.empty_tag('bgColor', [['indexed', 64]])
        end
      end

      def bg_and_fg_color(format, dxf_format)
        bg_color   = format.bg_color
        fg_color   = format.fg_color

        # Colors for dxf formats are handled differently from normal formats since
        # the normal format reverses the meaning of BG and FG for solid fills.
        if dxf_format && dxf_format != 0
          bg_color = format.dxf_bg_color
          fg_color = format.dxf_fg_color
        end

        [bg_color, fg_color]
      end

      #
      # Write the <borders> element.
      #
      def write_borders
        write_format_elements('borders', @border_count) do
          write_borders_base
        end
      end

      def write_borders_base
        @xf_formats.each do |format|
          write_border(format) if format.has_border?
        end
      end

      def write_format_elements(elements, count, &block)
        attributes = [['count', count]]

        @writer.tag_elements(elements, attributes, &block)
      end

      #
      # Write the <border> element.
      #
      def write_border(format, dxf_format = nil)
        # Write the start border tag.
        @writer.tag_elements('border', format.border_attributes) do
          write_border_base(format, dxf_format)
        end
      end

      def write_border_base(format, dxf_format)
        # Write the <border> sub elements.
        write_border_sub_elements(format)

        # Condition DXF formats don't allow diagonal borders
        if dxf_format
          write_sub_border('vertical')
          write_sub_border('horizontal')
        else
          # Ensure that a default diag border is set if the diag type is set.
          format.diag_border = 1 if format.diag_type != 0 && format.diag_border == 0

          write_sub_border('diagonal', format.diag_border, format.diag_color)
        end
      end

      def write_border_sub_elements(format)
        write_sub_border('left',   format.left,   format.left_color)
        write_sub_border('right',  format.right,  format.right_color)
        write_sub_border('top',    format.top,    format.top_color)
        write_sub_border('bottom', format.bottom, format.bottom_color)
      end

      BORDER_STYLES = %w[
        none
        thin
        medium
        dashed
        dotted
        thick
        double
        hair
        mediumDashed
        dashDot
        mediumDashDot
        dashDotDot
        mediumDashDotDot
        slantDashDot
      ]

      #
      # Write the <border> sub elements such as <right>, <top>, etc.
      #
      def write_sub_border(type, style = 0, color = nil)
        if style == 0
          @writer.empty_tag(type)
          return
        end

        attributes = [[:style, BORDER_STYLES[style]]]

        @writer.tag_elements(type, attributes) do
          if [0, 0x40].include?(color) # 'Automatic'
            @writer.empty_tag('color', [['auto', 1]])
          elsif color != 0 && color != 0x40 # 'Automatic'
            color = palette_color(color)

            @writer.empty_tag('color', [['rgb', color]])
          end
        end
      end

      #
      # Write the <cellStyleXfs> element.
      #
      def write_cell_style_xfs
        count = ptrue?(@has_hyperlink) ? 2 : 1

        attributes = [['count', count]]

        @writer.tag_elements('cellStyleXfs', attributes) do
          # Write the style_xf element.
          write_style_xf(0, 0)

          write_style_xf(1, @hyperlink_font_id) if ptrue?(@has_hyperlink)
        end
      end

      #
      # Write the <cellXfs> element.
      #
      def write_cell_xfs
        formats = @xf_formats

        attributes = [['count', formats.size]]

        @writer.tag_elements('cellXfs', attributes) do
          # Write the xf elements.
          formats.each { |format| write_xf(format) }
        end
      end

      #
      # Write the style <xf> element.
      #
      def write_style_xf(has_hyperlink, font_id)
        attributes = [
          ['numFmtId', 0],
          ['fontId',   font_id],
          ['fillId',   0],
          ['borderId', 0]
        ]

        if ptrue?(has_hyperlink)
          attributes << ['applyNumberFormat', 0]
          attributes << ['applyFill',         0]
          attributes << ['applyBorder',       0]
          attributes << ['applyAlignment',    0]
          attributes << ['applyProtection',   0]
          @writer.tag_elements('xf', attributes) do
            @writer.empty_tag('alignment',  [%w[vertical top]])
            @writer.empty_tag('protection', [['locked',   0]])
          end
        else
          @writer.empty_tag('xf', attributes)
        end
      end

      private

      def write_style_sheet_base
        write_num_fmts
        write_fonts
        write_fills
        write_borders
        write_cell_style_xfs
        write_cell_xfs
        write_cell_styles
        write_dxfs
        write_table_styles
        write_colors
      end

      #
      # Write the <xf> element.
      #
      def write_xf(format)
        # Check if XF format has alignment properties set.
        apply_align, align = format.get_align_properties

        # Check for cell protection properties.
        protection = format.get_protection_properties

        # Check if an alignment sub-element should be written.
        has_align = apply_align && !align.empty?

        # Write XF with sub-elements if required.
        if has_align || protection
          @writer.tag_elements('xf', format.xf_attributes) do
            @writer.empty_tag('alignment',  align)      if has_align
            @writer.empty_tag('protection', protection) if protection
          end
        else
          @writer.empty_tag('xf', format.xf_attributes)
        end
      end

      #
      # Write the <cellStyles> element.
      #
      def write_cell_styles
        count = ptrue?(@has_hyperlink) ? 2 : 1

        attributes = [['count', count]]

        @writer.tag_elements('cellStyles', attributes) do
          # Write the cellStyle element.
          write_cell_style('Hyperlink', 1, 8) if ptrue?(@has_hyperlink)
          write_cell_style('Normal', 0, 0)
        end
      end

      #
      # Write the <cellStyle> element.
      #
      def write_cell_style(name, xf_id, builtin_id)
        attributes = [
          ['name',      name],
          ['xfId',      xf_id],
          ['builtinId', builtin_id]
        ]

        @writer.empty_tag('cellStyle', attributes)
      end

      #
      # Write the <dxfs> element.
      #
      def write_dxfs
        attributes = [['count', @dxf_formats.count]]

        if @dxf_formats.empty?
          @writer.empty_tag('dxfs', attributes)
        else
          @writer.tag_elements('dxfs', attributes) do
            # Write the font elements for format objects that have them.
            @dxf_formats.each do |format|
              write_dxf(format)
            end
          end
        end
      end

      def write_dxf(format)
        @writer.tag_elements('dxf') do
          format.write_font(@writer, self, 1) if format.has_dxf_font?

          write_num_fmt(format.num_format_index, format.num_format) if format.num_format_index != 0

          write_fill(format, 1)    if format.has_dxf_fill?
          write_border(format, 1)  if format.has_dxf_border?
        end
      end

      #
      # Write the <tableStyles> element.
      #
      def write_table_styles
        attributes = [
          ['count',             0],
          %w[defaultTableStyle TableStyleMedium9],
          %w[defaultPivotStyle PivotStyleLight16]
        ]

        @writer.empty_tag('tableStyles', attributes)
      end

      #
      # Write the <colors> element.
      #
      def write_colors
        return if @custom_colors.empty?

        @writer.tag_elements('colors') do
          write_mru_colors(@custom_colors)
        end
      end

      #
      # Write the <mruColors> element for the most recently used colours.
      #
      def write_mru_colors(custom_colors)
        # Limit the mruColors to the last 10.
        count = custom_colors.size
        # array[-10, 10] returns array which contains last 10 items.
        custom_colors = custom_colors[-10, 10] if count > 10

        @writer.tag_elements('mruColors') do
          # Write the custom colors in reverse order.
          custom_colors.reverse.each do |color|
            write_color('rgb', color)
          end
        end
      end

      #
      # Write the <condense> element.
      #
      def write_condense
        attributes = [['val', 0]]

        @writer.empty_tag('condense', attributes)
      end

      #
      # Write the <extend> element.
      #
      def write_extend
        attributes = [['val', 0]]

        @writer.empty_tag('extend', attributes)
      end
    end
  end
end
end
