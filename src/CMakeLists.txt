cmake_minimum_required(VERSION 2.8)

project(dcpupp)

if(UNIX)
set(CMAKE_CXX_FLAGS "-std=c++0x")
endif(UNIX)

add_subdirectory(asm)
add_subdirectory(emu)

