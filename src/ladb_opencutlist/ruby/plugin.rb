module Ladb::OpenCutList

  require 'singleton'
  require 'fileutils'
  require 'json'
  require 'yaml'
  require 'base64'
  require 'uri'
  require 'tempfile'
  require 'set'
  require 'open-uri'
  require_relative 'constants'
  require_relative 'observer/app_observer'
  require_relative 'observer/plugin_observer'
  require_relative 'controller/materials_controller'
  require_relative 'controller/cutlist_controller'
  require_relative 'controller/importer_controller'
  require_relative 'controller/settings_controller'
  require_relative 'utils/dimension_utils'
  require_relative 'utils/path_utils'

  class Plugin
    
    include Singleton

    IS_RBZ = __dir__.start_with? Sketchup.find_support_file('Plugins')
    IS_DEV = EXTENSION_VERSION.end_with? '-dev'

    require 'pp' if IS_DEV

    DEFAULT_SECTION = ATTRIBUTE_DICTIONARY = 'ladb_opencutlist'.freeze
    SU_ATTRIBUTE_DICTIONARY = 'SU_DefinitionSet'.freeze

    PRESETS_KEY = 'core.presets'.freeze
    PRESETS_DEFAULT_NAME = '_default'.freeze

    PRESETS_PREPROCESSOR_NONE = 0
    PRESETS_PREPROCESSOR_D = 1                   # 1D dimension
    PRESETS_PREPROCESSOR_DXQ = 2                 # 1D dimension with quantity
    PRESETS_PREPROCESSOR_DXD = 3                 # 2D dimension
    PRESETS_PREPROCESSOR_DXDXQ = 4               # 2D dimension with quantity

    PRESETS_STORAGE_ALL = 0
    PRESETS_STORAGE_GLOBAL_ONLY = 1              # Value stored in global presets only
    PRESETS_STORAGE_MODEL_ONLY = 2               # Value stored in model presets only

    SETTINGS_KEY_LANGUAGE = 'settings.language'
    SETTINGS_KEY_DIALOG_MAXIMIZED_WIDTH = 'settings.dialog_maximized_width'
    SETTINGS_KEY_DIALOG_MAXIMIZED_HEIGHT = 'settings.dialog_maximized_height'
    SETTINGS_KEY_DIALOG_LEFT = 'settings.dialog_left'
    SETTINGS_KEY_DIALOG_TOP = 'settings.dialog_top'
    SETTINGS_KEY_DIALOG_ZOOM = 'settings.dialog_zoom'

    DIALOG_DEFAULT_MAXIMIZED_WIDTH = 1100
    DIALOG_DEFAULT_MAXIMIZED_HEIGHT = 640
    DIALOG_MINIMIZED_WIDTH = 90
    DIALOG_MINIMIZED_HEIGHT = 30 + 80 + 80 * 3     # = 3 Tab buttons
    DIALOG_DEFAULT_LEFT = 60
    DIALOG_DEFAULT_TOP = 100
    DIALOG_DEFAULT_ZOOM = '100%'
    DIALOG_PREF_KEY = 'fr.lairdubois.opencutlist'

    # -----

    def initialize

      @temp_dir = nil
      @language = nil
      @current_os = nil
      @i18n_strings_cache = nil
      @app_defaults_cache = nil
      @html_dialog_compatible = nil
      @manifest = nil
      @update_available = nil
      @update_muted = false
      @last_news_timestamp = nil

      @commands = {}
      @event_callbacks = {}
      @controllers = []
      @observers = []

      @started = false

      @dialog = nil
      @dialog_startup_tab_name = nil
      @dialog_maximized_width = read_default(SETTINGS_KEY_DIALOG_MAXIMIZED_WIDTH, DIALOG_DEFAULT_MAXIMIZED_WIDTH)
      @dialog_maximized_height = read_default(SETTINGS_KEY_DIALOG_MAXIMIZED_HEIGHT, DIALOG_DEFAULT_MAXIMIZED_HEIGHT)
      @dialog_left = read_default(SETTINGS_KEY_DIALOG_LEFT, DIALOG_DEFAULT_LEFT)
      @dialog_top = read_default(SETTINGS_KEY_DIALOG_TOP, DIALOG_DEFAULT_TOP)
      @dialog_zoom = read_default(SETTINGS_KEY_DIALOG_ZOOM, DIALOG_DEFAULT_ZOOM)

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
      if language.nil? || language == 'auto'
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
      @i18n_strings_cache = nil # Reset i18n strings cache
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

      unless @i18n_strings_cache
        file_path = File.join(__dir__, '..', 'yaml', 'i18n', "#{language}.yml")
        begin
          @i18n_strings_cache = YAML::load_file(file_path)
        rescue => e
          raise "Error loading i18n file (file='#{file_path}') : #{e.message}."
        end
      end

      # Iterate over values
      begin
        i18n_string = path_key.split('.').inject(@i18n_strings_cache) { |hash, key| hash[key] }
      rescue
        i18n_string = nil
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

    def clear_app_defaults_cache
      @app_defaults_cache = nil
    end

    def get_app_defaults(dictionary, section = nil, raise_not_found = true)

      section = '0' if section.nil?
      section = section.to_s
      cache_key = "#{dictionary}_#{section}"

      unless @app_defaults_cache && @app_defaults_cache.has_key?(cache_key)

        file_path = File.join(__dir__, '..', 'json', 'defaults', "#{dictionary}.json")
        begin
          file = File.open(file_path)
          data = JSON.load(file)
          file.close
        rescue => e
          raise "Error loading defaults file (file='#{file_path}') : #{e.message}."
        end

        model_unit_is_metric = DimensionUtils.instance.model_unit_is_metric

        defaults = {}
        if data.has_key? section
          data = data[section]
          data.each do |key, value|
            if value.is_a? Hash
              if model_unit_is_metric
                value = value['metric'] if value.has_key? 'metric'
              else
                value = value['imperial'] if value.has_key? 'imperial'
              end
            end
            defaults.store(key, value)
          end
        else
          if raise_not_found
            raise "Error loading defaults file (file='#{file_path}') : Section not found (section=#{section})."
          end
        end

        # Cache loaded defaults
        unless @app_defaults_cache
          @app_defaults_cache = {}
        end
        @app_defaults_cache.store(cache_key, defaults)

      end

      @app_defaults_cache[cache_key]
    end

    # -----

    def set_attribute(entity, key, value, dictionary = ATTRIBUTE_DICTIONARY)
      if value.is_a?(Hash) || value.is_a?(Array)
        # Encode hash or array to json (because attribute don't support hashs)
        value = value.to_json
      end
      entity.set_attribute(dictionary, key, value)
    end

    def get_attribute(entity, key, default_value = nil, dictionary = ATTRIBUTE_DICTIONARY)
      value = entity.get_attribute(dictionary, key, default_value)
      # Try to detect and convert json from String values
      if value != default_value && value.is_a?(String) && value[/^{(?:.)*}$|^\[(?:.)*\]$/]
        begin
          return JSON.parse(value)
        end
      end
      value
    end

    def write_default(key, value, section = DEFAULT_SECTION)
      Sketchup.write_default(section, key, value)
    end

    def read_default(key, default_value = nil, section = DEFAULT_SECTION)
      Sketchup.read_default(section, key, default_value)
    end

    # -----

    @global_presets_cache = nil
    @model_presets_cache = nil

    def _process_preset_values_with_app_defaults(dictionary, section, values, is_global)

      # Try to synchronize values with app defaults
      begin
        app_defaults = get_app_defaults(dictionary, section)
        preprocessors = get_app_defaults(dictionary, '_preprocessors', false)
        storages = get_app_defaults(dictionary, '_storages', false)
        processed_values = {}
        values.keys.each do |key|

          storage = storages.has_key?(key) ? storages[key] : PRESETS_STORAGE_ALL

          if app_defaults.has_key?(key) && # Only if exists in app defaults
              (storage == PRESETS_STORAGE_ALL ||
              (is_global && storage == PRESETS_STORAGE_GLOBAL_ONLY) ||
              (!is_global && storage == PRESETS_STORAGE_MODEL_ONLY))

            case preprocessors[key]
              when PRESETS_PREPROCESSOR_D
                processed_values[key] = DimensionUtils.instance.d_add_units(values[key])
              when PRESETS_PREPROCESSOR_DXQ
                processed_values[key] = DimensionUtils.instance.dxq_add_units(values[key])
              when PRESETS_PREPROCESSOR_DXD
                processed_values[key] = DimensionUtils.instance.dxd_add_units(values[key])
              when PRESETS_PREPROCESSOR_DXDXQ
                processed_values[key] = DimensionUtils.instance.dxdxq_add_units(values[key])
            else
              processed_values[key] = values[key]
            end

          end

        end
      rescue => e

        # App defaults don't contain the given dictionary and/or section. Values stays unchanged.
        processed_values = values

      end
      processed_values
    end

    def _merge_preset_values_with_defaults(values, default_values)
      merged_values = {}
      if default_values
        default_values.keys.each do |key|
          if values.has_key?(key)
            merged_values[key] = values[key]
          else
            merged_values[key] = default_values[key]
          end
        end
      else
        merged_values = values
      end
      merged_values
    end

    def read_global_presets
      @global_presets_cache = read_default(PRESETS_KEY, {})
    end

    def write_global_presets
      write_default(PRESETS_KEY, @global_presets_cache)
    end

    def reset_global_presets
      @global_presets_cache = {}
      write_global_presets
    end

    def set_global_preset(dictionary, values, name = nil, section = nil, fire_event = false)

      name = PRESETS_DEFAULT_NAME if name.nil?
      section = '0' if section.nil?

      # Read global presets cache if not previouly cached
      read_global_presets if @global_presets_cache.nil?

      # Create preset tree if it desn't exists
      unless @global_presets_cache.has_key?(dictionary)
        @global_presets_cache[dictionary] = {}
      end
      unless @global_presets_cache[dictionary].has_key?(section)
        @global_presets_cache[dictionary][section] = {}
      end

      if values.nil?

        # Remove preset if values is nil
        @global_presets_cache[dictionary][section].delete(name)
        @global_presets_cache[dictionary].delete(section) if @global_presets_cache[dictionary][section].empty?
        @global_presets_cache.delete(dictionary) if @global_presets_cache[dictionary].empty?

      else

        @global_presets_cache[dictionary][section][name] = _process_preset_values_with_app_defaults(dictionary, section, values, true)

      end

      # Store presets to SU defaults
      write_global_presets

      # Fire event
      self.trigger_onGlobalPresetChanged(dictionary, section) if fire_event

    end

    def get_global_preset(dictionary, name = nil, section = nil)

      name = PRESETS_DEFAULT_NAME if name.nil?
      section = '0' if section.nil?

      # Read global presets cache if not previouly cached
      read_global_presets if @global_presets_cache.nil?

      if name == PRESETS_DEFAULT_NAME
        begin
          default_values = get_app_defaults(dictionary, section)
        rescue => e
          # App defaults don't contain the given dictionary and/or section. Returns nil.
          return nil
        end
      else
        default_values = get_global_preset(dictionary, nil, section)
      end
      if @global_presets_cache.has_key?(dictionary) && @global_presets_cache[dictionary].has_key?(section) && @global_presets_cache[dictionary][section].has_key?(name)

        # Preset exists, synchronize returned values with default_values data and structure
        values = _merge_preset_values_with_defaults(@global_presets_cache[dictionary][section][name], default_values)

      else

        # Preset doesn't exists, return default_values
        values = default_values.clone

      end
      values
    end

    def list_global_preset_dictionaries
      read_global_presets if @global_presets_cache.nil?
      @global_presets_cache.keys.sort
    end

    def list_global_preset_sections(dictionary)
      read_global_presets if @global_presets_cache.nil?
      return @global_presets_cache[dictionary].keys.sort if @global_presets_cache.has_key?(dictionary)
      []
    end

    def list_global_preset_names(dictionary, section = nil)
      section = '0' if section.nil?
      read_global_presets if @global_presets_cache.nil?
      return @global_presets_cache[dictionary][section].keys.select { |k, v| k != PRESETS_DEFAULT_NAME }.sort if @global_presets_cache.has_key?(dictionary) && @global_presets_cache[dictionary].has_key?(section)
      []
    end

    def dump_global_presets
      require 'pp'
      read_global_presets if @global_presets_cache.nil?
      _debug('GLOBAL PRESETS') do
        pp @global_presets_cache
      end
    end

    # -----

    def clear_model_presets_cache
      @model_presets_cache = nil
    end

    def read_model_presets
      @model_presets_cache = Sketchup.active_model ? get_attribute(Sketchup.active_model, PRESETS_KEY, {}) : {}
    end

    def write_model_presets
      return unless Sketchup.active_model

      # Start model modification operation
      Sketchup.active_model.start_operation('write_model_presets', true, false, true)

      set_attribute(Sketchup.active_model, PRESETS_KEY, @model_presets_cache)

      # Commit model modification operation
      Sketchup.active_model.commit_operation
    end

    def reset_model_presets
      @model_presets_cache = {}
      write_model_presets
    end

    def set_model_preset(dictionary, values, section = nil, app_defaults_section = nil, fire_event = false)

      section = '0' if section.nil?
      app_defaults_section = '0' if app_defaults_section.nil?

      # Read model presets cache if not previouly cached
      read_model_presets if @model_presets_cache.nil?

      # Create preset tree if it desn't exists
      unless @model_presets_cache.has_key?(dictionary)
        @model_presets_cache[dictionary] = {}
      end
      unless @model_presets_cache[dictionary].has_key?(section)
        @model_presets_cache[dictionary][section] = {}
      end

      if values.nil?

        # Remove preset if values is nil
        @model_presets_cache[dictionary].delete(section)
        @model_presets_cache.delete(dictionary) if @model_presets_cache[dictionary].empty?

      else

        @model_presets_cache[dictionary][section] = _process_preset_values_with_app_defaults(dictionary, app_defaults_section, values, false)

      end

      # Store presets to SU defaults
      write_model_presets

      # Fire event
      self.trigger_onModelPresetChanged(dictionary, section) if fire_event

    end

    def get_model_preset(dictionary, section = nil, app_defaults_section = nil)

      section = '0' if section.nil?
      app_defaults_section = '0' if app_defaults_section.nil?

      # Read model presets cache if not previouly cached
      read_model_presets if @model_presets_cache.nil?

      default_values = get_global_preset(dictionary, nil, app_defaults_section)
      if @model_presets_cache.has_key?(dictionary) && @model_presets_cache[dictionary].has_key?(section)

        # Preset exists, synchronize returned values with default_values data and structure
        values = _merge_preset_values_with_defaults(@model_presets_cache[dictionary][section], default_values)

      else

        # Preset doesn't exists, return default_values
        values = default_values.clone

      end
      values
    end

    def list_model_preset_dictionaries
      read_model_presets if @model_presets_cache.nil?
      @model_presets_cache.keys.sort
    end

    def list_model_preset_sections(dictionary)
      read_model_presets if @model_presets_cache.nil?
      return @model_presets_cache[dictionary].keys.sort if @model_presets_cache.has_key?(dictionary)
      []
    end

    def dump_model_presets
      require 'pp'
      read_model_presets if @model_presets_cache.nil?
      _debug('MODEL PRESETS') do
        pp @model_presets_cache
      end
    end

    # -----

    def trigger_onGlobalPresetChanged(dictonary, section)
      @observers.each do |observer|
        if observer.respond_to?(:onGlobalPresetChanged)
          observer.onGlobalPresetChanged(dictonary, section)
        end
      end
    end

    def trigger_onModelPresetChanged(dictonary, section)
      @observers.each do |observer|
        if observer.respond_to?(:onModelPresetChanged)
          observer.onModelPresetChanged(dictonary, section)
        end
      end
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

    def add_event_callback(event, &block)
      if event.is_a? Array
        events = event
      else
        events = [ event ]
      end
      events.each do |e|
        unless @event_callbacks.has_key? e
          @event_callbacks[e] = []
        end
        @event_callbacks[e].push(block)
      end
    end

    def trigger_event(event, params)
      if @event_callbacks.has_key? event
        blocks = @event_callbacks[event]
        blocks.each do |block|
          block.call(params)
        end
      end
      if @dialog
        @dialog.execute_script("triggerEvent('#{event}', '#{params.is_a?(Hash) ? Base64.strict_encode64(JSON.generate(params)) : ''}');")
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

      # Clear Ruby console if dev running
      if IS_DEV
        SKETCHUP_CONSOLE.clear
      end

      # To minimize plugin initialization, start setup is called only once
      unless @started

        # -- Observers --

        Sketchup.add_observer(AppObserver.instance)
        @observers.push(PluginObserver.instance)

        # -- Controllers --

        @controllers.push(MaterialsController.new)
        @controllers.push(CutlistController.new)
        @controllers.push(ImporterController.new)
        @controllers.push(SettingsController.new)

        # -- Commands --

        register_command('core_set_update_status') do |params|
          set_update_status_command(params)
        end
        register_command('core_set_news_status') do |params|
          set_news_status_command(params)
        end
        register_command('core_upgrade') do |params|
          upgrade_command(params)
        end
        register_command('core_get_app_defaults') do |params|
          get_app_defaults_command(params)
        end
        register_command('core_set_global_preset') do |params|
          set_global_preset_command(params)
        end
        register_command('core_get_global_preset') do |params|
          get_global_preset_command(params)
        end
        register_command('core_list_global_preset_names') do |params|
          list_global_preset_names_command(params)
        end
        register_command('core_set_model_preset') do |params|
          set_model_preset_command(params)
        end
        register_command('core_get_model_preset') do |params|
          get_model_preset_command(params)
        end
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
        register_command('core_dialog_hide') do |params|
          dialog_hide_command
        end
        register_command('core_open_external_file') do |params|
          open_external_file_command(params)
        end
        register_command('core_open_url') do |params|
          open_url_command(params)
        end
        register_command('core_zoom_extents') do |params|
          zoom_extents_command
        end
        register_command('core_play_sound') do |params|
          play_sound_command(params)
        end
        register_command('core_send_action') do |params|
          send_action_command(params)
        end
        register_command('core_length_to_float') do |params|
          length_to_float_command(params)
        end
        register_command('core_float_to_length') do |params|
          float_to_length_command(params)
        end
        register_command('core_compute_size_aspect_ratio') do |params|
          compute_size_aspect_ratio_command(params)
        end

        @controllers.each { |controller|
          controller.setup_commands
          controller.setup_event_callbacks
        }

        @started = true

      end

    end

    def create_dialog

      # Start
      start

      # Create dialog instance
      dialog_title = get_i18n_string('core.dialog.title') + ' - ' + EXTENSION_VERSION + (IS_DEV ? " ( build: #{EXTENSION_BUILD} )" : '')
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
      call_json = ''
      @dialog.add_action_callback('ladb_opencutlist_command') do |action_context, chunk|
        match = /^([0-9]+)\/([0-9]+)\/(.+)$/.match(chunk)
        current_chunk_index = match[1]
        last_chunk_index = match[2]
        call_json += match[3]
        if current_chunk_index == last_chunk_index
          call = JSON.parse(call_json)
          call_json = ''
          response = execute_command(call['command'], call['params'])
          script = "rubyCommandCallback(#{call['id']}, '#{response.is_a?(Hash) ? Base64.strict_encode64(JSON.generate(response)) : ''}');"
          @dialog.execute_script(script) if @dialog
        end
      end

    end

    def show_dialog(tab_name = nil, auto_create = true, &ready_block)

      return if @dialog.nil? && !auto_create

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
          @dialog.execute_script("window.moveTo(#{left},#{top});")
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

    def dialog_set_zoom(zoom, persist = false)
      if @dialog
        @dialog.execute_script("$('body').css('zoom', '#{zoom}');")
        if persist
          @dialog_zoom = zoom
          write_default(SETTINGS_KEY_DIALOG_ZOOM, zoom)
        end
      end
    end

    def execute_dialog_command_on_tab(tab_name, command, parameters = nil, callback = nil)

      show_dialog(nil, true) do
        # parameters and callback must be formatted as JS code
        if tab_name and command
          @dialog.execute_script("$('body').ladbDialog('executeCommandOnTab', [ '#{tab_name}', '#{command}', #{parameters}, #{callback} ]);")
        end
      end

    end

    private

    # -- Utils ---

    def _debug(heading, &block)
      heading = "#{heading} - #{EXTENSION_NAME} #{EXTENSION_VERSION} ( build: #{EXTENSION_BUILD} )"
      puts '-' * heading.length
      puts heading
      puts '-' * heading.length
      block.call
      puts '-' * heading.length
    end

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

    def set_update_status_command(params)    # Expected params = { manifest: MANIFEST, update_available: BOOL, update_muted: BOOL }
      @manifest = params['manifest']
      @update_available = params['update_available']
      @update_muted = params['update_muted']
    end

    def set_news_status_command(params)    # Expected params = { last_news_timestamp: TIMESTAMP }
      @last_news_timestamp = params['last_news_timestamp']
    end

    def upgrade_command(params)    # Expected params = { url: 'RBZ_URL' }
      # Just open URL for older Sketchup versions
      if Sketchup.version_number < 1700000000
        open_url_command(params)
        return { :cancelled => true }
      end

      url = params['url']

      # Download the RBZ
      begin

        # URLs with spaces will raise an InvalidURIError, so we need to encode it.
        # However, the user can pass an already encoded URL, so we first need to
        # decode it.
        url = URI.encode(URI.decode(url))

        # This will raise an InvalidURIError if the URL is very wrong. It will still
        # pass for strings like "foo", though.
        url = URI(url)

        last_progress = 0
        request = Sketchup::Http::Request.new(url.to_s, Sketchup::Http::GET)
        request.set_download_progress_callback do |current, total|
          progress = current * 5 / total
          if progress > last_progress
            trigger_event('on_upgrade_progress', {
                :current => current,
                :total => total,
            })
            last_progress = progress
          end
        end
        request.start do |request, response|

          timer_running = false
          UI.start_timer(1, false) {

            # Timer with modal bug workaround https://ruby.sketchup.com/UI.html#start_timer-class_method
            return if timer_running
            timer_running = true

            # Prepare file
            downloads_dir = File.join(temp_dir, 'downloads')
            unless Dir.exist?(downloads_dir)
              Dir.mkdir(downloads_dir)
            end
            rbz_file = File.join(downloads_dir, 'ladb_opencutlist.rbz')

            # Write result to file
            File.open(rbz_file, 'wb') do |f|
              f.write(response.body)
            end

            success = false

            # Install the RBZ
            begin
              Sketchup.install_from_archive(rbz_file)
              success = true
            rescue Interrupt => e
              trigger_event('on_upgrade_cancelled', {})
            rescue Exception => e
              UI.beep
              UI.messagebox(get_i18n_string('core.upgrade.error.unzip') + "\n" + e.message)
              trigger_event('on_upgrade_cancelled', {})
            ensure

              # Remove downloaded archive
              File.unlink(rbz_file)

            end

            if success

              # Hide OCL dialog
              hide_dialog

              # Inform user to restart Sketchup
              UI.messagebox(get_i18n_string('core.upgrade.success'))

            end

          }

        end

      rescue Exception => e
        puts e.message
        puts e.backtrace
        UI.beep
        UI.messagebox(get_i18n_string('core.upgrade.error.download') + "\n" + e.message)
        return { :cancelled => true }
      end

    end

    def get_app_defaults_command(params) # Expected params = { dictionary: DICTIONARY, section: SECTION }
      dictionary = params['dictionary']
      section = params['section']

      { :defaults => get_app_defaults(dictionary, section) }
    end

    def set_global_preset_command(params) # Expected params = { dictionary: DICTIONARY, values: VALUES, name: NAME, section: SECTION }
      dictionary = params['dictionary']
      values = params['values']
      name = params['name']
      section = params['section']
      fire_event = params['fire_event']

      set_global_preset(dictionary, values, name, section, fire_event)
    end

    def get_global_preset_command(params) # Expected params = { dictionary: DICTIONARY, name: NAME, section: SECTION }
      dictionary = params['dictionary']
      name = params['name']
      section = params['section']

      { :preset => get_global_preset(dictionary, name, section) }
    end

    def list_global_preset_names_command(params) # Expected params = { dictionary: DICTIONARY, section: SECTION }
      dictionary = params['dictionary']
      section = params['section']

      { :names => list_global_preset_names(dictionary, section) }
    end

    def set_model_preset_command(params) # Expected params = { dictionary: DICTIONARY, values: VALUES, section: SECTION, app_default_section: APP_DEFAULT_SECTION }
      dictionary = params['dictionary']
      values = params['values']
      section = params['section']
      app_default_section = params['app_default_section']
      fire_event = params['fire_event']

      set_model_preset(dictionary, values, section, app_default_section, fire_event)
    end

    def get_model_preset_command(params) # Expected params = { dictionary: DICTIONARY, section: SECTION, app_default_section: APP_DEFAULT_SECTION }
      dictionary = params['dictionary']
      section = params['section']
      app_default_section = params['app_default_section']

      { :preset => get_model_preset(dictionary, section, app_default_section) }
    end

    def read_settings_command(params)    # Expected params = { keys: [ 'key1', ... ] }
      keys = params['keys']
      values = []
      keys.each { |key|

        value = read_default(key)

        if value.is_a? String
          value = value.gsub(/[\\]/, '')      # unescape double quote
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

    def write_settings_command(params)    # Expected params = { settings: [ { key => 'key1', value => 'value1' }, ... ] }
      settings = params['settings']

      settings.each { |setting|

        key = setting['key']
        value = setting['value']

        if value.is_a? String
          value = value.gsub(/["]/, '\"')        # escape double quote in string
        end

        write_default(key, value)

      }

    end

    def dialog_loaded_command
      dialog_set_zoom(@dialog_zoom)
      {
          :version => EXTENSION_VERSION,
          :build => EXTENSION_BUILD,
          :is_rbz => IS_RBZ,
          :is_dev => IS_DEV,
          :sketchup_is_pro => Sketchup.is_pro?,
          :sketchup_version => Sketchup.version,
          :sketchup_version_number => Sketchup.version_number,
          :ruby_version => RUBY_VERSION,
          :current_os => "#{current_os}",
          :is_64bit => Sketchup.respond_to?(:is_64bit?) && Sketchup.is_64bit?,
          :locale => Sketchup.get_locale,
          :language => Plugin.instance.language,
          :available_languages => Plugin.instance.get_available_languages,
          :decimal_separator => DimensionUtils.instance.decimal_separator,
          :html_dialog_compatible => html_dialog_compatible,
          :manifest => @manifest,
          :update_available => @update_available,
          :update_muted => @update_muted,
          :last_news_timestamp => @last_news_timestamp,
          :dialog_maximized_width => @dialog_maximized_width,
          :dialog_maximized_height => @dialog_maximized_height,
          :dialog_left => @dialog_left,
          :dialog_top => @dialog_top,
          :dialog_zoom => @dialog_zoom,
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

    def dialog_hide_command
      hide_dialog
    end

    def open_external_file_command(params)    # Expected params = { path: PATH_TO_FILE }
      path = params['path']
      if path
        UI.openURL("file:///#{path}")
      end
    end

    def open_url_command(params)    # Expected params = { url: URL }
      url = params['url']
      if url
        UI.openURL(url)
      end
    end

    def zoom_extents_command
      if Sketchup.active_model
        Sketchup.active_model.active_view.zoom_extents
      end
    end

    def play_sound_command(params)    # Expected params = { filename: WAV_FILE_TO_PLAY }
      UI.play_sound("#{__dir__}/../#{params['filename']}")
    end

    def send_action_command(params)
      action = params['action']

      # Send action
      success = Sketchup.send_action(action)

      {
          :success => success,
      }
    end

    def length_to_float_command(params)    # Expected params = { key_1: 'STRING_LENGTH', key_2: 'STRING_LENGTH', ... }
      float_lengths = {}
      params.each do |key, string_length|
        if string_length.index('x')
          # Convert string "size" to inch float array
          float_lengths[key] = string_length.split('x').map { |v| DimensionUtils.instance.d_to_ifloats(v).to_l.to_f }
        else
          # Convert string length to inch float
          float_lengths[key] = DimensionUtils.instance.d_to_ifloats(string_length).to_l.to_f
        end
      end
      float_lengths
    end

    def float_to_length_command(params)    # Expected params = { key_1: FLOAT_DIMENSION, key_2: FLOAT_DIMENSION, ... }
      string_lengths = {}
      params.each do |key, float_length|
        # Convert float inch length to string length with model unit
        string_lengths[key] = float_length.to_l.to_s
      end
      string_lengths
    end

    def compute_size_aspect_ratio_command(params)    # Expected params = { width: WIDTH, height: HEIGHT, ratio: W_ON_H_RATIO, is_width_master: BOOL }
      width = params['width']
      height = params['height']
      ratio = params['ratio']
      is_width_master = params['is_width_master']

      # Convert input values to Length
      w = DimensionUtils.instance.d_to_ifloats(width).to_l
      h = DimensionUtils.instance.d_to_ifloats(height).to_l

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