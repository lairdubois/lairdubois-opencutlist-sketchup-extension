#pragma once

constexpr auto SKPY_VERSION = "8.0.0";

#ifdef LIBSKPY_EXPORTS
#define DLL_EXPORTS __declspec(dllexport)
#else
#define DLL_EXPORTS
#endif

#ifdef __cplusplus
extern "C" {
#endif

DLL_EXPORTS char* c_get_skp_version_info(const char* s_input);

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif