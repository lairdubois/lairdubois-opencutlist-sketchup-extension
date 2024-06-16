#include <cstddef>
#include <cstdint>

constexpr auto PACKY_VERSION = "1.0.0";

#ifdef __cplusplus
extern "C" {
#endif

#ifdef LIBPACKY_EXPORTS
#define DLL_EXPORTS __declspec(dllexport)
#else
#define DLL_EXPORTS
#endif

DLL_EXPORTS void c_clear();

DLL_EXPORTS void c_append_shape_def(int id, int count, const int64_t* cpaths);
DLL_EXPORTS void c_append_bin_def(int id, int count, int64_t length, int64_t width, int type);

DLL_EXPORTS char* c_execute_rectangle(int64_t spacing, int64_t trimming, int rotations);
DLL_EXPORTS char* c_execute_rectangleguillotine(int64_t spacing, int64_t trimming, int rotations);
DLL_EXPORTS char* c_execute_irregular(int64_t spacing, int64_t trimming, int rotations);
DLL_EXPORTS char* c_execute_onedimensional(int64_t spacing, int64_t trimming, int rotations);

DLL_EXPORTS int64_t* c_get_solution();

DLL_EXPORTS void c_dispose_array64(const int64_t* p);

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif