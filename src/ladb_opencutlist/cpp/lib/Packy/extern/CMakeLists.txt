# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 9739113780f97e930f44c9db6a0f9c137a7d2057
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
