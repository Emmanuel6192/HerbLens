import 'dart:convert';
import 'package:flutter/services.dart';

class HerbResult {
  final String name;
  final double confidence;
  final List<HerbPrediction> topPredictions;

  const HerbResult({
    required this.name,
    required this.confidence,
    required this.topPredictions,
  });
}

class HerbPrediction {
  final String name;
  final double confidence;

  const HerbPrediction({required this.name, required this.confidence});
}

// ── Plant info model ─────────────────────────────────────────────────────────
class PlantInfo {
  final List<String> commonNames;
  final Map<String, String?> localNames;
  final String uses;
  final String botanicalName;

  const PlantInfo({
    required this.commonNames,
    required this.localNames,
    required this.uses,
    required this.botanicalName,
  });

  factory PlantInfo.fromJson(Map<String, dynamic> json) => PlantInfo(
        commonNames: (json['common_names'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        localNames: (json['names'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as String?)) ??
            {},
        uses: json['uses'] as String? ?? '—',
        botanicalName: json['botanical_name'] as String? ?? '—',
      );

  static PlantInfo get placeholder => const PlantInfo(
        commonNames: [],
        localNames:  {},
        uses:        '—',
        botanicalName: '—',
      );
}

// ── Database loader ──────────────────────────────────────────────────────────
class PlantDatabase {
  static Map<String, dynamic>? _cache;

  /// Call once at app startup (e.g. in main() or initState of HomeScreen)
  static Future<void> preload() async {
    if (_cache != null) return;
    try {
      final raw = await rootBundle.loadString('assets/plants.json');
      _cache = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      _cache = {}; // plants.json not yet present — use placeholders
    }
  }

  /// Look up a plant by its label name (case-insensitive fallback included)
  static PlantInfo getInfo(String plantName) {
    if (_cache == null) return PlantInfo.placeholder;

    // Exact match first
    if (_cache!.containsKey(plantName)) {
      return PlantInfo.fromJson(_cache![plantName] as Map<String, dynamic>);
    }

    // Case-insensitive fallback
    final key = _cache!.keys.firstWhere(
      (k) => k.toLowerCase() == plantName.toLowerCase(),
      orElse: () => '',
    );
    if (key.isNotEmpty) {
      return PlantInfo.fromJson(_cache![key] as Map<String, dynamic>);
    }

    return PlantInfo.placeholder;
  }
}
