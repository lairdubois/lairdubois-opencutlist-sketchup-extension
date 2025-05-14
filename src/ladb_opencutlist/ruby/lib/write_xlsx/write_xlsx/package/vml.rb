# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class Vml
      include Writexlsx::Utility

      def initialize
        @writer = Package::XMLWriterSimple.new
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file(
        data_id, vml_shape_id, comments_data,
        buttons_data, header_images_data = []
      )
        return unless @writer

        write_xml_namespace do
          # Write the o:shapelayout element.
          write_shapelayout(data_id)

          z_index = 1
          unless buttons_data.empty?
            vml_shape_id, z_index =
              write_shape_type_and_shape(
                buttons_data,
                vml_shape_id, z_index
              ) do
              write_button_shapetype
            end
          end
          unless comments_data.empty?
            write_shape_type_and_shape(
              comments_data,
              vml_shape_id, z_index
            ) do
              write_comment_shapetype
            end
          end
          unless header_images_data.empty?
            write_image_shapetype
            index = 1
            header_images_data.each do |image|
              # Write the v:shape element.
              vml_shape_id += 1
              write_image_shape(vml_shape_id, index, image)
              index += 1
            end
          end
        end
        @writer.crlf
        @writer.close
      end

      private

      def write_shape_type_and_shape(data, vml_shape_id, z_index)
        # Write the v:shapetype element.
        yield
        data.each do |obj|
          # Write the v:shape element.
          vml_shape_id += 1
          obj.write_shape(@writer, vml_shape_id, z_index)
          z_index += 1
        end
        [vml_shape_id, z_index]
      end

      #
      # Write the <xml> element. This is the root element of VML.
      #
      def write_xml_namespace(&block)
        @writer.tag_elements('xml', xml_attributes, &block)
      end

      # for <xml> elements.
      def xml_attributes
        schema  = 'urn:schemas-microsoft-com:'
        [
          ['xmlns:v', "#{schema}vml"],
          ['xmlns:o', "#{schema}office:office"],
          ['xmlns:x', "#{schema}office:excel"]
        ]
      end

      #
      # Write the <o:shapelayout> element.
      #
      def write_shapelayout(data_id)
        attributes = [
          ['v:ext', 'edit']
        ]

        @writer.tag_elements('o:shapelayout', attributes) do
          # Write the o:idmap element.
          write_idmap(data_id)
        end
      end

      #
      # Write the <o:idmap> element.
      #
      def write_idmap(data_id)
        attributes = [
          ['v:ext', 'edit'],
          ['data',  data_id]
        ]

        @writer.empty_tag('o:idmap', attributes)
      end

      #
      # Write the <v:shapetype> element.
      #
      def write_comment_shapetype
        attributes = [
          %w[id _x0000_t202],
          ['coordsize', '21600,21600'],
          ['o:spt',     202],
          ['path',      'm,l,21600r21600,l21600,xe']
        ]

        @writer.tag_elements('v:shapetype', attributes) do
          # Write the v:stroke element.
          write_stroke
          # Write the v:path element.
          write_comment_path('t', 'rect')
        end
      end

      #
      # Write the <v:shapetype> element.
      #
      def write_button_shapetype
        attributes = [
          %w[id _x0000_t201],
          ['coordsize', '21600,21600'],
          ['o:spt',     201],
          ['path',      'm,l,21600r21600,l21600,xe']
        ]

        @writer.tag_elements('v:shapetype', attributes) do
          # Write the v:stroke element.
          write_stroke
          # Write the v:path element.
          write_button_path
          # Write the o:lock element.
          write_shapetype_lock
        end
      end

      #
      # Write the <v:shapetype> element.
      #
      def write_image_shapetype
        id               = '_x0000_t75'
        coordsize        = '21600,21600'
        spt              = 75
        o_preferrelative = 't'
        path             = 'm@4@5l@4@11@9@11@9@5xe'
        filled           = 'f'
        stroked          = 'f'

        attributes = [
          ['id',               id],
          ['coordsize',        coordsize],
          ['o:spt',            spt],
          ['o:preferrelative', o_preferrelative],
          ['path',             path],
          ['filled',           filled],
          ['stroked',          stroked]
        ]

        @writer.tag_elements('v:shapetype', attributes) do
          # Write the v:stroke element.
          write_stroke

          # Write the v:formulas element.
          write_formulas

          # Write the v:path element.
          write_image_path

          # Write the o:lock element.
          write_aspect_ratio_lock
        end
      end

      #
      # Write the <v:path> element.
      #
      def write_button_path
        attributes = [
          %w[shadowok f],
          ['o:extrusionok', 'f'],
          %w[strokeok f],
          %w[fillok f],
          ['o:connecttype', 'rect']
        ]
        @writer.empty_tag('v:path', attributes)
      end

      #
      # Write the <v:path> element.
      #
      def write_image_path
        extrusionok     = 'f'
        gradientshapeok = 't'
        connecttype     = 'rect'

        attributes = [
          ['o:extrusionok',   extrusionok],
          ['gradientshapeok', gradientshapeok],
          ['o:connecttype',   connecttype]
        ]

        @writer.empty_tag('v:path', attributes)
      end

      #
      # Write the <o:lock> element.
      #
      def write_shapetype_lock
        attributes = [
          ['v:ext',     'edit'],
          %w[shapetype t]
        ]
        @writer.empty_tag('o:lock', attributes)
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
      # Write the <o:lock> element.
      #
      def write_aspect_ratio_lock
        ext         = 'edit'
        aspectratio = 't'

        attributes = [
          ['v:ext',       ext],
          ['aspectratio', aspectratio]
        ]

        @writer.empty_tag('o:lock', attributes)
      end

      #
      # Write the <v:shape> element.
      #
      def write_image_shape(id, index, image_property)
        # Scale the height/width by the resolution, relative to 72dpi.
        width  = image_property.width  * 72.0 / image_property.x_dpi
        height = image_property.height * 72.0 / image_property.y_dpi

        # Excel uses a rounding based around 72 and 96 dpi.
        width  = 72 / 96.0 * ((width  * 96 / 72.0) + 0.25).to_i
        height = 72 / 96.0 * ((height * 96 / 72.0) + 0.25).to_i

        width = width.to_i if (width - width.to_i).abs < 0.1
        height = height.to_i if (height - height.to_i).abs < 0.1

        type = '#_x0000_t75'

        style = [
          "position:absolute", "margin-left:0", "margin-top:0",
          "width:#{width}pt", "height:#{height}pt",
          "z-index:#{index}"
        ].join(';')
        attributes = [
          ['id',     image_property.position],
          ['o:spid', "_x0000_s#{id}"],
          ['type',   type],
          ['style',  style]
        ]

        @writer.tag_elements('v:shape', attributes) do
          # Write the v:imagedata element.
          write_imagedata(image_property)

          # Write the o:lock element.
          write_rotation_lock
        end
      end

      #
      # Write the <v:imagedata> element.
      #
      def write_imagedata(image_property)
        attributes = [
          ['o:relid', "rId#{image_property.ref_id}"],
          ['o:title', image_property.body]
        ]

        @writer.empty_tag('v:imagedata', attributes)
      end

      #
      # Write the <v:formulas> element.
      #
      def write_formulas
        @writer.tag_elements('v:formulas') do
          # Write the v:f elements.
          write_f('if lineDrawn pixelLineWidth 0')
          write_f('sum @0 1 0')
          write_f('sum 0 0 @1')
          write_f('prod @2 1 2')
          write_f('prod @3 21600 pixelWidth')
          write_f('prod @3 21600 pixelHeight')
          write_f('sum @0 0 1')
          write_f('prod @6 1 2')
          write_f('prod @7 21600 pixelWidth')
          write_f('sum @8 21600 0')
          write_f('prod @7 21600 pixelHeight')
          write_f('sum @10 21600 0')
        end
      end

      #
      # Write the <v:f> element.
      #
      def write_f(eqn)
        attributes = [['eqn', eqn]]

        @writer.empty_tag('v:f', attributes)
      end
    end
  end
end
end
