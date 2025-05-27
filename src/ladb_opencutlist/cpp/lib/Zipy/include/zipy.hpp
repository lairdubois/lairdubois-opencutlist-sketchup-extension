#pragma once

#include <zip.h>

constexpr auto ZIPY_VERSION = "1.0.0";

#ifdef __cplusplus
extern "C" {
#endif

#ifdef LIBZIPY_EXPORTS
#define DLL_EXPORTS __declspec(dllexport)
#else
#define DLL_EXPORTS
#endif

    DLL_EXPORTS zip_t* zipy_open(
        const char* zipname,
        int level,
        char mode
    );

    DLL_EXPORTS void zipy_close(
        zip_t *zip
    );


    DLL_EXPORTS int zipy_entry_open(
        zip_t* zip,
        const char* entryname
    );

    DLL_EXPORTS int zipy_entry_close(
        zip_t *zip
    );


    DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif