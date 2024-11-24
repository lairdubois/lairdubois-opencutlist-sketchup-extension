# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG a1a63a0c0e1ae54e4a4073208b6ed5fcdf4d6887
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
