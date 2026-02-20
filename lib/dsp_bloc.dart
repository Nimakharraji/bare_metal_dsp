import 'dart:async';
import 'dart:ffi' as ffi;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ffi_bridge.dart';

// --- State Definition ---
class DspState {
  final bool isRunning;
  final double rmsLevel;
  final List<double> fftData; // 512 frequency bins
  final double mediaTime;     // Sample-accurate clock from C++
  final String subtitleText;  // Current active subtitle
  final double masterGain;    // current gain (0.0 - 1.0)

  const DspState({
    required this.isRunning,
    required this.rmsLevel,
    required this.fftData,
    required this.mediaTime,
    required this.subtitleText,
    required this.masterGain,
  });

  // Factory for initial state
  factory DspState.initial() {
    return DspState(
      isRunning: false,
      rmsLevel: 0.0,
      fftData: List.filled(512, 0.0),
      mediaTime: 0.0,
      subtitleText: "",
      masterGain: 1.0,
    );
  }

  DspState copyWith({
    bool? isRunning,
    double? rmsLevel,
    List<double>? fftData,
    double? mediaTime,
    String? subtitleText,
    double? masterGain,
  }) {
    return DspState(
      isRunning: isRunning ?? this.isRunning,
      rmsLevel: rmsLevel ?? this.rmsLevel,
      fftData: fftData ?? this.fftData,
      mediaTime: mediaTime ?? this.mediaTime,
      subtitleText: subtitleText ?? this.subtitleText,
      masterGain: masterGain ?? this.masterGain,
    );
  }
}

// --- Events ---
abstract class DspEvent {}
class ToggleEngine extends DspEvent {}
class SetGain extends DspEvent {
  final double gain;
  SetGain(this.gain);
}
class _UpdateTelemetry extends DspEvent {}

// --- BLoC Implementation ---
class DspBloc extends Bloc<DspEvent, DspState> {
  final DspBridge _bridge;
  Timer? _telemetryTimer;

  DspBloc(this._bridge) : super(DspState.initial()) {
    on<ToggleEngine>(_onToggleEngine);
    on<_UpdateTelemetry>(_onUpdateTelemetry);
    on<SetGain>(_onSetGain);
  }

  void _onToggleEngine(ToggleEngine event, Emitter<DspState> emit) {
    if (state.isRunning) {
      _bridge.stopEngine();
      _telemetryTimer?.cancel();
      emit(DspState.initial());
    } else {
      _bridge.initEngine();
      
      // --- INJECT TEST SUBTITLES (For Debugging) ---
      // This loads directly into C++ std::vector memory
      const mockSrt = """
1
00:00:01,000 --> 00:00:03,500
SYSTEM INITIALIZED
ACCESSING AUDIO HARDWARE...

2
00:00:03,600 --> 00:00:06,000
SAMPLE-ACCURATE CLOCK
SYNCED TO AUDIO FRAME COUNT

3
00:00:06,100 --> 00:00:09,000
FAST FOURIER TRANSFORM
RADIX-2 ALGORITHM ACTIVE
""";
      _bridge.loadSubtitles(mockSrt);
      // ---------------------------------------------

      // 60 FPS Telemetry Loop (approx 16ms)
      _telemetryTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        add(_UpdateTelemetry());
      });
      emit(state.copyWith(isRunning: true));
    }
  }

  void _onSetGain(SetGain event, Emitter<DspState> emit) {
    _bridge.setGain(event.gain);
    emit(state.copyWith(masterGain: event.gain));
  }

  void _onUpdateTelemetry(_UpdateTelemetry event, Emitter<DspState> emit) {
    if (!state.isRunning) return;

    // 1. Fetch RMS (Atomic Read)
    final double level = _bridge.getRmsLevel();
    
    // 2. Fetch Time (Calculated from total_frames / sample_rate)
    final double time = _bridge.getMediaTime();

    // 3. Fetch FFT Data (Direct Pointer Access)
    final ffi.Pointer<ffi.Float> ptr = _bridge.getFftArray();
    List<double> currentFft = state.fftData; // Keep old data if null
    if (ptr != ffi.nullptr) {
      // Zero-Copy view would be unsafe in Dart if C++ frees memory, 
      // so we do a fast copy.
      currentFft = List<double>.from(ptr.asTypedList(512));
    }

    // 4. Fetch Subtitles
    // Optimization: We could check getSubtitleIndex() first to see if it changed,
    // but FFI string copy is negligible for short text.
    final int subIdx = _bridge.getSubtitleIndex();
    String currentSub = "";
    if (subIdx != -1) {
      currentSub = _bridge.getSubtitleText(subIdx);
    }

    emit(state.copyWith(
      rmsLevel: level,
      fftData: currentFft,
      mediaTime: time,
      subtitleText: currentSub,
    ));
  }

  @override
  Future<void> close() {
    _telemetryTimer?.cancel();
    _bridge.stopEngine(); 
    return super.close();
  }
}