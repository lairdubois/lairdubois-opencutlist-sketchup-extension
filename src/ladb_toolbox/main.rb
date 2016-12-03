require 'sketchup.rb'
require 'json'
require_relative 'ruby/app.rb'

module Ladb
  module Toolbox

    unless file_loaded?(__FILE__)

      # Initialize the app
      app = App.new

      # Setup Menu
      menu = UI.menu
      submenu = menu.add_submenu('L\'Air du Bois')
      submenu.add_item('Fiche de débit') {
        app.toggle_dialog
      }

      # Setup Toolbar
      toolbar = UI::Toolbar.new('L\'Air du Bois')
      cmd = UI::Command.new('Boîte à outils') {
        app.toggle_dialog
      }
      cmd.small_icon = 'img/icon-72x72.png'
      cmd.large_icon = 'img/icon-114x114.png'
      cmd.tooltip = "Boîte à outils"
      cmd.status_bar_text = "Boîte à outils"
      cmd.menu_text = "Boîte à outils"
      toolbar = toolbar.add_item(cmd)
      toolbar.show

      # file_loaded(__FILE__)
    end

  end
end

