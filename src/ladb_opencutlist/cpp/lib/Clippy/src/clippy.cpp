#include "clippy.hpp"

using namespace Clipper2Lib;

#ifdef __cplusplus
extern "C" {
#endif

DLL_EXPORTS CPathsDSolution* c_boolean_op(
        uint8_t clip_type,
        uint8_t fill_rule,
        CPathD closed_subjects,
        CPathD open_subjects,
        CPathD clips
) {

    auto* solution = CreateEmptyCPathsDSolution();

    solution->error = BooleanOpD(
            clip_type,
            fill_rule,
            closed_subjects,
            open_subjects,
            clips,
            solution->closed_paths,
            solution->open_paths,
            CLIPPY_PRECISION,
            false,
            false
    );

    return solution;
}

DLL_EXPORTS CPolyTreeDSolution* c_boolean_op_polytree(
        uint8_t clip_type,
        uint8_t fill_rule,
        CPathD closed_subjects,
        CPathD open_subjects,
        CPathD clips
) {

    auto* solution = CreateEmptyCPolyTreeDSolution();

    solution->error = BooleanOp_PolyTreeD(
            clip_type,
            fill_rule,
            closed_subjects,
            open_subjects,
            clips,
            solution->polytree,
            solution->open_paths
    );

    return solution;
}

DLL_EXPORTS CPathsDSolution* c_inflate_paths(
        CPathsD paths,
        double delta,
        uint8_t join_type,
        uint8_t end_type,
        double miter_limit,
        double arc_tolerance,
        int preserve_collinear,
        int reverse_solution
) {

    auto* solution = CreateEmptyCPathsDSolution();

    solution->error = InflatePathsD(
            paths,
            delta,
            solution->closed_paths,
            join_type,
            end_type,
            CLIPPY_PRECISION,
            miter_limit,
            arc_tolerance,
            preserve_collinear,
            reverse_solution
    );

    return solution;
}

DLL_EXPORTS int c_is_cpath_positive(
        CPathD cpath
) {
    return IsPositive(ConvertCPath(cpath)) ? 1 : 0;
}

DLL_EXPORTS double c_get_cpath_area(
        CPathD cpath
) {
    return Area(ConvertCPath(cpath));
}


DLL_EXPORTS int c_is_point_on_polygon(
        double x,
        double y,
        CPathD cpath
) {
    if (PointOnPath(PointD(x, y), ConvertCPath(cpath), true)) {
        return 1;
    }
    return 0;
}
DLL_EXPORTS int c_is_mid_point_on_polygon(
        double x1,
        double y1,
        double x2,
        double y2,
        CPathD cpath
) {
    if (PointOnPath(MidPoint(PointD(x1, y1), PointD(x2, y2)), ConvertCPath(cpath), true)) {
        return 1;
    }
    return 0;
}

DLL_EXPORTS void c_dispose_paths_solution(
    CPathsDSolution* p
) {
    delete[] p->closed_paths;
    delete[] p->open_paths;
    free(p);
}

DLL_EXPORTS void c_dispose_polytree_solution(
        CPolyTreeDSolution* p
) {
    delete[] p->polytree;
    delete[] p->open_paths;
    free(p);
}


DLL_EXPORTS char* c_version() {
    return const_cast<char*>(CLIPPY_VERSION);
}

#ifdef __cplusplus
}
#endif