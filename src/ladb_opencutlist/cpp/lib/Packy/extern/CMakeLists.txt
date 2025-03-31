# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 9bba8e66d71a47a8c2c64d19fda03fa9116050a0
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
