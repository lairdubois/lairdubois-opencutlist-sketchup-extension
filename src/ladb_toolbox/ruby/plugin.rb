require_relative 'observer/app_observer'
require_relative 'controller/cutlist_controller'
require_relative 'controller/materials_controller'

module Ladb
  module Toolbox
    class Plugin

      NAME = 'L\'Air du Bois - Boîte à outils Sketchup [BETA]'
      VERSION = '0.4.2'

      DIALOG_MAXIMIZED_WIDTH = 1100
      DIALOG_MAXIMIZED_HEIGHT = 800
      DIALOG_MINIMIZED_WIDTH = 90
      DIALOG_MINIMIZED_HEIGHT = 30 + 80 + 80 * 2    # = 2 Tab buttons
      DIALOG_LEFT = 200
      DIALOG_TOP = 100
      DIALOG_PREF_KEY = 'fr.lairdubois.plugin'

      attr_accessor :dialog

      @commands
      @controllers
      @html_dialog_compatible
      @current_os
      @started

      def initialize()
        @commands = {}
        @controllers = []
        @html_dialog_compatible = false
        @current_os = :OTHER
        @started = false
      end

      # -----

      def temp_dir
        temp_dir = File.join(Sketchup.temp_dir, "ladb_toolbox")
        unless Dir.exist?(temp_dir)
          Dir.mkdir(temp_dir)
        end
        temp_dir
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

          register_command('dialog_loaded') do |params|
            {
                :version => VERSION,
                :htmlDialogCompatible => @html_dialog_compatible,
                :sketchupVersion => Sketchup.version.to_s,
                :currentOS => "#{@current_os}"
            }
          end
          register_command('dialog_minimize') do |params|
            if @dialog
              @dialog.set_size(DIALOG_MINIMIZED_WIDTH, @html_dialog_compatible ? DIALOG_MINIMIZED_HEIGHT : DIALOG_MAXIMIZED_HEIGHT)
            end
          end
          register_command('dialog_maximize') do |params|
            if @dialog
              @dialog.set_size(DIALOG_MAXIMIZED_WIDTH, DIALOG_MAXIMIZED_HEIGHT)
            end
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
                    :style => UI::HtmlDialog::STYLE_DIALOG
                })
          else
            @dialog = UI::WebDialog.new(
                dialog_title,
                true,
                DIALOG_PREF_KEY,
                DIALOG_MINIMIZED_WIDTH,
                DIALOG_MAXIMIZED_HEIGHT,
                DIALOG_LEFT,
                DIALOG_TOP,
                true
            )
          end

          # Setup dialog page
          @dialog.set_file(__dir__ + '/../html/dialog.html')

          # Set dialog size
          @dialog.set_size(DIALOG_MINIMIZED_WIDTH, @html_dialog_compatible ? DIALOG_MINIMIZED_HEIGHT : DIALOG_MAXIMIZED_HEIGHT)

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

    end
  end
end