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
      file.puts("<g#{_svg_attributes(attributes)}>")
    end

    def _svg_write_group_end(file)
      file.puts("</g>")
    end

    def _svg_write_line(file, x1, y1, x2, y2, stroke_color = nil, attributes = {})
      file.puts("<line x1=\"#{x1}\" y1=\"#{y1}\" x2=\"#{x2}\" y2=\"#{y2}\" stroke=\"#{stroke_color ? "#{stroke_color}" : '#000000'}\"#{_svg_attributes(attributes)} />")
    end

    def _svg_write_rect(file, x, y, width, height, stroke_color = nil, fill_color = nil, attributes = {})
      file.puts("<rect x=\"#{x}\" y=\"#{y}\" width=\"#{width}\" height=\"#{height}\" stroke=\"#{stroke_color ? "#{stroke_color}" : "#{fill_color ? 'none' : '#000000'}"}\" fill=\"#{fill_color ? "#{fill_color}" : 'none'}\"#{_svg_attributes(attributes)} />")
    end

    def _svg_write_polygon(file, points, stroke_color = nil, fill_color = nil, attributes = {})
      file.puts("<polygon points=\"#{points}\" stroke=\"#{stroke_color ? "#{stroke_color}" : "#{fill_color ? 'none' : '#000000'}"}\" fill=\"#{fill_color ? "#{fill_color}" : 'none'}\"#{_svg_attributes(attributes)} />")
    end

    def _svg_write_circle(file, cx, cy, r, stroke_color = nil, fill_color = nil, attributes = {})
      file.puts("<circle cx=\"#{cx}\" cy=\"#{cy}\" r=\"#{r}\" stroke=\"#{stroke_color ? "#{stroke_color}" : "#{fill_color ? 'none' : '#000000'}"}\" fill=\"#{fill_color ? "#{fill_color}" : 'none'}\"#{_svg_attributes(attributes)} />")
    end

    def _svg_write_path(file, d, stroke_color = nil, fill_color = nil, attributes = {})
      file.puts("<path d=\"#{d}\" stroke=\"#{stroke_color ? "#{stroke_color}" : "#{fill_color ? 'none' : '#000000'}"}\"#{fill_color ? " fill=\"#{fill_color}\"" : ''}#{_svg_attributes(attributes)} />")
    end

    def _svg_attributes(attributes = {})
      return unless attributes.is_a?(Hash)
      "#{attributes.empty? ? '' : ' '}#{attributes.map { |key, value| "#{key}=\"#{value.to_s.gsub(/["']/, '')}\"" }.join(' ')}"
    end

  end

end