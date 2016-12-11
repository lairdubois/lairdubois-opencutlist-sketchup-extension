require 'base64'
require 'uri'

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

  def execute_js_callback(fn, data, tab_name = nil)

    if tab_name == nil
      tab_name = @tab_name    # No tab_name is defined use controller associated one
    end

    encoded_data = Base64.strict_encode64(URI.escape(JSON.generate(data)))
    script = "onRubyCallback('#{fn}', '#{encoded_data}', '#{tab_name}')"

    @app.dialog.execute_script(script)
  end

end