require 'fileutils'
require 'json'
require 'yaml'
require_relative 'observer/app_observer'
require_relative 'controller/cutlist_controller'
require_relative 'controller/materials_controller'

module Ladb
  module Toolbox
    class Plugin

      NAME = 'L\'Air du Bois - Woodworking Toolbox'
      VERSION = '1.4.0-dev'
      BUILD = '201803280830'

      DEFAULT_SECTION = DEFAULT_DICTIONARY = 'ladb_toolbox'

      SETTINGS_RW_STRATEGY_GLOBAL = 0               # Read/Write settings from/to global Sketchup defaults
      SETTINGS_RW_STRATEGY_GLOBAL_MODEL = 1         # Read/Write settings from/to global Sketchup defaults and (if undefined from)/to active model attributes
      SETTINGS_RW_STRATEGY_MODEL = 2                # Read/Write settings from/to active model attributes
      SETTINGS_RW_STRATEGY_MODEL_GLOBAL = 3         # Read/Write settings from/to active model attributes and (if undefined from)/to global Sketchup defaults

      DIALOG_MAXIMIZED_WIDTH = 1100
      DIALOG_MAXIMIZED_HEIGHT = 800
      DIALOG_MINIMIZED_WIDTH = 90
      DIALOG_MINIMIZED_HEIGHT = 30 + 80 + 80 * 2    # = 2 Tab buttons
      DIALOG_LEFT = 100
      DIALOG_TOP = 100
      DIALOG_PREF_KEY = 'fr.lairdubois.toolbox'

      attr_accessor :dialog, :current_os

      @commands
      @controllers
      @current_os
      @language
      @html_dialog_compatible
      @dialog_min_size
      @started
      @temp_dir

      def initialize()
        @commands = {}
        @controllers = []
        @current_os = :OTHER
        @language = nil
        @html_dialog_compatible = false
        @dialog_min_size = { :width => DIALOG_MINIMIZED_WIDTH, :height => DIALOG_MINIMIZED_HEIGHT }
        @started = false
        @temp_dir = nil
      end

      # -----

      def temp_dir
        if @temp_dir
          return @temp_dir
        end
        dir = File.join(Sketchup.temp_dir, "ladb_toolbox")
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
        available_translations = []
        Dir["#{__dir__}/../yaml/i18n/*.yml"].each { |file|
          available_translations.push(File.basename(file, File.extname(file)))
        }
        language = Sketchup.get_locale.split('-')[0].downcase
        if available_translations.include? language
          @language = language   # Uses SU locale only if translation is available
        else
          @language = 'en'
        end
        @language
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

      def start

        # To minimize plugin initialization, start setup is called only once
        unless @started

          # -- Check --

          # Fetch OS
          @current_os = (Object::RUBY_PLATFORM =~ /mswin/i || Object::RUBY_PLATFORM =~ /mingw/i) ? :WIN : ((Object::RUBY_PLATFORM =~ /darwin/i) ? :MAC : :OTHER)

          # Determine current language
          language

          # Check compatibility (If we can we use the HtmlDialog class - new in Sketchup 2017)
          @html_dialog_compatible = true
          begin
            Object.const_defined?('UI::HtmlDialog')
          rescue NameError
            @html_dialog_compatible = false
          end

          # -- Observers --

          Sketchup.add_observer(AppObserver.new(self))

          # -- Controllers --

          @controllers.push(CutlistController.new(self))
          @controllers.push(MaterialsController.new(self))

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
          register_command('core_dialog_minimize') do |params|
            dialog_minimize_command
          end
          register_command('core_dialog_maximize') do |params|
            dialog_maximize_command
          end
          register_command('core_open_external_file') do |params|
            open_external_file_command(params)
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
        dialog_title = get_i18n_string('core.dialog.title') + ' - ' + VERSION
        if @html_dialog_compatible
          @dialog = UI::HtmlDialog.new(
              {
                  :dialog_title => dialog_title,
                  :preferences_key => DIALOG_PREF_KEY,
                  :scrollable => true,
                  :resizable => true,
                  :width => DIALOG_MINIMIZED_WIDTH,
                  :height => DIALOG_MINIMIZED_HEIGHT,
                  :left => DIALOG_LEFT,
                  :top => DIALOG_TOP,
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
              DIALOG_LEFT,
              DIALOG_TOP,
              true
          )
          @dialog.min_width = DIALOG_MINIMIZED_WIDTH
          @dialog.min_height = DIALOG_MINIMIZED_HEIGHT
          @dialog.set_on_close {
            @dialog = nil
          }
        end

        # Setup dialog page
        @dialog.set_file("#{__dir__}/../html/dialog-#{@language}.html")

        # Set dialog size and position
        dialog_set_size(DIALOG_MINIMIZED_WIDTH, DIALOG_MINIMIZED_HEIGHT)
        dialog_set_position(DIALOG_LEFT, DIALOG_TOP)

        # Setup dialog actions
        @dialog.add_action_callback("ladb_toolbox_command") do |action_context, call_json|
          call = JSON.parse(call_json)
          response = execute_command(call['command'], call['params'])
          script = "rubyCommandCallback(#{call['id']}, '#{response.is_a?(Hash) ? Base64.strict_encode64(URI.escape(JSON.generate(response))) : ''}');"
          @dialog.execute_script(script)
        end

      end

      def show_dialog(tab_name = nil)

        unless @dialog
          create_dialog
        end

        if @dialog.visible?

          if tab_name
            # Startup tab name is defined call JS to select it
            @dialog.execute_script("$('body').ladbToolbox('selectTab', '#{tab_name}');")
          end

        else

          # Store the startup tab name
          @dialog_startup_tab_name = tab_name

          # Show dialog
          if @html_dialog_compatible
            @dialog.show
          else
            if @current_os == :MAC
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

      private

      def dialog_set_size(width, height)
        if @dialog
          if @current_os == :MAC && !@html_dialog_compatible
            @dialog.execute_script("window.resizeTo(#{width},#{height})")
          else
            @dialog.set_size(width, height)
          end
        end
      end

      def dialog_set_position(left, top)
        if @dialog
          if @current_os == :MAC && !@html_dialog_compatible
            @dialog.execute_script("window.moveTo(#{left},#{top})")
          else
            @dialog.set_position(left, top)
          end
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
                value = Sketchup.read_default(DEFAULT_SECTION, key)
                if value.nil?
                  value = Sketchup.active_model.get_attribute(DEFAULT_DICTIONARY, key)
                end
            elsif strategy == SETTINGS_RW_STRATEGY_MODEL || strategy == SETTINGS_RW_STRATEGY_MODEL_GLOBAL
                value = Sketchup.active_model.get_attribute(DEFAULT_DICTIONARY, key)
            end

          end
          if value.nil?
            value = Sketchup.read_default(DEFAULT_SECTION, key)
          end

          values.push({
                          :key => key,
                          :value => value
                      })
        }
        { :values => values }
      end

      def write_settings_command(params)    # Waiting params = { settings: [ { key => 'key1', value => 'value1' }, ... ], strategy: [0|1|2|3] }
        settings = params['settings']
        strategy = params['strategy']   # Strategy used to write settings SETTINGS_RW_STRATEGY_GLOBAL or SETTINGS_RW_STRATEGY_GLOBAL_MODEL or SETTINGS_RW_STRATEGY_MODEL or SETTINGS_RW_STRATEGY_MODEL_GLOBAL
        settings.each { |setting|
          key = setting['key']
          value = setting['value']
          if !strategy.nil? || strategy == SETTINGS_RW_STRATEGY_GLOBAL || strategy == SETTINGS_RW_STRATEGY_GLOBAL_MODEL
            Sketchup.write_default(DEFAULT_SECTION, key, value)
          end
          if Sketchup.active_model && (strategy == SETTINGS_RW_STRATEGY_MODEL || strategy == SETTINGS_RW_STRATEGY_MODEL_GLOBAL)
            Sketchup.active_model.set_attribute(DEFAULT_DICTIONARY, key, value)
          end
        }
      end

      def dialog_loaded_command
        {
            :version => VERSION,
            :build => BUILD,
            :sketchup_version => Sketchup.version.to_s,
            :ruby_version => RUBY_VERSION,
            :current_os => "#{@current_os}",
            :locale => Sketchup.get_locale,
            :language => @language,
            :html_dialog_compatible => @html_dialog_compatible,
            :dialog_startup_size => @dialog_min_size,
            :dialog_startup_tab_name => @dialog_startup_tab_name  # nil if none
        }
      end

      def dialog_minimize_command
        if @dialog
          dialog_set_size(DIALOG_MINIMIZED_WIDTH, DIALOG_MINIMIZED_HEIGHT)
        end
      end

      def dialog_maximize_command
        if @dialog
          dialog_set_size(DIALOG_MAXIMIZED_WIDTH, DIALOG_MAXIMIZED_HEIGHT)
        end
      end

      def open_external_file_command(params)    # Waiting params = { path: PATH_TO_FILE }
        path = params['path']
        if path
          UI.openURL("file:///#{path}")
        end
      end

    end
  end
end