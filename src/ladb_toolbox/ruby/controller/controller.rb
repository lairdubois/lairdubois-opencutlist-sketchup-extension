require 'base64'
require 'uri'

class Controller

  @plugin
  @tab_name

  def initialize(plugin, tab_name)
    @plugin = plugin
    @tab_name = tab_name
  end

  def setup_dialog_commands()
  end

end