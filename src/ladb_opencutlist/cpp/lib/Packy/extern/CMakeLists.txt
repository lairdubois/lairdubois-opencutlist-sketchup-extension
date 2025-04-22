# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 50b83fd8cf01bc742acb6ac72d253d9623585ae0
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
