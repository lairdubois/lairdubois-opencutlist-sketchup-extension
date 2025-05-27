#include <zipy.hpp>

#ifdef __cplusplus
extern "C" {
#endif

    DLL_EXPORTS zip_t* zipy_open(
        const char* zipname,
        int level,
        char mode
    ) {
        return zip_open(zipname, level, mode);
    }

    DLL_EXPORTS void zipy_close(
        zip_t* zip
    ) {
        zip_close(zip);
    }


    DLL_EXPORTS int zipy_entry_open(
        zip_t* zip,
        const char* entryname
    ) {
        return zip_entry_open(zip, entryname);
    }

    DLL_EXPORTS int zipy_entry_close(
        zip_t *zip
    ) {
        return zip_entry_close(zip);
    }


    DLL_EXPORTS char* c_version() {
        return (char*) ZIPY_VERSION;
    }

#ifdef __cplusplus
}
#endif