project(NanoMSVC3rdparty CXX C ASM ASM_NASM ASM_MASM)

set(CPM_CMAKE "${CMAKE_CURRENT_BINARY_DIR}/cmake/CPM.cmake")
set(CPM_URL https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.7/CPM.cmake)

set(CPM_SOURCE_CACHE "${CMAKE_CURRENT_SOURCE_DIR}/packages")
set(CMAKE_FIND_PACKAGE_REDIRECTS_DIR "${CMAKE_CURRENT_BINARY_DIR}/packages/redirects")

file(DOWNLOAD ${CPM_URL} ${CPM_CMAKE} EXPECTED_HASH SHA256=c0fc82149e00c43a21febe7b2ca57b2ffea2b8e88ab867022c21d6b81937eb50) # cmake -E sha256sum CPM.cmake
include(${CPM_CMAKE})

CPMAddPackage(NAME libjpeg-turbo URL https://github.com/libjpeg-turbo/libjpeg-turbo/archive/97a1575cb877e593cf9940cd869f41b1ddd4a4fd.tar.gz)
CPMAddPackage(NAME blake3 URL https://github.com/BLAKE3-team/BLAKE3/archive/refs/tags/1.6.1.tar.gz DOWNLOAD_ONLY YES)
add_subdirectory("${blake3_SOURCE_DIR}/c")

# old jpeg-turbo doesn't explicilty associate .asm extension with ASM dialect, small patch
get_target_property(TARGET_SOURCE_DIR simd SOURCE_DIR)
get_target_property(TARGET_SOURCES simd SOURCES)
list(FILTER TARGET_SOURCES INCLUDE REGEX "\\.asm$")
list(TRANSFORM TARGET_SOURCES PREPEND "${TARGET_SOURCE_DIR}/")
set_source_files_properties(${TARGET_SOURCES} TARGET_DIRECTORY simd PROPERTIES LANGUAGE ASM_NASM)