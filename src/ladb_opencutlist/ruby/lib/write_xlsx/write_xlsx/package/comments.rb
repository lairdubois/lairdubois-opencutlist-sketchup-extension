# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../format'
require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class Comment
      include Writexlsx::Utility

      DEFAULT_COLOR  = 81  # what color ?
      DEFAULT_WIDTH  = 128
      DEFAULT_HEIGHT = 74

      attr_reader :row, :col, :string, :color, :vertices
      attr_reader :font_size, :font_family
      attr_accessor :author, :visible

      def initialize(workbook, worksheet, row, col, string, options = {})
        options ||= {}
        @workbook    = workbook
        @worksheet   = worksheet
        @row = row
        @col = col
        options_parse(row, col, options)
        @string = string[0, STR_MAX]
        @start_row   ||= default_start_row(row)
        @start_col   ||= default_start_col(col)
        @visible     = options[:visible]
        @x_offset    = options[:x_offset] || default_x_offset(col)
        @y_offset    = options[:y_offset] || default_y_offset(row)
        @x_scale     = options[:x_scale]  || 1
        @y_scale     = options[:y_scale]  || 1
        @width       = (0.5 + ((options[:width]  || DEFAULT_WIDTH)  * @x_scale)).to_i
        @height      = (0.5 + ((options[:height] || DEFAULT_HEIGHT) * @y_scale)).to_i
        @vertices    = @worksheet.position_object_pixels(
          @start_col, @start_row, @x_offset, @y_offset,
          @width, @height
        ) << [@width, @height]
      end

      def backgrount_color(color)
        color_id = Format.color(color)

        if color_id.to_s =~ /^#[0-9A-F]{6}/i
          @color = color_id.to_s
        elsif color_id == 0
          @color = '#ffffe1'
        else
          rgb = @workbook.palette[color_id - 8]
          @color = "##{rgb_color(rgb)} [#{color_id}]"
        end
      end

      # Minor modification to allow comparison testing. Change RGB colors
      # from long format, ffcc00 to short format fc0 used by VML.
      def rgb_color(rgb)
        r, g, b = rgb
        result = sprintf("%02x%02x%02x", r, g, b)
        result = "#{::Regexp.last_match(1)}#{::Regexp.last_match(2)}#{::Regexp.last_match(3)}" if result =~ /^([0-9a-f])\1([0-9a-f])\2([0-9a-f])\3$/
        result
      end

      def default_start_row(row)
        case row
        when 0
          0
        when ROW_MAX - 3
          ROW_MAX - 7
        when ROW_MAX - 2
          ROW_MAX - 6
        when ROW_MAX - 1
          ROW_MAX - 5
        else
          row - 1
        end
      end

      def default_start_col(col)
        case col
        when COL_MAX - 3
          COL_MAX - 6
        when COL_MAX - 2
          COL_MAX - 5
        when COL_MAX - 1
          COL_MAX - 4
        else
          col + 1
        end
      end

      def default_x_offset(col)
        case col
        when COL_MAX - 3, COL_MAX - 2, COL_MAX - 1
          49
        else
          15
        end
      end

      def default_y_offset(row)
        case row
        when 0
          2
        when ROW_MAX - 3, ROW_MAX - 2
          16
        when ROW_MAX - 1
          14
        else
          10
        end
      end

      def v_shape_attributes(id, z_index)
        attr = v_shape_attributes_base(id)
        attr << ['style', (v_shape_style_base(z_index, vertices) + style_addition).join]
        attr << ['fillcolor',   color]
        attr << ['o:insetmode', 'auto']
        attr
      end

      def type
        '#_x0000_t202'
      end

      def style_addition
        ['visibility:', visibility]
      end

      def write_shape(writer, id, z_index)
        @writer = writer

        attributes = v_shape_attributes(id, z_index)

        @writer.tag_elements('v:shape', attributes) do
          # Write the v:fill element.
          write_fill
          # Write the v:shadow element.
          write_shadow
          # Write the v:path element.
          write_comment_path(nil, 'none')
          # Write the v:textbox element.
          write_textbox
          # Write the x:ClientData element.
          write_client_data
        end
      end

      def visibility
        ptrue?(visible) ? 'visible' : 'hidden'
      end

      #
      # Write the <v:fill> element.
      #
      def fill_attributes
        [
          ['color2', '#ffffe1']
        ]
      end

      #
      # Write the <v:shadow> element.
      #
      def write_shadow
        attributes = [
          %w[on t],
          %w[color black],
          %w[obscured t]
        ]

        @writer.empty_tag('v:shadow', attributes)
      end

      #
      # Write the <v:textbox> element.
      #
      def write_textbox
        attributes = [
          ['style', 'mso-direction-alt:auto']
        ]

        @writer.tag_elements('v:textbox', attributes) do
          # Write the div element.
          write_div('left')
        end
      end

      #
      # Write the <x:ClientData> element.
      #
      def write_client_data
        attributes = [
          %w[ObjectType Note]
        ]

        @writer.tag_elements('x:ClientData', attributes) do
          @writer.empty_tag('x:MoveWithCells')
          @writer.empty_tag('x:SizeWithCells')
          # Write the x:Anchor element.
          write_anchor
          # Write the x:AutoFill element.
          write_auto_fill
          # Write the x:Row element.
          @writer.data_element('x:Row', row)
          # Write the x:Column element.
          @writer.data_element('x:Column', col)
          # Write the x:Visible element.
          @writer.empty_tag('x:Visible') if ptrue?(visible)
        end
      end

      attr_writer :writer

      def font_name
        @font
      end

      private

      def options_parse(row, col, options)
        @color       = backgrount_color(options[:color] || DEFAULT_COLOR)
        @author      = options[:author]
        @start_cell  = options[:start_cell]
        @start_row, @start_col = if @start_cell
                                   substitute_cellref(@start_cell)
                                 else
                                   [options[:start_row], options[:start_col]]
                                 end
        @visible     = options[:visible]
        @x_offset    = options[:x_offset]       || default_x_offset(col)
        @y_offset    = options[:y_offset]       || default_y_offset(row)
        @x_scale     = options[:x_scale]        || 1
        @y_scale     = options[:y_scale]        || 1
        @font        = options[:font]           || 'Tahoma'
        @font_size   = options[:font_size]      || 8
        @font_family = options[:font_family]    || 2
        @width       = (0.5 + ((options[:width]  || DEFAULT_WIDTH)  * @x_scale)).to_i
        @height      = (0.5 + ((options[:height] || DEFAULT_HEIGHT) * @y_scale)).to_i
      end
    end

    class Comments
      include Writexlsx::Utility

      def initialize(worksheet)
        @worksheet = worksheet
        @writer = Package::XMLWriterSimple.new
        @author_ids = {}
        @comments = {}
      end

      def [](row)
        @comments[row]
      end

      def add(workbook, worksheet, row, col, string, options)
        @comments[row] ||= {}
        @comments[row][col] = [workbook, worksheet, row, col, string, options]
      end

      def empty?
        @comments.empty?
      end

      def size
        sorted_comments.size
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_comments do
            write_authors(sorted_comments)
            write_comment_list(sorted_comments)
          end
        end
      end

      def sorted_comments
        unless @sorted_comments
          @sorted_comments = []
          # We sort the comments by row and column but that isn't strictly required.
          @comments.keys.sort.each do |row|
            @comments[row].keys.sort.each do |col|
              user_options = @comments[row][col]
              comment = Comment.new(*user_options)
              @comments[row][col] = comment

              # Set comment visibility if required and not already user defined.
              @comments[row][col].visible ||= 1 if comments_visible?

              # Set comment author if not already user defined.
              @comments[row][col].author ||= @worksheet.comments_author
              @sorted_comments << @comments[row][col]
            end
          end
        end

        @sorted_comments
      end

      def has_comment_in_row?(row)
        !!@comments[row]
      end

      private

      def comments_visible?
        @worksheet.comments_visible?
      end

      #
      # Write the <comments> element.
      #
      def write_comments(&block)
        attributes = [['xmlns', XMLWriterSimple::XMLNS]]

        @writer.tag_elements('comments', attributes, &block)
      end

      #
      # Write the <authors> element.
      #
      def write_authors(comment_data)
        author_count = 0

        @writer.tag_elements('authors') do
          comment_data.each do |comment|
            author = comment.author || ''
            next unless author && !@author_ids[author]

            # Store the author id.
            @author_ids[author] = author_count
            author_count += 1

            # Write the author element.
            write_author(author)
          end
        end
      end

      #
      # Write the <author> element.
      #
      def write_author(data)
        @writer.data_element('author', data)
      end

      #
      # Write the <commentList> element.
      #
      def write_comment_list(comment_data)
        @writer.tag_elements('commentList') do
          comment_data.each { |comment| write_comment(comment) }
        end
      end

      #
      # Write the <comment> element.
      #
      def write_comment(comment)
        ref = xl_rowcol_to_cell(comment.row, comment.col)
        attributes = [['ref', ref]]

        author_id = (@author_ids[comment.author] if comment.author) || 0
        attributes << ['authorId', author_id]

        @writer.tag_elements('comment', attributes) do
          write_text(comment)
        end
      end

      #
      # Write the <text> element.
      #
      def write_text(comment)
        @writer.tag_elements('text') do
          # Write the text r element.
          write_text_r(comment)
        end
      end

      #
      # Write the <r> element.
      #
      def write_text_r(comment)
        @writer.tag_elements('r') do
          # Write the rPr element.
          write_r_pr(comment)
          # Write the text r element.
          write_text_t(comment)
        end
      end

      #
      # Write the text <t> element.
      #
      def write_text_t(comment)
        text = comment.string
        attributes = []

        attributes << ['xml:space', 'preserve'] if text =~ /^\s/ || text =~ /\s$/

        @writer.data_element('t', text, attributes)
      end

      #
      # Write the <rPr> element.
      #
      def write_r_pr(comment)
        @writer.tag_elements('rPr') do
          # Write the sz element.
          write_sz(comment.font_size)
          # Write the color element.
          write_color
          # Write the rFont element.
          write_r_font(comment.font_name)
          # Write the family element.
          write_family(comment.font_family)
        end
      end

      #
      # Write the <sz> element.
      #
      def write_sz(val)
        attributes = [['val', val]]

        @writer.empty_tag('sz', attributes)
      end

      #
      # Write the <color> element.
      #
      def write_color
        @writer.empty_tag('color', [['indexed', 81]])
      end

      #
      # Write the <rFont> element.
      #
      def write_r_font(val)
        attributes = [['val', val]]

        @writer.empty_tag('rFont', attributes)
      end

      #
      # Write the <family> element.
      #
      def write_family(val)
        attributes = [['val', val]]

        @writer.empty_tag('family', attributes)
      end
    end
  end
end
end
