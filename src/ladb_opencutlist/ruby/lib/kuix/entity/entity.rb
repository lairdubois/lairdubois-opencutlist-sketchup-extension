module Ladb::OpenCutList::Kuix

  class Entity

    attr_accessor :id
    attr_accessor :parent, :child, :last_child, :next, :previous
    attr_accessor :data

    def initialize(id = nil)

      @id = id

      @parent = nil
      @child = nil
      @last_child = nil

      @next = nil
      @previous = nil

      @invalidated = true

      @visible = true

      @data = nil

    end

    # -- DOM --

    def in_dom?
      @parent && @parent.in_dom?
    end

    # Append given widget to self and returns self
    def append(entity)
      throw 'Entity.append only supports Entity' unless entity.is_a?(Entity)
      throw 'Entity.append can\'t append itself' if entity == self
      throw 'Entity.append can\'t append nil' if entity.nil?

      # Remove widget from previous parent
      if entity.parent
        entity.remove
      end

      # Append widget to linked list
      entity.parent = self
      @last_child.next = entity if @last_child
      entity.previous = @last_child
      @child = entity unless @child
      @last_child = entity

      # Invalidate self
      invalidate

      # Returns self
      self
    end

    # Remove self widget from its parent and returns parent
    def remove
      return unless @parent
      if @parent.child == self
        @parent.child = @next
      end
      if @parent.last_child == self
        @parent.last_child = @previous
      end
      unless @previous.nil?
        @previous.next = @next
      end
      unless @next.nil?
        @next.previous = @previous
        @next = nil
      end
      @previous = nil
      parent = @parent
      @parent = nil
      parent.invalidate
      parent
    end

    def remove_all
      if @child
        entity = @child
        until entity.nil?
          next_widget = entity.next
          entity.next = nil
          entity.previous = nil
          entity.parent = nil
          entity = next_widget
        end
        @child = nil
        @last_child = nil
        invalidate
      end
    end

    # -- LAYOUT --

    def visible=(value)
      return if @visible == value
      @visible = value
      invalidate
    end

    def visible?
      @visible
    end

    def invalidated=(invalidated)
      @invalidated = invalidated
    end

    def invalidated?
      @invalidated
    end

    def invalidate
      @invalidated = true
      if @parent && !@parent.invalidated?
        @parent.invalidate
      end
    end

    # -- RENDER --

    def paint(graphics)
      paint_itself(graphics) if self.visible?
      paint_sibling(graphics)
    end

    def paint_content(graphics)
      @child.paint(graphics) if @child
    end

    def paint_itself(graphics)
      paint_content(graphics)
    end

    def paint_sibling(graphics)
      @next.paint(graphics) if @next
    end

    # --

    def to_s
      "#{self.class.name} (id=#{@id})"
    end

  end

end