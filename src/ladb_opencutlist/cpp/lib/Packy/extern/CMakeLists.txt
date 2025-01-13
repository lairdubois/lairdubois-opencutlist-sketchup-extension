# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG bb32ba42ab13ffdf8297d11072c44a8aebfc7a95
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
