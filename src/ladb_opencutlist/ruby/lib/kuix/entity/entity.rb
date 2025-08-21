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
      raise 'Entity.append only supports Entity' unless entity.is_a?(Entity)
      raise 'Entity.append can\'t append itself' if entity == self
      raise 'Entity.append can\'t append nil' if entity.nil?

      # Remove widget from previous parent
      entity.remove if entity.parent

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

    # Prepend given widget to self and returns self
    def prepend(entity)
      raise 'Entity.append only supports Entity' unless entity.is_a?(Entity)
      raise 'Entity.append can\'t prepend itself' if entity == self
      raise 'Entity.append can\'t prepend nil' if entity.nil?

      # Remove widget from previous parent
      entity.remove if entity.parent

      # Prepend widget to linked list
      entity.parent = self
      @child.previous = entity if @child
      entity.next = @child
      @child = entity
      @last_child = entity unless @last_child

      # Invalidate self
      invalidate

      # Returns self
      self
    end

    # Remove self widget from its parent and returns parent
    def remove
      return unless @parent
      @parent.child = @next if @parent.child == self
      @parent.last_child = @previous if @parent.last_child == self
      @previous.next = @next unless @previous.nil?
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

    def num_children
      return 0 if @child.nil?
      num_children = 0
      entity = @child
      until entity.nil?
        num_children += 1
        entity = entity.next
      end
      num_children
    end

    # -- LAYOUT --

    def valid?
      true
    end

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
      @parent.invalidate if @parent && !@parent.invalidated?
    end

    # -- RENDER --

    def paint(graphics)
      paint_itself(graphics) if visible? && valid?
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

    # -----

    def inspect
      self.class.inspect  # Simplify exception display
    end

  end

end