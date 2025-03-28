project(NanoMSVC3rdparty CXX C ASM ASM_NASM ASM_MASM)

set(CPM_CMAKE "${CMAKE_CURRENT_BINARY_DIR}/cmake/CPM.cmake")
set(CPM_URL https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.7/CPM.cmake)

set(CPM_SOURCE_CACHE "${CMAKE_CURRENT_SOURCE_DIR}/packages")
set(CMAKE_FIND_PACKAGE_REDIRECTS_DIR "${CMAKE_CURRENT_BINARY_DIR}/packages/redirects")

file(DOWNLOAD ${CPM_URL} ${CPM_CMAKE} EXPECTED_HASH SHA256=c0fc82149e00c43a21febe7b2ca57b2ffea2b8e88ab867022c21d6b81937eb50) # cmake -E sha256sum CPM.cmake
include(${CPM_CMAKE})

# I'm doing hard assumption here for my tests, no SSH remotes & forced HTTPS
# for the configuration only, note the nano image doesn't rewrite urls
set(ENV{GIT_CONFIG_GLOBAL} "${CMAKE_CURRENT_BINARY_DIR}/.gitconfig")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/.gitconfig"
[=[
[url "https://github.com/"]
  insteadOf = git@github.com:
[safe]
  directory = *
]=]
)

CPMAddPackage(NAME libjpeg-turbo URL https://github.com/libjpeg-turbo/libjpeg-turbo/archive/97a1575cb877e593cf9940cd869f41b1ddd4a4fd.tar.gz)
CPMAddPackage(NAME blake3 URL https://github.com/BLAKE3-team/BLAKE3/archive/refs/tags/1.6.1.tar.gz DOWNLOAD_ONLY YES)
add_subdirectory("${blake3_SOURCE_DIR}/c")
CPMAddPackage(NAME dxc GITHUB_REPOSITORY Devsh-Graphics-Programming/DirectXShaderCompiler GIT_TAG 96a5b5c85ee1ec7e8333d7140e1d2384be4faa02 GIT_SHALLOW YES DOWNLOAD_ONLY YES)

set(DXC_ENABLE_ETW OFF) # this is very important, without disabling this one its impossbile to compile dxcompiler on nano server within its current build system
set(HLSL_OPTIONAL_PROJS_IN_DEFAULT OFF)
set(HLSL_ENABLE_ANALYZE OFF)
set(HLSL_OFFICIAL_BUILD OFF)
set(HLSL_ENABLE_FIXED_VER OFF)
set(HLSL_FIXED_VERSION_LOCATION "")
set(HLSL_BUILD_DXILCONV ON)
set(CLANG_VENDOR "")
set(ENABLE_SPIRV_CODEGEN ON)
set(SPIRV_BUILD_TESTS OFF)
set(CLANG_ENABLE_ARCMT OFF)
set(CLANG_ENABLE_STATIC_ANALYZER OFF)
set(CLANG_INCLUDE_TESTS OFF)
set(LLVM_INCLUDE_TESTS OFF)
set(HLSL_INCLUDE_TESTS OFF)
set(LLVM_INCLUDE_UTILS OFF)
set(LLVM_TARGETS_TO_BUILD None)
set(LLVM_INCLUDE_DOCS OFF)
set(LLVM_INCLUDE_EXAMPLES OFF)
set(LIBCLANG_BUILD_STATIC ON)
set(LLVM_OPTIMIZED_TABLEGEN OFF)
set(LLVM_REQUIRES_EH ON)
set(LLVM_APPEND_VC_REV ON)
set(LLVM_ENABLE_RTTI ON)
set(LLVM_ENABLE_EH ON)
set(LLVM_DEFAULT_TARGET_TRIPLE dxil-ms-dx)
set(CLANG_BUILD_EXAMPLES OFF)
set(LLVM_REQUIRES_RTTI ON)
set(CLANG_CL OFF)
set(LLVM_ENABLE_WERROR OFF)
set(SPIRV_WERROR OFF)
set(DXC_BUILD_ARCH x64)
set(SPIRV_HEADERS_SKIP_INSTALL ON)
set(SPIRV_HEADERS_SKIP_EXAMPLES ON)
set(SKIP_SPIRV_TOOLS_INSTALL ON)
set(SPIRV_SKIP_TESTS ON)
set(SPIRV_SKIP_EXECUTABLES ON)
set(HLSL_ENABLE_DEBUG_ITERATORS ON)

include("${dxc_SOURCE_DIR}/cmake/caches/PredefinedParams.cmake")
add_subdirectory("${dxc_SOURCE_DIR}" EXCLUDE_FROM_ALL)
set_target_properties(dxcompiler PROPERTIES EXCLUDE_FROM_ALL False)

# old jpeg-turbo doesn't explicilty associate .asm extension with ASM dialect, small patch
get_target_property(TARGET_SOURCE_DIR simd SOURCE_DIR)
get_target_property(TARGET_SOURCES simd SOURCES)
list(FILTER TARGET_SOURCES INCLUDE REGEX "\\.asm$")
list(TRANSFORM TARGET_SOURCES PREPEND "${TARGET_SOURCE_DIR}/")
set_source_files_properties(${TARGET_SOURCES} TARGET_DIRECTORY simd PROPERTIES LANGUAGE ASM_NASM)