module Ladb::OpenCutList

  require_relative '../constants'

  module SvgWriterHelper

    def _svg_write_start(file, x, y, width, height, unit_sign)
      file.puts('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')
      file.puts("<!-- Generator: SketchUp, #{EXTENSION_NAME} Extension, Version #{EXTENSION_VERSION} -->")
      file.puts("<svg width=\"#{width}#{unit_sign}\" height=\"#{height}#{unit_sign}\" viewBox=\"#{x} #{y} #{width} #{height}\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:shaper=\"http://www.shapertools.com/namespaces/shaper\">")
    end

    def _svg_write_end(file)
      file.puts("</svg>")
    end

    def _svg_write_group_start(file, attributes = {})
      file.puts("<g#{_svg_append_attributes(attributes)}>")
    end

    def _svg_write_group_end(file)
      file.puts("</g>")
    end

    def _svg_write_tag(file, tag, attributes = {})
      file.puts("<#{tag}#{_svg_append_attributes(attributes)} />")
    end

    def _svg_append_attributes(attributes = {})
      return unless attributes.is_a?(Hash)
      "#{attributes.empty? ? '' : ' '}#{attributes.map { |key, value| "#{key}=\"#{value.to_s.gsub(/["']/, '')}\"" }.join(' ')}"
    end

  end

end