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

DLL_EXPORTS char* c_optimize_start(
        char* s_input
);
DLL_EXPORTS char* c_optimize_advance();
DLL_EXPORTS void c_optimize_cancel();

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif