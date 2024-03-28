#include <cstddef>
#include <cstdint>
#include <cstdbool>

#include "imagy.image.h"

constexpr auto IMAGY_VERSION = "1.0.0";

#ifdef __cplusplus
extern "C" {
#endif

#ifdef LIBIMAGY_EXPORTS
#define DLL_EXPORTS __declspec(dllexport)
#else
#define DLL_EXPORTS
#endif

DLL_EXPORTS int c_load(const char* filename);
DLL_EXPORTS int c_write(const char* filename);

DLL_EXPORTS int c_get_width(void);
DLL_EXPORTS int c_get_height(void);

DLL_EXPORTS void c_flip_x(void);
DLL_EXPORTS void c_flip_y(void);

DLL_EXPORTS void c_rotate_left(int times);
DLL_EXPORTS void c_rotate_right(int times);

DLL_EXPORTS char* c_version(void);

#ifdef __cplusplus
}
#endif