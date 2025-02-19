# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 9dede317cdc56bc92233e341887acabb9c6cb0c8
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
