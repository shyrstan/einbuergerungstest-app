import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/progress.dart';
import 'home.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _land;
  String _lang = 'de';

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _land = st.land;
    _lang = st.lang;
    // Pre-select device language if supported.
    final dev = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (S.languages.containsKey(dev)) _lang = dev;
  }

  @override
  Widget build(BuildContext context) {
    final s = S(_lang);
    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              Icon(Icons.verified_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(s.t('onb_welcome'), style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(s.t('onb_text'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 32),
              Text(s.t('choose_lang'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: S.languages.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _lang == e.key,
                          onSelected: (_) => setState(() => _lang = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text(s.t('choose_land'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _land,
                    isExpanded: true,
                    hint: const Text('—'),
                    items: kLaender.map((l) => DropdownMenuItem(value: l.code, child: Text(l.nameDe))).toList(),
                    onChanged: (v) => setState(() => _land = v),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _land == null
                    ? null
                    : () async {
                        final st = context.read<AppState>();
                        await st.setLang(_lang);
                        await st.setLand(_land!);
                        await st.setOnboarded();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
                      },
                child: Text(s.t('start')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
