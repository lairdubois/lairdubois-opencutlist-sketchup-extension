require_relative 'controller/cutlist_controller'
require_relative 'controller/materials_controller'

module Ladb
  module Toolbox
    class Plugin

      NAME = 'L\'Air du Bois - Boîte à outils Sketchup [BETA]'
      VERSION = '01.2'

      attr_accessor :dialog

      @controllers

      def initialize()
        @controllers = []
        @controllers.push(CutlistController.new(self))
        @controllers.push(MaterialsController.new(self))
      end

      def toggle_dialog
        if @dialog and @dialog.visible?
          @dialog.close
        else
          @dialog = UI::HtmlDialog.new(
              {
                  :dialog_title => NAME,
                  :preferences_key => "fr.lairdubois.plugin",
                  :scrollable => true,
                  :resizable => true,
                  :width => 90,
                  :height => 400,
                  :left => 200,
                  :top => 100,
                  :min_width => 90,
                  :style => UI::HtmlDialog::STYLE_DIALOG
              })
          @dialog.set_file(__dir__ + '/../html/dialog.html')
          @dialog.set_size(90, 400)
          @dialog.add_action_callback("ladb_dialog_loaded") do |action_context|
            @dialog.execute_script("$('body').ladbToolbox({ version: '#{VERSION}' });")
          end
          @dialog.add_action_callback("ladb_minimize") do |action_context|
            if @dialog
              @dialog.set_size(90, 400)
            end
          end
          @dialog.add_action_callback("ladb_maximize") do |action_context|
            if @dialog
              @dialog.set_size(1100, 800)
            end
          end
          @controllers.each { |controller|
            controller.setup_dialog_actions(dialog)
          }
          @dialog.show
        end
      end

    end
  end
end