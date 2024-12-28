# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 94793e4699bafee31bd81058c5a4caf4433066e6
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
