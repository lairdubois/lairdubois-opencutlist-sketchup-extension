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

}