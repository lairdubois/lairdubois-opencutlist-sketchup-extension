module Ladb
  module OpenCutList

    require 'sketchup.rb'
    require_relative 'plugin'

    PLUGIN ||= Plugin.new

    unless file_loaded?(__FILE__)

      # Setup OpenCutList UI integration
      PLUGIN.setup

      file_loaded(__FILE__)
    end

  end
end

