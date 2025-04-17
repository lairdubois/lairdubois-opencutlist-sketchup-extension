#pragma once

#include "shape/shape.hpp"

namespace shape
{

Point approximate_pole_of_inaccessibility(
        const Shape& shape,
        const std::vector<Shape>& holes = {},
        ElementPos number_of_line_segments = 12);

}