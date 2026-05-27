import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/herb_result.dart';

class ResultScreen extends StatelessWidget {
  final String imagePath;
  final HerbResult result;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.result,
  });

  Color get _confidenceColor {
    if (result.confidence >= 0.70) return const Color(0xFF7BC67A);
    if (result.confidence >= 0.40) return const Color(0xFFFFB347);
    return const Color(0xFFFF6B6B);
  }

  String get _confidenceLabel {
    if (result.confidence >= 0.70) return 'High Confidence';
    if (result.confidence >= 0.40) return 'Moderate Confidence';
    return 'Low Confidence';
  }

  @override
  Widget build(BuildContext context) {
    final info = PlantDatabase.getInfo(result.name);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1F0A),
      body: Column(
        children: [
          _buildImageHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIdentifiedHerb(info).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 20),
                  _buildCommonNames(info).animate().fadeIn(delay: 80.ms, duration: 500.ms),
                  const SizedBox(height: 20),
                  _buildLocalNames(info).animate().fadeIn(delay: 160.ms, duration: 500.ms),
                  const SizedBox(height: 20),
                  _buildUses(info).animate().fadeIn(delay: 240.ms, duration: 500.ms),
                  const SizedBox(height: 20),
                  _buildOtherPossibilities().animate().fadeIn(delay: 320.ms, duration: 500.ms),
                  const SizedBox(height: 32),
                  _buildActions(context).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image header ────────────────────────────────────────────────────────────
  Widget _buildImageHeader(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: Image.file(File(imagePath), fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.3), const Color(0xFF0D1F0A)],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _confidenceColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _confidenceColor.withOpacity(0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: _confidenceColor, size: 14),
                const SizedBox(width: 5),
                Text(_confidenceLabel,
                    style: TextStyle(
                        color: _confidenceColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Identified Herb (prominent name + circular confidence + botanical) ───────
  Widget _buildIdentifiedHerb(PlantInfo info) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: herb name + botanical name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Identified Herb', Icons.eco_rounded),
              const SizedBox(height: 8),
              Text(
                result.name,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                info.botanicalName,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Right: circular confidence meter
        _buildConfidenceMeter(),
      ],
    );
  }

  Widget _buildConfidenceMeter() {
    final pct = result.confidence;
    final label = '${(pct * 100).toStringAsFixed(0)}%';

    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(76, 76),
            painter: _ConfidenceRingPainter(
              progress: pct,
              trackColor: Colors.white.withOpacity(0.08),
              progressColor: _confidenceColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: _confidenceColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'match',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Common names (English) ──────────────────────────────────────────────────
  Widget _buildCommonNames(PlantInfo info) {
    if (info.commonNames.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Common Names', Icons.label_outline_rounded),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: info.commonNames
              .map((name) => _chip(name, const Color(0xFF7BC67A)))
              .toList(),
        ),
      ],
    );
  }

  // ── Local names ─────────────────────────────────────────────────────────────
  Widget _buildLocalNames(PlantInfo info) {
    // Always show all four languages, using "—" as placeholder when empty
    final languages = ['Igbo', 'Hausa', 'Yoruba', 'Bini'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3317),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7BC67A).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Local Names', Icons.translate_rounded),
          const SizedBox(height: 12),
          ...languages.map((lang) {
            final value = info.localNames[lang];
            final display = (value != null && value.isNotEmpty) ? value : '—';
            final isPlaceholder = display == '—';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      '$lang:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      display,
                      style: TextStyle(
                        color: isPlaceholder
                            ? Colors.white.withOpacity(0.25)
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Uses ─────────────────────────────────────────────────────────────────────
  Widget _buildUses(PlantInfo info) {
    final isPlaceholder = info.uses == '—' || info.uses.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3317),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7BC67A).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Uses', Icons.menu_book_rounded),
          const SizedBox(height: 12),
          Text(
            isPlaceholder ? '—' : info.uses,
            style: TextStyle(
              color: isPlaceholder
                  ? Colors.white.withOpacity(0.25)
                  : Colors.white.withOpacity(0.75),
              fontSize: 15,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  // ── Other Possibilities (top 5 alternatives) ────────────────────────────────
  Widget _buildOtherPossibilities() {
    // Show positions 2–5 (skip index 0 — the identified result)
    final alternatives = result.topPredictions.skip(1).take(4).toList();
    if (alternatives.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3317),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7BC67A).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Other Possibilities', Icons.help_outline_rounded),
          const SizedBox(height: 14),
          ...alternatives.asMap().entries.map((entry) {
            final i    = entry.key;
            final pred = entry.value;
            final pct  = pred.confidence * 100;
            return Padding(
              padding: EdgeInsets.only(bottom: i < alternatives.length - 1 ? 14 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 2}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pred.name,
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withOpacity(0.80),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.40),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pred.confidence.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.07),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.20),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────
  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Center(
                child: Text('Scan Another',
                    style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ),
        // Save Result button removed — not yet functional
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF7BC67A), size: 15),
      const SizedBox(width: 6),
      Text(label,
          style: GoogleFonts.dmSans(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Circular confidence ring painter ─────────────────────────────────────────
class _ConfidenceRingPainter extends CustomPainter {
  final double progress;     // 0.0 – 1.0
  final Color trackColor;
  final Color progressColor;

  const _ConfidenceRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - 8) / 2; // 4 px padding on each side
    const strokeWidth = 6.0;
    const startAngle = -math.pi / 2; // top

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Track (full circle)
    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ConfidenceRingPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
}
