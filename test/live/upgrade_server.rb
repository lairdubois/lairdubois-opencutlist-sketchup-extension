# Local HTTP server serving an RBZ with injected faults, for the self-updater
# live harness (test/live/upgrade_harness.rb). Plain Ruby, no gem : run it
# outside SketchUp.
#
#   ruby test/live/upgrade_server.rb [--port 8787] [--rbz dist/ladb_opencutlist.rbz]
#
# One path per scenario (GET http://127.0.0.1:8787/<scenario>) :
#
#   ok                  200, Content-Length
#   chunked             200, Transfer-Encoding: chunked (no total size)
#   gzip                200, Content-Encoding: gzip (announced size = compressed size)
#   redirect            302 -> 301 (relative, then absolute Location) -> ok
#   slow                200, throttled to ~8 s
#   slow_chunked        200, chunked, throttled to ~8 s
#   pause               200, 40 % sent, nothing for PAUSE_SECONDS, then the rest
#   not_found           404, HTML page
#   server_error        500, HTML page
#   html                200, an HTML page instead of the archive
#   empty               200, Content-Length: 0
#   truncated           Content-Length of the whole archive, connection closed at 40 %
#   truncated_chunked   chunked, connection closed at 40 % without the final chunk
#   corrupt             200, whole archive with one byte altered in the middle
#   stall               200, 10 % sent then nothing for STALL_SECONDS

require 'socket'
require 'zlib'
require 'stringio'

port = 8787
rbz_file = File.expand_path('../../dist/ladb_opencutlist.rbz', __dir__)
args = ARGV.dup
until args.empty?
  case (arg = args.shift)
  when '--port' then port = args.shift.to_i
  when '--rbz' then rbz_file = File.expand_path(args.shift)
  else abort("Unknown argument #{arg}")
  end
end
abort("Archive not found : #{rbz_file} (run gulp build, or pass --rbz)") unless File.file?(rbz_file)

STALL_SECONDS = 300
PAUSE_SECONDS = 3
RBZ = File.binread(rbz_file).freeze
RBZ_GZIP = begin
  io = StringIO.new(''.b)
  gz = Zlib::GzipWriter.new(io)
  gz.write(RBZ)
  gz.close
  io.string.freeze
end
RBZ_CORRUPT = begin
  data = RBZ.dup
  data.setbyte(data.bytesize / 2, data.getbyte(data.bytesize / 2) ^ 0xFF)
  data.freeze
end
HTML = "<!doctype html><html><body><h1>Not the archive</h1></body></html>".freeze

def head(client, status, headers = {})
  client.write("HTTP/1.1 #{status}\r\n")
  headers.merge('Connection' => 'close').each { |k, v| client.write("#{k}: #{v}\r\n") }
  client.write("\r\n")
end

def send_body(client, status, body, type = 'application/octet-stream', headers = {})
  head(client, status, { 'Content-Type' => type, 'Content-Length' => body.bytesize }.merge(headers))
  client.write(body)
end

def send_chunk(client, data)
  client.write("#{data.bytesize.to_s(16)}\r\n")
  client.write(data)
  client.write("\r\n")
end

def serve(client, path, port)
  case path
  when 'ok'
    send_body(client, '200 OK', RBZ)
  when 'chunked', 'truncated_chunked'
    head(client, '200 OK', 'Content-Type' => 'application/octet-stream', 'Transfer-Encoding' => 'chunked')
    limit = path == 'chunked' ? RBZ.bytesize : RBZ.bytesize * 4 / 10
    offset = 0
    while offset < limit
      size = [ 64 * 1024, limit - offset ].min
      send_chunk(client, RBZ.byteslice(offset, size))
      offset += size
    end
    client.write("0\r\n\r\n") if path == 'chunked'
  when 'slow_chunked'
    head(client, '200 OK', 'Content-Type' => 'application/octet-stream', 'Transfer-Encoding' => 'chunked')
    steps = 80
    step = (RBZ.bytesize + steps - 1) / steps
    steps.times do |i|
      data = RBZ.byteslice(i * step, step)
      send_chunk(client, data) unless data.nil? || data.empty?
      sleep(0.1)
    end
    client.write("0\r\n\r\n")
  when 'pause'
    head(client, '200 OK', 'Content-Type' => 'application/octet-stream', 'Content-Length' => RBZ.bytesize)
    split = RBZ.bytesize * 4 / 10
    client.write(RBZ.byteslice(0, split))
    sleep(PAUSE_SECONDS)
    client.write(RBZ.byteslice(split, RBZ.bytesize - split))
  when 'gzip'
    send_body(client, '200 OK', RBZ_GZIP, 'application/octet-stream', 'Content-Encoding' => 'gzip')
  when 'redirect'
    head(client, '302 Found', 'Location' => '/redirect_2', 'Content-Length' => 0)
  when 'redirect_2'
    head(client, '301 Moved Permanently', 'Location' => "http://127.0.0.1:#{port}/ok", 'Content-Length' => 0)
  when 'slow'
    head(client, '200 OK', 'Content-Type' => 'application/octet-stream', 'Content-Length' => RBZ.bytesize)
    steps = 80
    step = (RBZ.bytesize + steps - 1) / steps
    steps.times do |i|
      client.write(RBZ.byteslice(i * step, step) || '')
      sleep(0.1)
    end
  when 'not_found'
    send_body(client, '404 Not Found', HTML, 'text/html')
  when 'server_error'
    send_body(client, '500 Internal Server Error', HTML, 'text/html')
  when 'html'
    send_body(client, '200 OK', HTML, 'text/html')
  when 'empty'
    send_body(client, '200 OK', '')
  when 'truncated'
    head(client, '200 OK', 'Content-Type' => 'application/octet-stream', 'Content-Length' => RBZ.bytesize)
    client.write(RBZ.byteslice(0, RBZ.bytesize * 4 / 10))
  when 'corrupt'
    send_body(client, '200 OK', RBZ_CORRUPT)
  when 'stall'
    head(client, '200 OK', 'Content-Type' => 'application/octet-stream', 'Content-Length' => RBZ.bytesize)
    client.write(RBZ.byteslice(0, RBZ.bytesize / 10))
    sleep(STALL_SECONDS)
  else
    send_body(client, '404 Not Found', "Unknown scenario #{path}", 'text/plain')
  end
end

server = TCPServer.new('127.0.0.1', port)
puts "Serving #{rbz_file} (#{RBZ.bytesize} bytes) on http://127.0.0.1:#{port}/<scenario>"
$stdout.flush
loop do
  client = server.accept
  Thread.new(client) do |c|
    begin
      request_line = c.gets.to_s
      while (line = c.gets) && line != "\r\n"; end   # Skip the request headers
      path = request_line.split(' ')[1].to_s.sub(%r{\A/}, '').sub(/\?.*\z/, '')
      puts "#{Time.now.strftime('%H:%M:%S')} GET /#{path}"
      $stdout.flush
      serve(c, path, port)
    rescue => e
      puts "  #{path} : #{e.class} #{e.message}"   # The client hung up (cancelled request…)
    ensure
      c.close rescue nil
    end
  end
end
