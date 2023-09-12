module Ladb::OpenCutList

  require_relative '../constants'

  module SvgWriterHelper

    def _svg_indent(inc = 1)
      if @_svg_indent.nil?
        @_svg_indent = inc
      else
        @_svg_indent += inc
      end
    end

    def _svg_append_indent
      ''.ljust([ @_svg_indent.to_i, 0 ].max)
    end

    def _svg_append_attributes(attributes = {})
      return unless attributes.is_a?(Hash)
      "#{attributes.empty? ? '' : ' '}#{attributes.map { |key, value| "#{key}=\"#{value.to_s.gsub(/["']/, '')}\"" }.join(' ')}"
    end

    def _svg_write_start(file, x, y, width, height, unit_sign)
      file.puts('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')
      file.puts('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">')
      file.puts("<!-- Generator: SketchUp, #{EXTENSION_NAME} Extension, Version #{EXTENSION_VERSION} -->")
      file.puts("<svg width=\"#{width}#{unit_sign}\" height=\"#{height}#{unit_sign}\" viewBox=\"#{x} #{y} #{width} #{height}\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:serif=\"http://www.serif.com/\" xmlns:shaper=\"http://www.shapertools.com/namespaces/shaper\">")
      _svg_indent
    end

    def _svg_write_end(file)
      _svg_indent(-1)
      file.puts("</svg>")
    end

    def _svg_write_group_start(file, attributes = {})
      file.puts("#{_svg_append_indent}<g#{_svg_append_attributes(attributes)}>")
      _svg_indent
    end

    def _svg_write_group_end(file)
      _svg_indent(-1)
      file.puts("#{_svg_append_indent}</g>")
    end

    def _svg_write_tag(file, tag, attributes = {})
      file.puts("#{_svg_append_indent}<#{tag}#{_svg_append_attributes(attributes)} />")
    end

    # Colors

    def _svg_stroke_color(stroke_color, fill_color = nil)
      return stroke_color unless stroke_color.nil?
      return '#000000' if fill_color.nil?
      'none'
    end

    def _svg_fill_color(fill_color)
      return fill_color unless fill_color.nil?
      'none'
    end

    # ID

    def _svg_sanitize_id(id)
      id.to_s.gsub(/[\s]/, '_')
    end

  end

end