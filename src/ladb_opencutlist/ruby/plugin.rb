module Ladb::OpenCutList

  require 'singleton'
  require 'fileutils'
  require 'json'
  require 'yaml'
  require 'base64'
  require 'uri'
  require "tempfile"
  require_relative 'constants'
  require_relative 'observer/app_observer'
  require_relative 'controller/materials_controller'
  require_relative 'controller/cutlist_controller'
  require_relative 'controller/importer_controller'
  require_relative 'controller/settings_controller'
  require_relative 'utils/dimension_utils'
  require_relative 'utils/path_utils'

  class Plugin
    
    include Singleton

    DEBUG = EXTENSION_VERSION.end_with? '-dev'

    DEFAULT_SECTION = ATTRIBUTE_DICTIONARY = 'ladb_opencutlist'.freeze
    BC_DEFAULT_SECTION = BC_ATTRIBUTE_DICTIONARY = 'ladb_toolbox'.freeze

    SETTINGS_RW_STRATEGY_GLOBAL = 0               # Read/Write settings from/to global Sketchup defaults
    SETTINGS_RW_STRATEGY_GLOBAL_MODEL = 1         # Read/Write settings from/to global Sketchup defaults and (if undefined from)/to active model attributes
    SETTINGS_RW_STRATEGY_MODEL = 2                # Read/Write settings from/to active model attributes
    SETTINGS_RW_STRATEGY_MODEL_GLOBAL = 3         # Read/Write settings from/to active model attributes and (if undefined from)/to global Sketchup defaults

    SETTINGS_PREPROCESSOR_D = 1                   # 1D dimension
    SETTINGS_PREPROCESSOR_DXD = 2                 # 2D dimension

    SETTINGS_KEY_LANGUAGE = 'settings.language'
    SETTINGS_KEY_DIALOG_MAXIMIZED_WIDTH = 'settings.dialog_maximized_width'
    SETTINGS_KEY_DIALOG_MAXIMIZED_HEIGHT = 'settings.dialog_maximized_height'
    SETTINGS_KEY_DIALOG_LEFT = 'settings.dialog_left'
    SETTINGS_KEY_DIALOG_TOP = 'settings.dialog_top'

    DIALOG_DEFAULT_MAXIMIZED_WIDTH = 1100
    DIALOG_DEFAULT_MAXIMIZED_HEIGHT = 800
    DIALOG_MINIMIZED_WIDTH = 90
    DIALOG_MINIMIZED_HEIGHT = 30 + 80 + 80 * 3     # = 3 Tab buttons
    DIALOG_DEFAULT_LEFT = 100
    DIALOG_DEFAULT_TOP = 100
    DIALOG_PREF_KEY = 'fr.lairdubois.opencutlist'

    # -----

    def initialize

      @temp_dir = nil
      @language = nil
      @current_os = nil
      @i18n_strings = nil
      @html_dialog_compatible = nil

      @commands = {}
      @controllers = []

      @started = false

      @dialog = nil
      @dialog_startup_tab_name = nil
      @dialog_maximized_width = read_default(SETTINGS_KEY_DIALOG_MAXIMIZED_WIDTH, DIALOG_DEFAULT_MAXIMIZED_WIDTH)
      @dialog_maximized_height = read_default(SETTINGS_KEY_DIALOG_MAXIMIZED_HEIGHT, DIALOG_DEFAULT_MAXIMIZED_HEIGHT)
      @dialog_left = read_default(SETTINGS_KEY_DIALOG_LEFT, DIALOG_DEFAULT_LEFT)
      @dialog_top = read_default(SETTINGS_KEY_DIALOG_TOP, DIALOG_DEFAULT_TOP)

    end

    # -----

    def temp_dir
      if @temp_dir
        return @temp_dir
      end
      dir = File.join(Sketchup.temp_dir, "ladb_opencutlist")
      if Dir.exist?(dir)
        FileUtils.remove_dir(dir, true)   # Temp dir exists we clean it
      end
      Dir.mkdir(dir)
      @temp_dir = dir
    end

    def language
      if @language
        return @language
      end
      # Try to retrieve and set language from defaults
      set_language(read_default(SETTINGS_KEY_LANGUAGE))
      @language
    end

    def set_language(language, persist = false)
      if language.nil? or language == 'auto'
        language = Sketchup.get_locale.split('-')[0].downcase  # Retrieve SU language
      end
      available_languages = self.get_available_languages
      if available_languages.include? language
        @language = language   # Uses language only if translation is available
      else
        @language = 'en'
      end
      if persist
        write_default(SETTINGS_KEY_LANGUAGE, language)
      end
    end

    def get_available_languages
      available_languages = []
      Dir["#{__dir__}/../yaml/i18n/*.yml"].each { |file|
        available_languages.push(File.basename(file, File.extname(file)))
      }
      available_languages
    end

    def current_os
      if @current_os
        return @current_os
      end
      @current_os = (Object::RUBY_PLATFORM =~ /mswin/i || Object::RUBY_PLATFORM =~ /mingw/i) ? :WIN : ((Object::RUBY_PLATFORM =~ /darwin/i) ? :MAC : :OTHER)
    end

    def get_i18n_string(path_key)

      unless @i18n_strings
        begin
          yaml_file = "#{__dir__}/../yaml/i18n/#{language}.yml"
          @i18n_strings = YAML::load_file(yaml_file)
        rescue
          raise "Error loading i18n file (file='#{yaml_file}')."
        end
      end

      # Iterate over values
      begin
        i18n_string = path_key.split('.').inject(@i18n_strings) { |hash, key| hash[key] }
      rescue
        puts "I18n value not found (key=#{path_key})."
      end

      if i18n_string
        i18n_string
      else
        path_key
      end

    end

    def html_dialog_compatible
      if @html_dialog_compatible
        return @html_dialog_compatible
      end
      begin
        @html_dialog_compatible = Object.const_defined?('UI::HtmlDialog')
      rescue NameError
        @html_dialog_compatible = false
      end
      @html_dialog_compatible
    end

    # -----

    def set_attribute(entity, key, value)
      entity.set_attribute(ATTRIBUTE_DICTIONARY, key, value)
    end

    def get_attribute(entity, key, default_value = nil)
      # Try to retrieve entity attribute with Backward Compatibility with previous dictionary name
      entity.get_attribute(ATTRIBUTE_DICTIONARY, key, entity.get_attribute(BC_ATTRIBUTE_DICTIONARY, key, default_value))
    end

    def write_default(key, value)
      Sketchup.write_default(DEFAULT_SECTION, key, value)
    end

    def read_default(key, default_value = nil)
      # Try to retrieve default with Backward Compatibility with previous dictionary name
      Sketchup.read_default(DEFAULT_SECTION, key, Sketchup.read_default(BC_DEFAULT_SECTION, key, default_value))
    end

    # -----

    def register_command(command, &block)
      @commands[command] = block
    end

    def execute_command(command, params = nil)
      if @commands.has_key? command
        block = @commands[command]
        return block.call(params)
      end
      raise "Command '#{command}' not found"
    end

    # -----

    def trigger_event(event, params)
      if @dialog
        @dialog.execute_script("triggerEvent('#{event}', '#{params.is_a?(Hash) ? Base64.strict_encode64(URI.escape(JSON.generate(params))) : ''}');")
      end
    end

    # -----

    def setup

      # Setup Menu
      menu = UI.menu
      submenu = menu.add_submenu(get_i18n_string('core.menu.submenu'))
      submenu.add_item(get_i18n_string('tab.materials.title')) {
        show_dialog('materials')
      }
      submenu.add_item(get_i18n_string('tab.cutlist.title')) {
        show_dialog('cutlist')
      }
      submenu.add_item(get_i18n_string('tab.importer.title')) {
        show_dialog('importer')
      }
      submenu.add_separator
      edit_part_item = submenu.add_item(get_i18n_string('tab.cutlist.edit_part_properties')) {
        _edit_part_properties(_get_selected_component_entity)
      }
      menu.set_validation_proc(edit_part_item) {
        entity = _get_selected_component_entity
        if entity.nil?
          MF_GRAYED
        else
          MF_ENABLED
        end
      }
      edit_part_axes_item = submenu.add_item(get_i18n_string('tab.cutlist.edit_part_axes_properties')) {
        _edit_part_properties(_get_selected_component_entity, 'axes')
      }
      menu.set_validation_proc(edit_part_axes_item) {
        entity = _get_selected_component_entity
        if entity.nil?
          MF_GRAYED
        else
          MF_ENABLED
        end
      }

      # Setup Context Menu
      UI.add_context_menu_handler do |context_menu|
        entity = _get_selected_component_entity
        unless entity.nil?

          context_menu.add_separator
          submenu = context_menu.add_submenu(get_i18n_string('core.menu.submenu'))

          # Edit part item
          submenu.add_item(get_i18n_string('tab.cutlist.edit_part_properties')) {
            _edit_part_properties(entity)
          }
          submenu.add_item(get_i18n_string('tab.cutlist.edit_part_axes_properties')) {
            _edit_part_properties(entity, 'axes')
          }

        end
      end

      # Setup Toolbar
      toolbar = UI::Toolbar.new(get_i18n_string('core.toolbar.name'))
      cmd = UI::Command.new(get_i18n_string('core.toolbar.command')) {
        toggle_dialog
      }
      cmd.small_icon = '../img/icon-72x72.png'
      cmd.large_icon = '../img/icon-114x114.png'
      cmd.tooltip = get_i18n_string('core.toolbar.command')
      cmd.status_bar_text = get_i18n_string('core.toolbar.command')
      cmd.menu_text = get_i18n_string('core.toolbar.command')
      toolbar = toolbar.add_item(cmd)
      toolbar.restore

    end

    def start

      # Clear Ruby console if debug enabled
      if DEBUG
        SKETCHUP_CONSOLE.clear
      end

      # To minimize plugin initialization, start setup is called only once
      unless @started

        # -- Observers --

        Sketchup.add_observer(AppObserver.instance)

        # -- Controllers --

        @controllers.push(MaterialsController.new)
        @controllers.push(CutlistController.new)
        @controllers.push(ImporterController.new)
        @controllers.push(SettingsController.new)

        # -- Commands --

        register_command('core_read_settings') do |params|
          read_settings_command(params)
        end
        register_command('core_write_settings') do |params|
          write_settings_command(params)
        end
        register_command('core_dialog_loaded') do |params|
          dialog_loaded_command
        end
        register_command('core_dialog_ready') do |params|
          dialog_ready_command
        end
        register_command('core_dialog_minimize') do |params|
          dialog_minimize_command
        end
        register_command('core_dialog_maximize') do |params|
          dialog_maximize_command
        end
        register_command('core_open_external_file') do |params|
          open_external_file_command(params)
        end
        register_command('core_open_url') do |params|
          open_url_command(params)
        end
        register_command('core_open_model_info_page') do |params|
          open_model_info_page_command(params)
        end
        register_command('core_zoom_extents') do |params|
          zoom_extents_command
        end
        register_command('core_send_action') do |params|
          send_action_command(params)
        end
        register_command('core_compute_size_aspect_ratio_command') do |params|
          compute_size_aspect_ratio_command(params)
        end

        @controllers.each { |controller|
          controller.setup_commands
        }

        @started = true

      end

    end

    def create_dialog

      # Start
      start

      # Create dialog instance
      dialog_title = get_i18n_string('core.dialog.title') + ' - ' + EXTENSION_VERSION + (DEBUG ? " ( build: #{EXTENSION_BUILD} )" : '')
      if html_dialog_compatible
        @dialog = UI::HtmlDialog.new(
            {
                :dialog_title => dialog_title,
                :preferences_key => DIALOG_PREF_KEY,
                :scrollable => true,
                :resizable => true,
                :width => DIALOG_MINIMIZED_WIDTH,
                :height => DIALOG_MINIMIZED_HEIGHT,
                :left => @dialog_left,
                :top => @dialog_top,
                :min_width => DIALOG_MINIMIZED_WIDTH,
                :min_height => DIALOG_MINIMIZED_HEIGHT,
                :style => UI::HtmlDialog::STYLE_DIALOG
            })
        @dialog.set_on_closed {
          @dialog = nil
        }
      else
        @dialog = UI::WebDialog.new(
            dialog_title,
            true,
            DIALOG_PREF_KEY,
            DIALOG_MINIMIZED_WIDTH,
            DIALOG_MINIMIZED_HEIGHT,
            @dialog_left,
            @dialog_top,
            true
        )
        @dialog.min_width = DIALOG_MINIMIZED_WIDTH
        @dialog.min_height = DIALOG_MINIMIZED_HEIGHT
        @dialog.set_on_close {
          @dialog = nil
        }
      end

      # Setup dialog page
      @dialog.set_file("#{__dir__}/../html/dialog-#{language}.html")

      # Set dialog size and position
      dialog_set_size(DIALOG_MINIMIZED_WIDTH, DIALOG_MINIMIZED_HEIGHT)
      dialog_set_position(@dialog_left, @dialog_top)

      # Setup dialog actions
      @dialog.add_action_callback("ladb_opencutlist_command") do |action_context, call_json|
        call = JSON.parse(call_json)
        response = execute_command(call['command'], call['params'])
        script = "rubyCommandCallback(#{call['id']}, '#{response.is_a?(Hash) ? Base64.strict_encode64(URI.escape(JSON.generate(response))) : ''}');"
        @dialog.execute_script(script)
      end

    end

    def show_dialog(tab_name = nil, &ready_block)

      unless @dialog
        create_dialog
      end

      if @dialog.visible?

        if tab_name
          # Startup tab name is defined call JS to select it
          @dialog.execute_script("$('body').ladbDialog('selectTab', '#{tab_name}');")
        end

        if ready_block
          # Immediatly invoke the read block
          ready_block.call
        end

      else

        # Store the startup tab name
        @dialog_startup_tab_name = tab_name

        # Store the ready block
        @dialog_ready_block = ready_block

        # Show dialog
        if html_dialog_compatible
          @dialog.show
        else
          if current_os == :MAC
            @dialog.show_modal
          else
            @dialog.show
          end
        end

      end

    end

    def hide_dialog
      if @dialog
        @dialog.close
        @dialog = nil
        true
      else
        false
      end
    end

    def toggle_dialog
      unless hide_dialog
        show_dialog
      end
    end

    def dialog_set_size(width, height, persist = false)
      if @dialog
        if current_os == :MAC && !html_dialog_compatible
          @dialog.execute_script("window.resizeTo(#{width},#{height})")
        else
          @dialog.set_size(width, height)
        end
        if persist
          @dialog_maximized_width = width
          @dialog_maximized_height = height
          write_default(SETTINGS_KEY_DIALOG_MAXIMIZED_WIDTH, width)
          write_default(SETTINGS_KEY_DIALOG_MAXIMIZED_HEIGHT, height)
        end
      end
    end

    def dialog_set_position(left, top, persist = false)
      if @dialog
        if current_os == :MAC && !html_dialog_compatible
          @dialog.execute_script("window.moveTo(#{left},#{top})")
        else
          @dialog.set_position(left, top)
        end
        if persist
          @dialog_left = left
          @dialog_top = top
          write_default(SETTINGS_KEY_DIALOG_LEFT, left)
          write_default(SETTINGS_KEY_DIALOG_TOP, top)
        end
      end
    end

    def execute_dialog_command_on_tab(tab_name, command, parameters = nil, callback = nil)

      show_dialog(nil) do
        # parameters and callback must be formatted as JS code
        if tab_name and command
          @dialog.execute_script("$('body').ladbDialog('executeCommandOnTab', [ '#{tab_name}', '#{command}', #{parameters}, #{callback} ]);")
        end
      end

    end

    private

    # -- Utils ---

    def _get_selected_component_entity
      entity = (Sketchup.active_model.nil? || Sketchup.active_model.selection.length > 1) ? nil : Sketchup.active_model.selection.first
      if !entity.nil? && entity.is_a?(Sketchup::ComponentInstance)
        return entity
      end
      nil
    end

    def _edit_part_properties(entity, tab = 'general')
      unless entity.nil?
        execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: null, part_serialized_path: '#{PathUtils.serialize_path(Sketchup.active_model.active_path.nil? ? [ entity ] : Sketchup.active_model.active_path + [ entity ])}', tab: '#{tab}' }")
      end
    end

    # -- Commands ---

    def read_settings_command(params)    # Waiting params = { keys: [ 'key1', ... ], strategy: [0|1|2|3] }
      keys = params['keys']
      strategy = params['strategy']   # Strategy used to read settings SETTINGS_RW_STRATEGY_GLOBAL or SETTINGS_RW_STRATEGY_GLOBAL_MODEL or SETTINGS_RW_STRATEGY_MODEL or SETTINGS_RW_STRATEGY_MODEL_GLOBAL
      values = []
      keys.each { |key|

        value = nil
        if strategy && Sketchup.active_model

          if strategy == SETTINGS_RW_STRATEGY_GLOBAL_MODEL
              value = read_default(key)
              if value.nil?
                value = get_attribute(Sketchup.active_model, key)
              end
          elsif strategy == SETTINGS_RW_STRATEGY_MODEL || strategy == SETTINGS_RW_STRATEGY_MODEL_GLOBAL
              value = get_attribute(Sketchup.active_model, key)
          end

        end
        if value.nil?
          value = read_default(key)
        end

        if value.is_a? String
          value = value.gsub(/[\\]/, '')        # unescape double quote
        end

        values.push(
            {
                :key => key,
                :value => value
            }
        )

      }
      { :values => values }
    end

    def write_settings_command(params)    # Waiting params = { settings: [ { key => 'key1', value => 'value1', preprocessor => [0|1] }, ... ], strategy: [0|1|2|3] }
      settings = params['settings']
      strategy = params['strategy']   # Strategy used to write settings SETTINGS_RW_STRATEGY_GLOBAL or SETTINGS_RW_STRATEGY_GLOBAL_MODEL or SETTINGS_RW_STRATEGY_MODEL or SETTINGS_RW_STRATEGY_MODEL_GLOBAL
      settings.each { |setting|

        key = setting['key']
        value = setting['value']
        preprocessor = setting['preprocessor']    # Preprocessor used to reformat value SETTINGS_PREPROCESSOR_D or SETTINGS_PREPROCESSOR_DXD

        # Value Preprocessor
        unless value.nil?
          case preprocessor
            when SETTINGS_PREPROCESSOR_D
              value = DimensionUtils.instance.dd_add_units(value)
            when SETTINGS_PREPROCESSOR_DXD
              value = DimensionUtils.instance.dxd_add_units(value)
          end
        end

        if value.is_a? String
          value = value.gsub(/["]/, '\"')        # escape double quote in string
        end

        if strategy.nil? || strategy == SETTINGS_RW_STRATEGY_GLOBAL || strategy == SETTINGS_RW_STRATEGY_GLOBAL_MODEL || strategy == SETTINGS_RW_STRATEGY_MODEL_GLOBAL
          write_default(key, value)
        end
        if Sketchup.active_model && (strategy == SETTINGS_RW_STRATEGY_MODEL || strategy == SETTINGS_RW_STRATEGY_MODEL_GLOBAL || strategy == SETTINGS_RW_STRATEGY_GLOBAL_MODEL)
          set_attribute(Sketchup.active_model, key, value)
        end

      }
    end

    def dialog_loaded_command
      {
          :version => EXTENSION_VERSION,
          :build => EXTENSION_BUILD,
          :debug => DEBUG,
          :sketchup_is_pro => Sketchup.is_pro?,
          :sketchup_version => Sketchup.version,
          :sketchup_version_number => Sketchup.version_number,
          :ruby_version => RUBY_VERSION,
          :current_os => "#{current_os}",
          :is_64bit => Sketchup.respond_to?(:is_64bit?) && Sketchup.is_64bit?,
          :locale => Sketchup.get_locale,
          :language => Plugin.instance.language,
          :available_languages => Plugin.instance.get_available_languages,
          :html_dialog_compatible => html_dialog_compatible,
          :dialog_maximized_width => @dialog_maximized_width,
          :dialog_maximized_height => @dialog_maximized_height,
          :dialog_left => @dialog_left,
          :dialog_top => @dialog_top,
          :dialog_startup_tab_name => @dialog_startup_tab_name  # nil if none
      }
    end

    def dialog_ready_command
      if @dialog_ready_block
        @dialog_ready_block.call
        @dialog_ready_block = nil
      end
    end

    def dialog_minimize_command
      if @dialog
        dialog_set_size(DIALOG_MINIMIZED_WIDTH, DIALOG_MINIMIZED_HEIGHT)
      end
    end

    def dialog_maximize_command
      if @dialog
        dialog_set_size(@dialog_maximized_width, @dialog_maximized_height)
      end
    end

    def open_external_file_command(params)    # Waiting params = { path: PATH_TO_FILE }
      path = params['path']
      if path
        UI.openURL("file:///#{path}")
      end
    end

    def open_url_command(params)    # Waiting params = { url: URL }
      url = params['url']
      if url
        UI.openURL(url)
      end
    end

    def open_model_info_page_command(params)    # Waiting params = { page: PAGE_TO_SHOW }
      page = params['page']
      if page
        UI.show_model_info(page)
      end
    end

    def zoom_extents_command
      if Sketchup.active_model
        Sketchup.active_model.active_view.zoom_extents
      end
    end

    def send_action_command(params)
      action = params['action']

      # Send action
      success = Sketchup.send_action(action)

      {
          :success => success,
      }
    end

    def compute_size_aspect_ratio_command(params)    # Waiting params = { width: WIDTH, height: HEIGHT, ratio: W_ON_H_RATIO, is_width_master: BOOL }
      width = params['width']
      height = params['height']
      ratio = params['ratio']
      is_width_master = params['is_width_master']

      # Convert input values to Length
      w = DimensionUtils.instance.dd_to_ifloats(width).to_l
      h = DimensionUtils.instance.dd_to_ifloats(height).to_l

      if is_width_master
        h = (w / ratio).to_l
      else
        w = (h * ratio).to_l
      end

      {
          :width => w.to_s,
          :height => h.to_s
      }
    end

  end

end