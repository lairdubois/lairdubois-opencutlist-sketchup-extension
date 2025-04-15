#pragma once

#include "shape/shape.hpp"

namespace shape
{

Point find_approx_pole_of_inaccessibility(
    const Shape& shape,
    const std::vector<Shape>& holes = {});

}