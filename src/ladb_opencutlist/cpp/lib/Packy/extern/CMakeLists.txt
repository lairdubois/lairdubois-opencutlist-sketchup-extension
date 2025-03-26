# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG aa35eb9bff4883dfdfe8e4a32aead2942d24bd2e
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
