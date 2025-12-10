module Ladb::OpenCutList

  module Kuix

    # Key constants

    VK_TAB = 9
    VK_ENTER = 13
    if Sketchup.platform == :platform_osx
      VK_NUMPAD0 = 48
      VK_NUMPAD1 = 49
      VK_NUMPAD2 = 50
      VK_NUMPAD3 = 51
      VK_NUMPAD4 = 52
      VK_NUMPAD5 = 53
      VK_NUMPAD6 = 54
      VK_NUMPAD7 = 55
      VK_NUMPAD8 = 56
      VK_NUMPAD9 = 57
      VK_ADD = 43
    else
      VK_NUMPAD0 = 0x60
      VK_NUMPAD1 = 0x61
      VK_NUMPAD2 = 0x62
      VK_NUMPAD3 = 0x63
      VK_NUMPAD4 = 0x64
      VK_NUMPAD5 = 0x65
      VK_NUMPAD6 = 0x66
      VK_NUMPAD7 = 0x67
      VK_NUMPAD8 = 0x68
      VK_NUMPAD9 = 0x69
      VK_ADD = 0x6B
    end

    # Color constants

    COLOR_BLACK = Sketchup::Color.new(0, 0, 0).freeze
    COLOR_WHITE = Sketchup::Color.new(255, 255, 255).freeze
    COLOR_RED = Sketchup::Color.new(255, 0, 0).freeze
    COLOR_GREEN = Sketchup::Color.new(0, 255, 0).freeze
    COLOR_BLUE = Sketchup::Color.new(0, 0, 255).freeze
    COLOR_MAGENTA = Sketchup::Color.new(255, 0, 255).freeze
    COLOR_YELLOW = Sketchup::Color.new(255, 255, 0).freeze
    COLOR_CYAN = Sketchup::Color.new(0, 255, 255).freeze
    COLOR_ORANGE = Sketchup::Color.new(255, 127, 0).freeze
    COLOR_LIGHT_GREY = Sketchup::Color.new(220, 220, 220).freeze
    COLOR_MEDIUM_GREY = Sketchup::Color.new(170, 170, 170).freeze
    COLOR_DARK_GREY = Sketchup::Color.new(120, 120, 120).freeze
    COLOR_X = Sketchup::Color.new(255, 0, 15).freeze
    COLOR_Y = Sketchup::Color.new(0, 187, 0).freeze
    COLOR_Z = Sketchup::Color.new(0, 50, 255).freeze

    # Line stipple constants

    LINE_STIPPLE_SOLID = ''.freeze
    LINE_STIPPLE_DOTTED = '.'.freeze
    LINE_STIPPLE_SHORT_DASHES = '-'.freeze
    LINE_STIPPLE_LONG_DASHES = '_'.freeze
    LINE_STIPPLE_DASH_DOT_DASH = '-.-'.freeze

    # Point style constants

    POINT_STYLE_SQUARE = 1
    POINT_STYLE_TRIANGLE = 2
    POINT_STYLE_CIRCLE = 3
    POINT_STYLE_DIAMOND = 4
    POINT_STYLE_PLUS = 5
    POINT_STYLE_CROSS = 6
    POINT_STYLE_STAR = 7

    require_relative 'gl/graphics'
    require_relative 'gl/graphics2d'
    require_relative 'gl/graphics3d'

    require_relative 'layout/border_layout'
    require_relative 'layout/static_layout'
    require_relative 'layout/grid_layout'
    require_relative 'layout/inline_layout'

    require_relative 'geom/anchor'
    require_relative 'geom/bounds2d'
    require_relative 'geom/bounds3d'
    require_relative 'geom/inset2d'
    require_relative 'geom/point2d'
    require_relative 'geom/point3d'
    require_relative 'geom/size2d'
    require_relative 'geom/size3d'

    require_relative 'entity/entity'
    require_relative 'entity/2d/entity2d'
    require_relative 'entity/2d/canvas'
    require_relative 'entity/2d/panel'
    require_relative 'entity/2d/label'
    require_relative 'entity/2d/motif2d'
    require_relative 'entity/2d/button'
    require_relative 'entity/2d/progress'
    require_relative 'entity/2d/scroll_panel'
    require_relative 'entity/3d/entity3d'
    require_relative 'entity/3d/space'
    require_relative 'entity/3d/group'
    require_relative 'entity/3d/axes_helper'
    require_relative 'entity/3d/motif3d'
    require_relative 'entity/3d/mesh'
    require_relative 'entity/3d/segments'
    require_relative 'entity/3d/polyline'
    require_relative 'entity/3d/points'
    require_relative 'entity/3d/line'

    class KuixTool

      attr_reader :canvas # 2D drawing
      attr_reader :space  # 3D drawing

      def initialize(quit_on_esc = true, quit_on_undo = false)

        if Plugin::IS_DEV
          SKETCHUP_CONSOLE.clear
        end

        # Determine if the tool is deactiveted when the user hit the ESC key
        @quit_on_esc = quit_on_esc

        # Determine if the tool is deactiveted when the user undo last action
        @quit_on_undo = quit_on_undo

        # Cursor management
        @cursor_select_id = create_cursor('select', 0, 0)
        @cursors = [ @cursor_select_id ]

        # Internals

        @mouse_down_widget = nil
        @mouse_hover_widget = nil
        @mouse_is_outside = true

        @key_down_times = {}

      end

      # -- UI stuff --

      def setup_entities(view)
        # Override and implement startup entities here
      end

      def clear_canvas
        @canvas.remove_all unless @canvas.nil?
      end

      def clear_space
        @space.remove_all unless @space.nil?
      end

      # -- Cursors stuff --

      def create_cursor(name, hot_x, hot_y)
        cursor_id = nil
        cursor_path = File.join(PLUGIN_DIR,'img', "cursor-#{name}.#{PLUGIN.platform_is_mac? ? 'pdf' : 'svg'}")
        if cursor_path
          cursor_id = UI.create_cursor(cursor_path, hot_x, hot_y)
        end
        cursor_id
      end

      def set_root_cursor(cursor_id)
        @cursors[0] = cursor_id
        onSetCursor
      end

      def push_cursor(cursor_id)
        if @cursors.include?(cursor_id)
          return if @cursors.find_index(cursor_id) == 0
          @cursors.delete(cursor_id)
        end
        @cursors.push(cursor_id)
        onSetCursor
      end

      def pop_cursor(cursor_id = nil)
        if @cursors.length > 1
          if !cursor_id.nil?
            @cursors.delete(cursor_id)
          else
            @cursors.pop
          end
          onSetCursor
        end
      end

      def pop_to_root_cursor
        if @cursors.length > 1
          @cursors.slice!(1)
          onSetCursor
        end
      end

      # -- Tool stuff --

      def activate
        model = Sketchup.active_model
        onActivate(model.active_view) unless model.nil?
       end

      def deactivate(view)
        onDeactivate(view)
        view.invalidate
      end

      def suspend(view)
        onSuspend(view)
        view.invalidate
      end

      def resume(view)
        onResume(view)
      end

      def quit
        Sketchup.active_model.select_tool(nil) if Sketchup.active_model # Deactivate the tool
      end

      def draw(view)

        # Check if space need to be revalidated
        if @space.invalidated?
          @space.do_layout(IDENTITY)
        end

        # Paint the space
        @space.paint(Graphics3d.new(view))

        return unless @canvas

        # Check if viewport has changed
        if view.vpwidth != @canvas.bounds.width || view.vpheight != @canvas.bounds.height
          @canvas.bounds.set!(0, 0, view.vpwidth, view.vpheight)
          @canvas.do_layout
        end

        # Check if canvas need to be revalidated
        if @canvas.invalidated?
          @canvas.do_layout
        end

        # Paint the canvas
        @canvas.paint(Graphics2d.new(view))

      end

      def getExtents

        # Check if space needs to be revalidated
        if @space.invalidated?
          @space.do_layout(IDENTITY)
        end

        @space.extents
      end

      # -- Keys --

      def is_key_shift?(key)
        key == CONSTRAIN_MODIFIER_KEY
      end

      def is_key_alt_or_command?(key)
        key == ALT_MODIFIER_KEY
      end

      def is_key_ctrl_or_option?(key)
        key == COPY_MODIFIER_KEY
      end

      def is_key_down?(key)
        @key_down_times[key].is_a?(Time)
      end

      def is_key_shift_down?
        is_key_down?(CONSTRAIN_MODIFIER_KEY)
      end

      def is_key_alt_or_command_down?
        is_key_down?(ALT_MODIFIER_KEY)
      end

      def is_key_ctrl_or_option_down?
        is_key_down?(COPY_MODIFIER_KEY)
      end

      # -- Events --

      def onActivate(view)

        # Create the root canvas
        @canvas = Canvas.new(view)

        # Create the root space
        @space = Space.new(view)

        # Setup children widgets
        setup_entities(view)

        view.invalidate
      end

      def onDeactivate(view)
        @canvas.remove_all
        @space.remove_all
        view.invalidate
      end

      def onSuspend(view)
        @key_down_times.clear
        view.invalidate
      end

      def onResume(view)
        view.invalidate
      end

      def onCancel(reason, view)
        # 0 = the user canceled the current operation by hitting the escape key
        # 2 = the user did an undo while the tool was active.
        if (reason == 0 && @quit_on_esc) || (reason == 2 && @quit_on_undo)
          quit
        end
      end

      def onKeyDown(key, repeat, flags, view)
        @key_down_times[key] = Time.new if repeat == 1
        false
      end

      def onKeyUp(key, repeat, flags, view)
        key_down_time = @key_down_times[key]
        after_down = key_down_time.is_a?(Time)
        @key_down_times.delete(key)
        onKeyUpExtended(key, repeat, flags, view, after_down, after_down && (Time.new - key_down_time) <= 0.15) # < 150ms
      end

      def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
        false
      end

      def onLButtonDown(flags, x, y, view)
        hit_widget = @canvas.hit_widget(x, y)
        @mouse_down_widget = hit_widget
        if @mouse_down_widget
          @mouse_down_widget.onMouseDown(flags)
          return true
        end
        false
      end

      def onLButtonUp(flags, x, y, view)
        hit_widget = @canvas.hit_widget(x, y)
        if hit_widget && @mouse_down_widget == hit_widget
          @mouse_down_widget.onMouseClick(flags)
          @mouse_down_widget = nil
          return true
        end
        @mouse_down_widget = nil
        false
      end

      def onLButtonDoubleClick(flags, x, y, view)
        hit_widget = @canvas.hit_widget(x, y)
        if hit_widget
          hit_widget.onMouseDoubleClick(flags)
          @mouse_down_widget = nil
          return true
        end
        @mouse_down_widget = nil
        false
      end

      def onMouseMove(flags, x, y, view)
        hit_widget = @canvas.hit_widget(x, y)
        if hit_widget
          onMouseLeaveSpace(view) if @mouse_hover_widget.nil? && !@mouse_is_outside
          if hit_widget != @mouse_hover_widget
            if @mouse_hover_widget
              @mouse_hover_widget.onMouseLeave if @mouse_hover_widget.in_dom?
              pop_cursor
            end
            @mouse_hover_widget = hit_widget
            @mouse_hover_widget.onMouseEnter(flags)
            push_cursor(@cursor_select_id)
          end
          @mouse_is_outside = false
          return true
        else
          if @mouse_hover_widget
            @mouse_hover_widget.onMouseLeave if @mouse_hover_widget.in_dom?
            pop_cursor
          end
          @mouse_hover_widget = nil
          @mouse_is_outside = false
        end
        false
      end

      def onMouseLeave(view)
        if @mouse_hover_widget
          @mouse_hover_widget.onMouseLeave if @mouse_hover_widget.in_dom?
          pop_cursor
        else
          onMouseLeaveSpace(view)
        end
        @mouse_hover_widget = nil
        @mouse_is_outside = true
        false
      end

      def onMouseLeaveSpace(view)
        false
      end

      def onMouseWheel(flags, delta, x, y, view)
        hit_widget = @canvas.hit_widget(x, y, :wheel)
        return true if hit_widget && hit_widget.in_dom? && hit_widget.onMouseWheel(flags, delta)
        false
      end

      def onSetCursor
        UI.set_cursor(@cursors.last)
      end

      # -----

      def inspect
        self.class.inspect  # Simplify exception display
      end

    end

    if Sketchup.version_number >= 2300000000

      class KuixOverlay < Sketchup::Overlay

        attr_reader :canvas
        attr_reader :space

        def initialize(id, name, description: '')
          super

          # Create the root canvas
          @canvas = Canvas.new(Sketchup.active_model.active_view)

          # Create the root space
          @space = Space.new(Sketchup.active_model.active_view)

        end

        def draw(view)

          # Check if space need to be revalidated
          if @space.invalidated?
            @space.do_layout(IDENTITY)
          end

          # Paint the space
          @space.paint(Graphics3d.new(view))

          return unless @canvas

          # Check if viewport has changed
          if view.vpwidth != @canvas.bounds.width || view.vpheight != @canvas.bounds.height
            @canvas.bounds.set!(0, 0, view.vpwidth, view.vpheight)
            @canvas.do_layout
          end

          # Check if canvas need to be revalidated
          if @canvas.invalidated?
            @canvas.do_layout
          end

          # Paint the canvas
          @canvas.paint(Graphics2d.new(view))

        end

        def getExtents

          # Check if space need to be revalidated
          if @space.invalidated?
            @space.do_layout(IDENTITY)
          end

          @space.extents
        end

        # -----

        def inspect
          self.class.inspect  # Simplify exception display
        end

      end

    end

  end

end