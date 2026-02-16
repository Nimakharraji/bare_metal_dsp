#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include "engine.h"
#include <cmath>
#include <complex>
#include <algorithm>

const float PI = 3.14159265358979323846f;
static DSPEngine* global_engine = nullptr;

void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    if (pDevice->pUserData != nullptr && pInput != nullptr) {
        DSPEngine* engine = static_cast<DSPEngine*>(pDevice->pUserData);
        engine->processAudio(static_cast<const float*>(pInput), frameCount);
    }
    (void)pOutput;
}

DSPEngine::DSPEngine() : isRunning(false), currentRms(0.0f), device(nullptr), 
                         prevInput(0.0f), prevOutput(0.0f), bufferIndex(0) {
    // Zero out FFT memory
    std::fill_n(sampleBuffer, FFT_SIZE, 0.0f);
    std::fill_n(fftMagnitudes, FFT_BINS, 0.0f);
}

DSPEngine::~DSPEngine() {
    stop();
}

void DSPEngine::start() {
    if (isRunning.load()) return;
    
    device = new ma_device();
    
    ma_device_config deviceConfig = ma_device_config_init(ma_device_type_capture);
    deviceConfig.capture.format   = ma_format_f32; 
    deviceConfig.capture.channels = 1;             
    deviceConfig.sampleRate       = 48000;         
    deviceConfig.dataCallback     = data_callback;
    deviceConfig.pUserData        = this;          

    if (ma_device_init(NULL, &deviceConfig, device) != MA_SUCCESS) {
        delete device;
        device = nullptr;
        return;
    }

    ma_device_start(device);
    isRunning.store(true);
}

void DSPEngine::stop() {
    if (isRunning.load()) {
        if (device != nullptr) {
            ma_device_uninit(device);
            delete device;
            device = nullptr;
        }
        isRunning.store(false);
        currentRms.store(0.0f);
        prevInput = 0.0f;
        prevOutput = 0.0f;
        bufferIndex = 0;
    }
}

float DSPEngine::getRms() { return currentRms.load(); }
float* DSPEngine::getFftData() { return fftMagnitudes; }

// The Heavy-lifting FFT Algorithm (In-place Cooley-Tukey Radix-2)
void DSPEngine::computeFFT() {
    std::complex<float> data[FFT_SIZE];
    
    // 1. Apply Hann Window to prevent spectral leakage
    for(int i = 0; i < FFT_SIZE; i++) {
        float multiplier = 0.5f * (1.0f - std::cos(2.0f * PI * i / (FFT_SIZE - 1)));
        data[i] = std::complex<float>(sampleBuffer[i] * multiplier, 0.0f);
    }

    // 2. Bit-Reversal Permutation
    for (int i = 1, j = 0; i < FFT_SIZE; i++) {
        int bit = FFT_SIZE >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(data[i], data[j]);
    }

    // 3. Cooley-Tukey Butterfly Computations
    for (int len = 2; len <= FFT_SIZE; len <<= 1) {
        float angle = -2.0f * PI / len;
        std::complex<float> wlen(std::cos(angle), std::sin(angle));
        for (int i = 0; i < FFT_SIZE; i += len) {
            std::complex<float> w(1.0f, 0.0f);
            for (int j = 0; j < len / 2; j++) {
                std::complex<float> u = data[i + j];
                std::complex<float> v = data[i + j + len / 2] * w;
                data[i + j] = u + v;
                data[i + j + len / 2] = u - v;
                w *= wlen;
            }
        }
    }

    // 4. Calculate linear magnitudes and normalize
    for(int i = 0; i < FFT_BINS; i++) {
        // Normalizing by FFT_SIZE / 2
        fftMagnitudes[i] = std::abs(data[i]) / (FFT_SIZE / 2.0f); 
    }
}

void DSPEngine::processAudio(const float* inputBuffer, int frameCount) {
    float sumSquares = 0.0f;
    
    for (int i = 0; i < frameCount; ++i) {
        float sample = inputBuffer[i];
        
        // IIR DC Blocker
        float filteredSample = sample - prevInput + R * prevOutput;
        prevInput = sample;
        prevOutput = filteredSample;
        
        sumSquares += filteredSample * filteredSample;

        // Feed the FFT Buffer
        sampleBuffer[bufferIndex++] = filteredSample;
        if (bufferIndex >= FFT_SIZE) {
            computeFFT();
            bufferIndex = 0; // Reset buffer
        }
    }
    
    float rms = std::sqrt(sumSquares / frameCount);
    currentRms.store(rms);
}

// --- FFI EXPORTS ---
EXPORT void init_engine() {
    if (!global_engine) {
        global_engine = new DSPEngine();
        global_engine->start();
    }
}
EXPORT void stop_engine() {
    if (global_engine) {
        global_engine->stop();
        delete global_engine;
        global_engine = nullptr;
    }
}
EXPORT float get_rms_level() { return global_engine ? global_engine->getRms() : 0.0f; }
EXPORT float* get_fft_array() { return global_engine ? global_engine->getFftData() : nullptr; }