# -------------------------------------------------------------------
#                             Clippy

if(WIN32)
  add_compile_definitions(LIBCLIPPY_EXPORTS)
else()
  add_compile_options(-fPIC)
endif()

# Library headers
set(LIBRARY_HEADERS
        include/clippy.hpp
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
if(WIN32)
  set(LIBRARY_SOURCES
          src/clippy.cpp
          src/dllmain.cpp
  )
else()
  set(LIBRARY_SOURCES
          src/clippy.cpp
  )
endif()
source_group("Sources" FILES ${LIBRARY_SOURCES})

if(WIN32)
  include(GenerateExportHeader)
endif()

add_library(Clippy SHARED ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

if(WIN32)
  generate_export_header(Clippy
          BASE_NAME Clippy
          EXPORT_MACRO_NAME Clippy_EXPORT
          EXPORT_FILE_NAME Clippy_Export.h
          STATIC_DEFINE Clippy_BUILT_AS_STATIC
  )
endif()

target_include_directories(Clippy PUBLIC include)
target_link_libraries(Clippy PRIVATE Clipper2Wrapper)
target_compile_features(Clippy PRIVATE cxx_std_17)

install(TARGETS Clippy RUNTIME DESTINATION lib)

# -------------------------------------------------------------------
#                           Debug executable

if(OCL_BUILD_DEBUG_EXECUTABLES)

  add_executable(ClippyMain ${LIBRARY_HEADERS} ${LIBRARY_SOURCES} src/main.cpp)
  target_include_directories(ClippyMain PUBLIC include)
  target_link_libraries(ClippyMain PRIVATE Clipper2Wrapper)
  target_link_libraries(ClippyMain PRIVATE Clipper2Utils)
  target_link_libraries(ClippyMain PUBLIC Boost::program_options)
  target_compile_features(ClippyMain PRIVATE cxx_std_17)

  install(TARGETS ClippyMain RUNTIME DESTINATION lib)

endif()