# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 8f9b519dcf03627c8ab3d61c84d10565a90cea9b
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
