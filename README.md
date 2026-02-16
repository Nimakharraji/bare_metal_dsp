Markdown
# BARE-METAL DSP ENGINE 

A high-performance, zero-latency Digital Signal Processing (DSP) engine bridging a hardcore C++ audio backend with a Flutter/Dart control plane via Foreign Function Interface (FFI).

## Architectural Overview
This system completely bypasses standard high-level audio plugins. It captures raw audio directly from the hardware ADC using OS-level APIs (WASAPI on Windows via `miniaudio`) on a dedicated high-priority hardware thread. 

The Flutter UI strictly acts as a passive Control Plane, operating completely independent of the DSP thread. Memory synchronization is handled via lock-free atomic pointers.

### Core Features
* **Zero-Latency Audio Capture:** Direct hardware interfacing without framework overhead.
* **IIR Filtering (DC Blocker):** Hardware-level removal of ADC DC offsets.
* **Real-time FFT:** Radix-2 Cooley-Tukey algorithm executing $O(N \log N)$ running directly on the raw memory buffer.
* **End-to-End Telemetry:** 60fps UI synchronization rendering dBFS Master Meters and a 512-bin Spectrum Analyzer without blocking the audio thread.

## Directory Structure
```text
.
├── lib/               # Dart Control Plane & BLoC Architecture
├── src/               # The Muscle: Native C++ Engine & Mathematics
│   ├── engine.cpp     # Lock-free DSP Loop and WASAPI callbacks
│   ├── engine.h       # FFI Contract and Memory Layout
│   └── CMakeLists.txt # High-performance MSVC Compiler Directives (/O2, /fp:fast)
└── windows/           # Flutter Build Runner and CMake integration
Build Instructions (Windows x64)
To compile the hybrid environment, ensure you have MSVC, CMake, and Ninja correctly configured in your PATH.

1. Fetch Dependencies

Bash
flutter pub get
2. Compile & Run (Debug - Unoptimized for UI inspection)

Bash
flutter run -d windows
3. Compile & Run (Release - Maximum C++ Optimization)
Crucial for testing actual DSP CPU loads.

Bash
flutter run -d windows --release
Engineering Constraints
The src/ directory strictly forbids dynamic memory allocation (new/malloc) or OS-level locking mechanisms (mutex) inside the processAudio critical path to prevent audio dropouts.

UI elements read from the native pointers using Direct Memory Access (DMA) casting.