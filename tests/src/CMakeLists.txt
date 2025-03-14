add_library(NanoSLib STATIC nanomsvc.cpp)
add_library(NanoDLib SHARED nanomsvc.cpp)

set_target_properties(NanoSLib PROPERTIES MSVC_RUNTIME_LIBRARY MultiThreaded$<$<CONFIG:Debug>:Debug>)
set_target_properties(NanoDLib PROPERTIES MSVC_RUNTIME_LIBRARY MultiThreaded$<$<CONFIG:Debug>:Debug>DLL)

target_compile_definitions(NanoSLib PRIVATE NANO_BUILDING_LIB)
target_compile_definitions(NanoDLib PRIVATE NANO_BUILDING_LIB)
target_compile_definitions(NanoDLib PUBLIC NANO_SHARED_BUILD)

target_link_libraries(NanoSLib PUBLIC Version)
target_link_libraries(NanoDLib PRIVATE Version)

target_include_directories(NanoSLib PUBLIC ../include)
target_include_directories(NanoDLib PUBLIC ../include)

set(NANO_COMPILE_OPTIONS
    $<$<CONFIG:Debug>:/Od>
    $<$<CONFIG:Release>:/O2 /DNDEBUG>
    $<$<CONFIG:RelWithDebInfo>:/O2>
)

target_compile_options(NanoSLib PRIVATE ${NANO_COMPILE_OPTIONS})
target_compile_options(NanoDLib PRIVATE ${NANO_COMPILE_OPTIONS})

add_executable(NanoSExe main.cpp)
add_executable(NanoDExe main.cpp)

target_link_libraries(NanoSExe PRIVATE NanoSLib)
target_link_libraries(NanoDExe PRIVATE NanoDLib)

enable_testing()

add_test(NAME NANO_EXE_S_TEST
	COMMAND $<TARGET_FILE:NanoSExe>
	COMMAND_EXPAND_LISTS
)

add_test(NAME NANO_EXE_D_TEST
	COMMAND $<TARGET_FILE:NanoDExe>
	COMMAND_EXPAND_LISTS
)

cmake_path(GET CMAKE_CXX_COMPILER PARENT_PATH CL_DIR)
set_tests_properties(NANO_EXE_S_TEST NANO_EXE_D_TEST
	# this allows me to fire tests with correct DLLs in search path,
	# note you should distibute used redists or make sure your end 
	# user install them system wide
	PROPERTIES ENVIRONMENT_MODIFICATION PATH=path_list_prepend:${CL_DIR}
)