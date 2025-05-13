# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 2d1d1df8fcafdacbfd4b4e075749b3f1c99987ec
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
