#include "shape/labeling.hpp"

using namespace shape;

using Poly = std::vector<Point>;
using Polys = std::vector<Poly>;

/**
 * Convert a Shape to a list of vertex.
 *
 * @param shape The outline shape
 * @param outer Define if the shape represents an outline or hole.
 * @param segment_length The length of each line segment used to approximate circular arcs.
 * @return A Poly
 */
Poly shape_to_poly(
        const Shape& shape,
        const bool outer,
        const LengthDbl segment_length = 1)
{
    Poly poly;
    for (const auto& element: shape.elements) {
        switch (element.type) {
            case ShapeElementType::LineSegment:
                poly.emplace_back(element.start);
                break;
            case ShapeElementType::CircularArc:
                for (const auto& e: approximate_circular_arc_by_line_segments(element, segment_length, outer)) {
                    poly.emplace_back(element.start);
                }
                break;
        }
    }
    // Close the "Poly" by adding the last vertex at the end
    if (!shape.elements.empty())
        poly.emplace_back(shape.elements.back().end);
    return std::move(poly);
}

/**
 * Scale the given point position by a specified factor.
 *
 * @param point The point to scale.
 * @param factor The scaling factor to be applied to the point.
 * @return The scaled point.
 */
Point scale(
        const Point& point,
        const LengthDbl factor)
{
    return Point{point.x * factor, point.y * factor};
}

/**
 * Determines if a point lies on a line segment.
 *
 * @param segment The line segment defined by a pair of points (start, end)
 * @param point The point to test
 * @return true if the point lies on the line segment, false otherwise
 */
bool on_segment(
        const std::pair<Point, Point>& segment,
        const Point& point)
{
    if (point.x > std::fmax(segment.first.x, segment.second.x)
           || point.x < std::fmin(segment.first.x, segment.second.x)
           || point.y > std::fmax(segment.first.y, segment.second.y)
           || point.y < std::fmin(segment.first.y, segment.second.y))
            return false;

    return equal(cross_product(segment.second - segment.first, segment.second - point), 0.0);
}

/**
 * Computes the intersection point of two lines using Cramer's rule.
 * Each line is defined by a pair of points.
 *
 * @param line1 First line segment defined by a pair of points (start, end)
 * @param line2 Second line segment defined by a pair of points (start, end)
 * @param inter Reference to a Point that will store the intersection coordinates if it exists
 * @return true if the lines intersect at a unique point, false if they are parallel or coincident
 *
 * The function uses the general form of a line equation: ax + by = c
 * For each line, it calculates coefficients a, b, c and then uses
 * Cramer's rule to solve the system of equations.
 */
bool line_inter(
    const std::pair<Point, Point>& line1,
    const std::pair<Point, Point>& line2,
    Point& inter)
{
    LengthDbl a1 = line1.second.y - line1.first.y;
    LengthDbl b1 = line1.first.x - line1.second.x;
    LengthDbl c1 = a1 * line1.first.x + b1 * line1.first.y;

    LengthDbl a2 = line2.second.y - line2.first.y;
    LengthDbl b2 = line2.first.x - line2.second.x;
    LengthDbl c2 = a2 * line2.first.x + b2 * line2.first.y;

    LengthDbl det = a1 * b2 - a2 * b1;

    if (det == 0)
        return false;

    inter.x = (b2 * c1 - b1 * c2) / det;
    inter.y = (a1 * c2 - a2 * c1) / det;
    return true;
}

/**
 * Determines if two-line segments intersect and finds their intersection point if they do.
 *
 * @param segment1 First line segment defined by a pair of points (start, end)
 * @param segment2 Second line segment defined by a pair of points (start, end)
 * @param inter Reference to a Point that will store the intersection coordinates if found
 * @return True if the segments intersect (including if they intersect at an endpoint),
 *         false otherwise
 *
 * The function first computes the orientation of points using counter_clockwise checks.
 * It handles both general intersection cases and special cases where:
 * - Segments intersect at a non-endpoint
 * - One segment's endpoint lies on the other segment
 */
bool segments_intersect(
        const std::pair<Point, Point>& segment1,
        const std::pair<Point, Point>& segment2,
        Point& inter)
{
    int o1 = shape::counter_clockwise(segment1.first, segment1.second, segment2.first);
    int o2 = shape::counter_clockwise(segment1.first, segment1.second, segment2.second);
    int o3 = shape::counter_clockwise(segment2.first, segment2.second, segment1.first);
    int o4 = shape::counter_clockwise(segment2.first, segment2.second, segment1.second);

    if (o1 != o2 && o3 != o4)
        return line_inter({segment1.first, segment1.second}, {segment2.first, segment2.second}, inter);

    if (o1 == 0 && on_segment({segment1.first, segment1.second}, segment2.first)) {
        inter = segment2.first;
        return true;
    }

    if (o2 == 0 && on_segment({segment1.first, segment1.second}, segment2.second)) {
        inter = segment2.second;
        return true;
    }

    if (o3 == 0 && on_segment({segment2.first, segment2.second}, segment1.first)) {
        inter = segment1.first;
        return true;
    }

    if (o4 == 0 && on_segment({segment2.first, segment2.second}, segment1.second)) {
        inter = segment1.second;
        return true;
    }

    return false;
}

/**
 * This function is used to determine the relative position of an intersection point with respect to a given direction.
 *
 * @param label_position The reference point from which distances are measured
 * @param far A point defining the direction vector (with label_position)
 * @param inter The intersection point to measure the signed distance to
 * @return The signed distance value:
 *         - Positive if inter is in the same direction as the far point
 *         - Negative if inter is in the opposite direction
 *         - Near zero if inter is perpendicular to the direction
 *
 * The function works by:
 * 1. Creating vectors from label_position to both far and inter points
 * 2. Normalizing the vector to far point
 * 3. Computing dot product to determine relative position
 */
LengthDbl signed_distance(
        const Point& label_position,
        const Point& far,
        const Point& inter)
{
    Point vector_label_position_far = far - label_position;
    Point vector_label_position_inter = inter - label_position;
    LengthDbl length_label_position_far = distance(vector_label_position_far, Point());
    Point normalized_vector_label_position_far = scale(vector_label_position_far, (1.0 / length_label_position_far));
    return dot_product(vector_label_position_inter, normalized_vector_label_position_far);
}

/**
 * Sorts two parallel vectors using the insertion sort algorithm.
 * The first vector (interdists) is used as the sorting key,
 * and the second vector (inters) is reordered accordingly
 * to maintain the correspondence between elements.
 *
 * @param interdists Vector of distances to be sorted in ascending order
 * @param inters Vector of points to be reordered based on interdists sorting
 *
 * Note: Both vectors must have the same size. The function modifies
 * both vectors in-place.
 */
void sort_and_reorder(
        std::vector<LengthDbl>& interdists,
        std::vector<Point>& inters)
{
    for (size_t i = 1; i < interdists.size(); i++) {
        LengthDbl key_dist = interdists[i];
        Point key_inter = inters[i];
        int j = i - 1;
        while (j >= 0 && interdists[j] > key_dist) {
            interdists[j + 1] = interdists[j];
            inters[j + 1] = inters[j];
            j--;
        }
        interdists[j + 1] = key_dist;
        inters[j + 1] = key_inter;
    }
}

/**
 * Finds the nearest point on a line segment to a given point.
 *
 * @param segment The line segment defined by a pair of points (start, end)
 * @param point The reference point to find the nearest point from
 * @param result The resulting nearest point (modified by reference)
 * @return The distance between the given point and the nearest point found on the segment.
 */
LengthDbl closest_point_on_segment(
        const std::pair<Point, Point>& segment,
        const Point& point,
        Point& result)
{
    const Point vab = segment.second - segment.first;
    const Point vpa = point - segment.first;

    LengthDbl ab2 = dot_product(vab, vab);
    if (ab2 == 0.0) {
        result = segment.first;
        return distance(point, segment.first);
    }

    LengthDbl t = dot_product(vpa, vab) / ab2;
    if (t < 0.0)
        t = 0.0;
    else if (t > 1.0)
        t = 1.0;

    Point projection = scale(vab, t);
    result = segment.first + projection;

    return distance(point, result);
}

/**
 * Finds the closest point on the boundary of a polygon to a given exterior point.
 *
 * @param poly The polygon represented as a vector of points
 * @param exterior The reference point outside the polygon to find the closest point from
 * @param closest The resulting closest point on the polygon boundary (modified by reference)
 *
 * The function iterates through all segments of the polygon and:
 * 1. Calculates the closest point on each segment to the exterior point
 * 2. Keeps track of the minimum distance found
 * 3. Updates the result when a closer point is found
 */
void find_closest_point_on_boundary(
        const Poly& poly,
        const Point& exterior,
        Point& closest)
{
    LengthDbl min_dist = std::numeric_limits<LengthDbl>::max();
    Point test{};

    for (size_t i = 0; i < poly.size() - 1; i++) {
        LengthDbl dist = closest_point_on_segment({poly[i], poly[i + 1]}, exterior, test);
        if (dist < min_dist) {
            min_dist = dist;
            closest = test;
        }
    }
}

/**
 * Calculates the centroid (geometric center) and area of a polygon.
 *
 * @param poly The polygon represented as a vector of points
 * @param centroid Output parameter that will store the calculated centroid coordinates
 * @param area Output parameter that will store the calculated area of the polygon
 *
 * The function uses the geometric decomposition method to calculate both the centroid
 * and area of the polygon:
 * 1. Iterates through consecutive pairs of vertices
 * 2. Computes cross products to find signed areas of triangles
 * 3. Accumulates weighted sums for x and y coordinates
 * 4. Finally computes the centroid using the accumulated values divided by the total area
 *
 * Note: The polygon should be closed (last point equals first point) and vertices
 * should be ordered counter-clockwise for positive areas.
 */
void polygon_centroid(
        const Poly& poly,
        Point& centroid,
        AreaDbl& area)
{
    area = 0.0;
    LengthDbl sum_Cx = 0.0;
    LengthDbl sum_Cy = 0.0;

    for (size_t i = 0; i < poly.size() - 1; i++) {
        size_t next_i = i + 1;
        LengthDbl cross_product = shape::cross_product(poly[i], poly[next_i]);
        area += cross_product;
        sum_Cx += (poly[i].x + poly[next_i].x) * cross_product;
        sum_Cy += (poly[i].y + poly[next_i].y) * cross_product;
    }

    area /= 2.0;
    centroid.x = sum_Cx / (6.0 * area);
    centroid.y = sum_Cy / (6.0 * area);
}

Point shape::find_label_position(
        const ShapeWithHoles& shape)
{

    // Convert shape and holes to one unique Polys where the first Poly child is the outer polygon.
    Polys polys;
    polys.emplace_back(shape_to_poly(shape.shape, true));
    for (const auto& hole : shape.holes) {
        polys.emplace_back(shape_to_poly(hole, false));
    }

    // Scale all Polys (full geometry) to the unit square starting at (0,0), for convenience
    Point shift{std::numeric_limits<LengthDbl>::max(), std::numeric_limits<LengthDbl>::max()};
    LengthDbl magnify = -std::numeric_limits<LengthDbl>::max();

    for (const auto& poly : polys) {
        for (const auto& vertex : poly) {
            if (vertex.x < shift.x) shift.x = vertex.x;
            if (vertex.y < shift.y) shift.y = vertex.y;
            if (vertex.x > magnify) magnify = vertex.x;
            if (vertex.y > magnify) magnify = vertex.y;
        }
    }

    Polys shifted_polys = polys;
    for (auto& poly : shifted_polys) {
        for (auto& vertex : poly) {
            vertex = vertex - shift;
            vertex = scale(vertex, (1.0 / magnify));
        }
    }

    // Compute true centroid (accounting for the holes)
    Point centroid{0, 0};
    AreaDbl total_area = 0.0;
    Point tmppos{};
    AreaDbl area;

    for (const auto& poly : shifted_polys) {
        polygon_centroid(poly, tmppos, area);
        if (&poly != &shifted_polys[0])
            area *= -1;
        centroid = centroid + scale(tmppos, area);
        total_area += area;
    }
    centroid = scale(centroid, (1.0 / total_area));

    // Compute distance (min_dist) and vector (v) from centroid to nearest point of the countour
    LengthDbl min_dist = std::numeric_limits<LengthDbl>::max();
    Point closest{};

    for (const auto& poly : shifted_polys) {
        find_closest_point_on_boundary(poly, centroid, tmppos);
        LengthDbl dist = distance(centroid, tmppos);
        if (dist < min_dist) {
            min_dist = dist;
            closest = tmppos;
        }
    }

    Point v = closest - centroid;

    // Define points far upward (far1) and backward (far2) from centroid, along v
    // Thanks to scale(...), we are sure that these points are passed the geometry
    Point far1 = centroid + scale(v, (10.0 / min_dist));
    Point far2 = centroid - scale(v, (10.0 / min_dist));

    std::vector<Point> inters;
    std::vector<LengthDbl> interdists;

    // Compute the number of intersection points between the line parallel to v and the geometry
    // and sort them according to their position along the line
    for (const auto& poly : shifted_polys) {
        for (size_t j = 0; j < poly.size() - 1; j++) {
            Point inter{};
            if (segments_intersect({poly[j], poly[j + 1]}, {far1, far2}, inter)) {
                bool unique = true;
                for (const auto& existing_inter : inters) {
                    if (distance(inter, existing_inter) < 1e-6) {
                        unique = false;
                        break;
                    }
                }
                if (unique) {
                    inters.push_back(inter);
                    interdists.push_back(signed_distance(centroid, far1, inter));
                }
            }
        }
    }

    sort_and_reorder(interdists, inters);

    // Search for the longer intersection segment
    // Each segment is based on one intersection point and the next (in inters)
    // Note that we start with the first segment (which is inside the geometry)
    // and then we skip every other segment (i += 2), because, as we go through
    // the intersection segments, they are inside and outside the geometry,
    // successively.
    LengthDbl max_length = -std::numeric_limits<LengthDbl>::max();
    size_t id = -1;

    for (size_t i = 0; i < inters.size() - 1; i += 2) {
        if (LengthDbl length = distance(inters[i], inters[i + 1]); length > max_length) {
            max_length = length;
            id = i;
        }
    }

    // Place label at the center of the longest intersection segment
    Point label_position = inters[id] + inters[id + 1];
    label_position = scale(label_position, 0.5);

    // Transform back to the original geometry
    label_position = scale(label_position, magnify) + shift;

    return label_position;
}
