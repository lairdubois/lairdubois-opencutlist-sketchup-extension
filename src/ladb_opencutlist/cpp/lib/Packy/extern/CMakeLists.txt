# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 08a58d0bbac358446b9fe1b57eeda7607c696ce6
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
