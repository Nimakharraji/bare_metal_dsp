import 'dart:ffi' as ffi;
import 'dart:io';

// --- FFI Signature Definitions ---
typedef InitEngineNative = ffi.Void Function();
typedef InitEngineDart = void Function();

typedef StopEngineNative = ffi.Void Function();
typedef StopEngineDart = void Function();

typedef GetRmsNative = ffi.Float Function();
typedef GetRmsDart = double Function();

// NEW: Raw Pointer to the 512-bin FFT Float Array
typedef GetFftNative = ffi.Pointer<ffi.Float> Function();
typedef GetFftDart = ffi.Pointer<ffi.Float> Function();

class DspBridge {
  static final DspBridge _instance = DspBridge._internal();
  factory DspBridge() => _instance;

  late final ffi.DynamicLibrary _nativeLib;
  
  late final InitEngineDart initEngine;
  late final StopEngineDart stopEngine;
  late final GetRmsDart getRmsLevel;
  late final GetFftDart getFftArray;

  DspBridge._internal() {
    _loadLibrary();
    _bindSignatures();
  }

  void _loadLibrary() {
    if (Platform.isWindows) {
      _nativeLib = ffi.DynamicLibrary.open('baremetal_dsp.dll');
    } else if (Platform.isAndroid || Platform.isLinux) {
      _nativeLib = ffi.DynamicLibrary.open('libbaremetal_dsp.so');
    } else {
      throw UnsupportedError('OS not supported for Bare-metal DSP execution.');
    }
  }

  void _bindSignatures() {
    initEngine = _nativeLib.lookupFunction<InitEngineNative, InitEngineDart>('init_engine');
    stopEngine = _nativeLib.lookupFunction<StopEngineNative, StopEngineDart>('stop_engine');
    getRmsLevel = _nativeLib.lookupFunction<GetRmsNative, GetRmsDart>('get_rms_level');
    getFftArray = _nativeLib.lookupFunction<GetFftNative, GetFftDart>('get_fft_array');
  }
}