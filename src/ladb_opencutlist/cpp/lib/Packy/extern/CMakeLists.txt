# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG da446597d7d84f4b46bff0c1d3f7f218f5da545a
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
