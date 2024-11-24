#include <clipper2/clipper.wrapper.hpp>

namespace Clipper2Lib {

    const char* Version() {
        return CLIPPER2_VERSION;
    }

    void DisposeArray64(
            int64_t*& p
    ) {
        delete[] p;
    }

    void DisposeArrayD(
            double*& p
    ) {
        delete[] p;
    }

    int BooleanOp64(
            uint8_t clip_type,
            uint8_t fill_rule,
            const CPaths64 subjects,
            const CPaths64 subjects_open,
            const CPaths64 clips,
            CPaths64& solution,
            CPaths64& solution_open,
            bool preserve_collinear,
            bool reverse_solution
    ) {

        if (clip_type > static_cast<uint8_t>(ClipType::Xor)) return -4;
        if (fill_rule > static_cast<uint8_t>(FillRule::Negative)) return -3;

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
        if (!clipper.Execute(ClipType(clip_type), FillRule(fill_rule), sol, sol_open))
            return -1; // clipping bug - should never happen :)
        solution = CreateCPaths(sol);
        solution_open = CreateCPaths(sol_open);

        return 0; //success !!
    }

    int BooleanOp_PolyTree64(
            uint8_t clip_type,
            uint8_t fill_rule,
            const CPaths64 subjects,
            const CPaths64 subjects_open,
            const CPaths64 clips,
            CPolyTree64& sol_tree,
            CPaths64& solution_open,
            bool preserve_collinear,
            bool reverse_solution
    ) {

        if (clip_type > static_cast<uint8_t>(ClipType::Xor)) return -4;
        if (fill_rule > static_cast<uint8_t>(FillRule::Negative)) return -3;

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
        if (!clipper.Execute(ClipType(clip_type), FillRule(fill_rule), tree, sol_open))
            return -1; // clipping bug - should never happen :)

        sol_tree = CreateCPolyTree(tree, (int64_t) 1);
        solution_open = CreateCPaths(sol_open);

        return 0; // success !!
    }

    int BooleanOpD(
            uint8_t clip_type,
            uint8_t fill_rule,
            const CPathsD subjects,
            const CPathsD subjects_open,
            const CPathsD clips,
            CPathsD& solution,
            CPathsD& solution_open,
            int precision,
            bool preserve_collinear,
            bool reverse_solution
    ) {

        if (precision < -8 || precision > 8) return -5;
        if (clip_type > static_cast<uint8_t>(ClipType::Xor)) return -4;
        if (fill_rule > static_cast<uint8_t>(FillRule::Negative)) return -3;

        const double scale = std::pow(10, precision);
        const double inv_scale = 1 / scale;

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
        if (!clipper.Execute(ClipType(clip_type), FillRule(fill_rule), sol, sol_open)) return -1;

        solution = CreateCPathsDFromPaths64(sol, inv_scale);
        solution_open = CreateCPathsDFromPaths64(sol_open, inv_scale);

        return 0; // success !!
    }

    int BooleanOp_PolyTreeD(
            uint8_t clip_type,
            uint8_t fill_rule,
            const CPathsD subjects,
            const CPathsD subjects_open,
            const CPathsD clips,
            CPolyTreeD& solution,
            CPathsD& solution_open,
            int precision,
            bool preserve_collinear,
            bool reverse_solution
    ) {

        if (precision < -8 || precision > 8) return -5;
        if (clip_type > static_cast<uint8_t>(ClipType::Xor)) return -4;
        if (fill_rule > static_cast<uint8_t>(FillRule::Negative)) return -3;

        const double scale = std::pow(10, precision);
        const double inv_scale = 1 / scale;

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
        if (!clipper.Execute(ClipType(clip_type), FillRule(fill_rule), tree, sol_open))
            return -1; // clipping bug - should never happen :)

        solution = CreateCPolyTree(tree, inv_scale);
        solution_open = CreateCPathsDFromPaths64(sol_open, inv_scale);

        return 0; // success !!
    }


    int InflatePaths64(
            const CPaths64 paths,
            double delta,
            CPaths64& solution,
            uint8_t join_type,
            uint8_t end_type,
            double miter_limit,
            double arc_tolerance,
            bool preserve_collinear,
            bool reverse_solution
    ) {

        if (join_type > static_cast<uint8_t>(JoinType::Miter)) return -4;
        if (end_type > static_cast<uint8_t>(EndType::Round)) return -3;

        Paths64 input = ConvertCPaths(paths);
        ClipperOffset offset(miter_limit, arc_tolerance, preserve_collinear, reverse_solution);
        offset.AddPaths(input, JoinType(join_type), EndType(end_type));
        Paths64 result;
        offset.Execute(delta, result);

        solution = CreateCPaths(SimplifyPaths(result, 1.0));

        return 0; // Success !!
    }

    int InflatePathsD(
            const CPathsD paths,
            double delta,
            CPathsD& solution,
            uint8_t join_type,
            uint8_t end_type,
            int precision,
            double miter_limit,
            double arc_tolerance,
            bool preserve_collinear,
            bool reverse_solution
    ) {

        if (precision < -8 || precision > 8) return -5;
        if (join_type > static_cast<uint8_t>(JoinType::Miter)) return -4;
        if (end_type > static_cast<uint8_t>(EndType::Round)) return -3;

        const double scale = std::pow(10, precision);
        const double inv_scale = 1 / scale;

        ClipperOffset offset(miter_limit, arc_tolerance, preserve_collinear, reverse_solution);
        Paths64 input = ConvertCPathsDToPaths64(paths, scale);
        offset.AddPaths(input, JoinType(join_type), EndType(end_type));
        Paths64 result;
        offset.Execute(delta * scale, result);

        solution = CreateCPathsDFromPaths64(SimplifyPaths(result, 1.0), inv_scale);

        return 0; // Success !!
    }


    CPaths64 RectClip64(
            const CRect64& rect,
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
            const CRectD& rect,
            const CPathsD paths,
            int precision
    ) {

        if (CRectIsEmpty(rect) || !paths) return nullptr;
        if (precision < -8 || precision > 8) return nullptr;

        const double scale = std::pow(10, precision);
        const double inv_scale = 1 / scale;

        RectD r = CRectToRect(rect);
        Rect64 rec = ScaleRect<int64_t, double>(r, scale);
        Paths64 pp = ConvertCPathsDToPaths64(paths, scale);
        class RectClip64 rc(rec);
        Paths64 result = rc.Execute(pp);

        return CreateCPathsDFromPaths64(result, inv_scale);
    }

    CPaths64 RectClipLines64(
            const CRect64& rect,
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
            const CRectD& rect,
            const CPathsD paths,
            int precision
    ) {

        if (CRectIsEmpty(rect) || !paths) return nullptr;
        if (precision < -8 || precision > 8) return nullptr;

        const double scale = std::pow(10, precision);
        const double inv_scale = 1 / scale;

        Rect64 r = ScaleRect<int64_t, double>(CRectToRect(rect), scale);
        class RectClipLines64 rcl(r);
        Paths64 pp = ConvertCPathsDToPaths64(paths, scale);
        Paths64 result = rcl.Execute(pp);

        return CreateCPathsDFromPaths64(result, inv_scale);
    }


    CPaths64 MinkowskiSum64(
            const CPath64& cpattern,
            const CPath64& cpath,
            bool is_closed
    ) {

        Path64 path = ConvertCPath(cpath);
        Path64 pattern = ConvertCPath(cpattern);
        Paths64 solution = MinkowskiSum(pattern, path, is_closed);

        return CreateCPaths(solution);
    }

    CPaths64 MinkowskiDiff64(
            const CPath64& cpattern,
            const CPath64& cpath,
            bool is_closed
    ) {

        Path64 path = ConvertCPath(cpath);
        Path64 pattern = ConvertCPath(cpattern);
        Paths64 solution = MinkowskiDiff(pattern, path, is_closed);

        return CreateCPaths(solution);
    }

}