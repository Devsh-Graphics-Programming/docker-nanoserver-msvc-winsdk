if(CMAKE_VERSION VERSION_LESS "3.31.0")
    message(FATAL_ERROR "CMake version must be at least 3.31.0 to use this toolchain file!")
endif()

if(NOT CMAKE_GENERATOR MATCHES "Ninja*")
    message(FATAL_ERROR "CMAKE_GENERATOR = \"${CMAKE_GENERATOR}\" is unsupported, use Ninja (single or multi config) generators!")
endif()

# https://cmake.org/cmake/help/v3.31/variable/CMAKE_GENERATOR_INSTANCE.html#visual-studio-instance-selection
cmake_path(CONVERT $ENV{VS_INSTANCE_LOCATION} TO_CMAKE_PATH_LIST VS_INSTANCE_LOCATION NORMALIZE)
cmake_path(CONVERT $ENV{CMAKE_WINDOWS_KITS_10_DIR} TO_CMAKE_PATH_LIST WINDOWS_KITS_10_DIR NORMALIZE)
cmake_path(CONVERT $ENV{WINDOWS_SDK_VERSION} TO_CMAKE_PATH_LIST WINDOWS_SDK_VERSION NORMALIZE)
cmake_path(CONVERT $ENV{MSVC_TOOLSET_DIR} TO_CMAKE_PATH_LIST MSVC_TOOLSET_DIR NORMALIZE)
cmake_path(CONVERT $ENV{LLVM_TOOLSET_DIR} TO_CMAKE_PATH_LIST LLVM_TOOLSET_DIR NORMALIZE)

message(STATUS "VS_INSTANCE_LOCATION = \"${VS_INSTANCE_LOCATION}\"")
message(STATUS "WINDOWS_KITS_10_DIR = \"${WINDOWS_KITS_10_DIR}\"")
message(STATUS "WINDOWS_SDK_VERSION = \"${WINDOWS_SDK_VERSION}\"")
message(STATUS "MSVC_TOOLSET_DIR = \"${MSVC_TOOLSET_DIR}\"")
message(STATUS "LLVM_TOOLSET_DIR = \"${LLVM_TOOLSET_DIR}\"")

if(NOT EXISTS "${VS_INSTANCE_LOCATION}")
    message("VS_INSTANCE_LOCATION is invalid!")
endif()

macro(IS_WITHIN_VC_LOCATION VAR)
    string(FIND "${${VAR}}" "${VS_INSTANCE_LOCATION}" FOUND)
    if("${FOUND}" MATCHES "-1")
        message(FATAL_ERROR "${VAR} is not within VS_INSTANCE_LOCATION, did you move the toolset directory outside the VS installation?")
    endif()
endmacro()

IS_WITHIN_VC_LOCATION(MSVC_TOOLSET_DIR)
IS_WITHIN_VC_LOCATION(LLVM_TOOLSET_DIR)

set(CMAKE_SYSTEM_PROCESSOR ${CMAKE_HOST_SYSTEM_PROCESSOR})

if(ARCH)
    if(ARCH MATCHES "x64")
    elseif(ARCH MATCHES "arm64")
        set(CMAKE_SYSTEM_NAME Windows)
        set(CMAKE_SYSTEM_PROCESSOR arm64)
        # never tested it but I'm pretty sure _COMPILER needs to be updated depending on target ARCH
        message(FATAL_ERROR "TODO, Cross compilation requires ARM64 build tools compoment and updates to the toolchain file!")
    else()
        message(STATUS "Unsupported ARCH = \"${ARCH}\"")
        message(FATAL_ERROR "Supported ARCH = \"x64\", \"arm64\"")
    endif()
else()
 set(ARCH x64)
endif()

set(LIB
    "${WINDOWS_KITS_10_DIR}/Lib/${WINDOWS_SDK_VERSION}/ucrt/${ARCH}"
    "${WINDOWS_KITS_10_DIR}/Lib/${WINDOWS_SDK_VERSION}/um/${ARCH}"
    "${MSVC_TOOLSET_DIR}/lib/${ARCH}"
    "${MSVC_TOOLSET_DIR}/atlmfc/lib/${ARCH}"
)

set(INCLUDE
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/winrt"
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/cppwinrt"
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/shared"
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/ucrt"
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/um"
    "${MSVC_TOOLSET_DIR}/include"
    "${MSVC_TOOLSET_DIR}/atlmfc/include"
)

set(ENV{LIB} "${LIB}")
set(ENV{INCLUDE} "${INCLUDE}")

function(_VALIDATE_ENV_V_ ENVN)
list(APPEND TO_VALIDATE $ENV{${ENVN}})
foreach(EPATH IN LISTS TO_VALIDATE)
    if(NOT EXISTS "${EPATH}")
        message(FATAL_ERROR "Validation failed for ${ENVN} ENV. PATH = \"${EPATH}\" doesn't exist!")
    endif()
endforeach()
endfunction()

_VALIDATE_ENV_V_(LIB)
_VALIDATE_ENV_V_(INCLUDE)

macro(_UPDATE_STANDARD_DIRECTORIES_ WHAT VARV)
    set(CMAKE_C_STANDARD_${WHAT}_DIRECTORIES ${VARV} CACHE FILEPATH "")
    set(CMAKE_CXX_STANDARD_${WHAT}_DIRECTORIES ${VARV} CACHE FILEPATH "")
    set(CMAKE_RC_STANDARD_${WHAT}_DIRECTORIES ${VARV} CACHE FILEPATH "")
    set(CMAKE_ASM_STANDARD_${WHAT}_DIRECTORIES ${VARV} CACHE FILEPATH "")
    set(CMAKE_NASM_STANDARD_${WHAT}_DIRECTORIES ${VARV} CACHE FILEPATH "")
    set(CMAKE_MASM_STANDARD_${WHAT}_DIRECTORIES ${VARV} CACHE FILEPATH "")
endmacro()

_UPDATE_STANDARD_DIRECTORIES_(INCLUDE "${INCLUDE}")
_UPDATE_STANDARD_DIRECTORIES_(LINK "${LIB}")

set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

# extensions
# TODO: could use vswhere.exe with component IDs
macro(_REQUEST_EXTENSION_ WHAT HINT)
if(EXISTS "${HINT}")
    set(${WHAT} "${HINT}")
    message(STATUS "WITH ${WHAT} = \"${HINT}\"")
endif()
endmacro()

_REQUEST_EXTENSION_(DIASDK_INCLUDE_DIR "${VS_INSTANCE_LOCATION}/DIA SDK/include")

# redists
function(_REQUEST_REDIST_MODULES BASE OUTPUT)
    if(NOT EXISTS "${BASE}")
        message(FATAL_ERROR "Internal error, base \"${BASE}\" for redist module search directories doesn't exist - is your build tools installation corrupted?")
    endif()

    file(GLOB_RECURSE _MODULES LIST_DIRECTORIES false "${BASE}/*.dll")

    set(_DIRS)
    foreach(f IN LISTS _MODULES)
        get_filename_component(d "${f}" DIRECTORY)
        list(APPEND _DIRS "${d}")
    endforeach()

    list(REMOVE_DUPLICATES _DIRS)

    set(${OUTPUT} "${_DIRS}")

    if(NOT ${OUTPUT})
        message(FATAL_ERROR "Internal error, no redist module search directories found (CRTs) - is your build tools installation corrupted?")
    endif()

    set(${OUTPUT} "${${OUTPUT}}" PARENT_SCOPE)
endfunction()

cmake_path(GET MSVC_TOOLSET_DIR FILENAME VER)

set(REDISTS "${VS_INSTANCE_LOCATION}/VC/Redist/MSVC")
string(REGEX REPLACE "^([0-9]+)\\..*" "\\1" REDISTS_TARGET_MAJOR "${VER}")
file(GLOB REDISTS_VERSIONS RELATIVE "${REDISTS}" "${REDISTS}/${REDISTS_TARGET_MAJOR}.*")

if(NOT REDISTS_VERSIONS)
    message(FATAL_ERROR "No ${REDISTS_TARGET_MAJOR}.x Redists found at \"${REDISTS}\"!")
endif()

# current policy - pick latest redists since its backwards compatible
# note: toolset version is not guaranteed to match 1:1 redists versioning
list(GET REDISTS_VERSIONS 0 VER)
foreach(IT ${REDISTS_VERSIONS})
    if(IT VERSION_GREATER VER)
        set(VER ${IT})
    endif()
endforeach()

cmake_path(CONVERT "${VS_INSTANCE_LOCATION}/VC/Redist/MSVC/${VER}" TO_CMAKE_PATH_LIST MSVC_REDIST_BASE NORMALIZE)
_REQUEST_REDIST_MODULES("${MSVC_REDIST_BASE}/${ARCH}" RELEASE_REDISTS)
_REQUEST_REDIST_MODULES("${MSVC_REDIST_BASE}/debug_nonredist/${ARCH}" DEBUG_REDISTS)
set(MSVC_REDIST_MODULE_DIRECTORIES "${RELEASE_REDISTS};${DEBUG_REDISTS}" CACHE FILEPATH "MSVC Redist module search directories")

set(UCRTBASED_DLL_DIR "${WINDOWS_KITS_10_DIR}/bin/${WINDOWS_SDK_VERSION}/${ARCH}/ucrt" CACHE FILEPATH "Debug C++ Runtime DLL directory")
find_file(UCRTBASED_DLL_PATH NAMES ucrtbased.dll HINTS "${UCRTBASED_DLL_DIR}" REQUIRED)

set(BUILD_MODULE_SEARCH_DIRS 
    ${MSVC_REDIST_MODULE_DIRECTORIES}
    ${UCRTBASED_DLL_DIR}
)

# launchers
string(CONFIGURE [=[
@echo off
set "CMAKE=@CMAKE_COMMAND@"
set "PATH=@BUILD_MODULE_SEARCH_DIRS@;%PATH%"
%*
]=] SHELL)

set(SHELL_LOCATION "${CMAKE_BINARY_DIR}/shell.cmd")
file(WRITE "${SHELL_LOCATION}" "${SHELL}")

set_property(GLOBAL PROPERTY RULE_LAUNCH_CUSTOM "${SHELL_LOCATION}")

# NASM
find_program(CMAKE_ASM_NASM_COMPILER nasm HINTS ENV PATH ENV NASM_DIR NO_CACHE REQUIRED)
set(CMAKE_ASM_NASM_COMPILER "${CMAKE_ASM_NASM_COMPILER}" CACHE FILEPATH "")

# BINs
set(CL_BIN "${MSVC_TOOLSET_DIR}/bin/Host${ARCH}/${ARCH}")
set(CLANGCL_BIN "${LLVM_TOOLSET_DIR}/${ARCH}/bin")
set(WIN_SDK_BIN "${WINDOWS_KITS_10_DIR}/bin/${WINDOWS_SDK_VERSION}/${ARCH}")
