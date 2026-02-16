# ⚡ BARE-METAL DSP: X64 AUDIO HARNESS

> **High-Performance Audio Intelligence via C++ / Flutter Hybrid Architecture.**

This is not a standard audio plugin. This engine operates at the kernel level of Windows WASAPI, bypassing high-level framework latencies to deliver raw, real-time spectral analysis.

---

### 🛠 ENGINEERING SPECS
* **Low-Level Backend:** Pure C++17 with `miniaudio` integration for direct hardware ADC access.
* **Mathematical Core:** In-place **Radix-2 Cooley-Tukey FFT** ($1024$ samples) for ultra-fast frequency decomposition.
* **Zero-Latency Logic:** Lock-free atomic synchronization between the hardware thread and the UI isolate.
* **FFI Bridge:** Direct Memory Access (DMA) casting for high-speed telemetry.

### 📊 VISUAL TELEMETRY
The UI utilizes a specialized **Spectrum Analyzer** and **dBFS Master Meter** with a -60dB to 0dB range, utilizing a logarithmic mapping to match human auditory perception.

### 🚀 PERFORMANCE
* **Sampling Rate:** $48.0 \text{ kHz}$ (Professional Standard)
* **Buffer Resolution:** $1024$ Samples
* **FFT Bins:** $512$ Individual Frequency Bands
* **UI Sync:** Locked @ $60 \text{ FPS}$

---

## 🏗 SYSTEM SETUP

### **Compiler Requirements**
- **MSVC** (Visual Studio 2022 Build Tools)
- **CMake** 3.14+
- **Flutter** 3.7.0+

### **Production Build**
To trigger maximum compiler optimizations (`/O2`, `/fp:fast`):
```bash
flutter run -d windows --release