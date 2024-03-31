#ifndef CLIPPER_WRAPPER_H
#define CLIPPER_WRAPPER_H

#include "clipper2/clipper.h"

namespace Clipper2Lib {

  // Path manipulators

  Path64 ConvertCPathToPath(const int64_t *cpath);

  Paths64 ConvertCPathsToPaths(const int64_t *cpaths);


  void GetPathCountAndCPathsArrayLen(const Paths64 &paths, size_t &cnt, size_t &array_len);

  size_t GetPolyPath64ArrayLen(const PolyPath64 &polypath);

  void GetPolytreeCountAndCArrayLen(const PolyTree64 &tree, size_t &cnt, size_t &array_len);


  int64_t *ConvertPathsToCPaths(const Paths64 &paths);

  void ConvertPolyPathToCPolyPath(const PolyPath64 *polypath, int64_t *&v);

  int64_t *ConvertPolyTreeToCPolyTree(const PolyTree64 &polytree);


  // Boolean Ops

  void ExecuteBooleanOp(ClipType clip_type, Paths64 &closed_subjects, Paths64 &open_subjects, Paths64 &clips,
                        Paths64 &closed_paths_solution, Paths64 &open_paths_solution, bool preserve_colinear = false);

  void ExecuteBooleanOp(ClipType clip_type, Paths64 &closed_subjects, Paths64 &open_subjects, Paths64 &clips,
                        PolyTree64 &polytree_solution, Paths64 &open_paths_solution, bool preserve_colinear = false);

}

#endif // CLIPPER_WRAPPER_H
