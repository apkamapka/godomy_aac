import 'dart:ui' show Color;

/// Jeden element zdania (słowo z obrazkiem albo wpisany tekst).
class SentenceItem {
  /// Unikalny klucz w pasku zdania (do animacji i usuwania).
  final String key;
  final String? symbolId;
  final String label;
  final String? emoji;
  final String? imagePath;
  final Color color;
  final String? voicePath;
  final bool isText;

  const SentenceItem({
    required this.key,
    required this.label,
    required this.color,
    this.symbolId,
    this.emoji,
    this.imagePath,
    this.voicePath,
    this.isText = false,
  });

  bool get hasRecording => voicePath != null && voicePath!.isNotEmpty;

  SentenceItem withKey(String newKey) => SentenceItem(
        key: newKey,
        label: label,
        color: color,
        symbolId: symbolId,
        emoji: emoji,
        imagePath: imagePath,
        voicePath: voicePath,
        isText: isText,
      );

  Map<String, dynamic> toJson() => {
        'symbolId': symbolId,
        'label': label,
        'emoji': emoji,
        'imagePath': imagePath,
        'color': color.toARGB32(),
        'voicePath': voicePath,
        'isText': isText,
      };

  factory SentenceItem.fromJson(Map<String, dynamic> json, {required String key}) {
    return SentenceItem(
      key: key,
      symbolId: json['symbolId'] as String?,
      label: json['label'] as String? ?? '',
      emoji: json['emoji'] as String?,
      imagePath: json['imagePath'] as String?,
      color: Color((json['color'] as num?)?.toInt() ?? 0xFFFFFFFF),
      voicePath: json['voicePath'] as String?,
      isText: json['isText'] as bool? ?? false,
    );
  }
}

/// Zapisane zdanie („Moje zdania”) albo wpis w historii.
class StoredSentence {
  final String id;
  final List<SentenceItem> items;
  final DateTime time;

  const StoredSentence({required this.id, required this.items, required this.time});

  String get text => items.map((i) => i.label).join(' ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory StoredSentence.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final raw = (json['items'] as List?) ?? const [];
    final items = <SentenceItem>[];
    for (var i = 0; i < raw.length; i++) {
      final m = raw[i];
      if (m is Map) {
        items.add(SentenceItem.fromJson(Map<String, dynamic>.from(m), key: '${id}_$i'));
      }
    }
    return StoredSentence(
      id: id,
      items: items,
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
