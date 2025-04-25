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
        const char* s_input
);
DLL_EXPORTS char* c_optimize_advance(
        int run_id
);
DLL_EXPORTS char* c_optimize_cancel(
        int run_id
);
DLL_EXPORTS char* c_optimize_cancel_all();

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif