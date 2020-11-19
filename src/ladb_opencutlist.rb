module Ladb
  module OpenCutList

    require 'sketchup.rb'
    require 'extensions.rb'

    unless file_loaded?(__FILE__)

      # Create extension
      ex = SketchupExtension.new('OpenCutList', 'ladb_opencutlist/ruby/main')
      ex.version     = "1.9.9"  ## /!\ Auto-generated line, do not edit ##
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
      when 'it'
        ex.description = 'Generatore di Distinte Materiali e Schemi di Taglio per falegnami. Open Source, crowdfunded e facile da usare ;)'
      when 'pt'
        ex.description = 'Cutlist e gerador de diagrama de corte para marceneiros. Código aberto, crowdfunded e fácil de usar;)'
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