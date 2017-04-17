require 'sketchup.rb'
require_relative 'ruby/plugin.rb'

module Ladb
  module Toolbox

    # Initialize the app
    plugin = Plugin.new

    unless file_loaded?(__FILE__)

      # Setup Menu
      menu = UI.menu
      submenu = menu.add_submenu(plugin.get_i18n_string('core.menu.submenu'))
      submenu.add_item(plugin.get_i18n_string('tab.cutlist.title')) {
        plugin.show_dialog('cutlist')
      }
      submenu.add_item(plugin.get_i18n_string('tab.materials.title')) {
        plugin.show_dialog('materials')
      }

      # Setup Toolbar
      toolbar = UI::Toolbar.new('L\'Air du Bois')
      cmd = UI::Command.new(plugin.get_i18n_string('core.toolbar.command')) {
        plugin.toggle_dialog
      }
      cmd.small_icon = 'img/icon-72x72.png'
      cmd.large_icon = 'img/icon-114x114.png'
      cmd.tooltip = plugin.get_i18n_string('core.toolbar.command')
      cmd.status_bar_text = plugin.get_i18n_string('core.toolbar.command')
      cmd.menu_text = plugin.get_i18n_string('core.toolbar.command')
      toolbar = toolbar.add_item(cmd)
      toolbar.show

      file_loaded(__FILE__)
    end

  end
end

