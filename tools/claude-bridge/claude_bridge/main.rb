# Claude Bridge — minimal dev-only eval server for SketchUp
#
# Lets a local agent (Claude Code) inspect the live model by sending Ruby code
# over HTTP. Everything runs on the SketchUp main thread, so the SketchUp API
# is safe to use from evaluated code (long-running code will freeze the UI).
#
# Start/stop with the "Claude Bridge" toolbar button (checked = running), the
# Extensions > Claude Bridge menu item, or from the Ruby console:
#   Ladb::ClaudeBridge.start
#   Ladb::ClaudeBridge.stop
#
# Call (from a shell):
#   curl -s -H 'X-Claude-Bridge: 1' http://127.0.0.1:7857/ping
#   curl -s -X POST -H 'X-Claude-Bridge: 1' --data-binary @script.rb http://127.0.0.1:7857/eval
#
# The response is JSON: { ok:, result:, stdout: } or { ok: false, error:, backtrace: }.
# The result is the value of the last expression of the script.
#
# Security: binds 127.0.0.1 only. The X-Claude-Bridge header is required on
# every request so a malicious web page can't drive the server from a browser
# (custom headers force a CORS preflight, which is never granted). Any local
# process can still reach it: start it only when needed, this is an eval server.

require 'socket'
require 'json'
require 'stringio'

module Ladb
  module ClaudeBridge

    DEFAULT_PORT = 7857
    READ_TIMEOUT = 3      # seconds to receive a full request
    MAX_BODY_SIZE = 10 * 1024 * 1024
    GUARD_HEADER = 'x-claude-bridge'

    @server = nil
    @timer_id = nil

    def self.start(port: DEFAULT_PORT)
      stop
      @server = TCPServer.new('127.0.0.1', port)
      @timer_id = UI.start_timer(0.1, true) { _tick }
      _log("Listening on http://127.0.0.1:#{port}")
      _refresh_ui
      true
    rescue Errno::EADDRINUSE
      UI.messagebox("Claude Bridge: port #{port} already in use (bridge already running elsewhere?)")
      false
    end

    def self.stop
      UI.stop_timer(@timer_id) unless @timer_id.nil?
      @timer_id = nil
      @server.close unless @server.nil? || @server.closed?
      @server = nil
      _log('Stopped')
      _refresh_ui
    end

    def self.running?
      !@server.nil? && !@server.closed?
    end

    def self.toggle
      running? ? stop : start
    end

    # -----

    def self._log(message)
      SKETCHUP_CONSOLE.show
      puts "[ClaudeBridge] #{message}"
    end

    # Toolbar validation procs are only re-run on some UI events, so the
    # checked state lags one action behind without an explicit refresh.
    def self._refresh_ui
      UI.refresh_toolbars if UI.respond_to?(:refresh_toolbars)   # SketchUp >= 2018
    end

    # -----

    def self._tick
      return if @server.nil? || @server.closed?
      loop do
        client = @server.accept_nonblock(exception: false)
        break if client == :wait_readable || client.nil?
        _handle_client(client)
      end
    rescue => e
      puts "[ClaudeBridge] #{e.class}: #{e.message}"
    end

    def self._handle_client(client)
      method, path, headers, body = _read_request(client)

      unless headers.key?(GUARD_HEADER)
        return _respond(client, 403, { ok: false, error: "Missing #{GUARD_HEADER} header" })
      end

      _log("Request: #{method} #{path}")

      case [ method, path ]

      when [ 'GET', '/ping' ]
        model = Sketchup.active_model
        _respond(client, 200, {
          ok: true,
          sketchup: Sketchup.version,
          ruby: RUBY_VERSION,
          model_title: model && model.title,
          model_path: model && model.path,
        })

      when [ 'POST', '/eval' ]
        _respond(client, 200, _eval(body))

      else
        _respond(client, 404, { ok: false, error: "No route for #{method} #{path}" })
      end

    rescue => e
      _respond(client, 400, { ok: false, error: "#{e.class}: #{e.message}" }) rescue nil
    ensure
      client.close rescue nil
    end

    def self._eval(code)
      previous_stdout = $stdout
      $stdout = StringIO.new
      begin
        value = eval(code, _fresh_binding, 'claude-bridge-eval')
        { ok: true, result: _jsonable(value), stdout: $stdout.string }
      rescue Exception => e   # Exception: also report SyntaxError, SystemStackError...
        { ok: false, error: "#{e.class}: #{e.message}", backtrace: (e.backtrace || []).first(10), stdout: $stdout.string }
      ensure
        $stdout = previous_stdout
      end
    end

    # Fresh binding per request: locals don't leak between evals, constants (Sketchup, ...) resolve normally
    def self._fresh_binding
      binding
    end

    def self._jsonable(value)
      JSON.parse(JSON.generate(value), quirks_mode: true)
    rescue
      value.inspect
    end

    # -----

    def self._read_request(client)
      deadline = Time.now + READ_TIMEOUT
      buffer = +''

      # Head
      until (headers_end = buffer.index("\r\n\r\n"))
        buffer << _read_chunk(client, deadline)
      end
      head = buffer[0...headers_end]
      body = buffer[(headers_end + 4)..-1] || +''

      request_line, *header_lines = head.split("\r\n")
      method, path, _ = request_line.split(' ')
      headers = header_lines.to_h { |line|
        name, _, header_value = line.partition(':')
        [ name.strip.downcase, header_value.strip ]
      }

      # Body
      content_length = headers['content-length'].to_i
      raise "Body too large (#{content_length} bytes)" if content_length > MAX_BODY_SIZE
      body << _read_chunk(client, deadline) while body.bytesize < content_length

      [ method, path, headers, body.force_encoding(Encoding::UTF_8) ]
    end

    def self._read_chunk(client, deadline)
      until IO.select([ client ], nil, nil, 0.2)
        raise 'Read timeout' if Time.now > deadline
      end
      client.readpartial(65536)
    rescue EOFError
      raise 'Connection closed before request was complete'
    end

    def self._respond(client, status, payload)
      body = JSON.generate(payload)
      client.write("HTTP/1.1 #{status}\r\n" \
                   "Content-Type: application/json; charset=utf-8\r\n" \
                   "Content-Length: #{body.bytesize}\r\n" \
                   "Connection: close\r\n" \
                   "\r\n" \
                   "#{body}")
    end

    # ----- UI

    unless file_loaded?(__FILE__)

      icons_dir = File.join(File.dirname(__FILE__), 'icons')

      cmd = UI::Command.new('Claude Bridge') { toggle }
      cmd.tooltip = 'Claude Bridge'
      cmd.status_bar_text = "Start/stop the Claude Bridge eval server on http://127.0.0.1:#{DEFAULT_PORT}"
      icon = File.join(icons_dir, 'claude_bridge.svg')
      cmd.small_icon = icon
      cmd.large_icon = icon
      cmd.set_validation_proc { running? ? MF_CHECKED : MF_UNCHECKED }

      toolbar = UI::Toolbar.new('Claude Bridge')
      toolbar.add_item(cmd)
      toolbar.restore

      UI.menu('Plugins').add_item(cmd)

      file_loaded(__FILE__)
    end

  end
end