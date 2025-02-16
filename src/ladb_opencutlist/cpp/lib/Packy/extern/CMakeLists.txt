# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 11477b915edeef9bce08a4d80473588a3fb04513
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
