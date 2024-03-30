#include "clipper2/clipper.wrapper.h"

#include <clippy.h>

#ifdef __cplusplus
extern "C" {
#endif

Paths64 closed_subjects, open_subjects, clips;
Paths64 closed_paths_solution, open_paths_solution;
PolyTree64 polytree_solution;

DLL_EXPORTS void c_clear_subjects() {
  closed_subjects.clear();
  open_subjects.clear();
}

DLL_EXPORTS void c_append_closed_subject(const int64_t *cpath) {
  closed_subjects.push_back(ConvertCPathToPath(cpath));
}

DLL_EXPORTS void c_append_open_subject(const int64_t *cpath) {
  open_subjects.push_back(ConvertCPathToPath(cpath));
}


DLL_EXPORTS void c_clear_clips() {
  clips.clear();
}

DLL_EXPORTS void c_append_clip(const int64_t *cpath) {
  clips.push_back(ConvertCPathToPath(cpath));
}


DLL_EXPORTS void c_execute_union() {
  ExecuteBooleanOp(ClipType::Union, closed_subjects, open_subjects, clips, closed_paths_solution, open_paths_solution, false);
}

DLL_EXPORTS void c_execute_difference() {
  ExecuteBooleanOp(ClipType::Difference, closed_subjects, open_subjects, clips, closed_paths_solution, open_paths_solution, false);
}

DLL_EXPORTS void c_execute_intersection() {
  ExecuteBooleanOp(ClipType::Intersection, closed_subjects, open_subjects, clips, closed_paths_solution, open_paths_solution, false);
}

DLL_EXPORTS void c_execute_polytree() {
  ExecuteBooleanOp(ClipType::Union, closed_subjects, open_subjects, clips, polytree_solution, open_paths_solution, false);
}


DLL_EXPORTS void c_clear_paths_solution() {
  closed_paths_solution.clear();
  open_paths_solution.clear();
}

DLL_EXPORTS int64_t* c_get_closed_paths_solution() {
  return ConvertPathsToCPaths(closed_paths_solution);
}

DLL_EXPORTS int64_t* c_get_open_paths_solution() {
  return ConvertPathsToCPaths(open_paths_solution);
}

DLL_EXPORTS void c_clear_polytree_solution() {
  polytree_solution.Clear();
}

DLL_EXPORTS int64_t* c_get_polytree_solution() {
  return ConvertPolyTreeToCPolyTree(polytree_solution);
}


DLL_EXPORTS int c_is_cpath_positive(const int64_t* cpath) {
  return IsPositive(ConvertCPathToPath(cpath)) ? 1 : 0;
}

DLL_EXPORTS double c_get_cpath_area(const int64_t* cpath) {
  return Area(ConvertCPathToPath(cpath));
}


DLL_EXPORTS void c_dispose_array64(const int64_t* p) {
  delete[] p;
}


DLL_EXPORTS char* c_version() {
  return (char *)CLIPPY_VERSION;
}

#ifdef __cplusplus
}
#endif