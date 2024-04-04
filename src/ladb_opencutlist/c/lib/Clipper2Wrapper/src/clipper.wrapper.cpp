#include <clipper2/clipper.wrapper.h>

namespace Clipper2Lib {

  // Path manipulators

  Path64 ConvertCPathToPath(const int64_t *cpath) {
    Path64 result;
    if (!cpath) return result;
    const int64_t *v = cpath;
    size_t cnt = *v;
    v += 2;
    result.reserve(cnt);
    for (size_t i = 0; i < cnt; ++i) {
      int64_t x = *v++, y = *v++;
      result.emplace_back(x, y);
    }
    return result;
  }

  Paths64 ConvertCPathsToPaths(const int64_t *cpaths) {
    Paths64 result;
    if (!cpaths) return result;
    const int64_t *v = cpaths;
    ++v;
    size_t cnt = *v++;
    result.reserve(cnt);
    for (size_t i = 0; i < cnt; ++i) {
      result.push_back(ConvertCPathToPath(v));
    }
    return result;
  }


  void GetPathCountAndCPathsArrayLen(const Paths64 &paths, size_t &cnt, size_t &array_len) {
    array_len = 2;
    cnt = 0;
    for (const Path64 &path: paths) {
      if (path.empty()) continue;
      array_len += path.size() * 2 + 2;
      ++cnt;
    }
  }

  size_t GetPolyPath64ArrayLen(const PolyPath64 &polypath) {
    size_t result = 2; // poly_length + child_count
    result += polypath.Polygon().size() * 2;
    // + nested children
    for (size_t i = 0; i < polypath.Count(); ++i) {
      result += GetPolyPath64ArrayLen(*polypath[i]);
    }
    return result;
  }

  void GetPolytreeCountAndCArrayLen(const PolyTree64 &tree, size_t &cnt, size_t &array_len) {
    cnt = tree.Count(); // nb: top level count only
    array_len = GetPolyPath64ArrayLen(tree);
  }


  int64_t* ConvertPathsToCPaths(const Paths64 &paths) {

    /*

     Paths
      |counter|path1|path2|...|pathN
      |L  ,N  |     |     |...|

      L = Array length
      N = Number of paths

     Path
      |counter|coord1|coord2|...|coordN
      |N  ,0  |x1, y1|x2, y2|...|xN, yN

      N = Number of coords

     */

    size_t cnt = 0, array_len = 0;
    GetPathCountAndCPathsArrayLen(paths, cnt, array_len);
    int64_t *result = new int64_t[array_len], *v = result;
    *v++ = static_cast<int64_t>(array_len);
    *v++ = static_cast<int64_t>(cnt);
    for (const Path64 &path: paths) {
      if (path.empty()) continue;
      *v++ = static_cast<int64_t>(path.size());
      *v++ = 0;
      for (const Point64 &pt: path) {
        *v++ = pt.x;
        *v++ = pt.y;
      }
    }
    return result;
  }

  void ConvertPolyPathToCPolyPath(const PolyPath64 *polypath, int64_t *&v) {

    /*

     PolyPath
      |counter|coord1|coord2|...|coordN|child1|child2|...|childC|
      |N  ,C  |x1, y1|x2, y2|...|xN, yN|                        |

      N = Number of coords
      C = Number of children

     */

    *v++ = static_cast<int64_t>(polypath->Polygon().size());
    *v++ = static_cast<int64_t>(polypath->Count());
    for (const Point64 &pt: polypath->Polygon()) {
      *v++ = static_cast<int64_t>(pt.x);
      *v++ = static_cast<int64_t>(pt.y);
    }
    for (size_t i = 0; i < polypath->Count(); ++i) {
      ConvertPolyPathToCPolyPath(polypath->Child(i), v);
    }
  }

  int64_t* ConvertPolyTreeToCPolyTree(const PolyTree64 &polytree) {

    /*

     PolyTree
      |counter|child1|child2|...|childC|
      |L  , C |                        |

      L = Array length
      C = Number of children

     */

    size_t cnt, array_len;
    GetPolytreeCountAndCArrayLen(polytree, cnt, array_len);
    if (!cnt) return nullptr;
    int64_t *result = new int64_t[array_len], *v = result;
    *v++ = static_cast<int64_t>(array_len);
    *v++ = static_cast<int64_t>(polytree.Count());
    for (size_t i = 0; i < polytree.Count(); ++i) {
      ConvertPolyPathToCPolyPath(polytree.Child(i), v);
    }
    return result;
  }

  // Boolean Ops

  void ExecuteBooleanOp(ClipType clip_type, Paths64 &closed_subjects, Paths64 &open_subjects, Paths64 &clips, Paths64 &closed_paths_solution, Paths64 &open_paths_solution, bool preserve_colinear) {
    Clipper64 clipper;
    clipper.PreserveCollinear(preserve_colinear);
    clipper.AddSubject(closed_subjects);
    clipper.AddOpenSubject(open_subjects);
    clipper.AddClip(clips);
    clipper.Execute(clip_type, FillRule::NonZero, closed_paths_solution, open_paths_solution);
  }

  void ExecuteBooleanOp(ClipType clip_type, Paths64 &closed_subjects, Paths64 &open_subjects, Paths64 &clips, PolyTree64 &polytree_solution, Paths64 &open_paths_solution, bool preserve_colinear) {
    Clipper64 clipper;
    clipper.PreserveCollinear(preserve_colinear);
    clipper.AddSubject(closed_subjects);
    clipper.AddOpenSubject(open_subjects);
    clipper.AddClip(clips);
    clipper.Execute(clip_type, FillRule::NonZero, polytree_solution, open_paths_solution);
  }

}