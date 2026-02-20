import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart'; // حتما باید پکیج ffi رو داشته باشی

// --- FFI Signature Definitions (C++ Types) ---
typedef InitEngineNative = ffi.Void Function();
typedef InitEngineDart = void Function();

typedef StopEngineNative = ffi.Void Function();
typedef StopEngineDart = void Function();

typedef GetRmsNative = ffi.Float Function();
typedef GetRmsDart = double Function();

typedef GetFftNative = ffi.Pointer<ffi.Float> Function();
typedef GetFftDart = ffi.Pointer<ffi.Float> Function();

// --- NEW CONTROLS ---
typedef SetGainNative = ffi.Void Function(ffi.Float gain);
typedef SetGainDart = void Function(double gain);

typedef LoadSubtitlesNative = ffi.Void Function(ffi.Pointer<Utf8> data);
typedef LoadSubtitlesDart = void Function(ffi.Pointer<Utf8> data);

typedef GetSubIdxNative = ffi.Int32 Function();
typedef GetSubIdxDart = int Function();

typedef GetSubTextNative = ffi.Pointer<Utf8> Function(ffi.Int32 index);
typedef GetSubTextDart = ffi.Pointer<Utf8> Function(int index);

typedef GetTimeNative = ffi.Double Function();
typedef GetTimeDart = double Function();

class DspBridge {
  static final DspBridge _instance = DspBridge._internal();
  factory DspBridge() => _instance;

  late final ffi.DynamicLibrary _nativeLib;
  
  // Private Native Function Pointers
  late final InitEngineDart _initEngineNative;
  late final StopEngineDart _stopEngineNative;
  late final GetRmsDart _getRmsLevelNative;
  late final GetFftDart _getFftArrayNative;
  late final SetGainDart _setGainNative;
  late final LoadSubtitlesDart _loadSubtitlesNative;
  late final GetSubIdxDart _getSubtitleIndexNative;
  late final GetSubTextDart _getSubtitleTextNative;
  late final GetTimeDart _getMediaTimeNative;

  DspBridge._internal() {
    _loadLibrary();
    _bindSignatures();
  }

  void _loadLibrary() {
    try {
      if (Platform.isWindows) {
        _nativeLib = ffi.DynamicLibrary.open('baremetal_dsp.dll');
      } else if (Platform.isAndroid || Platform.isLinux) {
        _nativeLib = ffi.DynamicLibrary.open('libbaremetal_dsp.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        _nativeLib = ffi.DynamicLibrary.process();
      } else {
        throw UnsupportedError('OS not supported.');
      }
    } catch (e) {
      print("CRITICAL ERROR LOADING DLL: $e");
      // در محیط توسعه ممکنه هنوز DLL کپی نشده باشه، ارور رو چاپ میکنیم که کرش نکنه
      rethrow;
    }
  }

  void _bindSignatures() {
    try {
      _initEngineNative = _nativeLib.lookupFunction<InitEngineNative, InitEngineDart>('init_engine');
      _stopEngineNative = _nativeLib.lookupFunction<StopEngineNative, StopEngineDart>('stop_engine');
      _getRmsLevelNative = _nativeLib.lookupFunction<GetRmsNative, GetRmsDart>('get_rms_level');
      _getFftArrayNative = _nativeLib.lookupFunction<GetFftNative, GetFftDart>('get_fft_array');

      _setGainNative = _nativeLib.lookupFunction<SetGainNative, SetGainDart>('set_gain');
      _loadSubtitlesNative = _nativeLib.lookupFunction<LoadSubtitlesNative, LoadSubtitlesDart>('load_subtitles');
      _getSubtitleIndexNative = _nativeLib.lookupFunction<GetSubIdxNative, GetSubIdxDart>('get_subtitle_index');
      _getSubtitleTextNative = _nativeLib.lookupFunction<GetSubTextNative, GetSubTextDart>('get_subtitle_text');
      _getMediaTimeNative = _nativeLib.lookupFunction<GetTimeNative, GetTimeDart>('get_media_time');
    } catch (e) {
      print("ERROR BINDING FUNCTIONS: $e");
    }
  }

  // --- PUBLIC SAFE API (Called by Bloc) ---

  void initEngine() => _initEngineNative();
  
  void stopEngine() => _stopEngineNative();
  
  double getRmsLevel() => _getRmsLevelNative();
  
  ffi.Pointer<ffi.Float> getFftArray() => _getFftArrayNative();

  void setGain(double gain) {
    _setGainNative(gain);
  }

  // دریافت زمان دقیق از انجین
  double getMediaTime() {
    return _getMediaTimeNative();
  }

  // تبدیل استرینگ دارت به UTF8 برای C++
  void loadSubtitles(String srtContent) {
    final ptr = srtContent.toNativeUtf8();
    _loadSubtitlesNative(ptr);
    calloc.free(ptr); // آزادسازی حافظه موقت
  }

  int getSubtitleIndex() {
    return _getSubtitleIndexNative();
  }

  // تبدیل پوینتر C++ به استرینگ دارت
  String getSubtitleText(int index) {
    final ptr = _getSubtitleTextNative(index);
    if (ptr == ffi.nullptr) return "";
    return ptr.toDartString();
  }
}