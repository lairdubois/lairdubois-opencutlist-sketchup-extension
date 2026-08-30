module Ladb::OpenCutList

  require 'socket'
  require 'uri'

  # Minimal static file HTTP server, bound to loopback only, used to serve
  # dialog assets (html/css/js/img/fonts) so HtmlDialogs get a real HTTP
  # origin instead of file://. Some embedded content (e.g. YouTube's iframe
  # player) refuses to load under a null/file:// origin.
  #
  # Supports HTTP/1.1 keep-alive: a dialog page pulls in a hundred-ish CSS/JS/
  # font/image files, and closing the connection after every single one (a
  # fresh TCP handshake per asset) is noticeably slower than file:// even on
  # loopback -- so connections are kept open and reused across requests
  # unless the client explicitly asks to close.
  class LocalHttpServer

    # The server only runs on SketchUp's main thread, between two UI.start_timer
    # ticks: every request therefore costs at least one tick. At 0.02 s that
    # capped serving at ~45 req/s and ~22 ms of latency per file, very visible
    # whenever the embedded Chrome has nothing cached. So we poll fast while
    # there is traffic, and fall back to the slow period once the burst is over,
    # to avoid burning CPU while idle. (Measured: SketchUp honours sub-millisecond
    # intervals faithfully.)
    POLL_INTERVAL_ACTIVE = 0.002
    POLL_INTERVAL_IDLE = 0.02
    ACTIVE_WINDOW = 1.0

    IDLE_TIMEOUT = 15
    MAX_REQUEST_BYTES = 8192

    # Max number of requests kept by the tracer (see #trace=).
    TRACE_MAX = 100

    # Safe to cache aggressively in prod: the server binds a fresh ephemeral
    # port every session, so the origin (http://127.0.0.1:PORT) changes on
    # every SketchUp restart -- a cached response can never leak across
    # sessions, only speed up repeated dialog opens within the same one.
    CACHE_MAX_AGE = 86400

    HTTP_REASONS = {
        200 => 'OK',
        304 => 'Not Modified',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method Not Allowed',
    }.freeze

    MIME_TYPES = {
        '.html' => 'text/html; charset=utf-8',
        '.htm' => 'text/html; charset=utf-8',
        '.js' => 'application/javascript',
        '.css' => 'text/css',
        '.svg' => 'image/svg+xml',
        '.png' => 'image/png',
        '.jpg' => 'image/jpeg',
        '.jpeg' => 'image/jpeg',
        '.gif' => 'image/gif',
        '.ico' => 'image/x-icon',
        '.woff' => 'font/woff',
        '.woff2' => 'font/woff2',
        '.ttf' => 'font/ttf',
        '.json' => 'application/json',
        '.wav' => 'audio/wav',
    }.freeze
    DEFAULT_MIME_TYPE = 'application/octet-stream'.freeze

    attr_reader :port

    # Serving loop tuning. Accessors rather than constants so the benchmark
    # (tools/http-bench/) can compare strategies without reloading the extension.
    attr_accessor :poll_interval_active, :poll_interval_idle

    # Request tracer, to diagnose response times. From the Ruby console:
    #   PLUGIN.local_http_server.trace = true   # (re)starts recording
    #   ... open / use the dialog ...
    #   PLUGIN.local_http_server.dump_traces    # prints the details + a summary
    attr_reader :trace

    def initialize
      @server = nil
      @port = nil
      @poll_timer_id = nil
      @clients = {}
      @last_activity_at = 0.0
      @poll_interval_active = POLL_INTERVAL_ACTIVE
      @poll_interval_idle = POLL_INTERVAL_IDLE
      @trace = false
      @traces = []
    end

    # Idempotent. Returns the bound port (Integer) on success, nil on failure.
    # Never raises.
    def start
      return @port unless @server.nil?
      begin
        @server = TCPServer.new('127.0.0.1', 0)
        @port = @server.addr[1]
        @last_activity_at = Time.now.to_f
        _schedule_poll
        @port
      rescue Exception => e
        PLUGIN.dump_exception(e, false)
        @server = nil
        @port = nil
        nil
      end
    end

    def running?
      !@server.nil?
    end

    # Safe to call even if never started.
    def stop
      _cancel_poll
      @clients.each_key { |client| _close_quietly(client) }
      @clients.clear
      begin
        @server.close unless @server.nil?
      rescue Exception => e
        PLUGIN.dump_exception(e, false)
      ensure
        @server = nil
        @port = nil
      end
    end

    # Serves the pending connections. Called on every timer tick, but also
    # callable directly by a long running task hogging the main thread: without
    # it the dialog gets no answer (and Chrome none of its uncached resources)
    # for the whole duration of that task. Safe and cheap: does nothing if the
    # server is stopped, never blocks (everything is non-blocking) and does a
    # single pass.
    def pump
      return if @server.nil?
      _accept_new_clients
      _service_clients
      nil
    end

    def trace=(enabled)
      @traces = []
      @trace = !!enabled
    end

    # Prints the recorded requests, in ONE single console write: printing line
    # by line while measuring costs ~20ms per line when the Ruby console is
    # open -- far more than serving the request itself.
    def dump_traces
      if @traces.empty?
        puts '[OCL HTTP] no trace recorded (PLUGIN.local_http_server.trace = true)'
        return nil
      end
      durations = @traces.map { |t| t[:duration] }.sort
      span = @traces.last[:at] + @traces.last[:duration] / 1000.0 - @traces.first[:at]
      pick = lambda { |p| durations[[ (durations.size * p).to_i, durations.size - 1 ].min] }
      lines = @traces.map { |t|
        format('  %+8.2f ms  %8.2f ms  %9s  %s %s %s',
               (t[:at] - @traces.first[:at]) * 1000, t[:duration],
               _format_bytes(t[:bytes]), t[:status], t[:method], t[:path])
      }
      lines.unshift(format('[OCL HTTP] %d requests in %.0f ms (%.0f req/s) -- served %s',
                           @traces.size, span * 1000, span > 0 ? @traces.size / span : 0,
                           _format_bytes(@traces.inject(0) { |s, t| s + t[:bytes] })))
      lines.push(format('[OCL HTTP] handling time : avg %.2f ms | p50 %.2f | p95 %.2f | max %.2f',
                        durations.inject(0.0) { |s, d| s + d } / durations.size,
                        pick.call(0.5), pick.call(0.95), durations.last))
      puts lines.join("\n")
      nil
    end

    private

    def _format_bytes(bytes)
      return format('%.1f MB', bytes / 1048576.0) if bytes >= 1048576
      return format('%.1f KB', bytes / 1024.0) if bytes >= 1024
      "#{bytes} B"
    end

    def _schedule_poll
      return unless @poll_timer_id.nil?
      active = (Time.now.to_f - @last_activity_at.to_f) < ACTIVE_WINDOW
      @poll_timer_id = UI.start_timer(active ? @poll_interval_active : @poll_interval_idle, false) {
        @poll_timer_id = nil
        pump
        _schedule_poll if running?
      }
    end

    def _cancel_poll
      UI.stop_timer(@poll_timer_id) unless @poll_timer_id.nil?
      @poll_timer_id = nil
    end

    # Drain every pending connection (not just one per tick) -- a dialog load
    # opens several connections in parallel, and accepting only one per tick
    # would serialize the whole load against the poll interval.
    def _accept_new_clients
      return if @server.nil?
      loop do
        begin
          client = @server.accept_nonblock
        rescue IO::WaitReadable, Errno::EAGAIN
          return
        rescue Exception => e
          PLUGIN.dump_exception(e, false)
          return
        end
        @clients[client] = { :buffer => ''.dup, :last_activity => Time.now }
        @last_activity_at = Time.now.to_f
      end
    end

    # Non-blocking read pass over every open connection (new or kept-alive).
    def _service_clients
      now = Time.now
      @clients.keys.each do |client|
        state = @clients[client]
        next if state.nil? # closed by a previous iteration of this same pass

        begin
          data = client.read_nonblock(MAX_REQUEST_BYTES)
          state[:buffer] << data
          state[:last_activity] = now
        rescue IO::WaitReadable, Errno::EAGAIN
          # Nothing to read right now -- fine for a persistent, idle connection.
        rescue EOFError, Errno::ECONNRESET, Errno::EPIPE
          _close_client(client)
          next
        rescue Exception => e
          PLUGIN.dump_exception(e, false)
          _close_client(client)
          next
        end

        keep_alive = true
        while keep_alive
          header_block, rest = _extract_request(state[:buffer])
          break if header_block.nil?
          state[:buffer] = rest
          @last_activity_at = Time.now.to_f
          keep_alive = _handle_request(client, header_block)
        end
        _close_client(client) unless keep_alive

        next if @clients[client].nil? # just closed above

        if state[:buffer].bytesize > MAX_REQUEST_BYTES
          _close_client(client) # malformed / oversized request, bail out
        elsif now - state[:last_activity] > IDLE_TIMEOUT
          _close_client(client) # stale connection, free it up
        end
      end
    end

    # Splits the next full request (request-line + headers) off the front of
    # `buffer`. Returns [header_block, rest] or nil if not fully received yet.
    def _extract_request(buffer)
      if (idx = buffer.index("\r\n\r\n"))
        [buffer[0, idx], buffer[(idx + 4)..-1] || ''.dup]
      elsif (idx = buffer.index("\n\n"))
        [buffer[0, idx], buffer[(idx + 2)..-1] || ''.dup]
      end
    end

    # Parses and responds to one request. Returns true if the connection
    # should stay open (keep-alive) for the next request, false otherwise.
    def _handle_request(client, header_block)

      started_at = @trace ? Time.now.to_f : nil

      lines = header_block.split(/\r\n|\n/)
      method, raw_path, = lines.first.to_s.split(' ')
      wants_close = lines.any? { |line| line =~ /\Aconnection\s*:\s*close\s*\z/i }

      unless %w[GET HEAD].include?(method)
        _write_response(client, 405, 'text/plain', 'Method Not Allowed', wants_close)
        _trace_request(started_at, method, raw_path, 405, 0)
        return !wants_close
      end

      path = URI::DEFAULT_PARSER.unescape(raw_path.to_s.split('?').first.to_s)
      full_path = _resolve_path(path)
      if full_path.nil?
        _write_response(client, 403, 'text/plain', 'Forbidden', wants_close)
        _trace_request(started_at, method, raw_path, 403, 0)
        return !wants_close
      end

      unless File.file?(full_path)
        _write_response(client, 404, 'text/plain', 'Not Found', wants_close)
        _trace_request(started_at, method, raw_path, 404, 0)
        return !wants_close
      end

      # Conditional revalidation. In a source build Cache-Control is 'no-cache':
      # Chrome keeps the file but asks us every time whether it is still valid,
      # which turns the dialog's 4 MB of assets into a handful of empty 304s --
      # while still picking up the slightest source change instantly, unlike a
      # max-age.
      stat = File.stat(full_path)
      validators = _validators(stat)
      if _fresh?(lines, validators)
        _write_not_modified(client, wants_close, validators)
        _trace_request(started_at, method, raw_path, 304, 0)
        return !wants_close
      end

      body = method == 'HEAD' ? nil : File.binread(full_path)
      content_type = MIME_TYPES[File.extname(full_path).downcase] || DEFAULT_MIME_TYPE
      _write_response(client, 200, content_type, body, wants_close, stat.size, validators)
      _trace_request(started_at, method, raw_path, 200, stat.size)
      !wants_close
    rescue Exception => e
      PLUGIN.dump_exception(e, false)
      false
    end

    # Resolves `path` against PLUGIN_DIR (or PLUGIN.temp_dir for the '/tmp/' prefix,
    # used to serve dynamically generated thumbnails/textures) ; returns nil if it
    # would escape the applicable root.
    def _resolve_path(path)
      if path == '/tmp' || path.start_with?('/tmp/')
        root = File.expand_path(PLUGIN.temp_dir)
        sub_path = path.sub(/\A\/tmp\/?/, '')
      else
        root = File.expand_path(PLUGIN_DIR)
        sub_path = path
      end
      candidate = File.expand_path(File.join(root, sub_path))
      return nil unless candidate == root || candidate.start_with?(root + File::SEPARATOR)
      candidate
    end

    # Records the served request in memory. Deliberately silent: a single puts
    # per request is enough to completely dominate the serving time.
    def _trace_request(started_at, method, raw_path, status, bytes)
      return if started_at.nil?
      @traces.shift if @traces.size >= TRACE_MAX
      @traces << {
          :at => started_at,
          :duration => (Time.now.to_f - started_at) * 1000.0,
          :method => method,
          :path => raw_path,
          :status => status,
          :bytes => bytes,
      }
    end

    def _write_response(client, status, content_type, body, wants_close, content_length = nil, validators = nil)
      content_length ||= body ? body.bytesize : 0
      header = "HTTP/1.1 #{status} #{HTTP_REASONS[status]}\r\n" \
               "Content-Type: #{content_type}\r\n" \
               "Content-Length: #{content_length}\r\n" \
               "Cache-Control: #{status == 200 ? _cache_control : 'no-store'}\r\n" \
               "Connection: #{wants_close ? 'close' : 'keep-alive'}\r\n" \
               "#{_validators_header(validators)}" \
               "\r\n"
      client.write(header)
      client.write(body) if body
    rescue Exception => e
      PLUGIN.dump_exception(e, false)
    end

    def _write_not_modified(client, wants_close, validators)
      client.write("HTTP/1.1 304 #{HTTP_REASONS[304]}\r\n" \
                   "Cache-Control: #{_cache_control}\r\n" \
                   "Connection: #{wants_close ? 'close' : 'keep-alive'}\r\n" \
                   "#{_validators_header(validators)}" \
                   "\r\n")
    rescue Exception => e
      PLUGIN.dump_exception(e, false)
    end

    # In a source build files change under the dialog's feet: we still cache,
    # but with systematic revalidation (ETag/Last-Modified), which costs an
    # empty request instead of the whole file. Resolved lazily: Plugin isn't
    # defined yet when this file is loaded.
    def _cache_control
      @cache_control ||= Plugin::IS_RBZ ? "public, max-age=#{CACHE_MAX_AGE}" : 'no-cache'
    end

    def _validators(stat)
      {
          :etag => "\"#{stat.mtime.to_i.to_s(16)}-#{stat.size.to_s(16)}\"",
          :last_modified => stat.mtime.utc.strftime('%a, %d %b %Y %H:%M:%S GMT'),
      }
    end

    def _validators_header(validators)
      return '' if validators.nil?
      "ETag: #{validators[:etag]}\r\nLast-Modified: #{validators[:last_modified]}\r\n"
    end

    # Does the client already hold the current version?
    def _fresh?(lines, validators)
      lines.each do |line|
        if line =~ /\Aif-none-match\s*:\s*(.+?)\s*\z/i
          return $1.split(',').any? { |tag| tag.strip.sub(/\AW\//, '') == validators[:etag] }
        end
      end
      lines.any? { |line| line =~ /\Aif-modified-since\s*:\s*(.+?)\s*\z/i && $1 == validators[:last_modified] }
    end

    def _close_client(client)
      @clients.delete(client)
      _close_quietly(client)
    end

    def _close_quietly(client)
      client.close
    rescue Exception
    end

  end

end
