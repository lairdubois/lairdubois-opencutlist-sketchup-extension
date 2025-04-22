#pragma once

#include "shape/shape.hpp"

namespace shape
{

/**
 * Computes an optimal label position for a given shape.
 * 1/ exact calculation of the geometric center (C),
 * 2/ search for the closest point (P) on the contour,
 * 3/ we consider the line (CP), we search for all the segments of this line which intersect the geometry, and we take the center of the longest.
 *
 * @param shape The outline shape
 * @param holes List of hole shapes
 * @param number_of_line_segments The number of line segments used to approximate circular arcs.
 * @return A point representing the computed labeling position.
 */
Point find_label_position(
        const Shape& shape,
        const std::vector<Shape>& holes = {},
        ElementPos number_of_line_segments = 12);

}