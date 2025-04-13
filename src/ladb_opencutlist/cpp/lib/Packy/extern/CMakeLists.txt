# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 36363deaa08618e91e899d34a1b4161bafd91f79
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
