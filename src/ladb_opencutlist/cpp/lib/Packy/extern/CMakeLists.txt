# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG b3b810c07d309d0ab82bce1f80f349249df72827
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
