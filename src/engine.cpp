// CRITICAL: This macro must be defined ONLY ONCE in the entire project.
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include "engine.h"
#include <cmath>
#include <complex>
#include <algorithm>
#include <sstream>

const float PI = 3.14159265358979323846f;
static DSPEngine* global_engine = nullptr;

// --- Helper Functions ---
double parseTimestamp(const std::string& timestamp) {
    int h, m, s, ms;
    char sep;
    std::stringstream ss(timestamp);
    ss >> h >> sep >> m >> sep >> s >> sep >> ms;
    return (h * 3600.0) + (m * 60.0) + s + (ms / 1000.0);
}

void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    if (pDevice->pUserData != nullptr && pInput != nullptr) {
        DSPEngine* engine = static_cast<DSPEngine*>(pDevice->pUserData);
        // Cast away const specifically for processing logic
        engine->processAudio(const_cast<float*>(static_cast<const float*>(pInput)), frameCount);
    }
    (void)pOutput;
}

// --- Class Implementation ---

DSPEngine::DSPEngine() : 
    isRunning(false), device(nullptr), totalFramesProcessed(0),
    masterGain(1.0f), currentRms(0.0f), currentSubtitleIdx(-1),
    prevInput(0.0f), prevOutput(0.0f), bufferIndex(0) 
{
    std::fill_n(sampleBuffer, FFT_SIZE, 0.0f);
    std::fill_n(fftMagnitudes, FFT_BINS, 0.0f);
}

DSPEngine::~DSPEngine() {
    stop();
}

void DSPEngine::start() {
    if (isRunning.load()) return;
    
    device = new ma_device();
    ma_device_config config = ma_device_config_init(ma_device_type_capture);
    config.capture.format = ma_format_f32;
    config.capture.channels = 1;
    config.sampleRate = SAMPLE_RATE;
    config.dataCallback = data_callback;
    config.pUserData = this;
    config.periodSizeInFrames = 256; // Low latency

    if (ma_device_init(NULL, &config, device) != MA_SUCCESS) {
        delete device;
        device = nullptr;
        return;
    }

    totalFramesProcessed.store(0);
    ma_device_start(device);
    isRunning.store(true);
}

void DSPEngine::stop() {
    if (isRunning.load()) {
        if (device) {
            ma_device_uninit(device);
            delete device;
            device = nullptr;
        }
        isRunning.store(false);
        totalFramesProcessed.store(0);
    }
}

// --- Getters / Setters ---
float DSPEngine::getRms() { return currentRms.load(std::memory_order_relaxed); }
float* DSPEngine::getFftData() { return fftMagnitudes; }
double DSPEngine::getCurrentTime() const { 
    return (double)totalFramesProcessed.load(std::memory_order_relaxed) / (double)SAMPLE_RATE; 
}
void DSPEngine::setMasterGain(float gain) { masterGain.store(gain, std::memory_order_relaxed); }
int32_t DSPEngine::getActiveSubtitleIndex() const { return currentSubtitleIdx.load(std::memory_order_relaxed); }

const char* DSPEngine::getSubtitleText(int32_t index) const {
    if (index >= 0 && index < (int32_t)subtitles.size()) {
        return subtitles[index].text.c_str();
    }
    return "";
}

void DSPEngine::loadSubtitles(const char* srtContent) {
    // if (isRunning.load()) return; 

    subtitles.clear();
    std::stringstream ss(srtContent);
    std::string line;
    SubtitleEvent ev;
    int step = 0;

    while (std::getline(ss, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.empty()) {
            if (step == 2) { subtitles.push_back(ev); ev.text.clear(); }
            step = 0; continue;
        }
        if (step == 0) step = 1;
        else if (step == 1) {
            ev.startTime = parseTimestamp(line.substr(0, 12));
            ev.endTime = parseTimestamp(line.substr(17, 12));
            step = 2;
        } else if (step == 2) {
            if (!ev.text.empty()) ev.text += "\n";
            ev.text += line;
        }
    }
    if (step == 2 && !ev.text.empty()) subtitles.push_back(ev);
}

void DSPEngine::syncSubtitles(double timestamp) {
    if (subtitles.empty()) return;

    // Optimization: Check current index first
    int32_t current = currentSubtitleIdx.load(std::memory_order_relaxed);
    if (current >= 0 && current < (int32_t)subtitles.size()) {
        if (timestamp >= subtitles[current].startTime && timestamp <= subtitles[current].endTime) return;
    }

    // Binary Search
    auto it = std::upper_bound(subtitles.begin(), subtitles.end(), timestamp, 
        [](double val, const SubtitleEvent& e) { return val < e.startTime; });

    int32_t found = -1;
    if (it != subtitles.begin()) {
        auto candidate = std::prev(it);
        if (timestamp >= candidate->startTime && timestamp <= candidate->endTime) {
            found = (int32_t)std::distance(subtitles.begin(), candidate);
        }
    }
    
    if (found != current) currentSubtitleIdx.store(found, std::memory_order_release);
}

void DSPEngine::computeFFT() {
    std::complex<float> data[FFT_SIZE];
    for(int i=0; i<FFT_SIZE; i++) {
        float win = 0.5f * (1.0f - std::cos(2.0f * PI * i / (FFT_SIZE-1)));
        data[i] = std::complex<float>(sampleBuffer[i] * win, 0.0f);
    }
    
    // Standard Radix-2 Implementation
    for (int i=1, j=0; i<FFT_SIZE; i++) {
        int bit = FFT_SIZE >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(data[i], data[j]);
    }
    for (int len=2; len<=FFT_SIZE; len<<=1) {
        float angle = -2.0f * PI / len;
        std::complex<float> wlen(std::cos(angle), std::sin(angle));
        for (int i=0; i<FFT_SIZE; i+=len) {
            std::complex<float> w(1.0f, 0.0f);
            for (int j=0; j<len/2; j++) {
                std::complex<float> u = data[i+j], v = data[i+j+len/2]*w;
                data[i+j] = u+v; data[i+j+len/2] = u-v; w *= wlen;
            }
        }
    }
    for(int i=0; i<FFT_BINS; i++) fftMagnitudes[i] = std::abs(data[i]) / (FFT_SIZE/2.0f);
}

void DSPEngine::processAudio(float* input, uint32_t count) {
    float gain = masterGain.load(std::memory_order_relaxed);
    uint64_t total = totalFramesProcessed.fetch_add(count, std::memory_order_relaxed);
    syncSubtitles((double)total / SAMPLE_RATE);
    
    float sumSq = 0.0f;
    for(uint32_t i=0; i<count; ++i) {
        float s = input[i] * gain;
        float f = s - prevInput + R * prevOutput;
        prevInput = s; prevOutput = f;
        sumSq += f*f;
        
        sampleBuffer[bufferIndex++] = f;
        if(bufferIndex >= FFT_SIZE) {
            computeFFT();
            bufferIndex = 0;
        }
    }
    currentRms.store(std::sqrt(sumSq/count), std::memory_order_relaxed);
}

// --- Exports ---
EXPORT void init_engine() { if (!global_engine) { global_engine = new DSPEngine(); global_engine->start(); } }
EXPORT void stop_engine() { if (global_engine) { global_engine->stop(); delete global_engine; global_engine=nullptr; } }
EXPORT float get_rms_level() { return global_engine ? global_engine->getRms() : 0.0f; }
EXPORT float* get_fft_array() { return global_engine ? global_engine->getFftData() : nullptr; }
EXPORT void set_gain(float g) { if (global_engine) global_engine->setMasterGain(g); }
EXPORT void load_subtitles(const char* s) { if (global_engine) global_engine->loadSubtitles(s); }
EXPORT int32_t get_subtitle_index() { return global_engine ? global_engine->getActiveSubtitleIndex() : -1; }
EXPORT const char* get_subtitle_text(int32_t i) { return global_engine ? global_engine->getSubtitleText(i) : ""; }
EXPORT double get_media_time() { return global_engine ? global_engine->getCurrentTime() : 0.0; }