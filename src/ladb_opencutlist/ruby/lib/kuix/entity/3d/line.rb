module Ladb::OpenCutList::Kuix

  class Line < Lines

    def initialize(id = nil)
      super([
              [ 0, 0, 0 ],
              [ 1, 1, 1 ]
            ], false, id)
    end

  end

end