module Ladb
  module OpenCutList

    require 'sketchup.rb'
    require 'extensions.rb'
    require_relative 'ladb_opencutlist/ruby/constants.rb'

    unless file_loaded?(__FILE__)

      # Create extension
      ex = SketchupExtension.new(EXTENSION_NAME, 'ladb_opencutlist/ruby/main')
      ex.version     = EXTENSION_VERSION
      ex.copyright   = '2016-2020 - GNU GPLv3'
      ex.creator     = 'L\'Air du Bois - www.lairdubois.fr'

      # Localize description
      case Sketchup.get_locale.split('-')[0].downcase
      ## /!\ Auto-generated lines, do not edit ##
      ## DESCRIPTION_START ##
      when 'de'
        ex.description = 'Holzlistengenerator für Tischler/Schreiner/Zimmerer. Open Source, crowdfunded und einfach zu bedienen ;)'
      when 'fr'
        ex.description = 'Générateur de fiche de débit et calepinage de panneaux et barres pour les boiseux. Open Source, financé par les utilisateurs et facile à utiliser ;)'
      when 'ru'
        ex.description = 'Плагин расчета карт раскроя для деревообработчиков. Открытый исходный код, краундфандинг и простота использования.'
      else
        ex.description = 'Cutlist and Cutting Diagram Generator for Woodworkers. Open Source, crowdfunded and easy to use ;)'
      ## DESCRIPTION_END ##
      end

      # Register extension
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)

    end

  end
end