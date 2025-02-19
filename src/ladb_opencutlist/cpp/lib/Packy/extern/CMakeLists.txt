# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG aa9b8a3af15100d32a305b6db8616926905027ac
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
