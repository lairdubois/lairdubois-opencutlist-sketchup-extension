# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 8b6bfffd00e2636ac9b3cbc7862814b13d9f09bd
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
