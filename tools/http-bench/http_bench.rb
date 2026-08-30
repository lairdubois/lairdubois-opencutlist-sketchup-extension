# OpenCutList — banc de mesure du serveur HTTP local
#
# Outil de dev, hors distribution. Il mesure le service des assets tel que le
# Chrome embarqué le voit réellement (fetch depuis un HtmlDialog servi par le
# serveur local), et non tel qu'un client socket externe le voit : le thread
# principal de SketchUp est partagé entre CEF et la boucle de service, donc
# seul un client CEF donne un chiffre représentatif.
#
# Depuis la console Ruby :
#
#   load '<repo>/tools/http-bench/http_bench.rb'
#
#   Ladb::HttpBench.run                 # sweep complet : 4 stratégies x 2 scénarios
#   Ladb::HttpBench.run(:configs => [ :legacy ], :scenarios => [ :small ], :runs => 5)
#   Ladb::HttpBench.dialog(5)           # ouvre/ferme 5x le vrai dialogue OCL
#   Ladb::HttpBench.close

module Ladb
  module HttpBench

    OCL = Ladb::OpenCutList

    # Les assets réellement chargés à l'ouverture du dialogue Tabs.
    DIALOG_ASSETS = [
        '/css/vendor.min.css',
        '/css/ladb-opencutlist.min.css',
        '/css/ladb-opencutlist-icons.min.css',
        '/js/bundles/common-bundle.js',
        '/js/bundles/tabs-bundle.js',
        '/fonts/ladb_opencutlist.woff',
    ].freeze

    # Cas "beaucoup de petits fichiers" (vignettes, textures) : le pire cas pour
    # une boucle de service qui coûte un tick de timer par requête.
    SMALL_ASSET = '/js/constants.js'.freeze
    SMALL_COUNT = 120

    # Cadences de service comparées. :legacy = avant réglage adaptatif.
    CONFIGS = {
        :legacy => { :poll_interval_active => 0.02,  :poll_interval_idle => 0.02 },
        :fast   => { :poll_interval_active => 0.002, :poll_interval_idle => 0.02 },
    }.freeze

    class << self

      def run(configs: CONFIGS.keys, scenarios: [ :assets, :small, :revalidate ], runs: 3)
        server = OCL::PLUGIN.local_http_server
        port = server.start
        if port.nil?
          puts '[BENCH] serveur HTTP local indisponible'
          return nil
        end

        @plan = []
        configs.each { |config| scenarios.each { |scenario| runs.times { @plan << [ config, scenario ] } } }
        @results = []
        @started_at = Time.now

        puts "[BENCH] #{@plan.size} runs — #{configs.size} stratégies x #{scenarios.size} scénarios x #{runs}"
        _open_dialog(port)
        nil
      end

      # Mesure l'ouverture du vrai dialogue OCL : show -> dialog_ready_command.
      def dialog(count = 5)
        _install_ready_hook
        @dialog_times = []
        @dialog_remaining = count
        puts "[BENCH] ouverture du dialogue OCL x#{count}"
        _dialog_step
        nil
      end

      def close
        @dialog.close unless @dialog.nil?
        @dialog = nil
        nil
      end

      # --- runs dans le HtmlDialog ---

      private

      def _open_dialog(port)
        close

        html = _build_page(port)
        path = File.join(OCL::PLUGIN.temp_dir, 'http_bench.html')
        File.write(path, html)

        @dialog = UI::HtmlDialog.new(
            :dialog_title => 'OCL HTTP bench',
            :preferences_key => 'ladb_http_bench',
            :width => 620,
            :height => 460,
            :style => UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_on_closed { @dialog = nil }
        @dialog.add_action_callback('bench_ready') { |_ctx| _next_run }
        @dialog.add_action_callback('bench_result') { |_ctx, json| _on_result(JSON.parse(json)) }
        @dialog.set_url("http://127.0.0.1:#{port}/tmp/http_bench.html")
        @dialog.show
      end

      def _next_run
        if @plan.empty?
          _summary
          _apply_config(nil)
          return
        end
        config, scenario = @plan.shift
        _apply_config(config)
        urls = scenario == :small ? Array.new(SMALL_COUNT) { SMALL_ASSET } : DIALOG_ASSETS
        # :revalidate rejoue les mêmes URLs sans cache-busting, pour mesurer le
        # chemin réel d'une réouverture de dialogue (304 conditionnels).
        args = [ config.to_s, scenario.to_s, urls, 6, scenario == :revalidate ? 0 : Time.now.to_f ].to_json
        @dialog.execute_script("bench.run.apply(null, #{args});")
      end

      def _on_result(result)
        durations = result['results'].map { |r| r['ms'] }.sort
        bytes = result['results'].inject(0) { |sum, r| sum + r['bytes'] }
        pick = lambda { |p| durations[[ (durations.size * p).to_i, durations.size - 1 ].min] }
        row = {
            :config => result['config'],
            :scenario => result['scenario'],
            :total => result['total'],
            :n => durations.size,
            :bytes => bytes,
            :p50 => pick.call(0.5),
            :p95 => pick.call(0.95),
            :max => durations.last,
        }
        @results << row
        puts format('[BENCH] %-7s %-7s  total %7.1f ms  %3d req  %7.1f KB  p50 %6.1f  p95 %6.1f  max %6.1f',
                    row[:config], row[:scenario], row[:total], row[:n], row[:bytes] / 1024.0,
                    row[:p50], row[:p95], row[:max])
        _next_run
      end

      def _summary
        lines = [ '', format('[BENCH] === résumé (%d runs en %.1f s) ===', @results.size, Time.now - @started_at) ]
        lines << format('%-8s %-8s %11s %11s %10s %10s', 'config', 'scénario', 'total méd.', 'total min', 'p50 méd.', 'max méd.')
        @results.group_by { |row| [ row[:config], row[:scenario] ] }.each do |(config, scenario), rows|
          totals = rows.map { |row| row[:total] }.sort
          p50s = rows.map { |row| row[:p50] }.sort
          maxes = rows.map { |row| row[:max] }.sort
          median = lambda { |values| values[values.size / 2] }
          lines << format('%-8s %-8s %11.1f %11.1f %10.1f %10.1f',
                          config, scenario, median.call(totals), totals.first, median.call(p50s), median.call(maxes))
        end
        puts lines.join("\n")
      end

      def _apply_config(config)
        server = OCL::PLUGIN.local_http_server
        settings = config.nil? ? {
            :poll_interval_active => OCL::LocalHttpServer::POLL_INTERVAL_ACTIVE,
            :poll_interval_idle => OCL::LocalHttpServer::POLL_INTERVAL_IDLE,
        } : CONFIGS[config]
        server.poll_interval_active = settings[:poll_interval_active]
        server.poll_interval_idle = settings[:poll_interval_idle]
      end

      def _build_page(port)
        <<-HTML
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>OCL HTTP bench</title>
<style>
  body { font: 12px/1.5 Menlo, Consolas, monospace; margin: 0; padding: 12px; background: #1e1e1e; color: #ddd; }
  h1 { font-size: 13px; margin: 0 0 8px; color: #8ab4f8; }
  pre { margin: 0; white-space: pre-wrap; }
  .run { color: #9e9e9e; }
</style></head>
<body>
<h1>OpenCutList — banc HTTP local (port #{port})</h1>
<pre id="log">en attente…</pre>
<script>
  var log = document.getElementById('log');
  var lines = [];
  function print(line) {
    lines.push(line);
    if (lines.length > 40) lines.shift();
    log.textContent = lines.join('\\n');
  }
  function fetchOne(url, revalidate) {
    var t0 = performance.now();
    return fetch(url, { cache: revalidate ? 'default' : 'no-store' })
      .then(function (r) { return r.arrayBuffer(); })
      .then(function (buf) { return { url: url, ms: performance.now() - t0, bytes: buf.byteLength }; });
  }
  window.bench = {
    run: function (config, scenario, paths, parallel, bust) {
      // bust === 0 : on garde les mêmes URLs et le cache du navigateur, pour
      // mesurer la revalidation conditionnelle plutôt qu'un rechargement sec.
      var revalidate = bust === 0;
      var queue = paths.map(function (p, i) { return revalidate ? p : p + '?bench=' + bust + '-' + i; });
      var results = [];
      var t0 = performance.now();
      function worker() {
        if (!queue.length) return Promise.resolve();
        return fetchOne(queue.shift(), revalidate).then(function (r) { results.push(r); return worker(); });
      }
      var workers = [];
      for (var i = 0; i < parallel; i++) workers.push(worker());
      Promise.all(workers).then(function () {
        var total = performance.now() - t0;
        print(config + ' / ' + scenario + ' : ' + total.toFixed(1) + ' ms pour ' + results.length + ' requêtes');
        sketchup.bench_result(JSON.stringify({ config: config, scenario: scenario, total: total, results: results }));
      });
    }
  };
  window.addEventListener('load', function () { print('prêt'); sketchup.bench_ready(); });
</script>
</body></html>
        HTML
      end

      # --- ouverture du vrai dialogue OCL ---

      def _install_ready_hook
        return if defined?(@ready_hook_installed) && @ready_hook_installed
        OCL::Plugin.send(:prepend, Module.new do
          def dialog_ready_command
            Ladb::HttpBench.on_dialog_ready
            super
          end
        end)
        @ready_hook_installed = true
      end

      def _dialog_step
        if @dialog_remaining <= 0
          times = @dialog_times.sort
          puts format('[BENCH] dialogue OCL : min %.0f ms | médiane %.0f ms | max %.0f ms (%d ouvertures)',
                      times.first, times[times.size / 2], times.last, times.size)
          return
        end
        @dialog_remaining -= 1
        tabs_dialog = OCL::PLUGIN.instance_variable_get(:@tabs_dialog)
        tabs_dialog.close unless tabs_dialog.nil?
        UI.start_timer(0.8, false) {
          @dialog_t0 = Time.now
          OCL::PLUGIN.show_tabs_dialog
        }
      end

      public

      def on_dialog_ready
        return if @dialog_t0.nil?
        elapsed = (Time.now - @dialog_t0) * 1000
        @dialog_times << elapsed
        @dialog_t0 = nil
        puts format('[BENCH] dialogue OCL prêt en %.0f ms', elapsed)
        UI.start_timer(0.5, false) { _dialog_step }
      end

    end

  end
end
