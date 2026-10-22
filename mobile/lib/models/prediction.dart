/// A single recognised gesture, as returned by the backend WebSocket.
class Prediction {
  const Prediction({
    required this.gesture,
    required this.confidence,
    required this.at,
    this.sentence,
  });

  final String gesture;
  final double confidence;
  final DateTime at;
  final String? sentence;

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
        gesture: (json['gesture'] as String?) ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        sentence: json['sentence'] as String?,
        at: DateTime.now(),
      );
}
