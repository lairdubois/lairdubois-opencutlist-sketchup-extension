# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG f0b82c63ff7a2953b7d7c7a67378d805edf64cb3
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
