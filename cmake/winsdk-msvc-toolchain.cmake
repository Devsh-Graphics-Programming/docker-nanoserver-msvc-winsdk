message(STATUS "Configuring with \"${CMAKE_CURRENT_LIST_FILE}\" toolchain")

if(CMAKE_VERSION VERSION_LESS "3.31.0")
    message(FATAL_ERROR "CMake version must be at least 3.31.0 to use this toolchain file!")
endif()

if(NOT CMAKE_GENERATOR MATCHES "Ninja*")
    message(FATAL_ERROR "CMAKE_GENERATOR = \"${CMAKE_GENERATOR}\" is unsupported, use Ninja (single or multi config) generators!")
endif()

cmake_path(CONVERT $ENV{CMAKE_WINDOWS_KITS_10_DIR} TO_CMAKE_PATH_LIST WINDOWS_KITS_10_DIR NORMALIZE)
cmake_path(CONVERT $ENV{WINDOWS_SDK_VERSION} TO_CMAKE_PATH_LIST WINDOWS_SDK_VERSION NORMALIZE)
cmake_path(CONVERT $ENV{MSVC_TOOLSET_DIR} TO_CMAKE_PATH_LIST MSVC_TOOLSET_DIR NORMALIZE)

if(VERBOSE)
    message(STATUS "WINDOWS_KITS_10_DIR = \"${WINDOWS_KITS_10_DIR}\"")
    message(STATUS "WINDOWS_SDK_VERSION = \"${WINDOWS_SDK_VERSION}\"")
    message(STATUS "MSVC_TOOLSET_DIR = \"${MSVC_TOOLSET_DIR}\"")
endif()

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR ${CMAKE_HOST_SYSTEM_PROCESSOR})

if(ARCH)
    if(ARCH MATCHES "x64")
    elseif(ARCH MATCHES "arm64")
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
)

set(INCLUDE
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/winrt"
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/cppwinrt"
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/shared"
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/ucrt"
    "${WINDOWS_KITS_10_DIR}/Include/${WINDOWS_SDK_VERSION}/um"
    "${MSVC_TOOLSET_DIR}/include"
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

set(CMAKE_C_COMPILER "${MSVC_TOOLSET_DIR}/bin/Host${ARCH}/${ARCH}/cl.exe")
set(CMAKE_CXX_COMPILER "${MSVC_TOOLSET_DIR}/bin/Host${ARCH}/${ARCH}/cl.exe")
set(CMAKE_ASM_COMPILER "${MSVC_TOOLSET_DIR}/bin/Host${ARCH}/${ARCH}/cl.exe")
set(CMAKE_ASM_MASM_COMPILER "${MSVC_TOOLSET_DIR}/bin/Host${ARCH}/${ARCH}/ml64.exe")
find_program(CMAKE_ASM_NASM_COMPILER nasm HINTS ENV PATH ENV NASM_DIR NO_CACHE REQUIRED)
set(CMAKE_RC_COMPILER "${WINDOWS_KITS_10_DIR}/bin/${WINDOWS_SDK_VERSION}/${ARCH}/rc.exe")
set(CMAKE_LINKER "${MSVC_TOOLSET_DIR}/bin/Host${ARCH}/${ARCH}/link.exe")
set(CMAKE_AR "${MSVC_TOOLSET_DIR}/bin/Host${ARCH}/${ARCH}/lib.exe")
set(CMAKE_MT "${WINDOWS_KITS_10_DIR}/bin/${WINDOWS_SDK_VERSION}/${ARCH}/mt.exe")

macro(_UPDATE_STANDARD_DIRECTORIES_ WHAT VARV)
    set(CMAKE_C_STANDARD_${WHAT}_DIRECTORIES ${VARV})
    set(CMAKE_CXX_STANDARD_${WHAT}_DIRECTORIES ${VARV})
    set(CMAKE_ASM_STANDARD_${WHAT}_DIRECTORIES ${VARV})
    set(CMAKE_NASM_STANDARD_${WHAT}_DIRECTORIES ${VARV})
    set(CMAKE_MASM_STANDARD_${WHAT}_DIRECTORIES ${VARV})
endmacro()

_UPDATE_STANDARD_DIRECTORIES_(INCLUDE "${INCLUDE}")
_UPDATE_STANDARD_DIRECTORIES_(LINK "${LIB}")

set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)