# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class Button
      include Writexlsx::Utility

      def initialize(worksheet, row, col, params, default_row_pixels, button_number)
        @worksheet = worksheet
        @default_row_pixels = default_row_pixels

        # Set the button caption.
        caption = params[:caption] || "Button #{button_number}"

        @font = { _caption: caption }

        # Set the macro name.
        @macro = if params[:macro]
                   "[0]!#{params[:macro]}"
                 else
                   "[0]!Button#{button_number}_Click"
                 end

        # Set the alt text for the button.
        @description = params[:description]

        # Ensure that a width and height have been set.
        default_height = @default_row_pixels
        width  = params[:width]  || DEFAULT_COL_PIXELS
        height = params[:height] || default_row_pixels

        # Scale the size of the button box if required.
        width  *= params[:x_scale] if params[:x_scale]
        height *= params[:y_scale] if params[:y_scale]

        # Round the dimensions to the nearest pixel.
        width  = (0.5 + width).to_i
        height = (0.5 + height).to_i

        # Set the x/y offsets.
        x_offset = params[:x_offset] || 0
        y_offset = params[:y_offset] || 0

        start_row = row
        start_col = col

        # Calculate the positions of button object.
        vertices = @worksheet.position_object_pixels(
          start_col,
          start_row,
          x_offset,
          y_offset,
          width,
          height
        )

        # Add the width and height for VML.
        vertices << [width, height]

        @vertices = vertices
      end

      def v_shape_attributes(id, z_index)
        attributes = v_shape_attributes_base(id)
        attributes << ['alt', @description] if @description

        attributes << ['style', (v_shape_style_base(z_index, @vertices) + style_addition).join]
        attributes << ['o:button',    't']
        attributes << ['fillcolor',   color]
        attributes << ['strokecolor', 'windowText [64]']
        attributes << ['o:insetmode', 'auto']
        attributes
      end

      def type
        '#_x0000_t201'
      end

      def color
        'buttonFace [67]'
      end

      def style_addition
        ['mso-wrap-style:tight']
      end

      def write_shape(writer, id, z_index)
        @writer = writer

        attributes = v_shape_attributes(id, z_index)

        @writer.tag_elements('v:shape', attributes) do
          # Write the v:fill element.
          write_fill
          # Write the o:lock element.
          write_rotation_lock
          # Write the v:textbox element.
          write_textbox
          # Write the x:ClientData element.
          write_client_data
        end
      end

      # attributes for <v:fill> element.
      def fill_attributes
        [
          ['color2',             'buttonFace [67]'],
          ['o:detectmouseclick', 't']
        ]
      end

      #
      # Write the <o:lock> element.
      #
      def write_rotation_lock
        attributes = [
          ['v:ext',    'edit'],
          %w[rotation t]
        ]
        @writer.empty_tag('o:lock', attributes)
      end

      #
      # Write the <v:textbox> element.
      #
      def write_textbox
        attributes = [
          ['style', 'mso-direction-alt:auto'],
          ['o:singleclick', 'f']
        ]

        @writer.tag_elements('v:textbox', attributes) do
          # Write the div element.
          write_div('center', @font)
        end
      end

      #
      # Write the <x:ClientData> element.
      #
      def write_client_data
        attributes = [%w[ObjectType Button]]

        @writer.tag_elements('x:ClientData', attributes) do
          # Write the x:Anchor element.
          write_anchor
          # Write the x:PrintObject element.
          write_print_object
          # Write the x:AutoFill element.
          write_auto_fill
          # Write the x:FmlaMacro element.
          write_fmla_macro
          # Write the x:TextHAlign element.
          write_text_halign
          # Write the x:TextVAlign element.
          write_text_valign
        end
      end

      #
      # Write the <x:PrintObject> element.
      #
      def write_print_object
        @writer.data_element('x:PrintObject', 'False')
      end

      #
      # Write the <x:FmlaMacro> element.
      #
      def write_fmla_macro
        @writer.data_element('x:FmlaMacro', @macro)
      end

      #
      # Write the <x:TextHAlign> element.
      #
      def write_text_halign
        @writer.data_element('x:TextHAlign', 'Center')
      end

      #
      # Write the <x:TextVAlign> element.
      #
      def write_text_valign
        @writer.data_element('x:TextVAlign', 'Center')
      end
    end
  end
end
end
