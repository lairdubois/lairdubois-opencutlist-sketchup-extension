# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 5d0e70e1b679d0598b40059319c42ffa618a085b
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
