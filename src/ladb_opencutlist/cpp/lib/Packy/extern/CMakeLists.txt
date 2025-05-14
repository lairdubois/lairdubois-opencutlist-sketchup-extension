# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG cdb964226dd0f954e8d8c7ddd43ab6666ab8af94
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
