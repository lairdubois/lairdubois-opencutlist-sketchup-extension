# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 33301f600d881afe84e07f1a64072a11f7916d4c
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
