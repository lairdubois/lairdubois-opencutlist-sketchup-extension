#ifndef CLIPPER_WRAPPER_H
#define CLIPPER_WRAPPER_H

#include "clipper2/clipper.h"

namespace Clipper2Lib {

  typedef int64_t *CPath64;
  typedef int64_t *CPaths64;
  typedef double *CPathD;
  typedef double *CPathsD;

  typedef int64_t *CPolyPath64;
  typedef int64_t *CPolyTree64;
  typedef double *CPolyPathD;
  typedef double *CPolyTreeD;

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
  inline bool CRectIsEmpty(const CRect<T> &rect) {
    return (rect.right <= rect.left) || (rect.bottom <= rect.top);
  }

  template<typename T>
  inline Rect<T> CRectToRect(const CRect<T> &rect) {
    Rect<T> result;
    result.left = rect.left;
    result.top = rect.top;
    result.right = rect.right;
    result.bottom = rect.bottom;
    return result;
  }

  // -----

  const char *Version();

//  void DisposeArray64(
//          int64_t *&p
//  ) {
//    delete[] p;
//  }
//
//  void DisposeArrayD(
//          double *&p
//  ) {
//    delete[] p;
//  }

  int BooleanOp64(
          uint8_t cliptype,
          uint8_t fillrule,
          const CPaths64 subjects,
          const CPaths64 subjects_open,
          const CPaths64 clips,
          CPaths64 &solution,
          CPaths64 &solution_open,
          bool preserve_collinear = true,
          bool reverse_solution = false
  );

  int BooleanOp_PolyTree64(
          uint8_t cliptype,
          uint8_t fillrule,
          const CPaths64 subjects,
          const CPaths64 subjects_open,
          const CPaths64 clips,
          CPolyTree64 &sol_tree,
          CPaths64 &solution_open,
          bool preserve_collinear = true,
          bool reverse_solution = false
  );

  int BooleanOpD(
          uint8_t cliptype,
          uint8_t fillrule,
          const CPathsD subjects,
          const CPathsD subjects_open,
          const CPathsD clips,
          CPathsD &solution,
          CPathsD &solution_open, 
          int precision = 8,
          bool preserve_collinear = true,
          bool reverse_solution = false
  );

  int BooleanOp_PolyTreeD(
          uint8_t cliptype,
          uint8_t fillrule,
          const CPathsD subjects,
          const CPathsD subjects_open,
          const CPathsD clips,
          CPolyTreeD &solution,
          CPathsD &solution_open,
          int precision = 8,
          bool preserve_collinear = true,
          bool reverse_solution = false
  );


  CPaths64 InflatePaths64(
          const CPaths64 paths,
          double delta,
          uint8_t jointype,
          uint8_t endtype,
          double miter_limit = 2.0,
          double arc_tolerance = 0.0,
          bool reverse_solution = false
  );

  CPathsD InflatePathsD(
          const CPathsD paths,
          double delta,
          uint8_t jointype,
          uint8_t endtype,
          int precision = 8,
          double miter_limit = 2.0,
          double arc_tolerance = 0.0,
          bool reverse_solution = false
  );


  CPaths64 RectClip64(
          const CRect64 &rect,
          const CPaths64 paths
  );

  CPathsD RectClipD(
          const CRectD &rect,
          const CPathsD paths, int precision = 8
  );

  CPaths64 RectClipLines64(
          const CRect64 &rect,
          const CPaths64 paths
  );

  CPathsD RectClipLinesD(
          const CRectD &rect,
          const CPathsD paths, int precision = 8
  );

  // -- Internal functions ---

  template<typename T>
  static void GetPathCountAndCPathsArrayLen(
          const Paths <T> &paths,
          size_t &cnt,
          size_t &array_len
  ) {

    array_len = 2;
    cnt = 0;
    for (const Path <T> &path: paths) {
      if (path.size()) {
        array_len += path.size() * 2 + 2;
        ++cnt;
      }
    }

  }

  static size_t GetPolyPath64ArrayLen(
          const PolyPath64 &pp
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
          const PolyTree64 &tree,
          size_t &cnt,
          size_t &array_len
  ) {

    cnt = tree.Count(); // nb: top level count only
    array_len = GetPolyPath64ArrayLen(tree);

  }

  template<typename T>
  static T *CreateCPaths(
          const Paths <T> &paths
  ) {

    size_t cnt = 0, array_len = 0;
    GetPathCountAndCPathsArrayLen(paths, cnt, array_len);
    T *result = new T[array_len], *v = result;
    *v++ = array_len;
    *v++ = cnt;
    for (const Path <T> &path: paths) {
      if (!path.size()) continue;
      *v++ = path.size();
      *v++ = 0;
      for (const Point <T> &pt: path) {
        *v++ = pt.x;
        *v++ = pt.y;
      }
    }

    return result;
  }

  static CPathsD CreateCPathsDFromPaths64(
          const Paths64 &paths,
          double scale
  ) {

    size_t cnt, array_len;
    GetPathCountAndCPathsArrayLen(paths, cnt, array_len);
    CPathsD result = new double[array_len], v = result;
    *v++ = (double) array_len;
    *v++ = (double) cnt;
    for (const Path64 &path: paths) {
      if (!path.size()) continue;
      *v = (double) path.size();
      ++v;
      *v++ = 0;
      for (const Point64 &pt: path) {
        *v++ = pt.x * scale;
        *v++ = pt.y * scale;
      }
    }

    return result;
  }

  template<typename T>
  static Path <T> ConvertCPath(
          T *path
  ) {

    Path <T> result;
    if (!path) return result;
    T *v = path;
    size_t cnt = static_cast<size_t>(*v);
    v += 2; // skip 0 value
    result.reserve(cnt);
    for (size_t j = 0; j < cnt; ++j) {
      T x = *v++, y = *v++;
      result.push_back(Point<T>(x, y));
    }

    return result;
  }

  template<typename T>
  static Paths <T> ConvertCPaths(
          T *paths
  ) {

    Paths <T> result;
    if (!paths) return result;
    T *v = paths;
    ++v;
    size_t cnt = static_cast<size_t>(*v++);
    result.reserve(cnt);
    for (size_t i = 0; i < cnt; ++i) {
      size_t cnt2 = static_cast<size_t>(*v);
      v += 2;
      Path <T> path;
      path.reserve(cnt2);
      for (size_t j = 0; j < cnt2; ++j) {
        T x = *v++, y = *v++;
        path.push_back(Point<T>(x, y));
      }
      result.push_back(path);
    }

    return result;
  }

  static Paths64 ConvertCPathsDToPaths64(
          const CPathsD paths,
          double scale
  ) {

    Paths64 result;
    if (!paths) return result;
    double *v = paths;
    ++v; // skip the first value (0)
    size_t cnt = static_cast<size_t>(*v++);
    result.reserve(cnt);
    for (size_t i = 0; i < cnt; ++i) {
      size_t cnt2 = static_cast<size_t>(*v);
      v += 2;
      Path64 path;
      path.reserve(cnt2);
      for (size_t j = 0; j < cnt2; ++j) {
        double x = *v++ * scale;
        double y = *v++ * scale;
        path.push_back(Point64(x, y));
      }
      result.push_back(path);
    }

    return result;
  }

  template<typename T>
  static void CreateCPolyPath(
          const PolyPath64 *pp,
          T *&v,
          T scale
  ) {

    *v++ = static_cast<T>(pp->Polygon().size());
    *v++ = static_cast<T>(pp->Count());
    for (const Point64 &pt: pp->Polygon()) {
      *v++ = static_cast<T>(pt.x * scale);
      *v++ = static_cast<T>(pt.y * scale);
    }
    for (size_t i = 0; i < pp->Count(); ++i) {
      CreateCPolyPath(pp->Child(i), v, scale);
    }

  }

  template<typename T>
  static T *CreateCPolyTree(
          const PolyTree64 &tree,
          T scale
  ) {

    if (scale == 0) scale = 1;
    size_t cnt, array_len;
    GetPolytreeCountAndCStorageSize(tree, cnt, array_len);
    // allocate storage
    T *result = new T[array_len];
    T *v = result;

    *v++ = static_cast<T>(array_len);
    *v++ = static_cast<T>(tree.Count());
    for (size_t i = 0; i < tree.Count(); ++i) {
      CreateCPolyPath(tree.Child(i), v, scale);
    }

    return result;
  }

//
//
//
//  // Data manipulators
//
//  inline double Int64ToDouble(int64_t value) {
//    return value * PRECISION_INV_SCALE;
//  }
//  inline int64_t DoubleToInt64(double value) {
//    return value * PRECISION_SCALE;
//  }
//
//
//  Path64 ConvertCPathToPath(const double* cpath);
//  Paths64 ConvertCPathsToPaths(const double* cpaths);
//
//
//  void GetPathCountAndCPathsArrayLen(const Paths64 &paths, size_t &cnt, size_t &array_len);
//  size_t GetPolyPath64ArrayLen(const PolyPath64 &polypath);
//  void GetPolytreeCountAndCArrayLen(const PolyTree64 &tree, size_t &cnt, size_t &array_len);
//
//
//  CPathsD ConvertPathsToCPaths(const Paths64 &paths);
//  void ConvertPolyPathToCPolyPath(const PolyPath64* polypath, CPolyPathsD& v);
//  CPolyTreeD ConvertPolyTreeToCPolyTree(const PolyTree64 &polytree);
//
//
//  // Boolean Ops
//
//  void ExecuteBooleanOp(ClipType clip_type, Paths64 &closed_subjects, Paths64 &open_subjects, Paths64 &clips, Paths64 &closed_paths_solution, Paths64 &open_paths_solution, bool preserve_colinear = false);
//  void ExecuteBooleanOp(ClipType clip_type, Paths64 &closed_subjects, Paths64 &open_subjects, Paths64 &clips, PolyTree64 &polytree_solution, Paths64 &open_paths_solution, bool preserve_colinear = false);

}

#endif // CLIPPER_WRAPPER_H
