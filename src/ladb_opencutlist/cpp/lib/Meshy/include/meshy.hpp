constexpr auto MESHY_VERSION = "1.0.0";

#ifdef __cplusplus
extern "C" {
#endif

#ifdef LIBMESHY_EXPORTS
#define DLL_EXPORTS __declspec(dllexport)
#else
#define DLL_EXPORTS
#endif

DLL_EXPORTS char* c_operate(
        const char* s_input
);

DLL_EXPORTS char* c_version();

#ifdef __cplusplus
}
#endif