# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG c5a779501b68cb9afc18df504e4bfc1268837dd4
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
