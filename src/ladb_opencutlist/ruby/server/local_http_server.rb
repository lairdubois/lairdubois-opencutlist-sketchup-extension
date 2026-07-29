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

    POLL_INTERVAL = 0.02
    IDLE_TIMEOUT = 15
    MAX_REQUEST_BYTES = 8192

    # Safe to cache aggressively in prod: the server binds a fresh ephemeral
    # port every session, so the origin (http://127.0.0.1:PORT) changes on
    # every SketchUp restart -- a cached response can never leak across
    # sessions, only speed up repeated dialog opens within the same one.
    CACHE_MAX_AGE = 86400

    HTTP_REASONS = {
        200 => 'OK',
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

    def initialize
      @server = nil
      @port = nil
      @poll_timer_id = nil
      @clients = {}
    end

    # Idempotent. Returns the bound port (Integer) on success, nil on failure.
    # Never raises.
    def start
      return @port unless @server.nil?
      begin
        @server = TCPServer.new('127.0.0.1', 0)
        @port = @server.addr[1]
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

    private

    def _schedule_poll
      return unless @poll_timer_id.nil?
      @poll_timer_id = UI.start_timer(POLL_INTERVAL, false) {
        @poll_timer_id = nil
        _accept_new_clients
        _service_clients
        _schedule_poll if running?
      }
    end

    def _cancel_poll
      UI.stop_timer(@poll_timer_id) unless @poll_timer_id.nil?
      @poll_timer_id = nil
    end

    # Drain every pending connection (not just one per tick) -- a dialog load
    # opens several connections in parallel, and accepting only one per tick
    # would serialize the whole load against POLL_INTERVAL.
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
      lines = header_block.split(/\r\n|\n/)
      method, raw_path, = lines.first.to_s.split(' ')
      wants_close = lines.any? { |line| line =~ /\Aconnection\s*:\s*close\s*\z/i }

      unless %w[GET HEAD].include?(method)
        _write_response(client, 405, 'text/plain', 'Method Not Allowed', wants_close)
        return !wants_close
      end

      path = URI::DEFAULT_PARSER.unescape(raw_path.to_s.split('?').first.to_s)
      full_path = _resolve_path(path)
      if full_path.nil?
        _write_response(client, 403, 'text/plain', 'Forbidden', wants_close)
        return !wants_close
      end

      unless File.file?(full_path)
        _write_response(client, 404, 'text/plain', 'Not Found', wants_close)
        return !wants_close
      end

      body = method == 'HEAD' ? nil : File.binread(full_path)
      content_type = MIME_TYPES[File.extname(full_path).downcase] || DEFAULT_MIME_TYPE
      _write_response(client, 200, content_type, body, wants_close, File.size(full_path))
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

    def _write_response(client, status, content_type, body, wants_close, content_length = nil)
      content_length ||= body ? body.bytesize : 0
      cache_control = (status == 200 && Plugin::IS_RBZ) ? "public, max-age=#{CACHE_MAX_AGE}" : 'no-store'
      header = "HTTP/1.1 #{status} #{HTTP_REASONS[status]}\r\n" \
               "Content-Type: #{content_type}\r\n" \
               "Content-Length: #{content_length}\r\n" \
               "Cache-Control: #{cache_control}\r\n" \
               "Connection: #{wants_close ? 'close' : 'keep-alive'}\r\n" \
               "\r\n"
      client.write(header)
      client.write(body) if body
    rescue Exception => e
      PLUGIN.dump_exception(e, false)
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
