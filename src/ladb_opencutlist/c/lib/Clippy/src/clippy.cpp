#include "clippy.hpp"

using namespace Clipper2Lib;

#ifdef __cplusplus
extern "C" {
#endif

DLL_EXPORTS CPathsDSolution* c_boolean_op(uint8_t clip_type, uint8_t fill_rule, CPathD closed_subjects, CPathD open_subjects, CPathD clips) {

  CPathsDSolution *solution = (CPathsDSolution *)malloc(sizeof(CPathsDSolution));

  solution->error = Clipper2Lib::BooleanOpD(
          clip_type,
          fill_rule,
          closed_subjects,
          open_subjects,
          clips,
          solution->closed_paths,
          solution->open_paths
  );

  return solution;
}

DLL_EXPORTS CPolyTreeDSolution* c_boolean_op_polytree(uint8_t clip_type, uint8_t fill_rule, CPathD closed_subjects, CPathD open_subjects, CPathD clips) {

  CPolyTreeDSolution *solution = (CPolyTreeDSolution *)malloc(sizeof(CPolyTreeDSolution));

  solution->error = Clipper2Lib::BooleanOp_PolyTreeD(
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

DLL_EXPORTS int c_is_cpath_positive(CPathD cpath) {
  return IsPositive(ConvertCPath(cpath)) ? 1 : 0;
}

DLL_EXPORTS double c_get_cpath_area(CPathD cpath) {
  return Area(ConvertCPath(cpath));
}


DLL_EXPORTS void c_free_pointer(void* p) {
  free(p);
}

DLL_EXPORTS void c_dispose_array_d(const CPathD p) {
  delete[] p;
}


DLL_EXPORTS char* c_version() {
  return (char *)CLIPPY_VERSION;
}

#ifdef __cplusplus
}
#endif