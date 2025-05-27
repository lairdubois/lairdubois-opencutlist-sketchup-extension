#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdbool>

constexpr auto IMAGY_VERSION = "1.0.0";

#ifdef __cplusplus
extern "C" {
#endif

#ifdef LIBIMAGY_EXPORTS
#define DLL_EXPORTS __declspec(dllexport)
#else
#define DLL_EXPORTS
#endif

DLL_EXPORTS void c_clear();

DLL_EXPORTS int c_load(
        const char* filename
);
DLL_EXPORTS int c_write(
        const char* filename
);

DLL_EXPORTS int c_get_width();
DLL_EXPORTS int c_get_height();
DLL_EXPORTS int c_get_channels();

DLL_EXPORTS void c_flip_horizontal();
DLL_EXPORTS void c_flip_vertical();

DLL_EXPORTS void c_rotate(
        int angle
);

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif