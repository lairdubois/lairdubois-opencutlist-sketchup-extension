# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG d42a0b960a14312e7f111b005e390d312126bc3f
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
