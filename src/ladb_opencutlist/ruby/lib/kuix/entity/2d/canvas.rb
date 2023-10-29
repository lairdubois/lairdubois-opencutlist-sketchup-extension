module Ladb::OpenCutList::Kuix

  class Canvas < Entity2d

    attr_reader :view

    def initialize(view)
      super('canvas')
      @view = view
    end

    # -- DOM --

    def in_dom?
      true
    end

    # -- Layout --

    def invalidate
      super
      @view.invalidate
    end

  end

end