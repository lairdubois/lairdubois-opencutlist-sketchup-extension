# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 855d304e8af2ffba4449f6c0cbd9a2c508345da2
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
