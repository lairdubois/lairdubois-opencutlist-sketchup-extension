module Ladb
  module OpenCutList

    require 'sketchup.rb'
    require 'extensions.rb'
    require 'date'

    unless file_loaded?(__FILE__)

      if Sketchup.version_number < 1700000000
        UI.messagebox("/!\ CAUTION\nOpenCutList requires SketchUp 2017 or above to run correctly.\nDowngrade to version 3.x to run on prior version of SketchUp.", MB_OK)
      end

      # Plugin ID and DIR
      _file_ = __FILE__.dup
      _file_.force_encoding("UTF-8") if _file_.respond_to?(:force_encoding)

      PLUGIN_ID = File.basename(_file_, ".*")
      PLUGIN_DIR = File.join(File.dirname(_file_), PLUGIN_ID)

      # Create extension
      ex = SketchupExtension.new('OpenCutList', File.join(PLUGIN_DIR, 'ruby', 'main'))
      ex.version     = "7.0.0"  ## /!\ Auto-generated line, do not edit ##
      ex.copyright   = "2016-#{Date.today.year} - GNU GPLv3"  ## /!\ Auto-generated line, do not edit ##
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
        ex.description = 'תוסף לחישוב תוכניות חיתוך לנגרים ועוד. קוד פתוח, מימון המונים וקל לשימוש ;)'
      when 'hu'
        ex.description = 'Faipari Szakembereknek Szabáslista és Szabásterv készítő program. Nyílt forráskódú, közösségi finanszírozású és könnyen használható ;)'
      when 'it'
        ex.description = 'Generatore di Distinte Materiali e Schemi di Taglio per falegnami. Open Source, crowdfunded e facile da usare ;)'
      when 'nl'
        ex.description = 'Genereer materiaallijsten, zaagschema\'s voor panelen en balken voor houtbewerkers. Open Source, crowdfunded en gebruiksvriendelijk ;)'
      when 'pl'
        ex.description = 'Generator listy cięć i diagramów cięcia dla stolarzy. Open Source, finansowany społecznościowo i łatwy w użyciu ;)'
      when 'pt'
        ex.description = 'Lista de Peças e Gerador de Plano de Corte de chapas e barras para marceneiros, carpinteiros e serralheiros. Código aberto, crowdfunded e fácil de usar ;)'
      when 'ru'
        ex.description = 'Плагин расчета карт раскроя для деревообработчиков и не только. Открытый исходный код, краундфандинг и простота использования ;)'
      when 'sr'
        ex.description = 'Generator lista i dijagrama rezanja za stolare. Otvoreni kod, finansiran dobrovoljnim prilozima i jednostavan za upotrebu ;)'
      when 'uk'
        ex.description = 'Плагін розрахунку карт розкрою листового та погонного матеріалів для деревообробників і не тільки. Відкритий вихідний код, фінансується користувачами і простий у використанні ;)'
      when 'vi'
        ex.description = 'Danh sách cắt và Trình tạo sơ đồ cắt cho thợ mộc. Mã nguồn mở, được huy động vốn từ cộng đồng và dễ sử dụng;)'
      when 'zh'
        ex.description = '木工的切割清单和切割图生成器。 开源，众筹且易于使用 ;)'
      else
        ex.description = 'Cutlist and Cutting Diagram Generator for Woodworkers. Open Source, crowdfunded and easy to use ;)'
      ## DESCRIPTION_END ##
      end

      # Register extension
      Sketchup.register_extension(ex, true)

      file_loaded(_file_)

    end

  end
end
