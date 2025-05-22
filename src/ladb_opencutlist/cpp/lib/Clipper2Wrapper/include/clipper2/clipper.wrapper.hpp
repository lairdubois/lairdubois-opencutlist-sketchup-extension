#ifndef CLIPPER_WRAPPER_H
#define CLIPPER_WRAPPER_H

/*
 Boolean clipping:
 cliptype: None=0, Intersection=1, Union=2, Difference=3, Xor=4
 fillrule: EvenOdd=0, NonZero=1, Positive=2, Negative=3

 Polygon offsetting (inflate/deflate):
 jointype: Square=0, Bevel=1, Round=2, Miter=3
 endtype: Polygon=0, Joined=1, Butt=2, Square=3, Round=4

The path structures used extensively in other parts of this library are all
based on std::vector classes. Since C++ classes can't be accessed by other
languages, these paths are converted into very simple array data structures
(of either int64_t for CPath64 or double for CPathD) that can be parsed by
just about any programming language.

CPath64 and CPathD:
These are arrays of consecutive x and y path coordinates preceeded by
a pair of values containing the path's length (N) and a 0 value.
__________________________________
|counter|coord1|coord2|...|coordN|
|N, 0   |x1, y1|x2, y2|...|xN, yN|
__________________________________

CPaths64 and CPathsD:
These are also arrays containing any number of consecutive CPath64 or
CPathD  structures. But preceeding these consecutive paths, there is pair of
values that contain the total length of the array structure (A) and the
number of CPath64 or CPathD it contains (C). The space these structures will
occupy in memory = A * sizeof(int64_t) or  A * sizeof(double) respectively.
_______________________________
|counter|path1|path2|...|pathC|
|A  , C |                     |
_______________________________

CPolytree64 and CPolytreeD:
These are also arrays consisting of CPolyPath structures that represent
individual paths in a tree structure. However, the very first (ie top)
CPolyPath is just the tree container that doesn't have a path. And because
of that, its structure will be very slightly different from the remaining
CPolyPath. This difference will be discussed below.

CPolyPath64 and CPolyPathD:
These are simple arrays consisting of a series of path coordinates followed
by any number of child (ie nested) CPolyPath. Preceeding these are two values
indicating the length of the path (N) and the number of child CPolyPath (C).
____________________________________________________________
|counter|coord1|coord2|...|coordN| child1|child2|...|childC|
|N  , C |x1, y1|x2, y2|...|xN, yN|                         |
____________________________________________________________

As mentioned above, the very first CPolyPath structure is just a container
that owns (both directly and indirectly) every other CPolyPath in the tree.
Since this first CPolyPath has no path, instead of a path length, its very
first value will contain the total length of the CPolytree array (not its
total bytes length).

Again, all theses exported structures (CPaths64, CPathsD, CPolyTree64 &
CPolyTreeD) are arrays of either type int64_t or double, and the first
value in these arrays will always be the length of that array.

These array structures are allocated in heap memory which will eventually
need to be released. However, since applications dynamically linking to
these functions may use different memory managers, the only safe way to
free up this memory is to use the exported DisposeArray64 and
DisposeArrayD functions (see below).
*/

#include "clipper2/clipper.h"

namespace Clipper2Lib {

    typedef int64_t* CPath64;
    typedef int64_t* CPaths64;
    typedef double* CPathD;
    typedef double* CPathsD;

    typedef int64_t* CPolyPath64;
    typedef int64_t* CPolyTree64;
    typedef double* CPolyPathD;
    typedef double* CPolyTreeD;

    template<typename T>
    struct CRect {
        T left;
        T top;
        T right;
        T bottom;
    };

    typedef CRect<int64_t> CRect64;
    typedef CRect<double> CRectD;

    template<typename T>
    bool CRectIsEmpty(const CRect<T>& rect) {
        return rect.right <= rect.left || rect.bottom <= rect.top;
    }

    template<typename T>
    Rect<T> CRectToRect(const CRect<T>& rect) {
        Rect<T> result;
        result.left = rect.left;
        result.top = rect.top;
        result.right = rect.right;
        result.bottom = rect.bottom;
        return result;
    }

    // -----

    const char* Version();

    void DisposeArray64(
            int64_t*& p
    );

    void DisposeArrayD(
            double*& p
    );

    int BooleanOp64(
            uint8_t clip_type,
            uint8_t fill_rule,
            CPaths64 subjects,
            CPaths64 subjects_open,
            CPaths64 clips,
            CPaths64& solution,
            CPaths64& solution_open,
            bool preserve_collinear = true,
            bool reverse_solution = false
    );

    int BooleanOp_PolyTree64(
            uint8_t clip_type,
            uint8_t fill_rule,
            CPaths64 subjects,
            CPaths64 subjects_open,
            CPaths64 clips,
            CPolyTree64& sol_tree,
            CPaths64& solution_open,
            bool preserve_collinear = false,
            bool reverse_solution = false
    );

    int BooleanOpD(
            uint8_t clip_type,
            uint8_t fill_rule,
            CPathsD subjects,
            CPathsD subjects_open,
            CPathsD clips,
            CPathsD& solution,
            CPathsD& solution_open,
            int precision = 8,
            bool preserve_collinear = false,
            bool reverse_solution = false
    );

    int BooleanOp_PolyTreeD(
            uint8_t clip_type,
            uint8_t fill_rule,
            CPathsD subjects,
            CPathsD subjects_open,
            CPathsD clips,
            CPolyTreeD& solution,
            CPathsD& solution_open,
            int precision = 8,
            bool preserve_collinear = false,
            bool reverse_solution = false
    );


    int InflatePaths64(
            CPaths64 paths,
            double delta,
            CPaths64& solution,
            uint8_t join_type,
            uint8_t end_type,
            double miter_limit = 2.0,
            double arc_tolerance = 0.0,
            bool preserve_collinear = false,
            bool reverse_solution = false
    );

    int InflatePathsD(
            CPathsD paths,
            double delta,
            CPathsD& solution,
            uint8_t join_type,
            uint8_t end_type,
            int precision = 8,
            double miter_limit = 2.0,
            double arc_tolerance = 0.0,
            bool preserve_collinear = false,
            bool reverse_solution = false
    );


    CPaths64 RectClip64(
            CRect64& rect,
            CPaths64 paths
    );

    CPathsD RectClipD(
            CRectD& rect,
            CPathsD paths,
            int precision = 8
    );

    CPaths64 RectClipLines64(
            CRect64& rect,
            CPaths64 paths
    );

    CPathsD RectClipLinesD(
            CRectD& rect,
            CPathsD paths,
            int precision = 8
    );

    // -- Internal functions ---

    template<typename T>
    static void GetPathCountAndCPathsArrayLen(
            const Paths<T>& paths,
            size_t& cnt,
            size_t& array_len
    ) {

        array_len = 2;
        cnt = 0;
        for (const Path<T>& path: paths) {
            if (path.size()) {
                array_len += path.size() * 2 + 2;
                ++cnt;
            }
        }

    }

    static size_t GetPolyPath64ArrayLen(
            const PolyPath64& pp
    ) {

        size_t result = 2; // poly_length + child_count
        result += pp.Polygon().size() * 2;
        // plus nested children :)
        for (size_t i = 0; i < pp.Count(); ++i) {
            result += GetPolyPath64ArrayLen(*pp[i]);
        }

        return result;
    }

    static void GetPolytreeCountAndCStorageSize(
            const PolyTree64& tree,
            size_t& cnt,
            size_t& array_len
    ) {

        cnt = tree.Count(); // nb: top level count only
        array_len = GetPolyPath64ArrayLen(tree);

    }

    template<typename T>
    static T* CreateCPaths(
            const Paths<T>& paths
    ) {

        size_t cnt = 0, array_len = 0;
        GetPathCountAndCPathsArrayLen(paths, cnt, array_len);
        T* result = new T[array_len], * v = result;
        *v++ = array_len;
        *v++ = cnt;
        for (const Path<T>& path: paths) {
            if (!path.size()) continue;
            *v++ = path.size();
            *v++ = 0;
            for (const Point<T>& pt: path) {
                *v++ = pt.x;
                *v++ = pt.y;
            }
        }

        return result;
    }

    static CPathsD CreateCPathsDFromPaths64(
            const Paths64& paths,
            double scale
    ) {

        size_t cnt, array_len;
        GetPathCountAndCPathsArrayLen(paths, cnt, array_len);
        CPathsD result = new double[array_len], v = result;
        *v++ = (double) array_len;
        *v++ = (double) cnt;
        for (const Path64& path: paths) {
            if (path.empty()) continue;
            *v = (double) path.size();
            ++v;
            *v++ = 0;
            for (const Point64& pt: path) {
                *v++ = pt.x * scale;
                *v++ = pt.y * scale;
            }
        }

        return result;
    }

    template<typename T>
    static Path<T> ConvertCPath(
            T* path
    ) {

        Path<T> result;
        if (!path) return result;
        T* v = path;
        auto cnt = static_cast<size_t>(*v);
        v += 2; // skip 0 value
        result.reserve(cnt);
        for (size_t j = 0; j < cnt; ++j) {
            T x = *v++, y = *v++;
            result.emplace_back(x, y);
        }

        return result;
    }

    template<typename T>
    static Paths<T> ConvertCPaths(
            T* paths
    ) {

        Paths<T> result;
        if (!paths) return result;
        T* v = paths;
        ++v;
        auto cnt = static_cast<size_t>(*v++);
        result.reserve(cnt);
        for (size_t i = 0; i < cnt; ++i) {
            auto cnt2 = static_cast<size_t>(*v);
            v += 2;
            Path<T> path;
            path.reserve(cnt2);
            for (size_t j = 0; j < cnt2; ++j) {
                T x = *v++, y = *v++;
                path.emplace_back(x, y);
            }
            result.push_back(path);
        }

        return result;
    }

    static Paths64 ConvertCPathsDToPaths64(
            CPathsD paths,
            double scale
    ) {

        Paths64 result;
        if (!paths) return result;
        double* v = paths;
        ++v; // skip the first value (0)
        const auto cnt = static_cast<size_t>(*v++);
        result.reserve(cnt);
        for (size_t i = 0; i < cnt; ++i) {
            auto cnt2 = static_cast<size_t>(*v);
            v += 2;
            Path64 path;
            path.reserve(cnt2);
            for (size_t j = 0; j < cnt2; ++j) {
                double x = *v++ * scale;
                double y = *v++ * scale;
                path.emplace_back(x, y);
            }
            result.push_back(path);
        }

        return result;
    }

    template<typename T>
    static void CreateCPolyPath(
            const PolyPath64* pp,
            T*& v,
            T scale
    ) {

        *v++ = static_cast<T>(pp->Polygon().size());
        *v++ = static_cast<T>(pp->Count());
        for (const Point64& pt: pp->Polygon()) {
            *v++ = static_cast<T>(pt.x * scale);
            *v++ = static_cast<T>(pt.y * scale);
        }
        for (size_t i = 0; i < pp->Count(); ++i) {
            CreateCPolyPath(pp->Child(i), v, scale);
        }

    }

    template<typename T>
    static T* CreateCPolyTree(
            const PolyTree64& tree,
            T scale
    ) {

        if (scale == 0) scale = 1;
        size_t cnt, array_len;
        GetPolytreeCountAndCStorageSize(tree, cnt, array_len);
        // allocate storage
        T* result = new T[array_len];
        T* v = result;

        *v++ = static_cast<T>(array_len);
        *v++ = static_cast<T>(tree.Count());
        for (size_t i = 0; i < tree.Count(); ++i) {
            CreateCPolyPath(tree.Child(i), v, scale);
        }

        return result;
    }

    static bool PointOnPath(
            PointD point,
            PathD path,
            bool closed = false,
            double epsilon = 1e-6
    ) {
        size_t path_size = path.size();
        if (path_size < 2) return false;
        size_t max_index = closed ? path_size - 1 : path_size - 2;
        for (size_t i = 0; i <= max_index; ++i) {
            PointD p1 = path[i];
            PointD p2 = path[(i + 1) % path_size];
            if (PerpendicDistFromLineSqrd(point, p1, p2) <= epsilon) {
                if (std::abs(Distance(point, p1) + Distance(point, p2) - Distance(p1, p2)) < epsilon) {
                    return true;
                }
            }
        }
        return false;
    }


}

#endif // CLIPPER_WRAPPER_H
