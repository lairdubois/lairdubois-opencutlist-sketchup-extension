# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 784fee56be26531570f20d695c5d3da11c689834
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
