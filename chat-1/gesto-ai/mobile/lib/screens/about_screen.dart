import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/config.dart';
import '../app/l10n.dart';
import '../app/theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/section_card.dart';
import '../widgets/step_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, String url, String errorText) async {
    try {
      final bool ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) _snack(context, errorText);
    } on Object {
      if (context.mounted) _snack(context, errorText);
    }
  }

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            Text(l.about),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: <Widget>[
          // ---------------------------------------------------------- intro
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(gradient: kHeroGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const BrandMark(size: 46, glow: true),
                  const SizedBox(height: 16),
                  const BrandTitle(fontSize: 26, onDark: true),
                  const SizedBox(height: 8),
                  Text(
                    l.heroTagline,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.6,
                      color: fade(Colors.white, 0.86),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // -------------------------------------------------------- problem
          SectionHeader(eyebrow: l.about, title: l.problemTitle),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.problemBody1, style: GText.body),
                const SizedBox(height: 12),
                Text(l.problemBody2, style: GText.body),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ---------------------------------------------------- how it works
          SectionHeader(eyebrow: l.howItWorks, title: l.signItSayIt),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                StepCard(
                  index: 1,
                  title: l.stepCameraTitle,
                  body: l.stepCameraBody,
                  icon: Icons.videocam_rounded,
                ),
                const SizedBox(height: 14),
                StepCard(
                  index: 2,
                  title: l.stepModelTitle,
                  body: l.stepModelBody,
                  icon: Icons.auto_awesome_rounded,
                ),
                const SizedBox(height: 14),
                StepCard(
                  index: 3,
                  title: l.stepSpeechTitle,
                  body: l.stepSpeechBody,
                  icon: Icons.volume_up_rounded,
                ),
                const SizedBox(height: 16),
                Text(l.howItWorksBody, style: GText.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ------------------------------------------------------- tech stack
          SectionHeader(eyebrow: l.techTitle, title: l.techTitle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              TechChip(label: 'MediaPipe Tasks'),
              TechChip(label: 'TensorFlow', dotColor: kBlue),
              TechChip(label: 'FastAPI'),
              TechChip(label: 'WebSocket', dotColor: kBlue),
              TechChip(label: 'Python'),
              TechChip(label: 'Flutter', dotColor: kBlue),
              TechChip(label: 'Railway'),
              TechChip(label: 'Vercel', dotColor: kBlue),
            ],
          ),
          const SizedBox(height: 24),

          // ------------------------------------------------------------ team
          SectionHeader(eyebrow: l.teamTitle, title: l.teamSub),
          const SizedBox(height: 12),
          TeamCard(
            name: 'Muhammad Ghuzaif Arif',
            role: 'ML Engineer',
            description: l.isUrdu
                ? 'میڈیا پائپ لینڈ مارکس پر PSL اشاروں کے ماڈل کی تربیت اور بہتری۔'
                : 'Trains and tunes the PSL gesture classifier on top of MediaPipe hand landmarks.',
            assetImage: 'assets/team/ghuzaif.jpeg',
          ),
          const SizedBox(height: 10),
          TeamCard(
            name: 'Adeel Shahbaz',
            role: 'Backend Engineer',
            description: l.isUrdu
                ? 'FastAPI انفرنس سرور اور ریئل ٹائم WebSocket پائپ لائن۔'
                : 'Builds the FastAPI inference server and the real-time WebSocket prediction pipeline.',
            assetImage: 'assets/team/adeel.jpeg',
          ),
          const SizedBox(height: 10),
          TeamCard(
            name: 'Ishmal Nayyab',
            role: 'Frontend & UX',
            description: l.isUrdu
                ? 'قابلِ رسائی انٹرفیس اور اردو آواز کا تجربہ۔'
                : 'Crafts the accessible, judge-friendly interface and the Urdu voice experience.',
            assetImage: 'assets/team/ishmal.jpeg',
          ),
          const SizedBox(height: 24),

          // ----------------------------------------------------------- links
          SectionHeader(eyebrow: l.links, title: l.links),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: <Widget>[
                _LinkRow(
                  icon: Icons.language_rounded,
                  label: l.liveDemo,
                  value: AppConfig.webDemoUrl,
                  onTap: () => _open(context, AppConfig.webDemoUrl, l.linkFailed),
                ),
                const Divider(height: 1, color: kLine),
                _LinkRow(
                  icon: Icons.dns_rounded,
                  label: l.backendApi,
                  value: AppConfig.backendDocsUrl,
                  onTap: () =>
                      _open(context, AppConfig.backendDocsUrl, l.linkFailed),
                ),
                const Divider(height: 1, color: kLine),
                _LinkRow(
                  icon: Icons.code_rounded,
                  label: l.sourceCode,
                  value: AppConfig.repoUrl,
                  onTap: () => _open(context, AppConfig.repoUrl, l.linkFailed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: <Widget>[
                const BrandMark(size: 34),
                const SizedBox(height: 10),
                Text(
                  'Gesto AI · v${AppConfig.version} (${AppConfig.buildNumber})',
                  style: GText.bodySmall.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  l.footerNote,
                  textAlign: TextAlign.center,
                  style: GText.bodySmall.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fade(kTeal, 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: kTealDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: GText.h3.copyWith(fontSize: 14)),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GText.bodySmall.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 17, color: kInkSoft),
          ],
        ),
      ),
    );
  }
}
