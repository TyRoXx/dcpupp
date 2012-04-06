cmake_minimum_required(VERSION 2.8)

project(dcpupp)

set(CMAKE_CXX_FLAGS "-std=c++0x")

add_subdirectory(dcpu_asm)
add_subdirectory(dcpu_emu)
add_subdirectory(dcpu_code)

