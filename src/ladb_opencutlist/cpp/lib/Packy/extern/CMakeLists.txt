# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 6d83c0e8b59725befba58a826c417ab8ecfc54a1
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
