module Ladb::OpenCutList

  module Geometrix

    ONE_PI = Math::PI
    TWO_PI = 2 * Math::PI
    QUARTER_PI = Math::PI * 0.25
    HALF_PI = Math::PI * 0.5
    THREE_QUARTER_PI = Math::PI * 0.75

    require_relative 'finder/circle_finder'
    require_relative 'finder/ellipse_finder'
    require_relative 'finder/curve_finder'

  end

end