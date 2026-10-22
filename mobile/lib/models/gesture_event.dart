/// One entry in the local gesture history.
class GestureEvent {
  const GestureEvent({
    required this.gesture,
    required this.confidence,
    required this.at,
    this.sentence,
  });

  final String gesture;
  final double confidence;
  final DateTime at;
  final String? sentence;

  GestureEvent copyWith({double? confidence, DateTime? at, String? sentence}) =>
      GestureEvent(
        gesture: gesture,
        confidence: confidence ?? this.confidence,
        at: at ?? this.at,
        sentence: sentence ?? this.sentence,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'gesture': gesture,
        'confidence': confidence,
        'at': at.millisecondsSinceEpoch,
        if (sentence != null) 'sentence': sentence,
      };

  factory GestureEvent.fromJson(Map<String, dynamic> json) => GestureEvent(
        gesture: (json['gesture'] as String?) ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        at: DateTime.fromMillisecondsSinceEpoch(
          (json['at'] as num?)?.toInt() ?? 0,
        ),
        sentence: json['sentence'] as String?,
      );
}
