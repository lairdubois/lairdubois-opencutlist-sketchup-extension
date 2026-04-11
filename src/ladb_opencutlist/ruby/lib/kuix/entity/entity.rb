module Ladb::OpenCutList::Kuix

  class Entity

    attr_accessor :id
    attr_accessor :parent, :children
    attr_accessor :data

    def initialize(id = nil)

      @id = id

      @parent = nil
      @children = []

      @invalidated = true

      @visible = true

      @data = nil

    end

    # -- DOM --

    def in_dom?
      @parent && @parent.in_dom?
    end

    def empty?
      @children.empty?
    end

    # Append a given entity to self and returns self
    def append(entity)
      raise 'Entity.append only supports Entity' unless entity.is_a?(Entity)
      raise 'Entity.append can\'t append itself' if entity == self
      raise 'Entity.append can\'t append nil' if entity.nil?

      # Remove the entity from its previous parent
      entity.remove if entity.parent

      # Append entity to children array
      @children.push(entity)

      # Set parent of entity
      entity.parent = self

      # Invalidate self
      invalidate

      # Returns self
      self
    end

    # Prepend a given entity to self and returns self
    def prepend(entity)
      raise 'Entity.prepend only supports Entity' unless entity.is_a?(Entity)
      raise 'Entity.prepend can\'t prepend itself' if entity == self
      raise 'Entity.prepend can\'t prepend nil' if entity.nil?

      # Remove the entity from its previous parent
      entity.remove if entity.parent

      # Prepend entity to children array
      @children.unshift(entity)

      # Set parent of entity
      entity.parent = self

      # Invalidate self
      invalidate

      # Returns self
      self
    end

    # Remove self-entity from its parent and returns parent
    def remove
      return unless @parent

      parent = @parent

      @parent.children.delete(self)
      @parent = nil

      parent.invalidate
      parent
    end

    # Remove all children from self
    def clear
      return if @children.empty?

      @children.each { |child| child.remove }
      @children.clear
      invalidate

      self
    end

    def num_children
      @children.size
    end

    def prev_sibling
      return nil if @parent.nil?
      @parent.children[@parent.children.index(self) - 1]
    end

    def next_sibling
      return nil if @parent.nil?
      @parent.children[(@parent.children.index(self) + 1) % @parent.num_children]
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
      return unless visible? && valid?
      paint_content(graphics)
    end

    def paint_content(graphics)
      paint_itself(graphics)
      @children.each { |child| child.paint(graphics) }
    end

    def paint_itself(graphics)
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