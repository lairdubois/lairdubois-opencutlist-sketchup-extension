# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 54a0d34aad8a7436e43c86ea540e380bfa5fbfac
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
