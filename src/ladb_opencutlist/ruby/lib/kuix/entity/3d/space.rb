module Ladb::OpenCutList::Kuix

  class Space < Entity3d

    attr_reader :view

    def initialize(view)
      super('space')
      @view = view
    end

    # -- LAYOUT --

    def invalidate
      super
      @view.invalidate
    end

  end

end