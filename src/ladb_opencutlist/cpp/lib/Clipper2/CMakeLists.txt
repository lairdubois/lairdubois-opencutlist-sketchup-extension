# -------------------------------------------------------------------
#                             Clipper2

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
if(NOT DEFINED CMAKE_CXX_STANDARD OR CMAKE_CXX_STANDARD LESS 17)
  set(CMAKE_CXX_STANDARD 17)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# CLIPPER2_HI_PRECISION: See GetIntersectPoint() in clipper.core.h 
option(CLIPPER2_HI_PRECISION "Caution: enabling this will compromise performance" OFF)

# CLIPPER2_MAX_DECIMAL_PRECISION: maximum decimal precision when scaling PathsD to Paths64.
# Caution: excessive scaling will increase the likelihood of integer overflow errors.
set(CLIPPER2_MAX_DECIMAL_PRECISION 8 CACHE STRING "Maximum decimal precision range")

# Library headers
set(LIBRARY_HEADERS
        include/clipper2/clipper.h
        include/clipper2/clipper.version.h
        include/clipper2/clipper.core.h
        include/clipper2/clipper.engine.h
        include/clipper2/clipper.minkowski.h
        include/clipper2/clipper.offset.h
        include/clipper2/clipper.rectclip.h
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
set(LIBRARY_SOURCES
        src/clipper.engine.cpp
        src/clipper.offset.cpp
        src/clipper.rectclip.cpp
)
source_group("Sources" FILES ${LIBRARY_SOURCES})

add_library(Clipper2 ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

target_compile_definitions(
        Clipper2 PUBLIC
        CLIPPER2_MAX_DECIMAL_PRECISION=${CLIPPER2_MAX_DECIMAL_PRECISION}
        $<$<BOOL:${CLIPPER2_HI_PRECISION}>:CLIPPER2_HI_PRECISION>
)

target_include_directories(Clipper2 PUBLIC include)

if (MSVC)
  target_compile_options(Clipper2 PRIVATE /W4 /WX)
else()
  target_compile_options(Clipper2 PRIVATE -Wall -Wextra -Wpedantic -Werror -Wno-c++20-compat)
  target_link_libraries(Clipper2 PUBLIC -lm)
endif()
