module Ladb
  module OpenCutList

    require 'sketchup.rb'
    require 'extensions.rb'

    EXTENSION_NAME = 'OpenCutList'.freeze
    EXTENSION_VERSION = '1.6.0-dev'.freeze
    EXTENSION_BUILD = '201806270520'.freeze

    unless file_loaded?(__FILE__)

      # Create extension
      ex = SketchupExtension.new(EXTENSION_NAME, 'ladb_opencutlist/main')
      ex.version     = EXTENSION_VERSION
      ex.copyright   = '2016-2018 - GNU GPLv3'
      ex.creator     = 'L\'Air du Bois - www.lairdubois.fr'

      # Localize description
      case Sketchup.get_locale.split('-')[0].downcase
      when 'fr'
        ex.description = 'Générateur de fiche de débit et calepinage de panneaux pour les boiseux. Open Source et facile à utiliser ;)'
      when 'de'
        ex.description = 'Holzlistengenerator für Tischler/Schreiner. Open Source und einfach anzuwenden ;)'
      else
        ex.description = 'Cutlist and Cutting Diagram Generator for Woodworkers. Open Source and Easy to Use ;)'
      end

      # Register extension
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)

    end

  end
end