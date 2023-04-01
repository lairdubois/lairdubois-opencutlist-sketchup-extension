module Ladb::OpenCutList::Kuix

  class Arrow < Lines3d

    def initialize(id = nil)
      super([

        [  0.05 , 1/3.0 , 0 ],
        [ 1/2.0 , 1/3.0 , 0 ],
        [ 1/2.0 ,  0.05 , 0 ],
        [  0.95 , 1/2.0 , 0 ],
        [ 1/2.0 ,  0.95 , 0 ],
        [ 1/2.0 , 2/3.0 , 0 ],
        [  0.05 , 2/3.0 , 0 ]

      ], true, id)
    end

  end

end