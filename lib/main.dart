import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/strings.dart';
import 'models/question.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'services/ads.dart';
import 'services/iap.dart';
import 'services/progress.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.load();
  final raw = await rootBundle.loadString('assets/data/questions.json');
  final questions = (jsonDecode(raw) as List).map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
  final state = AppState();
  await state.init(questions);
  final iap = IapService(state);
  // Ads + IAP initialise in the background; the UI must not wait for them.
  // ignore: unawaited_futures
  AdService.instance.init();
  // ignore: unawaited_futures
  iap.init();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      Provider.value(value: iap),
    ],
    child: const EinbApp(),
  ));
}

class EinbApp extends StatelessWidget {
  const EinbApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final seed = const Color(0xFF1F3A5F);
    return MaterialApp(
      title: 'Einbürgerungstest 2026',
      debugShowCheckedModeBanner: false,
      locale: Locale(state.lang),
      supportedLocales: const [Locale('de'), Locale('en'), Locale('tr'), Locale('ar'), Locale('ru'), Locale('uk')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      home: state.onboarded && state.land != null ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
