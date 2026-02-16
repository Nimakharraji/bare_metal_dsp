#ifndef BAREMETAL_DSP_ENGINE_H
#define BAREMETAL_DSP_ENGINE_H

#include <atomic>

struct ma_device;

#if defined(_WIN32)
    #define EXPORT extern "C" __declspec(dllexport)
#else
    #define EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif

// DSP Constants
#define FFT_SIZE 1024
#define FFT_BINS (FFT_SIZE / 2)

/*
 * Hardcore DSP Engine - Real-time Audio Hardware Integration
 * Equipped with IIR Filtering and Radix-2 FFT Spectrum Analysis.
 */
class DSPEngine {
public:
    DSPEngine();
    ~DSPEngine();

    void start();
    void stop();
    float getRms();
    
    // Returns a raw pointer to the frequency magnitude array (512 bins)
    float* getFftData();

    void processAudio(const float* inputBuffer, int frameCount);

private:
    std::atomic<bool> isRunning;
    std::atomic<float> currentRms;
    ma_device* device;

    // --- IIR Filter States ---
    float prevInput;
    float prevOutput;
    const float R = 0.995f;

    // --- FFT Memory Blocks ---
    float sampleBuffer[FFT_SIZE];
    int bufferIndex;
    float fftMagnitudes[FFT_BINS]; // The final array Dart will read
    
    // Private hardcore math routine
    void computeFFT();
};

EXPORT void init_engine();
EXPORT void stop_engine();
EXPORT float get_rms_level();
// New FFI Bridge for Array Reading
EXPORT float* get_fft_array();

#endif // BAREMETAL_DSP_ENGINE_H