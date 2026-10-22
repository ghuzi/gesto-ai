import 'package:flutter/material.dart';

import '../app/theme.dart';

class StepCard extends StatelessWidget {
  const StepCard({
    super.key,
    required this.index,
    required this.title,
    required this.body,
    required this.icon,
  });

  final int index;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: kAquaGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fade(kTeal, 0.16)),
          ),
          child: Icon(icon, color: kTealDeep, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '${index.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kTeal,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(title, style: GText.h3)),
                ],
              ),
              const SizedBox(height: 4),
              Text(body, style: GText.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class TechChip extends StatelessWidget {
  const TechChip({super.key, required this.label, this.dotColor = kTeal});

  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
        ],
      ),
    );
  }
}

class TeamCard extends StatelessWidget {
  const TeamCard({
    super.key,
    required this.name,
    required this.role,
    required this.description,
    required this.assetImage,
  });

  final String name;
  final String role;
  final String description;
  final String assetImage;

  @override
  Widget build(BuildContext context) {
    return SectionRowCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              assetImage,
              width: 62,
              height: 62,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
                return Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: kAquaGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.person, color: kTealDeep, size: 30),
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: GText.h3),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTealDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Text(description, style: GText.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal white card without the InkWell, used by list rows.
class SectionRowCard extends StatelessWidget {
  const SectionRowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLine),
      ),
      child: child,
    );
  }
}
