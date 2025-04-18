#pragma once

#include "shape/shape.hpp"

namespace shape
{

/**
 * Computes the approximate pole of inaccessibility for a given shape, which is the point farthest from the edges of the shape.
 * 1/ exact calculation of the geometric center (C),
 * 2/ search for the closest point (P) on the contour,
 * 3/ we consider the line (CP), we search for all the segments of this line which intersect the geometry, and we take the center of the longest.
 *
 * @param shape The outline shape
 * @param holes List of hole shapes
 * @param number_of_line_segments the number of line segments used to approximate circular arcs.
 * @return A point representing the computed approximate pole of inaccessibility within the shape.
 */
Point approximate_pole_of_inaccessibility(
        const Shape& shape,
        const std::vector<Shape>& holes = {},
        ElementPos number_of_line_segments = 12);

}