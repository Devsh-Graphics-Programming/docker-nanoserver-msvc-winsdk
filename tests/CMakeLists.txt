cmake_minimum_required(VERSION 3.30)
project(NanoMSVC CXX C)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CONFIGURATION_TYPES "Debug;Release;RelWithDebInfo")

set(CPM_CMAKE "${CMAKE_CURRENT_BINARY_DIR}/cmake/CPM.cmake")
set(CPM_URL https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.7/CPM.cmake)

file(DOWNLOAD ${CPM_URL} ${CPM_CMAKE} EXPECTED_HASH SHA256=c0fc82149e00c43a21febe7b2ca57b2ffea2b8e88ab867022c21d6b81937eb50) # cmake -E sha256sum CPM.cmake
include(${CPM_CMAKE})

CPMAddPackage(NAME libjpeg-turbo URL https://github.com/libjpeg-turbo/libjpeg-turbo/archive/97a1575cb877e593cf9940cd869f41b1ddd4a4fd.tar.gz)
CPMAddPackage(NAME blake3 URL https://github.com/BLAKE3-team/BLAKE3/archive/refs/tags/1.6.1.tar.gz DOWNLOAD_ONLY YES)
add_subdirectory("${blake3_SOURCE_DIR}/c" blake3)

add_subdirectory(src)