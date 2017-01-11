require 'fileutils'
require_relative 'observer/app_observer'
require_relative 'controller/cutlist_controller'
require_relative 'controller/materials_controller'

module Ladb
  module Toolbox
    class Plugin

      NAME = 'L\'Air du Bois - Boîte à outils Sketchup [BETA]'
      VERSION = '0.4.5'

      DEFAULT_KEY_SECTION = 'ladb_toolbox'

      DIALOG_MAXIMIZED_WIDTH = 1100
      DIALOG_MAXIMIZED_HEIGHT = 800
      DIALOG_MINIMIZED_WIDTH = 90
      DIALOG_MINIMIZED_HEIGHT = 30 + 80 + 80 * 2    # = 2 Tab buttons
      DIALOG_LEFT = 200
      DIALOG_TOP = 100
      DIALOG_PREF_KEY = 'fr.lairdubois.toolbox'

      attr_accessor :dialog

      @commands
      @controllers
      @html_dialog_compatible
      @current_os
      @language
      @started
      @temp_dir

      def initialize()
        @commands = {}
        @controllers = []
        @html_dialog_compatible = false
        @current_os = :OTHER
        @language = 'en'
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

      # -----

      def register_command(command, &block)
        @commands[command] = block
      end

      def execute_command(command, params)
        if @commands.has_key? command
          command = @commands[command]
          return command.call(params)
        end
        raise "Command '#{command}' not found"
      end

      # -----

      def start

        # To minimize plugin initialization, start setup is called only once
        unless @started

          # -- Check --

          # Fetch OS
          @current_os = (Object::RUBY_PLATFORM =~ /mswin/i || Object::RUBY_PLATFORM =~ /mingw/i) ? :WIN : ((Object::RUBY_PLATFORM =~ /darwin/i) ? :MAC : :OTHER)

          # Locale
          available_translations = []
          Dir["#{__dir__}/../js/i18n/*.js"].each { |file|
            available_translations.push(File.basename(file, File.extname(file)))
          }
          language = Sketchup.get_locale.split('-')[0]
          if available_translations.include? language
            @language = language   # Uses SU locale only if translation is available
          end

          # Check compatibility (If we can we use the HtmlDialog class - new in Sketchup 2017)
          @html_dialog_compatible = true
          begin
            Object.const_defined?('UI::HtmlDialog')
          rescue NameError
            @html_dialog_compatible = false
          end

          # -- Observers --

          # TODO : Sketchup.add_observer(AppObserver.new(self))

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

          @controllers.each { |controller|
            controller.setup_commands
          }

          @started = true

        end

      end

      def toggle_dialog()
        if @dialog and @dialog.visible?
          @dialog.close
          @dialog = nil
        else

          # Start
          start

          # Create dialog instance
          dialog_title = NAME + ' - ' + VERSION
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
                    :min_heght => DIALOG_MINIMIZED_HEIGHT,
                    :style => UI::HtmlDialog::STYLE_DIALOG
                })
          else
            @dialog = UI::WebDialog.new(
                dialog_title,
                true,
                DIALOG_PREF_KEY,
                DIALOG_MINIMIZED_WIDTH,
                @current_os == :MAC ? DIALOG_MAXIMIZED_HEIGHT : DIALOG_MINIMIZED_HEIGHT,
                DIALOG_LEFT,
                DIALOG_TOP,
                true
            )
            @dialog.min_width = DIALOG_MINIMIZED_WIDTH
            @dialog.min_height = DIALOG_MINIMIZED_HEIGHT
          end

          # Setup dialog page
          @dialog.set_file("#{__dir__}/../html/dialog.html")

          # Set dialog size
          @dialog.set_size(DIALOG_MINIMIZED_WIDTH, !@html_dialog_compatible && @current_os == :MAC ? DIALOG_MAXIMIZED_HEIGHT : DIALOG_MINIMIZED_HEIGHT)

          # Setup dialog actions
          @dialog.add_action_callback("ladb_toolbox_command") do |action_context, call_json|
            call = JSON.parse(call_json)
            result = execute_command(call['command'], call['params'])
            script = "rubyCommandCallback(#{call['id']}, '#{result.is_a?(Hash) ? Base64.strict_encode64(URI.escape(JSON.generate(result))) : ''}');"
            @dialog.execute_script(script)
          end

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

      private

      # -- Commands ---

      def read_settings_command(params)    # Waiting params = { keys: [ 'key1', ... ] }
        keys = params['keys']
        values = []
        keys.each { |key|
          values.push({
                          :key => key,
                          :value => Sketchup.read_default(DEFAULT_KEY_SECTION, key)
                      })
        }
        { :values => values }
      end

      def write_settings_command(params)    # Waiting params = { settings: [ { key => 'key1', value => 'value1' }, ... ] }
        settings = params['settings']
        settings.each { |setting|
          key = setting['key']
          value = setting['value']
          Sketchup.write_default(DEFAULT_KEY_SECTION, key, value)
        }
      end

      def dialog_loaded_command
        {
            :version => VERSION,
            :sketchup_version => Sketchup.version.to_s,
            :current_os => "#{@current_os}",
            :locale => Sketchup.get_locale,
            :language => @language,
            :html_dialog_compatible => @html_dialog_compatible
        }
      end

      def dialog_minimize_command
        if @dialog
          @dialog.set_size(DIALOG_MINIMIZED_WIDTH, !@html_dialog_compatible && @current_os == :MAC ? DIALOG_MAXIMIZED_HEIGHT : DIALOG_MINIMIZED_HEIGHT)
        end
      end

      def dialog_maximize_command
        if @dialog
          @dialog.set_size(DIALOG_MAXIMIZED_WIDTH, DIALOG_MAXIMIZED_HEIGHT)
        end
      end

    end
  end
end