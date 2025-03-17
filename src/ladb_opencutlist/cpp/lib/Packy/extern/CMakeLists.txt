# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 94e08729a112a557b059e3818d7dee6c9f28e945
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
