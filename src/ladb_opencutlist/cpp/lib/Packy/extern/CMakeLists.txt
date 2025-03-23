# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 2c08a2c9702796337e7d27d63a2b62c37c7c4b76
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
