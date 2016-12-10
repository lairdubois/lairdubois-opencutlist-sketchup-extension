class Controller

  @app
  @tab_name

  def initialize(plugin, tab_name)
    @app = plugin
    @tab_name = tab_name
  end

  def setup_dialog_actions(dialog)
  end

  protected

  def execute_dialog_script(dialog, fn, json_data)
    script = "$('#ladb_tab_#{@tab_name}').ladbTab#{@tab_name.capitalize}('#{fn}', '" + json_data.gsub("'", %q(\\\')) + "')"
    dialog.execute_script(script)
  end

end