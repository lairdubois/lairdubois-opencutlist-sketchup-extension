# -------------------------------------------------------------------
#                             Zipy

# -------------------------------------------------------------------
#                             extern

add_subdirectory(extern)

# -------------------------------------------------------------------

if(WIN32)
  add_compile_definitions(LIBZIPY_EXPORTS)
else()
  add_compile_options(-fPIC)
endif()

# Library headers
set(LIBRARY_HEADERS
        include/zipy.hpp
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
if(WIN32)
  set(LIBRARY_SOURCES
          src/zipy.cpp
          src/dllmain.cpp
  )
else()
  set(LIBRARY_SOURCES
          src/zipy.cpp
  )
endif()
source_group("Sources" FILES ${LIBRARY_SOURCES})

if(WIN32)
  include(GenerateExportHeader)
endif()

add_library(Zipy SHARED ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

if(WIN32)
  generate_export_header(Zipy
          BASE_NAME Zipy
          EXPORT_MACRO_NAME Zipy_EXPORT
          EXPORT_FILE_NAME Zipy_Export.h
          STATIC_DEFINE Zipy_BUILT_AS_STATIC
  )
endif()

target_include_directories(Zipy PUBLIC include)
target_link_libraries(Zipy PUBLIC zip)
target_compile_features(Zipy PRIVATE cxx_std_17)

install(TARGETS Zipy RUNTIME DESTINATION lib)