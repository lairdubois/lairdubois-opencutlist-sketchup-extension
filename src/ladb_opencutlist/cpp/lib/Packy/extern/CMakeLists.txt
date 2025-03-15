# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG d7e0fbc6384b20ff15dced43372279e6fe27b853
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
