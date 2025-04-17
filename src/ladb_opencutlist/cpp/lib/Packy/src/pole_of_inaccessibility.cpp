#include "shape/pole_of_inaccessibility.hpp"

using namespace shape;

using Poly = std::vector<Point>;
using Polys = std::vector<Poly>;

Poly shape_to_poly(
        const Shape& shape,
        ElementPos number_of_line_segments,
        bool outer)
{
    Poly poly;
    for (const auto& element : shape.elements) {
        switch (element.type) {
        case ShapeElementType::LineSegment: {
            poly.emplace_back(element.start);
            break;
        } case ShapeElementType::CircularArc: {
            for (const auto& e : approximate_circular_arc_by_line_segments(element, number_of_line_segments, outer)) {
                poly.emplace_back(element.start);
            }
            break;
        }
        }
    }
    if (!shape.elements.empty())
        poly.emplace_back(shape.elements.back().end);
    return poly;
}

Point offset(
        Point& p,
        LengthDbl scalar)
{
    return Point{p.x * scalar, p.y * scalar};
}

int orientation(
        const Point& p,
        const Point& q,
        const Point& r)
{
    LengthDbl val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
    return (val == 0) ? 0 : ((val > 0) ? 1 : 2);
}

bool on_segment(
        const Point& p,
        const Point& q,
        const Point& r)
{
    return (q.x <= std::fmax(p.x, r.x) && q.x >= std::fmin(p.x, r.x) && q.y <= std::fmax(p.y, r.y) && q.y >= std::fmin(p.y, r.y));
}

bool line_inter(
        const Point& p1,
        const Point& q1,
        const Point& p2,
        const Point& q2,
        Point& inter)
{
    LengthDbl a1 = q1.y - p1.y;
    LengthDbl b1 = p1.x - q1.x;
    LengthDbl c1 = a1 * p1.x + b1 * p1.y;

    LengthDbl a2 = q2.y - p2.y;
    LengthDbl b2 = p2.x - q2.x;
    LengthDbl c2 = a2 * p2.x + b2 * p2.y;

    LengthDbl det = a1 * b2 - a2 * b1;

    if (det == 0)
        return false;
    else {
        inter.x = (b2 * c1 - b1 * c2) / det;
        inter.y = (a1 * c2 - a2 * c1) / det;
        return true;
    }
}

bool segments_intersect(
        const Point& p1,
        const Point& q1,
        const Point& p2,
        const Point& q2,
        Point& inter)
{
    int o1 = orientation(p1, q1, p2);
    int o2 = orientation(p1, q1, q2);
    int o3 = orientation(p2, q2, p1);
    int o4 = orientation(p2, q2, q1);

    if (o1 != o2 && o3 != o4)
        return line_inter(p1, q1, p2, q2, inter);

    if (o1 == 0 && on_segment(p1, p2, q1)) {
        inter = p2;
        return true;
    }

    if (o2 == 0 && on_segment(p1, q2, q1)) {
        inter = q2;
        return true;
    }

    if (o3 == 0 && on_segment(p2, p1, q2)) {
        inter = p1;
        return true;
    }

    if (o4 == 0 && on_segment(p2, q1, q2)) {
        inter = q1;
        return true;
    }

    return false;
}

LengthDbl signed_distance(
        const Point& poi,
        const Point& far,
        const Point& inter)
{
    Point vector_poi_far = far - poi;
    Point vector_poi_inter = inter - poi;
    LengthDbl length_poi_far = distance(vector_poi_far, Point());
    Point normalized_vector_poi_far = offset(vector_poi_far, (1.0 / length_poi_far));
    return dot_product(vector_poi_inter, normalized_vector_poi_far);
}

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

LengthDbl closest_pt_on_segment(
        const Point& A,
        const Point& B,
        const Point& O,
        Point& result)
{
    Point AB = B - A;
    Point AO = O - A;

    LengthDbl ab2 = dot_product(AB, AB);
    if (ab2 == 0.0) {
        result = A;
        return distance(O, A);
    }

    LengthDbl t = dot_product(AO, AB) / ab2;
    if (t < 0.0)
        t = 0.0;
    else if (t > 1.0)
        t = 1.0;

    Point projection = offset(AB, t);
    result = A + projection;

    return distance(O, result);
}

void find_closest_pt_on_boundary(
        const Poly& poly,
        const Point& exterior,
        Point& closest)
{
    LengthDbl min_dist = std::numeric_limits<LengthDbl>::max();
    Point test{};

    for (size_t i = 0; i < poly.size() - 1; i++) {
        LengthDbl dist = closest_pt_on_segment(poly[i], poly[i + 1], exterior, test);
        if (dist < min_dist) {
            min_dist = dist;
            closest = test;
        }
    }
}

void polygon_centroid(
        const Poly& poly,
        Point& centroid,
        AreaDbl& area)
{
    area = 0.0;
    LengthDbl sum_Cx = 0.0;
    LengthDbl sum_Cy = 0.0;

    for (size_t i = 0; i < poly.size() - 1; i++) {
        size_t next = i + 1;
        LengthDbl cross_product = poly[i].x * poly[next].y - poly[next].x * poly[i].y;
        area += cross_product;
        sum_Cx += (poly[i].x + poly[next].x) * cross_product;
        sum_Cy += (poly[i].y + poly[next].y) * cross_product;
    }

    area /= 2.0;
    centroid.x = sum_Cx / (6.0 * area);
    centroid.y = sum_Cy / (6.0 * area);
}

Point shape::approximate_pole_of_inaccessibility(
        const Shape& shape,
        const std::vector<Shape>& holes,
        ElementPos number_of_line_segments)
{
    Polys polys;
    polys.emplace_back(shape_to_poly(shape, number_of_line_segments, true));
    for (const auto& hole : holes) {
        polys.emplace_back(shape_to_poly(hole, number_of_line_segments, false));
    }

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
            vertex = offset(vertex, (1.0 / magnify));
        }
    }

    Point centroid{0, 0};
    AreaDbl total_area = 0.0;
    Point tmppos{};
    AreaDbl area;

    for (const auto& poly : shifted_polys) {
        polygon_centroid(poly, tmppos, area);
        if (&poly != &shifted_polys[0])
            area *= -1;
        centroid = centroid + offset(tmppos, area);
        total_area += area;
    }
    centroid = offset(centroid, (1.0 / total_area));

    LengthDbl min_dist = std::numeric_limits<LengthDbl>::max();
    Point closest{};

    for (const auto& poly : shifted_polys) {
        find_closest_pt_on_boundary(poly, centroid, tmppos);
        LengthDbl dist = distance(centroid, tmppos);
        if (dist < min_dist) {
            min_dist = dist;
            closest = tmppos;
        }
    }

    Point p = closest - centroid;

    Point far1 = centroid + offset(p, (10.0 / min_dist));
    Point far2 = centroid - offset(p, (10.0 / min_dist));

    std::vector<Point> inters;
    std::vector<LengthDbl> interdists;

    for (const auto& poly : shifted_polys) {
        for (size_t j = 0; j < poly.size() - 1; j++) {
            Point inter{};
            if (segments_intersect(poly[j], poly[j + 1], far1, far2, inter)) {
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

    LengthDbl max_length = -std::numeric_limits<LengthDbl>::max();
    int id = -1;

    for (size_t i = 0; i < inters.size() - 1; i += 2) {
        LengthDbl length = distance(inters[i], inters[i + 1]);
        if (length > max_length) {
            max_length = length;
            id = i;
        }
    }

    Point poi = inters[id] + inters[id + 1];

    poi = offset(poi, 0.5);
    poi = offset(poi, magnify) + shift;

    return poi;
}