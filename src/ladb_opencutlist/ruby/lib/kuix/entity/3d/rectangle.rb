module Ladb::OpenCutList::Kuix

  class Rectangle < Lines3d

    def initialize(id = nil)
      super([

        [ 0, 0, 0 ],
        [ 1, 0, 0 ],
        [ 1, 1, 0 ],
        [ 0, 1, 0 ]

      ], true, id)
    end

  end

end