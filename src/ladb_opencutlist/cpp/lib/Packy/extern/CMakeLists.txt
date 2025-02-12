# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 31c6c9ab7541606922b940a7866849d856599b64
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
