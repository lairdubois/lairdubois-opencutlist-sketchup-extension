# Converts the <path> and <rect> elements of an SVG file into a string compatible with
# Ladb::OpenCutList::Kuix::Motif2d.patterns_from_svg_path.
#
# Output format : absolute M/L commands only, "x,y" coordinates normalized to [0..1]
# (y pointing down, like SVG), sub-paths separated by a space.
# Compact format : H/V for axis-aligned segments, Z for closed sub-paths, no leading zero (.75), no spaces.
# Curves (C, S, Q, T) and arcs (A) are flattened into line segments.
# Transforms of the path and of its ancestor groups are applied.
#
# Usage : ruby svg-to-motif2d.rb [options] file.svg
#   -p, --precision N   Decimals kept (default 3)
#   -s, --segments N    Segments per curve / per quarter turn of arc (default 8)
#   -f, --fit           Normalize on the geometry bounds (aspect ratio kept, centered) instead of the viewBox
#   -c, --compact       Output the compact format
#   -r, --ruby          Output a ready-to-paste Kuix::Motif2d.new(...) Ruby expression

require 'rexml/document'
require 'strscan'
require 'optparse'

module SvgToMotif2d

  NUMBER_RE = /[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/
  SEPARATOR_RE = /[\s,]*/
  COMMAND_RE = /[MmLlHhVvCcSsQqTtAaZz]/
  IGNORED_ANCESTORS = %w[defs clipPath mask symbol marker pattern]

  # -- Transforms -- (matrix [a b c d e f] : x' = a*x + c*y + e, y' = b*x + d*y + f)

  IDENTITY = [ 1.0, 0.0, 0.0, 1.0, 0.0, 0.0 ]

  def self.multiply(m, n)
    [
      m[0] * n[0] + m[2] * n[1],
      m[1] * n[0] + m[3] * n[1],
      m[0] * n[2] + m[2] * n[3],
      m[1] * n[2] + m[3] * n[3],
      m[0] * n[4] + m[2] * n[5] + m[4],
      m[1] * n[4] + m[3] * n[5] + m[5]
    ]
  end

  def self.apply(m, x, y)
    [ m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5] ]
  end

  def self.parse_transform(value)
    matrix = IDENTITY
    return matrix if value.nil?
    value.scan(/(matrix|translate|scale|rotate|skewX|skewY)\s*\(([^)]*)\)/) do |name, args|
      a = args.scan(NUMBER_RE).map(&:to_f)
      m = case name
          when 'matrix'
            a[0, 6]
          when 'translate'
            [ 1, 0, 0, 1, a[0] || 0, a[1] || 0 ]
          when 'scale'
            [ a[0], 0, 0, a[1] || a[0], 0, 0 ]
          when 'rotate'
            r = (a[0] || 0) * Math::PI / 180
            rm = [ Math.cos(r), Math.sin(r), -Math.sin(r), Math.cos(r), 0, 0 ]
            if a.length >= 3
              rm = multiply(multiply([ 1, 0, 0, 1, a[1], a[2] ], rm), [ 1, 0, 0, 1, -a[1], -a[2] ])
            end
            rm
          when 'skewX'
            [ 1, 0, Math.tan(a[0] * Math::PI / 180), 1, 0, 0 ]
          when 'skewY'
            [ 1, Math.tan(a[0] * Math::PI / 180), 0, 1, 0, 0 ]
          end
      matrix = multiply(matrix, m.map(&:to_f))
    end
    matrix
  end

  # -- Path data --

  # Returns an Array of sub-paths (Array of [x, y]) in the path's local coordinates.
  def self.parse_path_data(d, segments)
    subpaths = []
    current = nil
    x = y = 0.0
    start_x = start_y = 0.0
    last_ctrl = nil   # [x, y, kind] kind = :cubic or :quad
    command = nil

    ss = StringScanner.new(d)
    read_number = lambda do
      ss.skip(SEPARATOR_RE)
      token = ss.scan(NUMBER_RE)
      raise "Invalid path data near '#{ss.rest[0, 20]}'" if token.nil?
      token.to_f
    end
    read_flag = lambda do
      ss.skip(SEPARATOR_RE)
      token = ss.scan(/[01]/)
      raise "Invalid arc flag near '#{ss.rest[0, 20]}'" if token.nil?
      token == '1'
    end
    line_to = lambda do |nx, ny|
      if current.nil?   # Drawing command without a preceding moveto
        current = [ [ x, y ] ]
        subpaths << current
      end
      current << [ nx, ny ]
      x, y = nx, ny
    end

    loop do
      ss.skip(SEPARATOR_RE)
      break if ss.eos?

      if (c = ss.scan(COMMAND_RE))
        command = c
      elsif command.nil? || command =~ /[Zz]/
        raise "Invalid path data near '#{ss.rest[0, 20]}'"
      end
      # else : implicit repetition of the previous command

      rel = command == command.downcase
      ox = rel ? x : 0.0
      oy = rel ? y : 0.0
      ctrl = nil

      case command.upcase
      when 'M'
        x = ox + read_number.call
        y = oy + read_number.call
        start_x, start_y = x, y
        current = [ [ x, y ] ]
        subpaths << current
        command = rel ? 'l' : 'L'   # Subsequent pairs are implicit linetos
      when 'L'
        nx = ox + read_number.call
        ny = oy + read_number.call
        line_to.call(nx, ny)
      when 'H'
        line_to.call(ox + read_number.call, y)
      when 'V'
        line_to.call(x, oy + read_number.call)
      when 'Z'
        line_to.call(start_x, start_y) if current && current.last != [ start_x, start_y ]
        x, y = start_x, start_y
        current = nil
      when 'C', 'S'
        if command.upcase == 'C'
          x1 = ox + read_number.call
          y1 = oy + read_number.call
        elsif last_ctrl && last_ctrl[2] == :cubic
          x1, y1 = 2 * x - last_ctrl[0], 2 * y - last_ctrl[1]
        else
          x1, y1 = x, y
        end
        x2 = ox + read_number.call
        y2 = oy + read_number.call
        ex = ox + read_number.call
        ey = oy + read_number.call
        x0, y0 = x, y
        (1..segments).each do |i|
          t = i.to_f / segments
          u = 1 - t
          line_to.call(
            u**3 * x0 + 3 * u**2 * t * x1 + 3 * u * t**2 * x2 + t**3 * ex,
            u**3 * y0 + 3 * u**2 * t * y1 + 3 * u * t**2 * y2 + t**3 * ey
          )
        end
        x, y = ex, ey   # Avoid float drift on the end point
        current[-1] = [ ex, ey ]
        ctrl = [ x2, y2, :cubic ]
      when 'Q', 'T'
        if command.upcase == 'Q'
          x1 = ox + read_number.call
          y1 = oy + read_number.call
        elsif last_ctrl && last_ctrl[2] == :quad
          x1, y1 = 2 * x - last_ctrl[0], 2 * y - last_ctrl[1]
        else
          x1, y1 = x, y
        end
        ex = ox + read_number.call
        ey = oy + read_number.call
        x0, y0 = x, y
        (1..segments).each do |i|
          t = i.to_f / segments
          u = 1 - t
          line_to.call(u**2 * x0 + 2 * u * t * x1 + t**2 * ex, u**2 * y0 + 2 * u * t * y1 + t**2 * ey)
        end
        x, y = ex, ey
        current[-1] = [ ex, ey ]
        ctrl = [ x1, y1, :quad ]
      when 'A'
        rx = read_number.call.abs
        ry = read_number.call.abs
        phi = read_number.call * Math::PI / 180
        large_arc = read_flag.call
        sweep = read_flag.call
        ex = ox + read_number.call
        ey = oy + read_number.call
        arc_points(x, y, rx, ry, phi, large_arc, sweep, ex, ey, segments).each { |px, py| line_to.call(px, py) }
        x, y = ex, ey
        current[-1] = [ ex, ey ] if current
      end

      last_ctrl = ctrl
    end

    subpaths.select { |subpath| subpath.length > 1 }
  end

  # Endpoint to center parameterization (SVG spec, appendix F.6.5)
  def self.arc_points(x1, y1, rx, ry, phi, large_arc, sweep, x2, y2, segments)
    return [] if x1 == x2 && y1 == y2
    return [ [ x2, y2 ] ] if rx == 0 || ry == 0

    cos_phi = Math.cos(phi)
    sin_phi = Math.sin(phi)
    dx = (x1 - x2) / 2
    dy = (y1 - y2) / 2
    x1p = cos_phi * dx + sin_phi * dy
    y1p = -sin_phi * dx + cos_phi * dy

    lambda = x1p**2 / rx**2 + y1p**2 / ry**2
    if lambda > 1
      rx *= Math.sqrt(lambda)
      ry *= Math.sqrt(lambda)
    end

    num = rx**2 * ry**2 - rx**2 * y1p**2 - ry**2 * x1p**2
    den = rx**2 * y1p**2 + ry**2 * x1p**2
    coef = Math.sqrt([ num / den, 0 ].max) * (large_arc == sweep ? -1 : 1)
    cxp = coef * rx * y1p / ry
    cyp = -coef * ry * x1p / rx
    cx = cos_phi * cxp - sin_phi * cyp + (x1 + x2) / 2
    cy = sin_phi * cxp + cos_phi * cyp + (y1 + y2) / 2

    ux = (x1p - cxp) / rx
    uy = (y1p - cyp) / ry
    vx = (-x1p - cxp) / rx
    vy = (-y1p - cyp) / ry
    theta1 = Math.atan2(uy, ux)
    delta = Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
    delta -= 2 * Math::PI if !sweep && delta > 0
    delta += 2 * Math::PI if sweep && delta < 0

    count = [ (delta.abs / (Math::PI / 2) * segments).ceil, 1 ].max
    (1..count).map do |i|
      theta = theta1 + delta * i / count
      [
        cos_phi * rx * Math.cos(theta) - sin_phi * ry * Math.sin(theta) + cx,
        sin_phi * rx * Math.cos(theta) + cos_phi * ry * Math.sin(theta) + cy
      ]
    end
  end

  # -- SVG --

  def self.view_box(svg)
    if (vb = svg.attributes['viewBox'])
      values = vb.scan(NUMBER_RE).map(&:to_f)
      return values if values.length == 4 && values[2] > 0 && values[3] > 0
    end
    w = svg.attributes['width'].to_s.to_f
    h = svg.attributes['height'].to_s.to_f
    return [ 0.0, 0.0, w, h ] if w > 0 && h > 0
    nil
  end

  def self.length_attribute(element, name)
    value = element.attributes[name]
    return nil if value.nil? || value.strip.empty? || value.strip == 'auto'
    value.to_f   # Units (px) are ignored
  end

  # Converts a <rect> into path data (rounded corners become arcs)
  def self.rect_path_data(element)
    x = length_attribute(element, 'x') || 0.0
    y = length_attribute(element, 'y') || 0.0
    w = length_attribute(element, 'width') || 0.0
    h = length_attribute(element, 'height') || 0.0
    return nil if w <= 0 || h <= 0   # Not rendered

    rx = length_attribute(element, 'rx')
    ry = length_attribute(element, 'ry')
    rx = ry if rx.nil? || rx < 0
    ry = rx if ry.nil? || ry < 0
    rx = [ rx || 0.0, w / 2 ].min
    ry = [ ry || 0.0, h / 2 ].min

    if rx > 0 && ry > 0
      "M#{x + rx},#{y} H#{x + w - rx} A#{rx},#{ry} 0 0 1 #{x + w},#{y + ry} " \
      "V#{y + h - ry} A#{rx},#{ry} 0 0 1 #{x + w - rx},#{y + h} " \
      "H#{x + rx} A#{rx},#{ry} 0 0 1 #{x},#{y + h - ry} " \
      "V#{y + ry} A#{rx},#{ry} 0 0 1 #{x + rx},#{y} Z"
    else
      "M#{x},#{y} H#{x + w} V#{y + h} H#{x} Z"
    end
  end

  def self.collect_subpaths(element, matrix, segments, out)
    return if IGNORED_ANCESTORS.include?(element.name)
    matrix = multiply(matrix, parse_transform(element.attributes['transform']))
    d = case element.name
        when 'path'
          element.attributes['d']
        when 'rect'
          rect_path_data(element)
        end
    if d
      parse_path_data(d, segments).each do |subpath|
        out << subpath.map { |px, py| apply(matrix, px, py) }
      end
    end
    element.elements.each { |child| collect_subpaths(child, matrix, segments, out) }
  end

  def self.format_number(value, precision, compact = false)
    s = format("%.#{precision}f", value)
    s = s.sub(/0+\z/, '').sub(/\.\z/, '') if s.include?('.')
    s = '0' if s == '-0'
    s = s.sub(/\A(-?)0\./, '\1.') if compact
    s
  end

  # coords : Array of [x, y] formatted Strings, without consecutive duplicates
  def self.compact_path_data(coords)
    closed = coords.length > 2 && coords.first == coords.last
    coords = coords[0..-2] if closed
    d = "M#{coords[0].join(',')}"
    coords.each_cons(2) do |(x0, y0), (x1, y1)|
      d << if y0 == y1
             "H#{x1}"
           elsif x0 == x1
             "V#{y1}"
           else
             "L#{x1},#{y1}"
           end
    end
    d << 'Z' if closed
    d
  end

  def self.convert(svg_content, precision: 3, segments: 8, fit: false, compact: false)
    doc = REXML::Document.new(svg_content)
    svg = doc.root
    raise 'Not an SVG document' if svg.nil? || svg.name != 'svg'

    subpaths = []
    svg.elements.each { |child| collect_subpaths(child, IDENTITY, segments, subpaths) }
    raise 'No <path> or <rect> found' if subpaths.empty?

    if fit
      xs = subpaths.flatten(1).map(&:first)
      ys = subpaths.flatten(1).map(&:last)
      size = [ xs.max - xs.min, ys.max - ys.min ].max
      raise 'Degenerated geometry' if size <= 0
      min_x = xs.min - (size - (xs.max - xs.min)) / 2
      min_y = ys.min - (size - (ys.max - ys.min)) / 2
      width = height = size
    else
      min_x, min_y, width, height = view_box(svg)
      raise 'No usable viewBox or width/height (use --fit)' if width.nil?
    end

    out_of_range = false
    patterns = subpaths.map do |subpath|
      coords = subpath.map do |px, py|
        nx = (px - min_x) / width
        ny = (py - min_y) / height
        out_of_range ||= nx < 0 || ny < 0 || nx > 1 || ny > 1
        [ format_number(nx, precision, compact), format_number(ny, precision, compact) ]
      end
      coords = coords.chunk { |c| c }.map(&:first)   # Drop duplicates created by rounding
      next nil if coords.length < 2
      compact ? compact_path_data(coords) : 'M' + coords.map { |c| c.join(',') }.join('L')
    end.compact

    warn 'Warning: some points are outside [0..1] and will be drawn outside the Motif2d bounds (try --fit)' if out_of_range

    patterns.join(compact ? '' : ' ')
  end

end

if __FILE__ == $0

  options = { precision: 3, segments: 8, fit: false, compact: false, ruby: false }
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: ruby svg-to-motif2d.rb [options] file.svg'
    opts.on('-p', '--precision N', Integer, 'Decimals kept (default 3)') { |v| options[:precision] = v }
    opts.on('-s', '--segments N', Integer, 'Segments per curve / per quarter turn of arc (default 8)') { |v| options[:segments] = [ v, 1 ].max }
    opts.on('-f', '--fit', 'Normalize on the geometry bounds instead of the viewBox') { options[:fit] = true }
    opts.on('-c', '--compact', 'Output the compact format (H/V, Z, .75, no spaces)') { options[:compact] = true }
    opts.on('-r', '--ruby', 'Output a Kuix::Motif2d.new(...) Ruby expression') { options[:ruby] = true }
    opts.on('-h', '--help', 'Show this help') { puts opts; exit }
  end
  parser.parse!

  if ARGV.length != 1
    warn parser.banner
    exit 1
  end

  begin
    result = SvgToMotif2d.convert(
      File.read(ARGV[0]),
      precision: options[:precision],
      segments: options[:segments],
      fit: options[:fit],
      compact: options[:compact]
    )
    puts options[:ruby] ? "Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('#{result}'))" : result
  rescue StandardError => e
    warn "Error: #{e.message}"
    exit 1
  end

end
