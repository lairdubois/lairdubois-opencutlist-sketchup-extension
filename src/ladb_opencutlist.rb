require 'sketchup.rb'
require 'extensions.rb'
require_relative 'ladb_opencutlist/ruby/plugin.rb'

module Ladb
  module OpenCutList

    # Create and Register extension
    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new(Plugin::NAME, 'ladb_opencutlist/main')
      ex.description = Plugin.get_i18n_string('core.extension.description')
      ex.version     = Plugin::VERSION
      ex.copyright   = '2016-2018 - GNU GPL'
      ex.creator     = 'L\'Air du Bois www.lairdubois.fr'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

  end
end