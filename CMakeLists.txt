# -------------------------------------------------------------------
#                 Build system for OpenCutList C/C++ libs
# -------------------------------------------------------------------
# Requirements:
#   - CMake version 3.18+
#   - A C++17 compiler
# -------------------------------------------------------------------

cmake_minimum_required(VERSION 3.18)

project("OpenCutList Dynamic Libraries" LANGUAGES C CXX)

# CMake options
set(CMAKE_BUILD_TYPE "Release")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(WIN32)
  set(CMAKE_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/src/ladb_opencutlist/bin/win/)
endif()
if(APPLE)
  set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "" FORCE)
  set(CMAKE_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/src/ladb_opencutlist/bin/osx/)
endif()

option(BUILD_SHARED_LIBS ON)

message(STATUS "--------------- General configuration -------------")
message(STATUS "CMake Generator:                ${CMAKE_GENERATOR}")
message(STATUS "Compiler:                       ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "Build type:                     ${CMAKE_BUILD_TYPE}")
message(STATUS "CMAKE_CXX_FLAGS:                ${CMAKE_CXX_FLAGS}")
message(STATUS "CMAKE_CXX_FLAGS_DEBUG:          ${CMAKE_CXX_FLAGS_DEBUG}")
message(STATUS "CMAKE_CXX_FLAGS_RELEASE:        ${CMAKE_CXX_FLAGS_RELEASE}")
message(STATUS "CMAKE_CXX_FLAGS_RELWITHDEBINFO: ${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
message(STATUS "CMAKE_EXE_LINKER_FLAGS          ${CMAKE_EXE_LINKER_FLAGS}")
message(STATUS "CMAKE_LINKER_FLAGS_DEBUG        ${CMAKE_LINKER_FLAGS_DEBUG}")
message(STATUS "CMAKE_SHARED_LINKER_FLAGS       ${CMAKE_SHARED_LINKER_FLAGS}")
message(STATUS "CMAKE_SOURCE_DIR:               ${CMAKE_SOURCE_DIR}" )
message(STATUS "CMAKE_INSTALL_PREFIX:           ${CMAKE_INSTALL_PREFIX}" )
message(STATUS "CMAKE_PREFIX_PATH:              ${CMAKE_PREFIX_PATH}" )
message(STATUS "CMAKE_TOOLCHAIN_FILE:           ${CMAKE_TOOLCHAIN_FILE}" )
message(STATUS "---------------------------------------------------")

add_subdirectory(src/ladb_opencutlist/c/lib)