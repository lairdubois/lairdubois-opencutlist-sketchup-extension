# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG c31cd6a0fdcb9291946f0884a6306e4a1c502daf
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
