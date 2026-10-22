import 'package:flutter/material.dart';

import '../app/theme.dart';

enum LinkState { connecting, connected, disconnected }

/// Pill showing the WebSocket state with a pulsing dot.
class ConnectionChip extends StatefulWidget {
  const ConnectionChip({
    super.key,
    required this.state,
    required this.label,
    this.onRetry,
    this.retryLabel = 'Reconnect',
  });

  final LinkState state;
  final String label;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  State<ConnectionChip> createState() => _ConnectionChipState();
}

class _ConnectionChipState extends State<ConnectionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _tint {
    switch (widget.state) {
      case LinkState.connected:
        return kTeal;
      case LinkState.connecting:
        return kAmber;
      case LinkState.disconnected:
        return kDanger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: fade(_tint, 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: fade(_tint, 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 14,
                height: 14,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _controller.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        if (widget.state != LinkState.disconnected)
                          Container(
                            width: 4 + 10 * t,
                            height: 4 + 10 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: fade(_tint, 0.35 * (1 - t)),
                            ),
                          ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _tint,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: fade(_tint, 0.95),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.state == LinkState.disconnected && widget.onRetry != null) ...<Widget>[
          const SizedBox(width: 8),
          TextButton(
            onPressed: widget.onRetry,
            style: TextButton.styleFrom(
              foregroundColor: kTealDeep,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              widget.retryLabel,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}
