import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ffi_bridge.dart';
import 'dsp_bloc.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

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
        scaffoldBackgroundColor: const Color(0xFF050505),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF9D), // Neon Cyan/Green
          secondary: Color(0xFFFF3366), // Neon Pink/Red
          surface: Color(0xFF121212),
          background: Color(0xFF050505),
        ),
        fontFamily: 'Consolas', // Monospace for technical feel
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'BARE-METAL DSP // X64',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            height: 1.0,
          ),
        ),
      ),
      body: BlocBuilder<DspBloc, DspState>(
        builder: (context, state) {
          final primaryColor = state.isRunning
              ? Theme.of(context).colorScheme.primary
              : Colors.grey;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- 1. Status & Timecode ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusIndicator(state.isRunning, primaryColor),
                    _buildTimecode(state.mediaTime),
                  ],
                ),
                const SizedBox(height: 30),

                // --- 2. Subtitle Display (Hardware Synced) ---
                CyberContainer(
                  height: 100,
                  primaryColor: primaryColor,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        state.subtitleText.isEmpty ? "-- NO SIGNAL --" : state.subtitleText,
                        key: ValueKey(state.subtitleText),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: state.subtitleText.isEmpty 
                              ? Colors.white12 
                              : const Color(0xFFFFD700), // Gold for text
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          shadows: state.subtitleText.isNotEmpty
                              ? [const Shadow(blurRadius: 10, color: Colors.orangeAccent)]
                              : [],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // --- 3. Visualizer (FFT + RMS) ---
                CyberContainer(
                  primaryColor: primaryColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildRmsMeter(context, state.rmsLevel, primaryColor),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: SpectrumPainter(state.fftData, primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // --- 4. Controls (Gain & Power) ---
                const Text(
                  "HARDWARE GAIN CONTROL",
                  style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2),
                ),
                Slider(
                  value: state.masterGain,
                  min: 0.0,
                  max: 2.0,
                  activeColor: primaryColor,
                  inactiveColor: Colors.white10,
                  onChanged: (val) {
                    context.read<DspBloc>().add(SetGain(val));
                  },
                ),
                const SizedBox(height: 20),
                
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => context.read<DspBloc>().add(ToggleEngine()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isRunning 
                          ? Colors.red.withOpacity(0.2) 
                          : primaryColor.withOpacity(0.2),
                      foregroundColor: state.isRunning ? Colors.red : primaryColor,
                      side: BorderSide(
                        color: state.isRunning ? Colors.red : primaryColor, 
                        width: 2
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: Text(
                      state.isRunning ? 'TERMINATE PROCESS' : 'INITIALIZE ENGINE',
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 3
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator(bool isRunning, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          isRunning ? "ONLINE" : "OFFLINE",
          style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildTimecode(double time) {
    final int minutes = (time / 60).floor();
    final int seconds = (time % 60).floor();
    final int millis = ((time * 1000) % 1000).floor();
    
    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}',
      style: const TextStyle(
        fontFeatures: [FontFeature.tabularFigures()],
        fontSize: 18,
        color: Colors.white,
        fontWeight: FontWeight.w300,
      ),
    );
  }

  Widget _buildRmsMeter(BuildContext context, double rawRms, Color color) {
    // Convert to dB
    final double db = rawRms > 0.00001 ? 20 * math.log(rawRms) / math.ln10 : -100.0;
    final double normalized = ((db + 60) / 60).clamp(0.0, 1.0); // range -60dB to 0dB

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("MASTER OUTPUT", style: TextStyle(fontSize: 10, color: Colors.white38)),
            Text("${db.toStringAsFixed(1)} dB", style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.white10),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: normalized,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Reusable Cyberpunk Container ---
class CyberContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;
  final Color primaryColor;

  const CyberContainer({
    super.key, 
    required this.child, 
    this.height, 
    this.padding = EdgeInsets.zero,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

// --- FFT Painter ---
class SpectrumPainter extends CustomPainter {
  final List<double> fftData;
  final Color color;

  SpectrumPainter(this.fftData, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (fftData.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = (size.width / fftData.length) * 0.8 // spacing
      ..strokeCap = StrokeCap.square; // Technical look

    final int bins = fftData.length;
    final double barWidth = size.width / bins;

    for (int i = 0; i < bins; i++) {
      double magnitude = fftData[i];
      // Log scale for better visualization
      double db = magnitude > 0.000001 ? 20.0 * (math.log(magnitude) / math.ln10) : -100.0;
      double normalized = ((db + 70) / 70).clamp(0.0, 1.0);
      
      // Enhance highs and lows artificially for visual punch
      normalized = math.pow(normalized, 1.5).toDouble();

      double barHeight = normalized * size.height;

      // Gradient effect
      paint.shader = LinearGradient(
        colors: [color.withOpacity(0.1), color],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(i * barWidth, size.height - barHeight, barWidth, barHeight));

      if (barHeight > 0) {
        canvas.drawLine(
          Offset(i * barWidth, size.height),
          Offset(i * barWidth, size.height - barHeight),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) => true;
}