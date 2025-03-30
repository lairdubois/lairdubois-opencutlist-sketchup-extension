# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 86c14d976425a4ea5b7797f71cd849f4bf4f7926
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
