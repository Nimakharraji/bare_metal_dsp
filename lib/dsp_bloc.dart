import 'dart:async';
import 'dart:ffi' as ffi;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ffi_bridge.dart';

// --- States ---
class DspState {
  final bool isRunning;
  final double rmsLevel;
  final List<double> fftData; // 512 frequency bins
  
  const DspState({
    required this.isRunning, 
    required this.rmsLevel,
    required this.fftData,
  });
}

// --- Events ---
abstract class DspEvent {}
class ToggleEngine extends DspEvent {}
class _UpdateTelemetry extends DspEvent {}

// --- BLoC (The Control Plane) ---
class DspBloc extends Bloc<DspEvent, DspState> {
  final DspBridge _bridge;
  Timer? _telemetryTimer;

  DspBloc(this._bridge) : super(DspState(isRunning: false, rmsLevel: 0.0, fftData: List.filled(512, 0.0))) {
    on<ToggleEngine>(_onToggleEngine);
    on<_UpdateTelemetry>(_onUpdateTelemetry);
  }

  void _onToggleEngine(ToggleEngine event, Emitter<DspState> emit) {
    if (state.isRunning) {
      _bridge.stopEngine();
      _telemetryTimer?.cancel();
      emit(DspState(isRunning: false, rmsLevel: 0.0, fftData: List.filled(512, 0.0)));
    } else {
      _bridge.initEngine();
      _telemetryTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        add(_UpdateTelemetry());
      });
      emit(DspState(isRunning: true, rmsLevel: 0.0, fftData: List.filled(512, 0.0)));
    }
  }

  void _onUpdateTelemetry(_UpdateTelemetry event, Emitter<DspState> emit) {
    if (state.isRunning) {
      final double level = _bridge.getRmsLevel();
      final ffi.Pointer<ffi.Float> ptr = _bridge.getFftArray();
      
      List<double> currentFft = List.filled(512, 0.0);
      if (ptr != ffi.nullptr) {
        // Direct Memory Access (DMA): Fast casting from C pointer to Dart TypedData
        final floatList = ptr.asTypedList(512);
        currentFft = List<double>.from(floatList);
      }
      
      emit(DspState(isRunning: true, rmsLevel: level, fftData: currentFft));
    }
  }

  @override
  Future<void> close() {
    _telemetryTimer?.cancel();
    _bridge.stopEngine(); 
    return super.close();
  }
}