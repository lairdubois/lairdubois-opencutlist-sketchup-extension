# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 3c3e6ff98d8179da5bc380b2c829a7c0bf9b1eaf
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
