# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 4fee89933cd2189b954372e5bc5f63c32f40c4f5
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
