# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG c65db0c1430ab7272e7e370ec02f2187bf86abcd
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
