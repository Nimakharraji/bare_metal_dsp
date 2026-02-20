cmake_minimum_required(VERSION 3.14)

project(baremetal_dsp_engine LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- Flag Management ---
if(MSVC)
    # Common flags for Windows
    add_compile_options(/fp:fast)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)

    # Apply /O2 (Optimization) ONLY for Release and Profile
    add_compile_options($<$<CONFIG:Release>:/O2>)
    add_compile_options($<$<CONFIG:Profile>:/O2>)

    # Apply /Od (Disable Optimization) for Debug to allow /RTC1 work
    add_compile_options($<$<CONFIG:Debug>:/Od>)
    add_compile_options($<$<CONFIG:Debug>:/Zi>)
else()
    # Linux/Android/macOS
    add_compile_options(-Ofast -pthread)
endif()

# Define the shared library
add_library(baremetal_dsp SHARED
    engine.cpp
)

# Include directories
target_include_directories(baremetal_dsp PRIVATE .)

# Platform specific linking
if(UNIX AND NOT APPLE)
    target_link_libraries(baremetal_dsp PRIVATE dl pthread m)
endif()

if(APPLE)
    find_library(COREAUDIO CoreAudio)
    find_library(AUDIOTOOLBOX AudioToolbox)
    target_link_libraries(baremetal_dsp PRIVATE ${COREAUDIO} ${AUDIOTOOLBOX})
endif()

set_target_properties(baremetal_dsp PROPERTIES 
    WINDOWS_EXPORT_ALL_SYMBOLS TRUE
)