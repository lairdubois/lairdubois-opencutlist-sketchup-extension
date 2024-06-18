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

DLL_EXPORTS void c_append_bin_def(int id, int count, int64_t length, int64_t width, int type);
DLL_EXPORTS void c_append_shape_def(int id, int count, int rotations, const int64_t* cpaths);

DLL_EXPORTS char* c_execute_rectangle(char *c_objective, int64_t c_spacing, int64_t trimming, int verbosity_level);
DLL_EXPORTS char* c_execute_rectangleguillotine(char *c_objective, char *c_first_stage_orientation, int64_t c_spacing, int64_t c_trimming, int verbosity_level);
DLL_EXPORTS char* c_execute_irregular(char *c_objective, int64_t c_spacing, int64_t c_trimming, int verbosity_level);
DLL_EXPORTS char* c_execute_onedimensional(char *c_objective, int64_t c_spacing, int64_t c_trimming, int verbosity_level);

DLL_EXPORTS int64_t* c_get_solution();

DLL_EXPORTS void c_dispose_array64(const int64_t* p);

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif