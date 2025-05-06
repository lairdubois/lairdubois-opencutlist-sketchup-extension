# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 828e89958c208451072ea6cea4a046175032f377
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
