module Ladb
  module OpenCutList

    require 'sketchup.rb'
    require_relative 'plugin'

    unless file_loaded?(__FILE__)

      # Setup OpenCutList plugin
      Plugin.instance.setup

      file_loaded(__FILE__)
    end

  end
end

