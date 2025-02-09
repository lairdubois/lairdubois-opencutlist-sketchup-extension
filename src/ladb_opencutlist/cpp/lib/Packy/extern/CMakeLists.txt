# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 5d3950f5fdd048cd29c118debb985075e44d8ec7
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
