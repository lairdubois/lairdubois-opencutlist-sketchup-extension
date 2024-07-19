#include <clipper2/clipper.wrapper.hpp>

namespace Clipper2Lib {

  const char *Version() {
    return CLIPPER2_VERSION;
  }

  int BooleanOp64(
          uint8_t cliptype,
          uint8_t fillrule,
          const CPaths64 subjects,
          const CPaths64 subjects_open,
          const CPaths64 clips,
          CPaths64 &solution,
          CPaths64 &solution_open,
          bool preserve_collinear,
          bool reverse_solution
  ) {

    if (cliptype > static_cast<uint8_t>(ClipType::Xor)) return -4;
    if (fillrule > static_cast<uint8_t>(FillRule::Negative)) return -3;

    Paths64 sub, sub_open, clp, sol, sol_open;
    sub = ConvertCPaths(subjects);
    sub_open = ConvertCPaths(subjects_open);
    clp = ConvertCPaths(clips);

    Clipper64 clipper;
    clipper.PreserveCollinear(preserve_collinear);
    clipper.ReverseSolution(reverse_solution);
    if (sub.size() > 0) clipper.AddSubject(sub);
    if (sub_open.size() > 0) clipper.AddOpenSubject(sub_open);
    if (clp.size() > 0) clipper.AddClip(clp);
    if (!clipper.Execute(ClipType(cliptype), FillRule(fillrule), sol, sol_open)) return -1; // clipping bug - should never happen :)
    solution = CreateCPaths(sol);
    solution_open = CreateCPaths(sol_open);

    return 0; //success !!
  }

  int BooleanOp_PolyTree64(
          uint8_t cliptype,
          uint8_t fillrule,
          const CPaths64 subjects,
          const CPaths64 subjects_open,
          const CPaths64 clips,
          CPolyTree64 &sol_tree,
          CPaths64 &solution_open,
          bool preserve_collinear,
          bool reverse_solution
  ) {

    if (cliptype > static_cast<uint8_t>(ClipType::Xor)) return -4;
    if (fillrule > static_cast<uint8_t>(FillRule::Negative)) return -3;

    Paths64 sub, sub_open, clp, sol_open;
    sub = ConvertCPaths(subjects);
    sub_open = ConvertCPaths(subjects_open);
    clp = ConvertCPaths(clips);

    PolyTree64 tree;
    Clipper64 clipper;
    clipper.PreserveCollinear(preserve_collinear);
    clipper.ReverseSolution(reverse_solution);
    if (sub.size() > 0) clipper.AddSubject(sub);
    if (sub_open.size() > 0) clipper.AddOpenSubject(sub_open);
    if (clp.size() > 0) clipper.AddClip(clp);
    if (!clipper.Execute(ClipType(cliptype), FillRule(fillrule), tree, sol_open)) return -1; // clipping bug - should never happen :)

    sol_tree = CreateCPolyTree(tree, (int64_t) 1);
    solution_open = CreateCPaths(sol_open);

    return 0; // success !!
  }

  int BooleanOpD(
          uint8_t cliptype,
          uint8_t fillrule,
          const CPathsD subjects,
          const CPathsD subjects_open,
          const CPathsD clips,
          CPathsD &solution,
          CPathsD &solution_open,
          int precision,
          bool preserve_collinear,
          bool reverse_solution
  ) {

    if (precision < -8 || precision > 8) return -5;
    if (cliptype > static_cast<uint8_t>(ClipType::Xor)) return -4;
    if (fillrule > static_cast<uint8_t>(FillRule::Negative)) return -3;

    const double scale = std::pow(10, precision);

    Paths64 sub, sub_open, clp, sol, sol_open;
    sub = ConvertCPathsDToPaths64(subjects, scale);
    sub_open = ConvertCPathsDToPaths64(subjects_open, scale);
    clp = ConvertCPathsDToPaths64(clips, scale);

    Clipper64 clipper;
    clipper.PreserveCollinear(preserve_collinear);
    clipper.ReverseSolution(reverse_solution);
    if (sub.size() > 0) clipper.AddSubject(sub);
    if (sub_open.size() > 0) clipper.AddOpenSubject(sub_open);
    if (clp.size() > 0) clipper.AddClip(clp);
    if (!clipper.Execute(ClipType(cliptype),FillRule(fillrule), sol, sol_open)) return -1;

    solution = CreateCPathsDFromPaths64(sol, 1 / scale);
    solution_open = CreateCPathsDFromPaths64(sol_open, 1 / scale);

    return 0; // success !!
  }

  int BooleanOp_PolyTreeD(
          uint8_t cliptype,
          uint8_t fillrule,
          const CPathsD subjects,
          const CPathsD subjects_open,
          const CPathsD clips,
          CPolyTreeD &solution,
          CPathsD &solution_open,
          int precision,
          bool preserve_collinear,
          bool reverse_solution
  ) {

    if (precision < -8 || precision > 8) return -5;
    if (cliptype > static_cast<uint8_t>(ClipType::Xor)) return -4;
    if (fillrule > static_cast<uint8_t>(FillRule::Negative)) return -3;

    double scale = std::pow(10, precision);

    Paths64 sub, sub_open, clp, sol_open;
    sub = ConvertCPathsDToPaths64(subjects, scale);
    sub_open = ConvertCPathsDToPaths64(subjects_open, scale);
    clp = ConvertCPathsDToPaths64(clips, scale);

    PolyTree64 tree;
    Clipper64 clipper;
    clipper.PreserveCollinear(preserve_collinear);
    clipper.ReverseSolution(reverse_solution);
    if (sub.size() > 0) clipper.AddSubject(sub);
    if (sub_open.size() > 0) clipper.AddOpenSubject(sub_open);
    if (clp.size() > 0) clipper.AddClip(clp);
    if (!clipper.Execute(ClipType(cliptype), FillRule(fillrule), tree, sol_open)) return -1; // clipping bug - should never happen :)

    solution = CreateCPolyTree(tree, 1 / scale);
    solution_open = CreateCPathsDFromPaths64(sol_open, 1 / scale);

    return 0; // success !!
  }


  CPaths64 InflatePaths64(
          const CPaths64 paths,
          double delta,
          uint8_t jointype,
          uint8_t endtype,
          double miter_limit,
          double arc_tolerance,
          bool reverse_solution
  ) {

    Paths64 pp;
    pp = ConvertCPaths(paths);
    ClipperOffset clip_offset(miter_limit, arc_tolerance, reverse_solution);
    clip_offset.AddPaths(pp, JoinType(jointype), EndType(endtype));

    Paths64 result;
    clip_offset.Execute(delta, result);
    return CreateCPaths(result);
  }

  CPathsD InflatePathsD(
          const CPathsD paths,
          double delta,
          uint8_t jointype,
          uint8_t endtype,
          int precision,
          double miter_limit,
          double arc_tolerance,
          bool reverse_solution
  ) {

    if (precision < -8 || precision > 8 || !paths) return nullptr;

    const double scale = std::pow(10, precision);
    ClipperOffset clip_offset(miter_limit, arc_tolerance, reverse_solution);
    Paths64 pp = ConvertCPathsDToPaths64(paths, scale);
    clip_offset.AddPaths(pp, JoinType(jointype), EndType(endtype));
    Paths64 result;
    clip_offset.Execute(delta * scale, result);

    return CreateCPathsDFromPaths64(result, 1 / scale);
  }


  CPaths64 RectClip64(
          const CRect64 &rect,
          const CPaths64 paths
  ) {

    if (CRectIsEmpty(rect) || !paths) return nullptr;

    Rect64 r64 = CRectToRect(rect);
    class RectClip64 rc(r64);
    Paths64 pp = ConvertCPaths(paths);
    Paths64 result = rc.Execute(pp);
    return CreateCPaths(result);
  }

  CPathsD RectClipD(
          const CRectD &rect,
          const CPathsD paths,
          int precision
  ) {

    if (CRectIsEmpty(rect) || !paths) return nullptr;
    if (precision < -8 || precision > 8) return nullptr;

    const double scale = std::pow(10, precision);

    RectD r = CRectToRect(rect);
    Rect64 rec = ScaleRect<int64_t, double>(r, scale);
    Paths64 pp = ConvertCPathsDToPaths64(paths, scale);
    class RectClip64 rc(rec);
    Paths64 result = rc.Execute(pp);

    return CreateCPathsDFromPaths64(result, 1 / scale);
  }

  CPaths64 RectClipLines64(
          const CRect64 &rect,
          const CPaths64 paths
  ) {

    if (CRectIsEmpty(rect) || !paths) return nullptr;

    Rect64 r = CRectToRect(rect);
    class RectClipLines64 rcl(r);
    Paths64 pp = ConvertCPaths(paths);
    Paths64 result = rcl.Execute(pp);

    return CreateCPaths(result);
  }

  CPathsD RectClipLinesD(
          const CRectD &rect,
          const CPathsD paths,
          int precision
  ) {

    if (CRectIsEmpty(rect) || !paths) return nullptr;
    if (precision < -8 || precision > 8) return nullptr;

    const double scale = std::pow(10, precision);
    Rect64 r = ScaleRect<int64_t, double>(CRectToRect(rect), scale);
    class RectClipLines64 rcl(r);
    Paths64 pp = ConvertCPathsDToPaths64(paths, scale);
    Paths64 result = rcl.Execute(pp);

    return CreateCPathsDFromPaths64(result, 1 / scale);
  }


  CPaths64 MinkowskiSum64(
          const CPath64 &cpattern,
          const CPath64 &cpath,
          bool is_closed
  ) {

    Path64 path = ConvertCPath(cpath);
    Path64 pattern = ConvertCPath(cpattern);
    Paths64 solution = MinkowskiSum(pattern, path, is_closed);

    return CreateCPaths(solution);
  }

  CPaths64 MinkowskiDiff64(
          const CPath64 &cpattern,
          const CPath64 &cpath,
          bool is_closed
  ) {

    Path64 path = ConvertCPath(cpath);
    Path64 pattern = ConvertCPath(cpattern);
    Paths64 solution = MinkowskiDiff(pattern, path, is_closed);

    return CreateCPaths(solution);
  }
  
  
  
  
  
  
  

  // Data manipulators

//  Path64 ConvertCPathToPath(const double* cpath) {
//    Path64 result;
//    if (!cpath) return result;
//    const double *v = cpath;
//    size_t cnt = *v;
//    v += 2;
//    result.reserve(cnt);
//    for (size_t i = 0; i < cnt; ++i) {
//      double x = *v++, y = *v++;
//      result.emplace_back(DoubleToInt64(x), DoubleToInt64(y));
//    }
//    return result;
//  }
//
//  Paths64 ConvertCPathsToPaths(const double* cpaths) {
//    Paths64 result;
//    if (!cpaths) return result;
//    const double *v = cpaths;
//    ++v;
//    size_t cnt = *v++;
//    result.reserve(cnt);
//    for (size_t i = 0; i < cnt; ++i) {
//      result.push_back(ConvertCPathToPath(v));
//    }
//    return result;
//  }
//
//
//  void GetPathCountAndCPathsArrayLen(const Paths64 &paths, size_t &cnt, size_t &array_len) {
//    array_len = 2;
//    cnt = 0;
//    for (const Path64 &path: paths) {
//      if (path.empty()) continue;
//      array_len += path.size() * 2 + 2;
//      ++cnt;
//    }
//  }
//
//  size_t GetPolyPath64ArrayLen(const PolyPath64 &polypath) {
//    size_t result = 2; // poly_length + child_count
//    result += polypath.Polygon().size() * 2;
//    // + nested children
//    for (size_t i = 0; i < polypath.Count(); ++i) {
//      result += GetPolyPath64ArrayLen(*polypath[i]);
//    }
//    return result;
//  }
//
//  void GetPolytreeCountAndCArrayLen(const PolyTree64 &tree, size_t &cnt, size_t &array_len) {
//    cnt = tree.Count(); // nb: top level count only
//    array_len = GetPolyPath64ArrayLen(tree);
//  }
//
//
//  CPathD ConvertPathsToCPaths(const Paths64 &paths) {
//
//    /*
//
//     Paths
//      |counter|path1|path2|...|pathN
//      |L  ,N  |     |     |...|
//
//      L = Array length
//      N = Number of paths
//
//     Path
//      |counter|coord1|coord2|...|coordN
//      |N  ,0  |x1, y1|x2, y2|...|xN, yN
//
//      N = Number of coords
//
//     */
//
//    size_t cnt = 0, array_len = 0;
//    GetPathCountAndCPathsArrayLen(paths, cnt, array_len);
//    double *result = new double[array_len], *v = result;
//    *v++ = static_cast<double>(array_len);
//    *v++ = static_cast<double>(cnt);
//    for (const Path64 &path: paths) {
//      if (path.empty()) continue;
//      *v++ = static_cast<double>(path.size());
//      *v++ = 0;
//      for (const Point64 &pt: path) {
//        *v++ = Int64ToDouble(pt.x);
//        *v++ = Int64ToDouble(pt.y);
//      }
//    }
//    return result;
//  }
//
//  void ConvertPolyPathToCPolyPath(const PolyPath64* polypath, CPolyPathsD& v) {
//
//    /*
//
//     PolyPath
//      |counter|coord1|coord2|...|coordN|child1|child2|...|childC|
//      |N  ,C  |x1, y1|x2, y2|...|xN, yN|                        |
//
//      N = Number of coords
//      C = Number of children
//
//     */
//
//    *v++ = static_cast<double>(polypath->Polygon().size());
//    *v++ = static_cast<double>(polypath->Count());
//    for (const Point64 &pt: polypath->Polygon()) {
//      *v++ = Int64ToDouble(static_cast<double>(pt.x));
//      *v++ = Int64ToDouble(static_cast<double>(pt.y));
//    }
//    for (size_t i = 0; i < polypath->Count(); ++i) {
//      ConvertPolyPathToCPolyPath(polypath->Child(i), v);
//    }
//  }
//
//  CPolyTreeD ConvertPolyTreeToCPolyTree(const PolyTree64 &polytree) {
//
//    /*
//
//     PolyTree
//      |counter|child1|child2|...|childC|
//      |L  , C |                        |
//
//      L = Array length
//      C = Number of children
//
//     */
//
//    size_t cnt, array_len;
//    GetPolytreeCountAndCArrayLen(polytree, cnt, array_len);
//    if (!cnt) return nullptr;
//    double *result = new double[array_len], *v = result;
//    *v++ = static_cast<double>(array_len);
//    *v++ = static_cast<double>(polytree.Count());
//    for (size_t i = 0; i < polytree.Count(); ++i) {
//      ConvertPolyPathToCPolyPath(polytree.Child(i), v);
//    }
//    return result;
//  }
//
//  // Boolean Ops
//
//  void ExecuteBooleanOp(ClipType clip_type, Paths64 &closed_subjects, Paths64 &open_subjects, Paths64 &clips, Paths64 &closed_paths_solution, Paths64 &open_paths_solution, bool preserve_colinear) {
//    Clipper64 clipper;
//    clipper.PreserveCollinear(preserve_colinear);
//    clipper.AddSubject(closed_subjects);
//    clipper.AddOpenSubject(open_subjects);
//    clipper.AddClip(clips);
//    clipper.Execute(clip_type, FillRule::NonZero, closed_paths_solution, open_paths_solution);
//  }
//
//  void ExecuteBooleanOp(ClipType clip_type, Paths64 &closed_subjects, Paths64 &open_subjects, Paths64 &clips, PolyTree64 &polytree_solution, Paths64 &open_paths_solution, bool preserve_colinear) {
//    Clipper64 clipper;
//    clipper.PreserveCollinear(preserve_colinear);
//    clipper.AddSubject(closed_subjects);
//    clipper.AddOpenSubject(open_subjects);
//    clipper.AddClip(clips);
//    clipper.Execute(clip_type, FillRule::NonZero, polytree_solution, open_paths_solution);
//  }

}