import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ffi_bridge.dart';
import 'dsp_bloc.dart';

void main() {
  final dspBridge = DspBridge();
  
  runApp(
    BlocProvider(
      create: (_) => DspBloc(dspBridge),
      child: const BareMetalApp(),
    ),
  );
}

class BareMetalApp extends StatelessWidget {
  const BareMetalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bare-Metal DSP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF9D),
          surface: Color(0xFF141414),
        ),
        fontFamily: 'Consolas',
      ),
      home: const DspControlPanel(),
    );
  }
}

class DspControlPanel extends StatelessWidget {
  const DspControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DSP TELEMETRY // x64',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.0),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFF222222), height: 1.0),
        ),
      ),
      body: Center(
        child: BlocBuilder<DspBloc, DspState>(
          builder: (context, state) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusIndicator(state.isRunning),
                const SizedBox(height: 40),
                _buildStudioRmsMeter(state.rmsLevel),
                const SizedBox(height: 30),
                // --- NEW: FFT Spectrum Analyzer ---
                _buildSpectrumAnalyzer(state.fftData),
                const SizedBox(height: 50),
                _buildControlButton(context, state.isRunning),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpectrumAnalyzer(List<double> fftData) {
    return Column(
      children: [
        const Text(
          'REAL-TIME SPECTRUM (FFT)',
          style: TextStyle(color: Colors.white54, letterSpacing: 2.0, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Container(
          width: 600,
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0C),
            border: Border.all(color: const Color(0xFF222222), width: 1.5),
          ),
          child: CustomPaint(
            painter: SpectrumPainter(fftData),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(bool isRunning) {
    final color = isRunning ? const Color(0xFF00FF9D) : const Color(0xFFFF3366);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.6),
                blurRadius: 12,
                spreadRadius: 2,
              )
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          isRunning ? 'ENGINE: ONLINE' : 'ENGINE: OFFLINE',
          style: TextStyle(
            color: color,
            fontSize: 20,
            letterSpacing: 3.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStudioRmsMeter(double rawRms) {
    final double dbfs = rawRms > 0.00001 ? 20.0 * (math.log(rawRms) / math.ln10) : -100.0;
    const double minDb = -60.0;
    const double maxDb = 0.0;
    final double normalizedMeter = ((dbfs - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    
    Color meterColor = const Color(0xFF00FF9D);
    if (dbfs > -10.0) meterColor = Colors.orange;
    if (dbfs > -3.0) meterColor = Colors.redAccent;

    return Column(
      children: [
        const Text(
          'STUDIO METER (dBFS)',
          style: TextStyle(color: Colors.white54, letterSpacing: 2.0, fontSize: 12),
        ),
        const SizedBox(height: 15),
        Container(
          width: 600,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            border: Border.all(color: const Color(0xFF333333), width: 1.0),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: normalizedMeter,
            child: Container(color: meterColor),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          dbfs <= -100.0 ? '-INF dB' : '${dbfs.toStringAsFixed(1)} dB',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(BuildContext context, bool isRunning) {
    return InkWell(
      onTap: () => context.read<DspBloc>().add(ToggleEngine()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isRunning ? const Color(0xFFFF3366) : const Color(0xFF00FF9D), 
            width: 2
          ),
          color: (isRunning ? const Color(0xFFFF3366) : const Color(0xFF00FF9D)).withOpacity(0.05),
        ),
        child: Text(
          isRunning ? 'HALT PROCESS' : 'INITIALIZE ENGINE',
          style: TextStyle(
            color: isRunning ? const Color(0xFFFF3366) : const Color(0xFF00FF9D),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}

// --- HARDCORE SPECTRUM PAINTER ---
class SpectrumPainter extends CustomPainter {
  final List<double> fftData;
  SpectrumPainter(this.fftData);

  @override
  void paint(Canvas canvas, Size size) {
    if (fftData.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF00FF9D)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square;

    final int bins = fftData.length;
    final double barWidth = size.width / bins;

    for (int i = 0; i < bins; i++) {
      // 1. Logarithmic mapping for visuals (human ear hears logarithmically)
      double magnitude = fftData[i];
      double db = magnitude > 0.000001 ? 20.0 * (math.log(magnitude) / math.ln10) : -100.0;
      
      // 2. Normalize to canvas height (-80dB to 0dB range)
      double normalizedDb = ((db + 80) / 80).clamp(0.0, 1.0);
      double barHeight = normalizedDb * size.height;

      // 3. Dynamic Coloring for frequencies (Low = Green, Mid = Yellow, High = Blue/Pink)
      if (i > bins * 0.7) {
        paint.color = const Color(0xFFFF3366); // Highs
      } else if (i > bins * 0.3) {
        paint.color = const Color(0xFF00FF9D); // Mids
      } else {
        paint.color = const Color(0xFF00AAFF); // Lows
      }

      final double x = i * barWidth;
      final double y = size.height - barHeight;

      canvas.drawLine(Offset(x, size.height), Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) => true;
}