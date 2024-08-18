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

DLL_EXPORTS void c_append_bin_def(int id, int count, double length, double width, int type);
DLL_EXPORTS void c_append_item_def(int id, int count, int rotations, double* cpaths);

DLL_EXPORTS char* c_execute(char *raw_input, int verbosity_level);
DLL_EXPORTS char* c_execute_rectangle(char *c_objective, double c_spacing, double c_trimming, int verbosity_level);
DLL_EXPORTS char* c_execute_rectangleguillotine(char *c_objective, char *c_cut_type, char *c_first_stage_orientation, double c_spacing, double c_trimming, int verbosity_level);
DLL_EXPORTS char* c_execute_irregular(char *c_objective, double c_spacing, double c_trimming, int verbosity_level);
DLL_EXPORTS char* c_execute_onedimensional(char *c_objective, double c_spacing, double c_trimming, int verbosity_level);

DLL_EXPORTS double* c_get_solution();

DLL_EXPORTS void c_dispose_array_d(const double* p);

DLL_EXPORTS char* c_optimize(char* input);

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif