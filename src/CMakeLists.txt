cmake_minimum_required(VERSION 3.14)

project(baremetal_dsp_engine LANGUAGES CXX)

# Hardcore optimization flags conditionally applied based on Build Configuration
if(MSVC)
    add_compile_options(/fp:fast /std:c++17 /MT)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
    
    # Release/Profile: Maximum speed (/O2)
    add_compile_options("$<$<CONFIG:Release>:/O2>")
    add_compile_options("$<$<CONFIG:Profile>:/O2>")
    
    # Debug: Disable optimization for compatibility with /RTC1
    add_compile_options("$<$<CONFIG:Debug>:/Od>")
else()
    add_compile_options(-ffast-math -std=c++17)
    
    add_compile_options("$<$<CONFIG:Release>:-O3>")
    add_compile_options("$<$<CONFIG:Profile>:-O3>")
    add_compile_options("$<$<CONFIG:Debug>:-O0>")
endif()

# Output target is a shared library
add_library(baremetal_dsp SHARED
    engine.cpp
)

set_target_properties(baremetal_dsp PROPERTIES 
    WINDOWS_EXPORT_ALL_SYMBOLS TRUE
)