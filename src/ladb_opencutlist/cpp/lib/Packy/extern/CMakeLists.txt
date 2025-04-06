# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 737de9dc497dbbe3bb117f3d4d1c10668c71e17e
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
