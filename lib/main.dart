import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ffi_bridge.dart';
import 'dsp_bloc.dart';

void main() {
  // Ensure status bar style matches the dark theme
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
        scaffoldBackgroundColor: const Color(
          0xFF050505,
        ), // Deeper black background
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF9D), // Neon Cyan/Green
          secondary: Color(0xFFFF3366), // Neon Pink/Red
          surface: Color(0xFF121212), // Slightly lighter card background
          background: Color(0xFF050505),
        ),
        fontFamily: 'Consolas',
        // Modern app bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF050505),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Consolas',
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
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
        title: const Text('BARE-METAL DSP // X64'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(
            height: 2.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<DspBloc, DspState>(
        builder: (context, state) {
          final primaryColor =
              state.isRunning
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Section 1: Engine Status ---
                _buildStatusSection(context, state.isRunning, primaryColor),
                const SizedBox(height: 25),

                // --- Section 2: Telemetry Visualization ---
                CyberCard(
                  primaryColor: primaryColor,
                  title: 'REAL-TIME TELEMETRY',
                  child: Column(
                    children: [
                      _buildStudioRmsMeter(context, state.rmsLevel),
                      const SizedBox(height: 30),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 20),
                      _buildSpectrumAnalyzer(
                        context,
                        state.fftData,
                        primaryColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // --- Section 3: Controls ---
                _buildControlSection(context, state.isRunning, primaryColor),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI Sections ---

  Widget _buildStatusSection(
    BuildContext context,
    bool isRunning,
    Color primaryColor,
  ) {
    return CyberCard(
      primaryColor: primaryColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing Indicator Icon
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.6),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              isRunning
                  ? Icons.power_settings_new_rounded
                  : Icons.power_off_rounded,
              color: Colors.black,
              size: 16,
            ),
          ),
          const SizedBox(width: 20),
          // Status Text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ENGINE STATUS',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isRunning ? 'SYSTEM ONLINE' : 'SYSTEM OFFLINE',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 22,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: primaryColor.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudioRmsMeter(BuildContext context, double rawRms) {
    final double dbfs =
        rawRms > 0.00001 ? 20.0 * (math.log(rawRms) / math.ln10) : -100.0;
    const double minDb = -60.0;
    const double maxDb = 0.0;
    final double normalizedMeter = ((dbfs - minDb) / (maxDb - minDb)).clamp(
      0.0,
      1.0,
    );

    Color meterColor = Theme.of(context).colorScheme.primary;
    if (dbfs > -10.0) meterColor = Colors.orangeAccent;
    if (dbfs > -3.0) meterColor = Theme.of(context).colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MASTER OUTPUT (dBFS)',
              style: TextStyle(
                color: Colors.white54,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
            Text(
              dbfs <= -100.0 ? '-INF dB' : '${dbfs.toStringAsFixed(1)} dB',
              style: TextStyle(
                color: meterColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Modern Meter Bar
        Container(
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12, width: 1.0),
          ),
          child: Stack(
            children: [
              // The fill bar
              FractionallySizedBox(
                widthFactor: normalizedMeter,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [meterColor.withOpacity(0.5), meterColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: meterColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                ),
              ),
              // Grid lines for dB markers (optional aesthetic)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  9,
                  (index) => Container(width: 1, color: Colors.black12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpectrumAnalyzer(
    BuildContext context,
    List<double> fftData,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SPECTRUM FFT (512 BINS)',
          style: TextStyle(
            color: Colors.white54,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10, width: 1.0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(painter: SpectrumPainter(fftData, primaryColor)),
          ),
        ),
      ],
    );
  }

  Widget _buildControlSection(
    BuildContext context,
    bool isRunning,
    Color primaryColor,
  ) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: () => context.read<DspBloc>().add(ToggleEngine()),
        style: ElevatedButton.styleFrom(
          backgroundColor: isRunning ? Colors.black : primaryColor,
          foregroundColor: isRunning ? primaryColor : Colors.black,
          side: BorderSide(color: primaryColor, width: 2.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isRunning ? 0 : 10,
          shadowColor: primaryColor.withOpacity(0.5),
        ),
        child: Text(
          isRunning ? 'HALT HARDWARE PROCESS' : 'INITIALIZE ENGINE',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
            color: isRunning ? primaryColor : Colors.black,
          ),
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS & PAINTERS ---

// A reusable card widget for the cyberpunk aesthetic
class CyberCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Color primaryColor;

  const CyberCard({
    super.key,
    required this.child,
    this.title,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }
}

class SpectrumPainter extends CustomPainter {
  final List<double> fftData;
  final Color primaryColor;

  SpectrumPainter(this.fftData, this.primaryColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (fftData.isEmpty) return;

    final paint =
        Paint()
          ..strokeWidth =
              size.width /
              fftData.length *
              0.8 // Thicker, spaced bars
          ..strokeCap = StrokeCap.round; // Rounded tops for a modern look

    final int bins = fftData.length;
    final double barWidth = size.width / bins;

    for (int i = 0; i < bins; i++) {
      // Logarithmic mapping
      double magnitude = fftData[i];
      double db =
          magnitude > 0.000001
              ? 20.0 * (math.log(magnitude) / math.ln10)
              : -100.0;

      // Normalize (-80dB to 0dB range)
      double normalizedDb = ((db + 80) / 80).clamp(0.0, 1.0);
      // Apply a curve to emphasize peaks subtly
      normalizedDb = math.pow(normalizedDb, 1.2).toDouble();
      double barHeight = normalizedDb * size.height;

      // Dynamic Coloring based on frequency band
      Color barColor;
      if (i > bins * 0.7) {
        barColor = const Color(0xFFFF3366); // Highs (Pink/Red)
      } else if (i > bins * 0.3) {
        barColor = primaryColor; // Mids (Green/Cyan)
      } else {
        barColor = const Color(0xFF00AAFF); // Lows (Blue)
      }

      // Apply a vertical gradient to the bar for depth
      paint.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [barColor.withOpacity(0.3), barColor],
      ).createShader(
        Rect.fromLTWH(
          i * barWidth,
          size.height - barHeight,
          barWidth,
          barHeight,
        ),
      );

      final double x = i * barWidth + barWidth / 2;
      final double yStart = size.height;
      final double yEnd = size.height - barHeight;

      // Ensure we don't draw below the canvas if height is 0
      if (barHeight > 0) {
        canvas.drawLine(Offset(x, yStart), Offset(x, yEnd), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) => true;
}
