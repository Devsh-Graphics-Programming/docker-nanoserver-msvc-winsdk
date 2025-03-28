cmake_policy(SET CMP0119 NEW) # https://cmake.org/cmake/help/latest/policy/CMP0119.html#policy:CMP0119
cmake_minimum_required(VERSION 3.31.0)
project(NanoMSVC CXX C)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(3rdparty)
add_subdirectory(src)