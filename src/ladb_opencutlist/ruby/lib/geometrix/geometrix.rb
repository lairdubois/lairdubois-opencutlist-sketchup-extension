module Ladb::OpenCutList

  module Geometrix

    QUARTER_PI = Math::PI * 0.25
    HALF_PI = Math::PI * 0.5
    THREE_QUARTER_PI = Math::PI * 0.75
    ONE_PI = Math::PI
    FIVE_QUARTER_PI = Math::PI * 1.25
    THREE_HALF_PI = Math::PI * 1.5
    SEVEN_HALF_PI = Math::PI * 1.75
    TWO_PI = 2 * Math::PI
    FOUR_PI = 4 * Math::PI

    require_relative 'finder/border_finder'
    require_relative 'finder/centroid_finder'
    require_relative 'finder/circle_finder'
    require_relative 'finder/ellipse_finder'
    require_relative 'finder/curve_finder'

    require_relative 'approximator/ellipse_approximator'

  end

end