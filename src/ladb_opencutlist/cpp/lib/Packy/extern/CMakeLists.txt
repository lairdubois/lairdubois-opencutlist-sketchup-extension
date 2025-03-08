# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 5b53ae8d440242a57da050e3eef5b5460981b332
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
