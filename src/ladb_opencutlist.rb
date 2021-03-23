module Ladb
  module OpenCutList

    require 'sketchup.rb'
    require 'extensions.rb'

    unless file_loaded?(__FILE__)

      # Create extension
      ex = SketchupExtension.new('OpenCutList', 'ladb_opencutlist/ruby/main')
      ex.version     = "2.0.0"  ## /!\ Auto-generated line, do not edit ##
      ex.copyright   = '2016-2020 - GNU GPLv3'
      ex.creator     = 'L\'Air du Bois - www.lairdubois.fr'

      # Localize description
      case Sketchup.get_locale.split('-')[0].downcase
      ## /!\ Auto-generated lines, do not edit ##
      ## DESCRIPTION_START ##
      when 'ar'
        ex.description = 'مولد لرسومات التقطيع التخطيطية و قوائم القَطع موجه للنجارين. مفتوح المصدر و ممول جماهيريا و سهل الاستخدام ;)'
      when 'cs'
        ex.description = 'Kusovník a nářezový plán pro truhláře. Zdarma, financován z darů a snadno použitelný ;)'
      when 'de'
        ex.description = 'Holzlistengenerator für Tischler/Schreiner/Zimmerer. Open Source, crowdfunded und einfach zu bedienen ;)'
      when 'es'
        ex.description = 'Generador de lista de corte y diagrama de corte para carpinteros. Software de código abierto, financiado por crowdfunding, es fácil de usar ;)'
      when 'fr'
        ex.description = 'Générateur de fiche de débit et calepinage de panneaux et barres pour les boiseux. Open Source, financé par les utilisateurs et facile à utiliser ;)'
      when 'he'
        ex.description = 'תוסף לחישוב תוכניות חיתוך לנגרים ועוד. קוד פתוח, מימון המונים וקלות שימוש ;)'
      when 'it'
        ex.description = 'Generatore di Distinte Materiali e Schemi di Taglio per falegnami. Open Source, crowdfunded e facile da usare ;)'
      when 'nl'
        ex.description = 'Genereer materiaallijsten, zaagschema\'s voor panelen en balken voor houtbewerkers. Open Source, crowdfunded en gebruiksvriendelijk ;)'
      when 'pl'
        ex.description = 'Generator listy cięć i schematów cięcia dla stolarzy. Open Source, crowdfunded i łatwy w użyciu ;) '
      when 'pt'
        ex.description = 'Planilha de Produção e Gerador de Diagrama de Corte de chapas e pranchas MLC para Marceneiros e carpinteiros. Código aberto, crowdfunded e fácil de usar ;)'
      when 'ru'
        ex.description = 'Плагин расчета карт раскроя для деревообработчиков и не только. Открытый исходный код, краундфандинг и простота использования ;)'
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
