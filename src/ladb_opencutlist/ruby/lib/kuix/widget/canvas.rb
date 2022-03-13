module Ladb::OpenCutList::Kuix

  class Canvas < Widget

    def initialize(view)
      super('canvas')
      @view = view
    end

    # -- Layout --

    def invalidate
      super
      @view.invalidate
    end

  end

end