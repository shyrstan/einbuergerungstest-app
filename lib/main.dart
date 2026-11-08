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
import 'theme.dart';

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
      theme: buildAppTheme(),
      home: state.onboarded && state.land != null ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
