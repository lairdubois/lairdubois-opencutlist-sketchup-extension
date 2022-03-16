module Ladb::OpenCutList

  module Kuix

    require_relative 'gl/graphics'

    require_relative 'layout/border_layout'
    require_relative 'layout/static_layout'
    require_relative 'layout/grid_layout'
    require_relative 'layout/inline_layout'

    require_relative 'model/anchor'
    require_relative 'model/size'
    require_relative 'model/point'
    require_relative 'model/bounds'
    require_relative 'model/inset'

    require_relative 'widget/widget'
    require_relative 'widget/canvas'
    require_relative 'widget/label'
    require_relative 'widget/button'

    class KuixTool

      attr_reader :canvas

      def initialize(quit_on_esc = true, quit_on_undo = false)

        if Plugin::IS_DEV
          SKETCHUP_CONSOLE.clear
        end

        # Determine if the tool is deactiveted when the user hit the ESC key
        @quit_on_esc = quit_on_esc

        # Determine if the tool is deactiveted when the user undo last action
        @quit_on_undo = quit_on_undo

        # Cursor management
        @cursor_select_id = create_cursor('select', 4, 7)
        @cursors = [ @cursor_select_id ]

        # Internals

        @mouse_down_widget = nil
        @mouse_hover_widget = nil

      end

      # -- UI stuff --

      def setup_widgets(view)
        # Override and implement startup widgets here
      end

      def create_cursor(name, hot_x, hot_y)
        cursor_id = nil
        cursor_path = File.join(__dir__, '..', '..', '..', 'img', "cursor-#{name}.#{Plugin.instance.current_os == :MAC ? 'pdf' : 'svg'}")
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
        @cursors.push(cursor_id)
      end

      def pop_cursor
        if @cursors.length > 1
          @cursors.pop
        end
      end

      # -- Tool stuff --

      def activate
        model = Sketchup.active_model
        if model
          onActivate(model.active_view)
        end
      end

      def deactivate(view)
        onDeactivate(view)
      end

      def suspend(view)
        onSuspend(view)
      end

      def resume(view)
        onResume(view)
      end

      def quit(view)
        # Deactivate the tool
        view.model.select_tool(nil)
      end

      def draw(view)
        return unless @canvas

        # Check if viewport has changed
        if view.vpwidth != @canvas.bounds.width || view.vpheight != @canvas.bounds.height
          @canvas.bounds.set(0, 0, view.vpwidth, view.vpheight)
          @canvas.do_layout
        end

        # Check if canvas need to be revalidated
        if @canvas.invalidated?
          @canvas.do_layout
        end

        # Paint the canvas
        @canvas.paint(Graphics.new(view))

      end

      def getExtents
        Sketchup.active_model.bounds
      end

      # -- Events --

      def onActivate(view)

        # Create the root canvas
        @canvas = Canvas.new(view)

        # Setup children widgets
        setup_widgets(view)

        view.invalidate
      end

      def onDeactivate(view)
        view.invalidate
      end

      def onSuspend(view)
        view.invalidate
      end

      def onResume(view)
        view.invalidate
      end

      def onCancel(reason, view)
        # 0 = the user canceled the current operation by hitting the escape key
        # 2 = the user did an undo while the tool was active.
        if (reason == 0 && @quit_on_esc) || (reason == 2 && @quit_on_undo)
          quit(view)
        end
      end

      def onKeyDown(key, repeat, flags, view)
      end

      def onKeyUp(key, repeat, flags, view)
      end

      def onLButtonDown(flags, x, y, view)
        hit_widget = @canvas.hit_widget(x, y)
        @mouse_down_widget = hit_widget
        if @mouse_down_widget
          @mouse_down_widget.onMouseDown(flags)
          return true
        end
      end

      def onLButtonUp(flags, x, y, view)
        hit_widget = @canvas.hit_widget(x, y)
        if hit_widget && @mouse_down_widget == hit_widget
          @mouse_down_widget.onMouseClick(flags)
          @mouse_down_widget = nil
          return true
        end
        @mouse_down_widget = nil
      end

      def onLButtonDoubleClick(flags, x, y, view)
        hit_widget = @canvas.hit_widget(x, y)
        if hit_widget
          hit_widget.onMouseDoubleClick(flags)
          @mouse_down_widget = nil
          return true
        end
        @mouse_down_widget = nil
      end

      def onMouseMove(flags, x, y, view)
        hit_widget = @canvas.hit_widget(x, y)
        if hit_widget
          if hit_widget != @mouse_hover_widget
            if @mouse_hover_widget
              @mouse_hover_widget.onMouseLeave
              pop_cursor
            end
            @mouse_hover_widget = hit_widget
            @mouse_hover_widget.onMouseEnter(flags)
            push_cursor(@cursor_select_id)
          end
          return true
        else
          if @mouse_hover_widget
            @mouse_hover_widget.onMouseLeave
            pop_cursor
          end
          @mouse_hover_widget = nil
        end
      end

      def onMouseLeave(view)
        if @mouse_hover_widget
          @mouse_hover_widget.onMouseLeave
          pop_cursor
        end
        @mouse_hover_widget = nil
      end

      def onSetCursor
        UI.set_cursor(@cursors.last)
      end

    end

  end

end