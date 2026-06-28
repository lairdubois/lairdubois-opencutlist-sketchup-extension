# -------------------------------------------------------------------
#                             Skpy

# -------------------------------------------------------------------
#                             extern

add_subdirectory(extern)

# -------------------------------------------------------------------

if(WIN32)
  add_compile_definitions(LIBSKPY_EXPORTS)
else()
  add_compile_options(-fPIC)
endif()

# Library headers
set(LIBRARY_HEADERS
        include/skp_header_reader.hpp
        include/skpy.hpp
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
if(WIN32)
  set(LIBRARY_SOURCES
          src/skp_header_reader.cpp
          src/skpy.cpp
          src/dllmain.cpp
  )
else()
  set(LIBRARY_SOURCES
          src/skp_header_reader.cpp
          src/skpy.cpp
  )
endif()
source_group("Sources" FILES ${LIBRARY_SOURCES})

if(WIN32)
  include(GenerateExportHeader)
endif()

add_library(Skpy SHARED ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

if(WIN32)
  generate_export_header(Skpy
          BASE_NAME Skpy
          EXPORT_MACRO_NAME Skpy_EXPORT
          EXPORT_FILE_NAME Skpy_Export.h
          STATIC_DEFINE Skpy_BUILT_AS_STATIC
  )
endif()

target_include_directories(Skpy PUBLIC include)
target_link_libraries(Skpy PRIVATE nlohmann_json::nlohmann_json)
target_compile_features(Skpy PRIVATE cxx_std_17)

install(TARGETS Skpy RUNTIME DESTINATION lib)

# -------------------------------------------------------------------
#                           Debug executable

if(OCL_BUILD_MAIN)

  add_executable(SkpyMain ${LIBRARY_HEADERS} ${LIBRARY_SOURCES} src/main.cpp)
  target_include_directories(SkpyMain PUBLIC include)
  target_link_libraries(SkpyMain PRIVATE nlohmann_json::nlohmann_json)
  target_link_libraries(SkpyMain PRIVATE Boost::program_options)
  target_compile_features(SkpyMain PRIVATE cxx_std_17)

  install(TARGETS SkpyMain RUNTIME DESTINATION lib)

endif()
