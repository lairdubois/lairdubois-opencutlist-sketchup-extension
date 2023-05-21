module Ladb::OpenCutList

  require_relative '../../helper/face_triangles_helper'

  class CommonExportFaceTo2dWorker

    include FaceTrianglesHelper

    FILE_FORMAT_DXF = 'dxf'.freeze
    FILE_FORMAT_SVG = 'svg'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_DXF, FILE_FORMAT_SVG ]

    def initialize(face, transformation, file_format, file_name = 'FACE')

      @face = face
      @transformation = transformation
      @file_format = file_format
      @file_name = file_name

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @face

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export_to_3d.title', { :file_format => @file_format }), '', "#{@file_name}.#{@file_format}")
      if path

        # Force "file_format" file extension
        unless path.end_with?(".#{@file_format}")
          path = "#{path}.#{@file_format}"
        end

        begin

          unit_converter = DimensionUtils.instance.length_to_model_unit_float(1.0.to_l)

          success = _write_face(path, @face, @transformation,unit_converter ) && File.exist?(path)

          return { :errors => [ [ 'tab.cutlist.error.failed_export_to_3d_file', { :file_format => @file_format, :error => e.message } ] ] } unless success
          return { :export_path => path }
        rescue => e
          puts e.inspect
          puts e.backtrace
          return { :errors => [ [ 'tab.cutlist.error.failed_export_to_3d_file', { :file_format => @file_format, :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

    private

    def _write_face(path, face, transformation, unit_converter)

      # Open output file
      file = File.new(path , 'w')

      # Write header
      case @file_format
      when FILE_FORMAT_DXF

        file.puts(%w[0 SECTION 2 ENTITIES].join("\n"))

        face.loops.each do |loop|

          file.puts(%w[0 POLYLINE 8 0 66 1].join("\n"))
          file.puts(%w[70 1 10 0.0 20 0.0 30 0.0].join("\n"))

          loop.vertices.each do |vertex|
            point = vertex.position.transform(transformation)
            file.puts(%w[0 VERTEX 8 0].join("\n"))
            file.puts("10\n#{_convert(point.x, unit_converter)}")
            file.puts("20\n#{_convert(point.y, unit_converter)}")
            file.puts("30\n0.0")
            file.puts("70\n32")
          end

          file.puts(%w[0 SEQEND].join("\n"))

        end

        file.puts(%w[0 ENDSEC 0 EOF].join("\n"))

      when FILE_FORMAT_SVG

        bounds = Geom::BoundingBox.new.add(_compute_children_faces_triangles([ face ], transformation))
        width = _convert(bounds.width, unit_converter)
        height = _convert(bounds.height, unit_converter)
        unit_sign = DimensionUtils.instance.unit_sign

        file.puts('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')
        file.puts('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">')
        file.puts("<svg width=\"#{width}#{unit_sign}\" height=\"#{height}#{unit_sign}\" viewBox=\"0 -#{height} #{width} #{height}\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:shaper=\"http://www.shapertools.com/namespaces/shaper\">")

        outside = []
        pockets = []
        face.loops.each do |loop|
          coords = []
          loop.vertices.each do |vertex|
            point = vertex.position.transform(transformation)
            coords << "#{_convert(point.x, unit_converter)},-#{_convert(point.y, unit_converter)}"
          end
          data = "M#{coords.join('L')}Z"
          outside << data
          pockets << data unless loop.outer?
        end
        file.puts("<path d=\"#{outside.join}\" shaper:cutType=\"outside\" fill=\"#000000\" />")
        pockets.each do |pocket|
          file.puts("<path d=\"#{pocket}\" shaper:cutType=\"pocket\" fill=\"#7F7F7F\" />")
        end

        file.puts("</svg>")

      end

      # Close output file
      file.close

      true
    end

    def _convert(value, unit_converter, precision = 6)
      (value.to_f * unit_converter).round(precision)
    end

  end

end