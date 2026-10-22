/// Snapshot of `GET /health` from the FastAPI backend.
class BackendHealth {
  const BackendHealth({
    required this.status,
    required this.modelLoaded,
    required this.gestureLabels,
    this.sequenceLength,
    this.confidenceThreshold,
  });

  final String status;
  final bool modelLoaded;
  final List<String> gestureLabels;
  final int? sequenceLength;
  final double? confidenceThreshold;

  factory BackendHealth.fromJson(Map<String, dynamic> json) {
    final List<String> labels = <String>[];
    final Object? rawLabels = json['gesture_labels'];
    if (rawLabels is List) {
      for (final Object? label in rawLabels) {
        if (label is String && label.isNotEmpty) labels.add(label);
      }
    }

    int? sequenceLength;
    double? threshold;
    final Object? config = json['config'];
    if (config is Map) {
      final Object? seq = config['SEQUENCE_LENGTH'];
      if (seq is num) sequenceLength = seq.toInt();
      final Object? thr = config['CONFIDENCE_THRESHOLD'];
      if (thr is num) threshold = thr.toDouble();
    }

    return BackendHealth(
      status: (json['status'] as String?) ?? 'unknown',
      modelLoaded: json['model_loaded'] == true,
      gestureLabels: labels,
      sequenceLength: sequenceLength,
      confidenceThreshold: threshold,
    );
  }
}
