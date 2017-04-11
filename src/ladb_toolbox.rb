require 'sketchup.rb'
require 'extensions.rb'
require_relative 'ladb_toolbox/ruby/plugin.rb'

module Ladb
  module Toolbox

    # Create and Register extension
    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new(Plugin::NAME, 'ladb_toolbox/main')
      ex.description = 'Boîte à outils pour les boiseux - Générateur de fiche de débit.'
      ex.version     = Plugin::VERSION
      ex.copyright   = 'L\'Air du Bois © 2016-2017 - GPL'
      ex.creator     = 'Boris Beaulant www.lairdubois.fr'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

  end
end