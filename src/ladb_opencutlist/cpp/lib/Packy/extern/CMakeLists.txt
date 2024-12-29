# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG ddefec9fc8fb5f1c8a9bd649ff6db0581575363e
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
