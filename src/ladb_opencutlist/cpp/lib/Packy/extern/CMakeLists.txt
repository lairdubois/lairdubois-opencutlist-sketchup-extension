# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG a9c0511222535c70b2998a16c8ea0bb71bf7c25c
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
