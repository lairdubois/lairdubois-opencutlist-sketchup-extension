# -------------------------------------------------------------------
#                             Xly

# -------------------------------------------------------------------
#                             extern

add_subdirectory(extern)

# -------------------------------------------------------------------

if(WIN32)
  add_compile_definitions(LIBXLY_EXPORTS)
else()
  add_compile_options(-fPIC)
endif()

# Library headers
set(LIBRARY_HEADERS
        include/xly.hpp
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
if(WIN32)
  set(LIBRARY_SOURCES
          src/xly.cpp
          src/dllmain.cpp
  )
else()
  set(LIBRARY_SOURCES
          src/xly.cpp
  )
endif()
source_group("Sources" FILES ${LIBRARY_SOURCES})

if(WIN32)
  include(GenerateExportHeader)
endif()

add_library(Xly SHARED ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

if(WIN32)
  generate_export_header(Xly
          BASE_NAME Xly
          EXPORT_MACRO_NAME Xly_EXPORT
          EXPORT_FILE_NAME Xly_Export.h
          STATIC_DEFINE Xly_BUILT_AS_STATIC
  )
endif()

target_include_directories(Xly PUBLIC include)
target_link_libraries(Xly PUBLIC nlohmann_json::nlohmann_json)
target_link_libraries(Xly PUBLIC xlsxwriter)
target_compile_features(Xly PRIVATE cxx_std_17)

install(TARGETS Xly RUNTIME DESTINATION lib)

# -------------------------------------------------------------------
#                           Debug executable

add_executable(XlyMain ${LIBRARY_HEADERS} ${LIBRARY_SOURCES} src/main.cpp)
target_include_directories(XlyMain PUBLIC include)
target_link_libraries(XlyMain PUBLIC nlohmann_json::nlohmann_json)
target_link_libraries(XlyMain PUBLIC xlsxwriter)
target_link_libraries(XlyMain PUBLIC Boost::program_options)
target_compile_features(XlyMain PRIVATE cxx_std_17)

install(TARGETS XlyMain RUNTIME DESTINATION lib)

