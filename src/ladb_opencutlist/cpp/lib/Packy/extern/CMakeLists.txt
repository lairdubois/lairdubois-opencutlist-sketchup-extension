# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/fontanf/packingsolver.git
        GIT_TAG 3d36ff45f4ffacfb94801dce0fc7812ba3321122
#        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
#        GIT_TAG 6ce1f9aa277a824a8d31c1a248a6afd53290c51d
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
