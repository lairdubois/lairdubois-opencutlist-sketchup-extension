module Ladb::OpenCutList

  require 'fileutils'
  require 'json'
  require 'yaml'
  require 'base64'
  require 'uri'
  require 'tempfile'
  require 'set'
  require 'open-uri'
  require 'digest'
  require_relative 'constants'
  require_relative 'observer/app_observer'
  require_relative 'observer/plugin_observer'
  require_relative 'controller/materials_controller'
  require_relative 'controller/cutlist_controller'
  require_relative 'controller/outliner_controller'
  require_relative 'controller/importer_controller'
  require_relative 'controller/settings_controller'
  require_relative 'utils/dimension_utils'
  require_relative 'utils/path_utils'
  require_relative 'utils/hash_utils'
  require_relative 'tool/smart_draw_tool'
  require_relative 'tool/smart_handle_tool'
  require_relative 'tool/smart_paint_tool'
  require_relative 'tool/smart_axes_tool'
  require_relative 'tool/smart_axes_tool_new'
  require_relative 'tool/smart_export_tool'

  class Plugin
    
    IS_RBZ = PLUGIN_DIR.start_with?(Sketchup.find_support_file('Plugins', ''))
    IS_DEV = EXTENSION_VERSION.end_with?('-dev')

    require 'pp' if IS_DEV

    DEFAULT_SECTION = ATTRIBUTE_DICTIONARY = 'ladb_opencutlist'.freeze
    SU_ATTRIBUTE_DICTIONARY = 'SU_DefinitionSet'.freeze

    PRESETS_KEY = 'core.presets'.freeze
    PRESETS_DEFAULT_NAME = '_default'.freeze

    PRESETS_PREPROCESSOR_NONE = 0
    PRESETS_PREPROCESSOR_D = 1                   # 1D dimension
    PRESETS_PREPROCESSOR_D_NEGATIVE_ALLOWED = 5  # 1D dimension (negative value allowed)
    PRESETS_PREPROCESSOR_DXQ = 2                 # 1D dimension with quantity
    PRESETS_PREPROCESSOR_DXD = 3                 # 2D dimension
    PRESETS_PREPROCESSOR_DXDXQ = 4               # 2D dimension with quantity

    PRESETS_STORAGE_ALL = 0
    PRESETS_STORAGE_GLOBAL_ONLY = 1              # Value stored in global presets only
    PRESETS_STORAGE_MODEL_ONLY = 2               # Value stored in model presets only

    PRESETS_CLEANER_NONE = 0
    PRESETS_CLEANER_ORDER_STRATEGY = 1           # Clean order strategy value

    SETTINGS_KEY_LANGUAGE = 'settings.language'
    SETTINGS_KEY_DIALOG_MAXIMIZED_WIDTH = 'settings.dialog_maximized_width'
    SETTINGS_KEY_DIALOG_MAXIMIZED_HEIGHT = 'settings.dialog_maximized_height'
    SETTINGS_KEY_DIALOG_LEFT = 'settings.dialog_left'
    SETTINGS_KEY_DIALOG_TOP = 'settings.dialog_top'
    SETTINGS_KEY_DIALOG_PRINT_MARGIN = 'settings.dialog_print_margin'
    SETTINGS_KEY_DIALOG_TABLE_ROW_SIZE = 'settings.dialog_table_row_size'
    SETTINGS_KEY_COMPONENTS_LAST_DIR = 'settings.components_last_dir'
    SETTINGS_KEY_MATERIALS_LAST_DIR = 'settings.materials_last_dir'

    TABS_DIALOG_MINIMIZED_WIDTH = 90
    TABS_DIALOG_MINIMIZED_HEIGHT = 28 + 80 + 80 * 3     # = 3 Tab buttons
    TABS_DIALOG_DEFAULT_MAXIMIZED_WIDTH = 1150
    TABS_DIALOG_DEFAULT_MAXIMIZED_HEIGHT = 640
    TABS_DIALOG_DEFAULT_LEFT = 60
    TABS_DIALOG_DEFAULT_TOP = 100
    TABS_DIALOG_DEFAULT_PRINT_MARGIN = 0   # 0 = Normal, 1 = Small
    TABS_DIALOG_DEFAULT_TABLE_ROW_SIZE = 0   # 0 = Normal, 1 = Compact
    TABS_DIALOG_PREF_KEY = 'fr.lairdubois.opencutlist'

    MODAL_DIALOG_DEFAULT_WIDTH = 700
    MODAL_DIALOG_DEFAULT_HEIGHT = 700
    MODAL_DIALOG_PREF_KEY = 'fr.lairdubois.opencutlist.modal'

    DOCS_URL = 'https://www.lairdubois.fr/opencutlist/docs'
    DOCS_DEV_URL = 'https://www.lairdubois.fr/opencutlist/docs-dev'

    # -----

    def initialize

      @temp_dir = nil
      @language = nil
      @webgl_available = false

      @i18n_strings_cache = nil
      @app_defaults_cache = nil

      @manifest = nil
      @update_available = nil
      @update_muted = false
      @last_news_timestamp = nil

      @commands = {}
      @event_callbacks = {}
      @controllers = []
      @observers = []

      @started = false

      @tabs_dialog = nil
      @tabs_dialog_maximized = false
      @tabs_dialog_startup_tab_name = nil
      @tabs_dialog_maximized_width = read_default(SETTINGS_KEY_DIALOG_MAXIMIZED_WIDTH, TABS_DIALOG_DEFAULT_MAXIMIZED_WIDTH)
      @tabs_dialog_maximized_height = read_default(SETTINGS_KEY_DIALOG_MAXIMIZED_HEIGHT, TABS_DIALOG_DEFAULT_MAXIMIZED_HEIGHT)
      @tabs_dialog_left = read_default(SETTINGS_KEY_DIALOG_LEFT, TABS_DIALOG_DEFAULT_LEFT)
      @tabs_dialog_top = read_default(SETTINGS_KEY_DIALOG_TOP, TABS_DIALOG_DEFAULT_TOP)
      @tabs_dialog_print_margin = read_default(SETTINGS_KEY_DIALOG_PRINT_MARGIN, TABS_DIALOG_DEFAULT_PRINT_MARGIN)
      @tabs_dialog_table_row_size = read_default(SETTINGS_KEY_DIALOG_TABLE_ROW_SIZE, TABS_DIALOG_DEFAULT_TABLE_ROW_SIZE)

      @modal_dialog = nil

    end

    # -----

    def temp_dir
      return @temp_dir unless @temp_dir.nil?
      dir = File.join(Sketchup.temp_dir, PLUGIN_ID)
      FileUtils.remove_dir(dir, true) if Dir.exist?(dir)  # Temp dir exists we clean it
      Dir.mkdir(dir)
      @temp_dir = dir
    end

    def language
      return @language unless @language.nil?
      # Try to retrieve and set language from defaults
      set_language(read_default(SETTINGS_KEY_LANGUAGE))
      @language
    end

    def set_language(language, persist = false)
      if language.nil? || language == 'auto'
        language = Sketchup.get_locale.split('-')[0].downcase  # Retrieve SU language
      end
      available_languages = self.get_available_languages
      if available_languages.include?(language)
        @language = language   # Uses language only if translation is available
      else
        @language = DEFAULT_LANGUAGE
      end
      if persist
        write_default(SETTINGS_KEY_LANGUAGE, @language)
      end
      @i18n_strings_cache = nil # Reset i18n strings cache
    end

    def get_enabled_languages
      return ENABLED_LANGUAGES unless IS_DEV
      ENABLED_LANGUAGES.flat_map { |language| [ language, "zz_#{language}" ] }
    end

    def get_available_languages
      available_languages = []
      Dir[File.join(PLUGIN_DIR, 'js', 'i18n', '*.js')].each { |file|
        available_languages.push(File.basename(file, File.extname(file)))
      }
      available_languages = get_enabled_languages & available_languages
      available_languages.sort
    end

    def webgl_available?
      @webgl_available
    end

    def platform_is_win?
      Sketchup.platform == :platform_win
    end

    def platform_is_mac?
      Sketchup.platform == :platform_osx
    end

    def platform_name
      Sketchup.platform == :platform_osx ? 'mac' : 'win'
    end

    def get_i18n_string(path_key, vars = nil)

      unless @i18n_strings_cache
        file_path = File.join(PLUGIN_DIR, 'yaml', 'i18n', "#{language}.yml")
        begin
          @i18n_strings_cache = YAML::load_file(file_path)
        rescue => e
          raise "Error loading i18n file (file='#{file_path}') : #{e.message}."
        end
      end

      # Process plural if a count var is defined
      if vars.is_a?(Hash) && !vars[:count].nil? && vars[:count] > 1 && !path_key.end_with?('_plural')
        path_key += '_plural'
      end

      # Iterate over values
      begin
        i18n_string = path_key.split('.').inject(@i18n_strings_cache) { |hash, key| hash[key] }
      rescue
        i18n_string = nil
        puts "I18n value not found (key=#{path_key})."
      end

      if i18n_string && i18n_string.is_a?(String)
        i18n_string = i18n_string.gsub(/\$t\(([^$()]+)\)/){ get_i18n_string("#{ $1.strip }", vars) }
        if vars.is_a?(Hash)
          vars.each do |k, v|
            i18n_string = i18n_string.gsub(Regexp.new("{{\s*#{k}\s*}}")){ v.to_s }
          end
        end
        return i18n_string
      end

      path_key
    end

    def open_docs_page(page)

      url = IS_DEV ? DOCS_DEV_URL : DOCS_URL
      url += "?v=#{EXTENSION_VERSION}&build=#{EXTENSION_BUILD}-#{(IS_RBZ ? 'rbz' : 'src')}&language=#{language}&locale=#{Sketchup.get_locale}"
      url += "&page=#{page}"

      # URLs with spaces will raise an InvalidURIError, so we need to encode it.
      url = URI::DEFAULT_PARSER.escape(url)

      request = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
      request.start do |request, response|

        if response.status_code == 200
          json = JSON.parse(response.body)
          if json['url'] && json['url'].is_a?(String)
            UI.openURL(URI::DEFAULT_PARSER.escape(json['url']))
            return
          end
        end

        puts "Failed to load docs page (page=#{page}, status=#{response.status_code})"
      end

    end

    def dump_exception(e, show_console = true, message = nil)

      SKETCHUP_CONSOLE.show if show_console

      heading = "Please email the following error to opencutlist@lairdubois.fr"
      puts '-' * heading.length
      puts heading
      puts '-' * heading.length
      puts "OpenCutList #{EXTENSION_VERSION} (build:#{EXTENSION_BUILD}) / #{language} - SketchUp #{Sketchup.version} - #{platform_name}"
      puts "#{e.inspect}"
      puts e.backtrace.join("\n")
      puts '-' * heading.length
      unless message.nil? || message.to_s.empty?
        puts message.to_s
        puts '-' * heading.length
      end

    end

    # -----

    def clear_app_defaults_cache
      @app_defaults_cache = nil
    end

    def get_app_defaults(dictionary, section = nil, raise_not_found = true)

      section = '0' if section.nil?
      section = section.to_s unless section.is_a?(String)
      cache_key = "#{dictionary}_#{section}"

      unless @app_defaults_cache && @app_defaults_cache.has_key?(cache_key)

        file_path = File.join(PLUGIN_DIR, 'json', 'defaults', "#{dictionary}.json")
        begin
          file = File.open(file_path)
          data = JSON.load(file)
          file.close
        rescue => e
          raise "Error loading defaults file (file='#{file_path}') : #{e.message}."
        end

        model_unit_is_metric = DimensionUtils.model_unit_is_metric

        defaults = {}
        if data.has_key?(section)
          data = data[section]
          data.each do |key, value|
            if value.is_a?(Hash)
              if model_unit_is_metric
                value = value['metric'] if value.has_key?('metric')
              else
                value = value['imperial'] if value.has_key?('imperial')
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
      begin
        Sketchup.read_default(section, key, default_value)
      rescue => e
        return default_value
      end
    end

    # -----

    @global_presets_cache = nil

    def _process_preset_values_with_app_defaults(dictionary, section, values, is_global)

      # Try to synchronize values with app defaults
      begin
        app_defaults = get_app_defaults(dictionary, section)
        storages = get_app_defaults(dictionary, '_storages', false)
        preprocessors = get_app_defaults(dictionary, '_preprocessors', false)
        processed_values = {}
        values.keys.each do |key|

          storage = storages.has_key?(key) ? storages[key] : PRESETS_STORAGE_ALL

          if app_defaults.has_key?(key) && # Only if exists in app defaults
              (storage == PRESETS_STORAGE_ALL ||
              (is_global && storage == PRESETS_STORAGE_GLOBAL_ONLY) ||
              (!is_global && storage == PRESETS_STORAGE_MODEL_ONLY))

            case preprocessors[key]
            when PRESETS_PREPROCESSOR_D
              processed_values[key] = DimensionUtils.d_add_units(values[key])
            when PRESETS_PREPROCESSOR_D_NEGATIVE_ALLOWED
              negative = values[key].is_a?(String) && values[key].start_with?('-')
              processed_value = DimensionUtils.d_add_units(negative ? values[key][1..-1] : values[key])
              processed_values[key] = "#{'-' if negative && processed_value != '0'}#{processed_value}"
            when PRESETS_PREPROCESSOR_DXQ
              processed_values[key] = DimensionUtils.dxq_add_units(values[key])
            when PRESETS_PREPROCESSOR_DXD
              processed_values[key] = DimensionUtils.dxd_add_units(values[key])
            when PRESETS_PREPROCESSOR_DXDXQ
              processed_values[key] = DimensionUtils.dxdxq_add_units(values[key])
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

    def _merge_preset_values_with_defaults(dictionary, values, default_values)
      merged_values = {}
      contains_default_values = false
      if default_values
        default_values.keys.each do |key|
          if values.has_key?(key)

            cleaners = get_app_defaults(dictionary, '_cleaners', false)
            case cleaners[key]
              when PRESETS_CLEANER_ORDER_STRATEGY

                if values[key] != default_values[key]

                  if values[key].is_a?(String)  # Values must be a string else use default

                    # Remove properties that doesn't exist in default
                    # Add properties that exist in default, but not in model
                    # Use prior custom values

                    h_custom_properties = values[key].split('>').map { |v| [v.delete('-'), v] }.to_h # { 'length' => '-length', ... }
                    h_default_properties = default_values[key].split('>').map { |v| [v.delete('-'), v] }.to_h # { 'length' => '-length', ... }

                    sorters = []

                    # Remove old properties
                    h_custom_properties.each { |property, sorter|
                      next unless h_default_properties.has_key?(property) && !sorter.nil?
                      sorters.push(sorter)
                      h_default_properties.delete(property)
                    }

                    # Append new properties
                    h_default_properties.each { |property, sorter|
                      sorters.push(sorter)
                    }

                    merged_values[key] = sorters.join('>')

                  else
                    merged_values[key] = default_values[key]
                  end

                else
                  merged_values[key] = values[key]
                end

            else
              merged_values[key] = values[key]
            end

          else
            merged_values[key] = default_values[key]
            contains_default_values = true
          end
        end
      else
        merged_values = values
      end
      [ merged_values, contains_default_values ]
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

    def get_global_presets
      read_global_presets if @global_presets_cache.nil?
      @global_presets_cache
    end

    def set_global_preset(dictionary, values, name = nil, section = nil, fire_event = false)

      name = PRESETS_DEFAULT_NAME if name.nil?
      name = name.to_s unless name.is_a?(String)
      section = '0' if section.nil?
      section = section.to_s unless section.is_a?(String)

      # Read global presets cache if not previously cached
      read_global_presets if @global_presets_cache.nil?

      # Create preset tree if it doesn't exist
      @global_presets_cache[dictionary] = {} unless @global_presets_cache.has_key?(dictionary)
      @global_presets_cache[dictionary][section] = {} unless @global_presets_cache[dictionary].has_key?(section)

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
      PluginObserver.instance.onGlobalPresetChanged(dictionary, section) if fire_event

    end

    def get_global_preset(dictionary, name = nil, section = nil)
      values, contains_default_values = get_global_preset_context(dictionary, name, section)
      values
    end

    def get_global_preset_context(dictionary, name = nil, section = nil)

      name = PRESETS_DEFAULT_NAME if name.nil?
      name = name.to_s unless name.is_a?(String)
      section = '0' if section.nil?
      section = section.to_s unless section.is_a?(String)

      # Read global presets cache if not previously cached
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
        values, contains_default_values = _merge_preset_values_with_defaults(dictionary, @global_presets_cache[dictionary][section][name], default_values)

      else

        # Preset doesn't exists, return default_values
        values = default_values.clone
        contains_default_values = true

      end
      [ values, contains_default_values ]
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
      section = section.to_s unless section.is_a?(String)
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

    @model_presets_cache = nil

    def clear_model_presets_cache
      @model_presets_cache = nil
    end

    def read_model_presets
      @model_presets_cache = Sketchup.active_model ? get_attribute(Sketchup.active_model, PRESETS_KEY, {}) : {}
    end

    def write_model_presets
      return unless Sketchup.active_model

      # Start model modification operation
      Sketchup.active_model.start_operation('OCL Write Model Presets', true, false, true)

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
      section = section.to_s unless section.is_a?(String)
      app_defaults_section = '0' if app_defaults_section.nil?

      # Read model presets cache if not previously cached
      read_model_presets if @model_presets_cache.nil?

      # Create preset tree if it doesn't exist
      @model_presets_cache[dictionary] = {} unless @model_presets_cache.has_key?(dictionary)
      @model_presets_cache[dictionary][section] = {} unless @model_presets_cache[dictionary].has_key?(section)

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
      PluginObserver.instance.onModelPresetChanged(dictionary, section) if fire_event

    end

    def get_model_preset(dictionary, section = nil, app_defaults_section = nil)
      values, contains_default_values = get_model_preset_context(dictionary, section, app_defaults_section)
      values
    end

    def get_model_preset_context(dictionary, section = nil, app_defaults_section = nil)

      section = '0' if section.nil?
      section = section.to_s unless section.is_a?(String)
      app_defaults_section = '0' if app_defaults_section.nil?

      # Read model presets cache if not previously cached
      read_model_presets if @model_presets_cache.nil?

      default_values = get_global_preset(dictionary, nil, app_defaults_section)
      if @model_presets_cache.has_key?(dictionary) && @model_presets_cache[dictionary].has_key?(section)

        # Preset exists, synchronize returned values with default_values data and structure
        values, contains_default_values = _merge_preset_values_with_defaults(dictionary, @model_presets_cache[dictionary][section], default_values)

      else

        # Preset doesn't exists, return default_values
        values = default_values.clone
        contains_default_values = true

      end
      [ values, contains_default_values ]
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

    def register_command(command, &block)
      @commands[command] = block
    end

    def execute_command(command, params = nil)
      start unless @started
      if @commands.has_key?(command)
        block = @commands[command]
        return block.call(params.is_a?(Hash) ? HashUtils.symbolize_keys(params) : params) # params keys are symbolized to be ready for using as "keyword arguments"
      end
      raise "Command '#{command}' not found"
    end

    # -----

    def add_event_callback(event, &block)
      if event.is_a?(Array)
        events = event
      else
        events = [ event ]
      end
      events.each do |e|
        unless @event_callbacks.has_key?(e)
          @event_callbacks[e] = []
        end
        @event_callbacks[e].push(block)
      end
      block
    end

    def remove_event_callback(event, block)
      if event.is_a?(Array)
        events = event
      else
        events = [ event ]
      end
      events.each do |e|
        next unless @event_callbacks.has_key?(e)
        @event_callbacks[e].delete(block)
      end
    end

    def trigger_event(event, params = nil)
      if @event_callbacks.has_key?(event)
        blocks = @event_callbacks[event]
        blocks.each do |block|
          block.call(params)
        end
      end
      if @tabs_dialog
        @tabs_dialog.execute_script("triggerEvent('#{event}', '#{params.is_a?(Hash) ? Base64.strict_encode64(JSON.generate(params)) : ''}');")
      end
    end

    # -----

    def add_observer(observer)
      @observers << observer unless @observers.include?(observer)
    end

    def remove_observer(observer)
      @observers.delete(observer)
    end

    # -----

    def setup

      fn_get_selected_component_entity = lambda do
        entity = (Sketchup.active_model.nil? || Sketchup.active_model.selection.length > 1) ? nil : Sketchup.active_model.selection.first
        return entity if entity.is_a?(Sketchup::ComponentInstance)
        nil
      end

      fn_edit_part_properties = lambda do |entity, tab = 'general'|
        unless entity.nil?
          execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: null, part_serialized_path: '#{PathUtils.serialize_path(Sketchup.active_model.active_path.nil? ? [ entity ] : Sketchup.active_model.active_path + [ entity ])}', tab: '#{tab}' }")
        end
      end

      # Setup Menu
      menu = UI.menu
      submenu = menu.add_submenu(get_i18n_string('core.menu.submenu'))
      submenu.add_item(get_i18n_string('tab.materials.title')) {
        show_tabs_dialog('materials')
      }
      submenu.add_item(get_i18n_string('tab.cutlist.title')) {
        show_tabs_dialog('cutlist')
      }
      submenu.add_item(get_i18n_string('tab.outliner.title')) {
        show_tabs_dialog('outliner')
      }
      submenu.add_item(get_i18n_string('tab.importer.title')) {
        show_tabs_dialog('importer')
      }
      submenu.add_separator
      submenu.add_item(get_i18n_string('core.menu.item.generate_cutlist')) {
        execute_tabs_dialog_command_on_tab('cutlist', 'generate_cutlist')
      }
      submenu.add_separator
      edit_part_item = submenu.add_item(get_i18n_string('core.menu.item.edit_part_properties')) {
        fn_edit_part_properties.call(fn_get_selected_component_entity.call)
      }
      menu.set_validation_proc(edit_part_item) {
        fn_get_selected_component_entity.call.nil? ? MF_GRAYED : MF_ENABLED
      }
      edit_part_axes_item = submenu.add_item(get_i18n_string('core.menu.item.edit_part_axes_properties')) {
        fn_edit_part_properties.call(fn_get_selected_component_entity.call, 'axes')
      }
      menu.set_validation_proc(edit_part_axes_item) {
        fn_get_selected_component_entity.call.nil? ? MF_GRAYED : MF_ENABLED
      }
      submenu.add_separator
      %w[draw handle paint axes export].each do |stripped_name|

        clazz = Object.const_get("Ladb::OpenCutList::Smart#{stripped_name.capitalize}Tool")

        smart_tool_submenu = submenu.add_submenu(get_i18n_string("core.menu.item.smart_#{stripped_name}"))
        smart_tool_submenu.add_item(get_i18n_string("core.menu.item.smart_#{stripped_name}")) {
          Sketchup.active_model.select_tool(clazz.new) if Sketchup.active_model
        }
        smart_tool_submenu.add_separator
        clazz::ACTIONS.each do |action_def|
          smart_tool_submenu.add_item(get_i18n_string("tool.smart_#{stripped_name}.action_#{action_def[:action]}")) {
            Sketchup.active_model.select_tool(clazz.new(current_action: action_def[:action])) if Sketchup.active_model
          }
        end

      end
      submenu.add_separator
      submenu.add_item(get_i18n_string('core.menu.item.reset_dialog_position')) {
        tabs_dialog_reset_position
      }

      # Setup Context Menu
      UI.add_context_menu_handler do |context_menu|
        unless (entity = fn_get_selected_component_entity.call).nil?

          context_menu.add_separator
          submenu = context_menu.add_submenu(get_i18n_string('core.menu.submenu'))

          # Edit part item
          submenu.add_item(get_i18n_string('core.menu.item.edit_part_properties')) {
            fn_edit_part_properties.call(entity)
          }
          submenu.add_item(get_i18n_string('core.menu.item.edit_part_axes_properties')) {
            fn_edit_part_properties.call(entity, 'axes')
          }

        end
      end

      # Setup Main Toolbar
      toolbar = UI::Toolbar.new(get_i18n_string('core.toolbar.name'))

      cmd = UI::Command.new(get_i18n_string('core.toolbar.command.dialog')) {
        toggle_tabs_dialog
      }
      cmd.small_icon = '../img/icon-dialog-72x72.png'
      cmd.large_icon = '../img/icon-dialog-114x114.png'
      cmd.tooltip = get_i18n_string('core.toolbar.command.dialog')
      cmd.status_bar_text = get_i18n_string('core.toolbar.command.dialog')
      cmd.menu_text = get_i18n_string('core.toolbar.command.dialog')
      toolbar = toolbar.add_item(cmd)

      toolbar.restore

      # Setup Tools Toolbar
      toolbar = UI::Toolbar.new(get_i18n_string('core.toolbar.name') + " - " + get_i18n_string('core.toolbar.tools'))

      cmd = UI::Command.new(get_i18n_string('core.toolbar.command.smart_draw')) {
        if Sketchup.active_model
          if Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartDrawTool)
            Sketchup.active_model.select_tool(nil)
          else
            Sketchup.active_model.select_tool(SmartDrawTool.new)
          end
          Sketchup.focus if Sketchup.respond_to?(:focus)
        end
      }
      cmd.small_icon = '../img/icon-smart-draw-72x72.png'
      cmd.large_icon = '../img/icon-smart-draw-114x114.png'
      cmd.tooltip = get_i18n_string('core.toolbar.command.smart_draw')
      cmd.status_bar_text = get_i18n_string('core.toolbar.command.smart_draw')
      cmd.menu_text = get_i18n_string('core.toolbar.command.smart_draw')
      cmd.set_validation_proc {
        Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartDrawTool) ? MF_CHECKED : MF_UNCHECKED
      }
      toolbar = toolbar.add_item(cmd)

      cmd = UI::Command.new(get_i18n_string('core.toolbar.command.smart_handle')) {
        if Sketchup.active_model
          if Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartHandleTool)
            Sketchup.active_model.select_tool(nil)
          else
            Sketchup.active_model.select_tool(SmartHandleTool.new)
          end
          Sketchup.focus if Sketchup.respond_to?(:focus)
        end
      }
      cmd.small_icon = '../img/icon-smart-handle-72x72.png'
      cmd.large_icon = '../img/icon-smart-handle-114x114.png'
      cmd.tooltip = get_i18n_string('core.toolbar.command.smart_handle')
      cmd.status_bar_text = get_i18n_string('core.toolbar.command.smart_handle')
      cmd.menu_text = get_i18n_string('core.toolbar.command.smart_handle')
      cmd.set_validation_proc {
        Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartHandleTool) ? MF_CHECKED : MF_UNCHECKED
      }
      toolbar = toolbar.add_item(cmd)

      cmd = UI::Command.new(get_i18n_string('core.toolbar.command.smart_paint')) {
        if Sketchup.active_model
          if Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartPaintTool)
            Sketchup.active_model.select_tool(nil)
          else
            Sketchup.active_model.select_tool(SmartPaintTool.new)
          end
          Sketchup.focus if Sketchup.respond_to?(:focus)
        end
      }
      cmd.small_icon = '../img/icon-smart-paint-72x72.png'
      cmd.large_icon = '../img/icon-smart-paint-114x114.png'
      cmd.tooltip = get_i18n_string('core.toolbar.command.smart_paint')
      cmd.status_bar_text = get_i18n_string('core.toolbar.command.smart_paint')
      cmd.menu_text = get_i18n_string('core.toolbar.command.smart_paint')
      cmd.set_validation_proc {
        Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartPaintTool) ? MF_CHECKED : MF_UNCHECKED
      }
      toolbar = toolbar.add_item(cmd)

      cmd = UI::Command.new(get_i18n_string('core.toolbar.command.smart_axes')) {
        if Sketchup.active_model
          if Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartAxesTool)
            Sketchup.active_model.select_tool(nil)
          else
            Sketchup.active_model.select_tool(SmartAxesTool.new)
          end
          Sketchup.focus if Sketchup.respond_to?(:focus)
        end
      }
      cmd.small_icon = '../img/icon-smart-axes-72x72.png'
      cmd.large_icon = '../img/icon-smart-axes-114x114.png'
      cmd.tooltip = get_i18n_string('core.toolbar.command.smart_axes')
      cmd.status_bar_text = get_i18n_string('core.toolbar.command.smart_axes')
      cmd.menu_text = get_i18n_string('core.toolbar.command.smart_axes')
      cmd.set_validation_proc {
        Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartAxesTool) ? MF_CHECKED : MF_UNCHECKED
      }
      toolbar = toolbar.add_item(cmd)

      # cmd = UI::Command.new(get_i18n_string('core.toolbar.command.smart_axes') + '_2') {
      #   if Sketchup.active_model
      #     if Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartAxesToolNew)
      #       Sketchup.active_model.select_tool(nil)
      #     else
      #       Sketchup.active_model.select_tool(SmartAxesToolNew.new)
      #     end
      #     Sketchup.focus if Sketchup.respond_to?(:focus)
      #   end
      # }
      # cmd.small_icon = '../img/icon-dialog-72x72.png'
      # cmd.large_icon = '../img/icon-dialog-114x114.png'
      # cmd.tooltip = get_i18n_string('core.toolbar.command.smart_axes')
      # cmd.status_bar_text = get_i18n_string('core.toolbar.command.smart_axes')
      # cmd.menu_text = get_i18n_string('core.toolbar.command.smart_axes')
      # cmd.set_validation_proc {
      #   Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartAxesToolNew) ? MF_CHECKED : MF_UNCHECKED
      # }
      # toolbar = toolbar.add_item(cmd)

      cmd = UI::Command.new(get_i18n_string('core.toolbar.command.smart_export')) {
        if Sketchup.active_model
          if Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartExportTool)
            Sketchup.active_model.select_tool(nil)
          else
            Sketchup.active_model.select_tool(SmartExportTool.new)
          end
          Sketchup.focus if Sketchup.respond_to?(:focus)
        end
      }
      cmd.small_icon = '../img/icon-smart-export-72x72.png'
      cmd.large_icon = '../img/icon-smart-export-114x114.png'
      cmd.tooltip = get_i18n_string('core.toolbar.command.smart_export')
      cmd.status_bar_text = get_i18n_string('core.toolbar.command.smart_export')
      cmd.menu_text = get_i18n_string('core.toolbar.command.smart_export')
      cmd.set_validation_proc {
        Sketchup.active_model.tools.respond_to?(:active_tool) && Sketchup.active_model.tools.active_tool.is_a?(SmartExportTool) ? MF_CHECKED : MF_UNCHECKED
      }
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

        add_observer(PluginObserver.instance)
        Sketchup.add_observer(AppObserver.instance)

        # -- Controllers --

        @controllers.push(MaterialsController.new)
        @controllers.push(CutlistController.new)
        @controllers.push(OutlinerController.new)
        @controllers.push(ImporterController.new)
        @controllers.push(SettingsController.new)

        # -- Commands --

        register_command('core_set_update_status') do |params|
          set_update_status_command(**params)
        end
        register_command('core_set_news_status') do |params|
          set_news_status_command(**params)
        end
        register_command('core_upgrade') do |params|
          upgrade_command(**params)
        end
        register_command('core_get_app_defaults') do |params|
          get_app_defaults_command(**params)
        end
        register_command('core_set_global_preset') do |params|
          set_global_preset_command(**params)
        end
        register_command('core_get_global_preset') do |params|
          get_global_preset_command(**params)
        end
        register_command('core_list_global_preset_names') do |params|
          list_global_preset_names_command(**params)
        end
        register_command('core_set_model_preset') do |params|
          set_model_preset_command(**params)
        end
        register_command('core_get_model_preset') do |params|
          get_model_preset_command(**params)
        end
        register_command('core_read_settings') do |params|
          read_settings_command(**params)
        end
        register_command('core_write_settings') do |params|
          write_settings_command(**params)
        end
        register_command('core_dialog_loaded') do |params|
          dialog_loaded_command(**params)
        end
        register_command('core_dialog_ready') do |params|
          dialog_ready_command
        end
        register_command('core_tabs_dialog_minimize') do |params|
          tabs_dialog_minimize_command
        end
        register_command('core_tabs_dialog_maximize') do |params|
          tabs_dialog_maximize_command
        end
        register_command('core_tabs_dialog_hide') do |params|
          tabs_dialog_hide_command
        end
        register_command('core_modal_dialog_hide') do |params|
          modal_dialog_hide_command
        end
        register_command('core_open_external_file') do |params|
          open_external_file_command(**params)
        end
        register_command('core_open_url') do |params|
          open_url_command(**params)
        end
        register_command('core_zoom_extents') do |params|
          zoom_extents_command
        end
        register_command('core_play_sound') do |params|
          play_sound_command(**params)
        end
        register_command('core_send_action') do |params|
          send_action_command(**params)
        end
        register_command('core_length_to_float') do |params|
          length_to_float_command(params)
        end
        register_command('core_float_to_length') do |params|
          float_to_length_command(params)
        end
        register_command('core_compute_size_aspect_ratio') do |params|
          compute_size_aspect_ratio_command(**params)
        end
        register_command('core_copy_to_clipboard') do |params|
          copy_to_clipboard_command(**params)
        end
        register_command('core_unload_c_lib') do |params|
          unload_c_lib_command(**params)
        end

        @controllers.each { |controller|
          controller.setup_commands
          controller.setup_event_callbacks
        }

        @started = true

      end

    end

    # -- Dialogs --

    def create_tabs_dialog

      # Start
      start

      # Create dialog instance
      @tabs_dialog = UI::HtmlDialog.new(
          {
              :dialog_title => get_i18n_string('core.dialog.title') + ' - ' + EXTENSION_VERSION + (IS_DEV ? " ( build: #{EXTENSION_BUILD} )" : ''),
              :preferences_key => TABS_DIALOG_PREF_KEY,
              :scrollable => true,
              :resizable => true,
              :width => TABS_DIALOG_MINIMIZED_WIDTH,
              :height => TABS_DIALOG_MINIMIZED_HEIGHT,
              :left => @tabs_dialog_left,
              :top => @tabs_dialog_top,
              :min_width => TABS_DIALOG_MINIMIZED_WIDTH,
              :min_height => TABS_DIALOG_MINIMIZED_HEIGHT,
              :style => UI::HtmlDialog::STYLE_DIALOG
          })
      @tabs_dialog.set_on_closed {
        @tabs_dialog = nil
        @tabs_dialog_maximized = false
        trigger_event('on_tags_dialog_close', {})
      }
      @tabs_dialog.set_can_close {
        tabs_dialog_store_current_position
        tabs_dialog_store_current_size
        true
      }

      # Setup dialog page
      @tabs_dialog.set_file(File.join(PLUGIN_DIR, 'html', "dialog-tabs-#{language}.html"))

      # Setup dialog actions
      @tabs_dialog.add_action_callback('ladb_opencutlist_setup_dialog_context') do |action_context, call_json|
        @tabs_dialog.execute_script("setDialogContext('tabs');")
      end
      @tabs_dialog.add_action_callback('ladb_opencutlist_command') do |action_context, call_json|
        call = JSON.parse(call_json)
        response = execute_command(call['command'], call['params'])
        script = "rubyCommandCallback(#{call['id']}, '#{response.is_a?(Hash) ? Base64.strict_encode64(JSON.generate(response)) : ''}');"
        @tabs_dialog.execute_script(script) if @tabs_dialog
      end

    end

    def show_tabs_dialog(tab_name = nil, auto_create = true, &ready_block)

      return if @tabs_dialog.nil? && !auto_create

      create_tabs_dialog unless @tabs_dialog

      if @tabs_dialog.visible?

        if tab_name
          # Startup tab name is defined call JS to select it
          @tabs_dialog.bring_to_front
          @tabs_dialog.execute_script("$('body').ladbDialogTabs('selectTab', '#{tab_name}');")
        end

        if ready_block
          # Immediately invoke the ready block
          ready_block.call
        end

      else

        # Store the startup tab name
        @tabs_dialog_startup_tab_name = tab_name

        # Store the ready block
        @dialog_ready_block = ready_block

        # Show dialog
        @tabs_dialog.show

        # Set dialog size and position (those functions must be called after `show` call to have a coherent position on Windows)
        tabs_dialog_set_size(TABS_DIALOG_MINIMIZED_WIDTH, TABS_DIALOG_MINIMIZED_HEIGHT)
        tabs_dialog_set_position(@tabs_dialog_left, @tabs_dialog_top)

      end

    end

    def hide_tabs_dialog
      if @tabs_dialog
        @tabs_dialog.close
        return true
      end
      false
    end

    def toggle_tabs_dialog
      show_tabs_dialog unless hide_tabs_dialog
    end

    def tabs_dialog_reset_position
      @tabs_dialog_left = TABS_DIALOG_DEFAULT_LEFT
      @tabs_dialog_top = TABS_DIALOG_DEFAULT_TOP
      tabs_dialog_store_position(@tabs_dialog_left, @tabs_dialog_top)
      if @tabs_dialog
        tabs_dialog_set_position(@tabs_dialog_left, @tabs_dialog_top)
      else
        show_tabs_dialog
      end
    end

    def tabs_dialog_store_size(width, height)
      @tabs_dialog_maximized_width = [ width, TABS_DIALOG_DEFAULT_MAXIMIZED_WIDTH ].max
      @tabs_dialog_maximized_height = [ height, TABS_DIALOG_DEFAULT_MAXIMIZED_HEIGHT ].max
      write_default(SETTINGS_KEY_DIALOG_MAXIMIZED_WIDTH, width)
      write_default(SETTINGS_KEY_DIALOG_MAXIMIZED_HEIGHT, height)
    end

    def tabs_dialog_store_current_size
      if @tabs_dialog && @tabs_dialog.respond_to?(:get_size) && @tabs_dialog_maximized
        width, height = @tabs_dialog.get_size
        return if width.nil? || height.nil?
        tabs_dialog_store_size(width, height) if width >= TABS_DIALOG_MINIMIZED_WIDTH && height >= TABS_DIALOG_MINIMIZED_HEIGHT
      end
    end

    def tabs_dialog_set_size(width, height)
      @tabs_dialog.set_size(width, height) if @tabs_dialog
    end

    def tabs_dialog_inc_maximized_size(inc_width = 0, inc_height = 0)
      tabs_dialog_store_size(@tabs_dialog_maximized_width + inc_width, @tabs_dialog_maximized_height + inc_height)
      tabs_dialog_set_size(@tabs_dialog_maximized_width, @tabs_dialog_maximized_height) if @tabs_dialog_maximized
    end

    def tabs_dialog_store_position(left, top)
      @tabs_dialog_left = left
      @tabs_dialog_top = top
      write_default(SETTINGS_KEY_DIALOG_LEFT, left)
      write_default(SETTINGS_KEY_DIALOG_TOP, top)
    end

    def tabs_dialog_store_current_position
      if @tabs_dialog && @tabs_dialog.respond_to?(:get_position)
        if @tabs_dialog.respond_to?(:get_size)
          width, height = @tabs_dialog.get_size
          return if width.nil? || height.nil?
          return if width < TABS_DIALOG_MINIMIZED_WIDTH || height < TABS_DIALOG_MINIMIZED_HEIGHT  # Do not store the position if dialog size is smaller than minimized size
        end
        left, top = @tabs_dialog.get_position
        tabs_dialog_store_position(left, top) if left > 0 && top > 0
      end
    end

    def tabs_dialog_set_position(left, top)
      @tabs_dialog.set_position(left, top) if @tabs_dialog
    end

    def tabs_dialog_inc_position(inc_left = 0, inc_top = 0)
      tabs_dialog_store_position(@tabs_dialog_left + inc_left, @tabs_dialog_top + inc_top)
      tabs_dialog_set_position(@tabs_dialog_left, @tabs_dialog_top)
    end

    def tabs_dialog_set_print_margin(print_margin, persist = false)
      @tabs_dialog_print_margin = print_margin
      write_default(SETTINGS_KEY_DIALOG_PRINT_MARGIN, print_margin) if persist
    end

    def tabs_dialog_set_table_row_size(table_row_size, persist = false)
      @tabs_dialog_table_row_size = table_row_size
      write_default(SETTINGS_KEY_DIALOG_TABLE_ROW_SIZE, table_row_size) if persist
    end

    def execute_tabs_dialog_command_on_tab(tab_name, command, parameters = nil, callback = nil)

      show_tabs_dialog(nil, true) do
        # parameters and callback must be formatted as JS code
        if tab_name and command
          @tabs_dialog.bring_to_front
          @tabs_dialog.execute_script("$('body').ladbDialogTabs('executeCommandOnTab', [ '#{tab_name}', '#{command}', #{parameters}, #{callback} ]);")
        end
      end

    end

    def create_modal_dialog(modal_name, params = nil)

      # Start
      start

      @modal_dialog = UI::HtmlDialog.new(
        {
          :dialog_title => ' ',
          :preferences_key => MODAL_DIALOG_PREF_KEY,
          :scrollable => true,
          :resizable => true,
          :width => MODAL_DIALOG_DEFAULT_WIDTH,
          :height => MODAL_DIALOG_DEFAULT_HEIGHT,
          :min_width => MODAL_DIALOG_DEFAULT_WIDTH,
          :min_height => MODAL_DIALOG_DEFAULT_HEIGHT,
          :style => UI::HtmlDialog::STYLE_UTILITY
        }
      )
      @modal_dialog.set_on_closed {
        @modal_dialog = nil
      }

      # Setup dialog page
      @modal_dialog.set_file(File.join(PLUGIN_DIR, 'html', "dialog-modal-#{language}.html"))

      # Setup dialog actions
      @modal_dialog.add_action_callback('ladb_opencutlist_setup_dialog_context') do |action_context, call_json|
        @modal_dialog.execute_script("setDialogContext('modal', '#{Base64.strict_encode64(JSON.generate({ :startup_modal_name => modal_name, :params => params }))}');")
      end
      @modal_dialog.add_action_callback('ladb_opencutlist_command') do |action_context, call_json|
        call = JSON.parse(call_json)
        response = execute_command(call['command'], call['params'])
        script = "rubyCommandCallback(#{call['id']}, '#{response.is_a?(Hash) ? Base64.strict_encode64(JSON.generate(response)) : ''}');"
        @modal_dialog.execute_script(script) if @modal_dialog
      end

    end

    def show_modal_dialog(modal_name = nil, params = nil)

      unless @modal_dialog
        create_modal_dialog(modal_name, params)
      end

      unless @modal_dialog.visible?

        # Show dialog
        @modal_dialog.show
        @modal_dialog.center

      end

    end

    def hide_modal_dialog
      if @modal_dialog
        @modal_dialog.close
        true
      else
        false
      end
    end

    def toggle_modal_dialog
      unless hide_modal_dialog
        show_modal_dialog
      end
    end

    # -- Devtool ---

    def devtool(tool)
      case tool
      when 'webgl_report'
        dialog = UI::HtmlDialog.new({
                                      :min_width => 500,
                                      :min_height => 500,
                                      :style => UI::HtmlDialog::STYLE_DIALOG
                                    })
        dialog.set_url('https://webglreport.com/')
        dialog.center
        dialog.show
      else
        UI.messagebox("Unknow DevTool #{tool}")
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

    # -- Commands ---

    def set_update_status_command(manifest:, update_available:, update_muted:)    # Expected params = { manifest: MANIFEST, update_available: BOOL, update_muted: BOOL }
      @manifest = manifest
      @update_available = update_available
      @update_muted = update_muted
    end

    def set_news_status_command(last_news_timestamp:)    # Expected params = { last_news_timestamp: TIMESTAMP }
      @last_news_timestamp = last_news_timestamp
    end

    def upgrade_command(url:)    # Expected params = { url: 'RBZ_URL' }
      # Just open URL for older Sketchup versions
      if Sketchup.version_number < 1700000000
        open_url_command(url)
        return { :cancelled => true }
      end

      # Download the RBZ
      begin

        # URLs with spaces will raise an InvalidURIError, so we need to encode spaces.
        url = URI::DEFAULT_PARSER.escape(url)

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
            Dir.mkdir(downloads_dir) unless Dir.exist?(downloads_dir)
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
              hide_tabs_dialog

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

    def get_app_defaults_command(dictionary:, section: nil) # Expected params = { dictionary: DICTIONARY, section: SECTION }
      { :defaults => get_app_defaults(dictionary, section) }
    end

    def set_global_preset_command(dictionary:, values:, name: nil, section: nil, fire_event: false) # Expected params = { dictionary: DICTIONARY, values: VALUES, name: NAME, section: SECTION }
      set_global_preset(dictionary, values, name, section, fire_event)
    end

    def get_global_preset_command(dictionary:, name: nil, section: nil) # Expected params = { dictionary: DICTIONARY, name: NAME, section: SECTION }
      { :preset => get_global_preset(dictionary, name, section) }
    end

    def list_global_preset_names_command(dictionary:, section: nil) # Expected params = { dictionary: DICTIONARY, section: SECTION }
      { :names => list_global_preset_names(dictionary, section) }
    end

    def set_model_preset_command(dictionary:, values:, section: nil, app_default_section: nil, fire_event: false) # Expected params = { dictionary: DICTIONARY, values: VALUES, section: SECTION, app_default_section: APP_DEFAULT_SECTION }
      set_model_preset(dictionary, values, section, app_default_section, fire_event)
    end

    def get_model_preset_command(dictionary:, section: nil, app_default_section: nil) # Expected params = { dictionary: DICTIONARY, section: SECTION, app_default_section: APP_DEFAULT_SECTION }
      { :preset => get_model_preset(dictionary, section, app_default_section) }
    end

    def read_settings_command(keys:)    # Expected params = { keys: [ 'key1', ... ] }
      values = []
      keys.each { |key|

        value = read_default(key)

        if value.is_a?(String)
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

    def write_settings_command(settings:)    # Expected params = { settings: [ { key => 'key1', value => 'value1' }, ... ] }
      return unless settings.is_a?(Array)

      settings.each { |setting|

        key = setting['key']
        value = setting['value']
        value = value.gsub(/["]/, '\"') if value.is_a?(String)       # escape double quote in string

        write_default(key, value)

      }
    end

    def dialog_loaded_command(webgl_available:, dialog_type:, dialog_params:)

      @webgl_available = webgl_available == true

      base_capabilities = {
          :version => EXTENSION_VERSION,
          :build => EXTENSION_BUILD,
          :is_rbz => IS_RBZ,
          :is_dev => IS_DEV,
          :sketchup_is_pro => Sketchup.is_pro?,
          :sketchup_version => Sketchup.version,
          :sketchup_version_number => Sketchup.version_number,
          :ruby_version => RUBY_VERSION,
          :chrome_version => defined?(UI::HtmlDialog::CHROME_VERSION) ? UI::HtmlDialog::CHROME_VERSION : nil,
          :platform_name => platform_name,
          :is_64bit => Sketchup.respond_to?(:is_64bit?) && Sketchup.is_64bit?,
          :locale => Sketchup.get_locale,
          :language => PLUGIN.language,
          :available_languages => PLUGIN.get_available_languages,
          :decimal_separator => DimensionUtils.decimal_separator,
      }

      case dialog_type
      when 'tabs'
        return base_capabilities.merge(
          {
            :manifest => @manifest,
            :update_available => @update_available,
            :update_muted => @update_muted,
            :last_news_timestamp => @last_news_timestamp,
            :tabs_dialog_print_margin => @tabs_dialog_print_margin,
            :tabs_dialog_table_row_size => @tabs_dialog_table_row_size,
            :tabs_dialog_startup_tab_name => @tabs_dialog_startup_tab_name # nil if none
          }
        ).merge({
                  :webgl_available => webgl_available,
                  :dialog_type => dialog_type,
                  :dialog_params => dialog_params
                })
      when 'modal'
        return base_capabilities.merge({
                                         :webgl_available => webgl_available,
                                         :dialog_type => dialog_type,
                                         :dialog_params => dialog_params
                                       })
      end

    end

    def dialog_ready_command
      if @dialog_ready_block
        @dialog_ready_block.call
        @dialog_ready_block = nil
      end
    end

    def tabs_dialog_minimize_command
      if @tabs_dialog

        tabs_dialog_store_current_position
        tabs_dialog_store_current_size
        tabs_dialog_set_size(TABS_DIALOG_MINIMIZED_WIDTH, TABS_DIALOG_MINIMIZED_HEIGHT)
        @tabs_dialog_maximized = false

        # Focus SketchUp
        Sketchup.focus if Sketchup.respond_to?(:focus)

      end
    end

    def tabs_dialog_maximize_command
      if @tabs_dialog
        tabs_dialog_set_size(@tabs_dialog_maximized_width, @tabs_dialog_maximized_height)
        @tabs_dialog_maximized = true
      end
    end

    def tabs_dialog_hide_command
      hide_tabs_dialog
    end

    def modal_dialog_hide_command
      hide_modal_dialog
    end

    def open_external_file_command(path:)    # Expected params = { path: PATH_TO_FILE }
      return unless path.is_a?(String)
      url = "file:///#{path}"
      url = URI::DEFAULT_PARSER.escape(url) if platform_is_mac? && Sketchup.version_number >= 1800000000
      UI.openURL(url)
    end

    def open_url_command(url:)    # Expected params = { url: URL }
      return unless url.is_a?(String)
      url = 'https://' + url unless /^https?:\/\//.match(url)  # Force url starts by "https://"
      UI.openURL(URI::DEFAULT_PARSER.escape(url))
    end

    def zoom_extents_command
      if Sketchup.active_model
        Sketchup.active_model.active_view.zoom_extents
      end
    end

    def play_sound_command(filename:)    # Expected params = { filename: WAV_FILE_TO_PLAY }
      return unless filename.is_a?(String)
      UI.play_sound(File.join(PLUGIN_DIR, 'wav', filename))
    end

    def send_action_command(action:)

      # Send action
      success = Sketchup.send_action(action)

      {
          :success => success,
      }
    end

    def length_to_float_command(params)    # Expected params = { key_1: 'STRING_LENGTH', key_2: 'STRING_LENGTH', ... }
      float_lengths = {}
      params.each do |key, string_length|
        next unless string_length.is_a?(String)
        if string_length.index('x')
          # Convert string "size" to inch float array
          float_lengths[key] = string_length.split('x').map { |v| DimensionUtils.d_to_ifloats(v).to_l.to_f }
        else
          # Convert string length to inch float
          float_lengths[key] = DimensionUtils.d_to_ifloats(string_length).to_l.to_f
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

    def compute_size_aspect_ratio_command(width: '1m', height: '1m', ratio: 1, is_width_master: true)    # Expected params = { width: WIDTH, height: HEIGHT, ratio: W_ON_H_RATIO, is_width_master: BOOL }

      # Convert input values to Length
      w = DimensionUtils.d_to_ifloats(width).to_l
      h = DimensionUtils.d_to_ifloats(height).to_l

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

    def copy_to_clipboard_command(data: '')
      return { :success => false } if Sketchup.version_number < 2310000000

      success = UI.set_clipboard_data(data)

      {
        :success => success
      }
    end

    def unload_c_lib_command(lib:)
      return { :errors => [ "Error : lib param must be a string" ] } unless lib.is_a?(String)
      begin
        lib = lib.downcase
        require_relative "lib/fiddle/#{lib}/#{lib}"
        Fiddle.const_get(lib.capitalize).unload
      rescue Exception => e
        return { :errors => [ "Error unloading #{lib}: #{e.message}" ] }
      end
      { :success => true }
    end

  end

end