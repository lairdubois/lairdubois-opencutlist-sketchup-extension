module Ladb
  module OpenCutList

    require 'sketchup.rb'
    require_relative 'plugin'

    unless file_loaded?(__FILE__)

      # Setup OpenCutList plugin
      PLUGIN = Plugin.new
      PLUGIN.setup

      file_loaded(__FILE__)
    end

  end
end

