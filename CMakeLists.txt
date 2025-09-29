# -------------------------------------------------------------------
#                 Build system for OpenCutList C/C++ libs
# -------------------------------------------------------------------
# Requirements:
#   - CMake version 3.18+
#   - A C++17 compiler
# -------------------------------------------------------------------

cmake_minimum_required(VERSION 3.18)

if(APPLE)
  set(CMAKE_OSX_DEPLOYMENT_TARGET "10.13" CACHE STRING "Minimum OS X deployment version" FORCE)
  set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "Available architectures" FORCE)
endif()

project("OpenCutList Dynamic Libraries"
        DESCRIPTION "CMake configuration to build all OpenCutList Dynamic Libraries"
        LANGUAGES C CXX)

# CMake options
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_VERBOSE_MAKEFILE OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(WIN32)
  if(MSVC)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
  endif()
  set(CMAKE_OBJECT_PATH_MAX 260)
  set(CMAKE_GENERATOR_PLATFORM "x64")
  set(CMAKE_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/src/ladb_opencutlist/bin/win/)
endif()
if(APPLE)
  set(CMAKE_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/src/ladb_opencutlist/bin/osx/)
endif()
set(OCL_BUILD_MAIN OFF CACHE BOOL "Enables compilation of debug executables")

option(BUILD_SHARED_LIBS ON)

message(STATUS "--------------- General configuration -------------")
message(STATUS "CMAKE_VERSION:                  ${CMAKE_VERSION}")
message(STATUS "CMAKE_GENERATOR:                ${CMAKE_GENERATOR}")
message(STATUS "CMAKE_GENERATOR_PLATFORM:       ${CMAKE_GENERATOR_PLATFORM}")
message(STATUS "CMAKE_CXX_COMPILER_ID:          ${CMAKE_CXX_COMPILER_ID}")
message(STATUS "CMAKE_CXX_COMPILER_VERSION:     ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "CMAKE_BUILD_TYPE:               ${CMAKE_BUILD_TYPE}")
message(STATUS "CMAKE_CXX_FLAGS:                ${CMAKE_CXX_FLAGS}")
message(STATUS "CMAKE_CXX_FLAGS_DEBUG:          ${CMAKE_CXX_FLAGS_DEBUG}")
message(STATUS "CMAKE_CXX_FLAGS_RELEASE:        ${CMAKE_CXX_FLAGS_RELEASE}")
message(STATUS "CMAKE_EXE_LINKER_FLAGS          ${CMAKE_EXE_LINKER_FLAGS}")
message(STATUS "CMAKE_LINKER_FLAGS_DEBUG        ${CMAKE_LINKER_FLAGS_DEBUG}")
message(STATUS "CMAKE_SHARED_LINKER_FLAGS       ${CMAKE_SHARED_LINKER_FLAGS}")
message(STATUS "CMAKE_SOURCE_DIR:               ${CMAKE_SOURCE_DIR}" )
message(STATUS "CMAKE_INSTALL_PREFIX:           ${CMAKE_INSTALL_PREFIX}" )
message(STATUS "CMAKE_PREFIX_PATH:              ${CMAKE_PREFIX_PATH}" )
message(STATUS "CMAKE_TOOLCHAIN_FILE:           ${CMAKE_TOOLCHAIN_FILE}" )
message(STATUS "--------------- Windows configuration -------------")
message(STATUS "CMAKE_MSVC_RUNTIME_LIBRARY:     ${CMAKE_MSVC_RUNTIME_LIBRARY}" )
message(STATUS "CMAKE_OBJECT_PATH_MAX:          ${CMAKE_OBJECT_PATH_MAX}" )
message(STATUS "--------------- Mac configuration -------------")
message(STATUS "CMAKE_OSX_ARCHITECTURES:        ${CMAKE_OSX_ARCHITECTURES}" )
message(STATUS "CMAKE_OSX_DEPLOYMENT_TARGET:    ${CMAKE_OSX_DEPLOYMENT_TARGET}" )
message(STATUS "---------------------------------------------------")

add_subdirectory(src/ladb_opencutlist/cpp/lib)