require 'base64'
require 'uri'

class Controller

  @plugin
  @tab_name

  def initialize(plugin, tab_name)
    @plugin = plugin
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

    @plugin.dialog.execute_script(script)
  end

end