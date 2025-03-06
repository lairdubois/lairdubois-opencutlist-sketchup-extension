# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG c4ee96d60e5c2de4b5c2ed3da58a9f042e27717c
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
