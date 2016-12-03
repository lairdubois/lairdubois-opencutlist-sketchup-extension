require 'sketchup.rb'
require 'extensions.rb'

module Ladb
  module Toolbox

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('L\'Air du Bois - Boîte à outils Sketchup', 'ladb_toolbox/main')
      ex.description = 'Boîte à outils pour les boiseux - Générateur de fiche de débit.'
      ex.version     = '0.1.2'
      ex.copyright   = 'L\'Air du Bois © 2016 - GPL'
      ex.creator     = 'Boris Beaulant www.lairdubois.fr'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

  end
end