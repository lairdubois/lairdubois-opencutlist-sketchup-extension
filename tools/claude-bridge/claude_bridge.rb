# Claude Bridge — minimal dev-only eval server for SketchUp
#
# Extension registrar. Install by copying (or symlinking) this file and the
# claude_bridge/ folder into SketchUp's Plugins directory, or load this file
# with the AS On-Demand Ruby Loader.
#
# Once loaded, use the "Claude Bridge" toolbar button (or the
# Extensions > Claude Bridge menu item) to start/stop the server.

require 'sketchup.rb'
require 'extensions.rb'

module Ladb
  module ClaudeBridge

    unless file_loaded?(__FILE__)

      ex = SketchupExtension.new('Claude Bridge', File.join(File.dirname(__FILE__), 'claude_bridge', 'main'))
      ex.description = 'Dev-only local HTTP eval server that lets a local agent (Claude Code) inspect the live SketchUp model.'
      ex.version = '1.0.0'
      ex.creator = 'Boris Beaulant'
      ex.copyright = '2026 Boris Beaulant'
      Sketchup.register_extension(ex, true)

      file_loaded(__FILE__)
    end

  end
end