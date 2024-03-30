#include <cstddef>
#include <cstdint>
#include <cstdbool>

constexpr auto CLIPPY_VERSION = "1.0.0";

#ifdef __cplusplus
extern "C" {
#endif

#ifdef LIBCLIPPY_EXPORTS
#define DLL_EXPORTS __declspec(dllexport)
#else
#define DLL_EXPORTS
#endif

DLL_EXPORTS void c_clear_subjects();
DLL_EXPORTS void c_append_closed_subject(const int64_t *cpath);
DLL_EXPORTS void c_append_open_subject(const int64_t *cpath);

DLL_EXPORTS void c_clear_clips();
DLL_EXPORTS void c_append_clip(const int64_t *cpath);

DLL_EXPORTS void c_execute_union();
DLL_EXPORTS void c_execute_difference();
DLL_EXPORTS void c_execute_intersection();
DLL_EXPORTS void c_execute_polytree();

DLL_EXPORTS void c_clear_paths_solution();
DLL_EXPORTS int64_t* c_get_closed_paths_solution();
DLL_EXPORTS int64_t* c_get_open_paths_solution();
DLL_EXPORTS void c_clear_polytree_solution();
DLL_EXPORTS int64_t* c_get_polytree_solution();

DLL_EXPORTS int c_is_cpath_positive(const int64_t* cpath);
DLL_EXPORTS double c_get_cpath_area(const int64_t* cpath);

DLL_EXPORTS void c_dispose_array64(const int64_t* p);

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif