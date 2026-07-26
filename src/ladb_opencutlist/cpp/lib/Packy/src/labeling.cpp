#include "shape/labeling.hpp"

#include <queue>

using namespace shape;

static constexpr double SQRT2 = 1.4142135623730951;

/**
 * Distance from a point to a line segment.
 *
 * @param start The first endpoint of the segment.
 * @param end   The second endpoint of the segment.
 * @param point The query point.
 * @return The distance between the point and the nearest point on the segment.
 */
LengthDbl distance_point_to_segment(
        const Point& start,
        const Point& end,
        const Point& point)
{
    const Point vab = end - start;
    const Point vpa = point - start;

    LengthDbl ab2 = dot_product(vab, vab);
    if (ab2 == 0.0) {
        return distance(point, start);
    }

    LengthDbl t = dot_product(vpa, vab) / ab2;
    if (t < 0.0) {
        t = 0.0;
    } else if (t > 1.0) {
        t = 1.0;
    }

    return distance(point, {start.x + t * vab.x, start.y + t * vab.y});
}

/**
 * Distance from a point to a single shape element.
 *
 * Works directly on the native PackingSolver element, avoiding any polygon
 * conversion. For circular arcs the distance is computed exactly:
 * - if the point projects radially inside the arc cone, the distance is the
 *   gap to the circle: |dist(point, center) - radius|;
 * - otherwise the nearest point is one of the two arc endpoints.
 *
 * @param element The shape element (line segment or circular arc).
 * @param point   The query point.
 * @return The distance between the point and the element.
 */
LengthDbl distance_point_to_element(
        const ShapeElement& element,
        const Point& point)
{
    if (element.type == ShapeElementType::LineSegment) {
        return distance_point_to_segment(element.start, element.end, point);
    }

    if (element.type == ShapeElementType::CircularArc) {
        LengthDbl radius = distance(element.center, element.start);
        // Arc cone test: element.length(point) only depends on the direction
        // of (point - center) - it is the arc length from the start to the
        // radial projection of the point on the circle - so the point projects
        // radially inside the arc iff that length does not exceed the arc's
        // own length. (Full arcs always pass: the angle stays in [0, 2*pi).)
        if (!strictly_greater(element.length(point), element.length())) {
            return std::abs(distance(point, element.center) - radius);
        }
    }

    return std::min(
            distance(point, element.start),
            distance(point, element.end));
}

/**
 * Minimum distance from a point to the boundary of a shape with holes
 * (outer contour and every hole), iterating over native shape elements.
 *
 * @param shape_with_holes The shape with optional holes.
 * @param point            The query point.
 * @return The distance to the nearest boundary element.
 */
LengthDbl distance_to_boundary(
        const ShapeWithHoles& shape_with_holes,
        const Point& point)
{
    LengthDbl min_dist = std::numeric_limits<LengthDbl>::max();
    for (const auto& element : shape_with_holes.shape.elements) {
        min_dist = std::min(min_dist, distance_point_to_element(element, point));
    }
    for (const auto& hole : shape_with_holes.holes) {
        for (const auto& element : hole.elements) {
            min_dist = std::min(min_dist, distance_point_to_element(element, point));
        }
    }
    return min_dist;
}

/**
 * Finds the optimal label position inside a shape using the Polylabel algorithm.
 *
 * Finds the pole of inaccessibility: the interior point farthest from all
 * boundaries (outer contour and holes). Equivalent to the center of the
 * largest inscribed circle.
 *
 * Based on: Mapbox Polylabel (https://github.com/mapbox/polylabel)
 * Complexity: O(n * log(1/epsilon) * log(n))
 *
 * @param shape_with_holes The shape with optional holes.
 * @return The point with maximum clearance from all boundaries.
 */
Point shape::find_label_position(
        const ShapeWithHoles& shape_with_holes)
{
    AxisAlignedBoundingBox aabb = shape_with_holes.shape.compute_min_max();
    LengthDbl width     = aabb.x_max - aabb.x_min;
    LengthDbl height    = aabb.y_max - aabb.y_min;
    LengthDbl cell_size = std::min(width, height);

    if (cell_size == 0) {
        return {aabb.x_min, aabb.y_min};
    }

    // A cell covers a square of side 2*half centred on `center`.
    // dist = signed distance from center to the nearest boundary element:
    //        positive if inside the shape, negative if outside.
    // max  = maximum achievable dist for any point in this cell
    //      = dist + half * sqrt(2)  (distance to the farthest corner).
    struct Cell {
        Point     center;
        LengthDbl half;
        LengthDbl dist;
        LengthDbl max;
    };

    // Build a cell and compute its signed distance to the boundary,
    // working directly on the native shape elements.
    auto make_cell = [&](const Point& p, LengthDbl half) -> Cell {
        LengthDbl d = distance_to_boundary(shape_with_holes, p);
        LengthDbl dist = shape_with_holes.contains(p) ? d : -d;
        return {p, half, dist, dist + half * SQRT2};
    };

    // Max-priority queue: explore the most-promising cells first.
    auto cmp = [](const Cell& a, const Cell& b) { return a.max < b.max; };
    std::priority_queue<Cell, std::vector<Cell>, decltype(cmp)> queue(cmp);

    // Seed with a grid of cells covering the full bounding box.
    LengthDbl h = cell_size / 2.0;
    for (LengthDbl x = aabb.x_min; x < aabb.x_max; x += cell_size) {
        for (LengthDbl y = aabb.y_min; y < aabb.y_max; y += cell_size) {
            queue.push(make_cell({x + h, y + h}, h));
        }
    }

    // Initialize the best candidate with the bounding-box centroid.
    Cell best = make_cell(
        {(aabb.x_min + aabb.x_max) / 2.0, (aabb.y_min + aabb.y_max) / 2.0},
        0);

    // Stop refining when no cell can beat the best by more than epsilon.
    const LengthDbl epsilon = cell_size * 0.001;

    while (!queue.empty()) {
        Cell cell = queue.top();
        queue.pop();

        if (cell.dist > best.dist) {
            best = cell;
        }

        // Prune: this cell cannot improve on the current best.
        if (cell.max - best.dist <= epsilon) {
            continue;
        }

        // Subdivide into 4 quadrants and enqueue each.
        h = cell.half / 2.0;
        queue.push(make_cell({cell.center.x - h, cell.center.y - h}, h));
        queue.push(make_cell({cell.center.x + h, cell.center.y - h}, h));
        queue.push(make_cell({cell.center.x - h, cell.center.y + h}, h));
        queue.push(make_cell({cell.center.x + h, cell.center.y + h}, h));
    }

    return best.center;
}