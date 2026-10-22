import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_scope.dart';
import 'app/app_state.dart';
import 'app/l10n.dart';
import 'app/theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  final AppState state = AppState();
  await state.load();

  runApp(GestoApp(state: state));
}

class GestoApp extends StatelessWidget {
  const GestoApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (BuildContext context, Widget? child) {
          final Locale locale = Locale(state.language.code);
          return MaterialApp(
            title: 'Gesto AI',
            debugShowCheckedModeBanner: false,
            theme: buildGestoTheme(),
            locale: locale,
            supportedLocales: const <Locale>[Locale('en'), Locale('ur')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (BuildContext context, Widget? child) {
              return Directionality(
                textDirection:
                    state.language.isUrdu ? TextDirection.rtl : TextDirection.ltr,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: state.onboarded
                ? const RootShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
