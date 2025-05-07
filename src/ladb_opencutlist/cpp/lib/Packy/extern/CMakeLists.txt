# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG a4a25893eb275caace3461b8c5d75187289ab66e
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
