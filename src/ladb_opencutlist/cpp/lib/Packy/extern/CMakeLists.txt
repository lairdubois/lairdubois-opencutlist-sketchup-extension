# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 0879b29ebddb3fef7337fea9527390296a00bd21
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
