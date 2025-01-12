# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG ed338fcf6474a5cc1672cf014da2728835777b3c
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
