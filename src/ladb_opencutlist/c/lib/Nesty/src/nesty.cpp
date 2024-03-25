#include "clipper2/clipper.h"

#include <nesty.h>

#ifdef __cplusplus
extern "C" {
#endif

DLL_EXPORTS char* c_version(void) {
  return (char *)CLIPPER2_VERSION;
}

#ifdef __cplusplus
}
#endif