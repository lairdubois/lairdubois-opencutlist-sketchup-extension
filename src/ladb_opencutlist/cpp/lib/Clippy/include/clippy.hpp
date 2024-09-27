#include <cstddef>
#include <cstdint>
#include <cstdbool>

#include "clipper2/clipper.wrapper.hpp"

using namespace Clipper2Lib;

constexpr auto CLIPPY_VERSION = "1.0.0";

typedef struct {
    CPathsD closed_paths;
    CPathsD open_paths;
    int64_t error;
} CPathsDSolution;

typedef struct {
    CPolyTreeD polytree;
    CPathsD open_paths;
    int error;
} CPolyTreeDSolution;

#ifdef __cplusplus
extern "C" {
#endif

#ifdef LIBCLIPPY_EXPORTS
#define DLL_EXPORTS __declspec(dllexport)
#else
#define DLL_EXPORTS
#endif

DLL_EXPORTS CPathsDSolution* c_boolean_op(
        uint8_t clip_type,
        uint8_t fill_rule,
        CPathsD closed_subjects,
        CPathsD open_subjects,
        CPathsD clips
);
DLL_EXPORTS CPolyTreeDSolution* c_boolean_op_polytree(
        uint8_t clip_type,
        uint8_t fill_rule,
        CPathsD closed_subjects,
        CPathsD open_subjects,
        CPathsD clips
);

DLL_EXPORTS CPathsDSolution* c_inflate_paths(
        CPathsD paths,
        double delta,
        uint8_t join_type,
        uint8_t end_type,
        double miter_limit = 2.0,
        double arc_tolerance = 1e6,
        int preserve_collinear = 0,
        int reverse_solution = 0
);

DLL_EXPORTS int c_is_cpath_positive(
        CPathD cpath
);
DLL_EXPORTS double c_get_cpath_area(
        CPathD cpath
);

DLL_EXPORTS void c_dispose_paths_solution(
        CPathsDSolution* p
);
DLL_EXPORTS void c_dispose_polytree_solution(
        CPolyTreeDSolution* p
);

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif