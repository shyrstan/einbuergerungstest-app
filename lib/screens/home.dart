import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/progress.dart';
import '../widgets/banner_box.dart';
import 'exam.dart';
import 'practice.dart';
import 'settings.dart';
import 'stats.dart';
import 'topics.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = S.of(context);
    final total = st.relevant.length;
    final mastered = st.masteredCount();
    final ratio = total == 0 ? 0.0 : mastered / total;
    final landName = kLaender.firstWhere((l) => l.code == st.land, orElse: () => const LandInfo('', '')).nameDe;
    final wrong = st.wrongOnes.length;

    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.t('app_title')),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
        bottomNavigationBar: const BannerBox(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(value: ratio, strokeWidth: 8, backgroundColor: Colors.white54),
                          Center(child: Text('${(ratio * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.t('home_progress'), style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(s.t('home_mastered', {'n': mastered, 'total': total})),
                          const SizedBox(height: 4),
                          Text(ratio >= 0.8 ? s.t('home_exam_ready') : s.t('home_keep_going'),
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _MenuTile(
              icon: Icons.menu_book_outlined,
              title: s.t('menu_learn'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopicsScreen())),
            ),
            _MenuTile(
              icon: Icons.list_alt_outlined,
              title: s.t('menu_all'),
              subtitle: s.t('questions_count', {'n': st.general.length}),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PracticeScreen(title: s.t('menu_all'), pool: st.general, smart: true))),
            ),
            _MenuTile(
              icon: Icons.map_outlined,
              title: s.t('menu_land', {'land': landName}),
              subtitle: s.t('questions_count', {'n': st.landQuestions.length}),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PracticeScreen(title: landName, pool: st.landQuestions, smart: false))),
            ),
            _MenuTile(
              icon: Icons.timer_outlined,
              title: s.t('menu_exam'),
              highlighted: true,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamIntroScreen())),
            ),
            _MenuTile(
              icon: Icons.replay_outlined,
              title: s.t('menu_mistakes'),
              subtitle: wrong > 0 ? s.t('questions_count', {'n': wrong}) : null,
              onTap: () {
                if (wrong == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('mistakes_empty'))));
                  return;
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PracticeScreen(title: s.t('menu_mistakes'), pool: st.wrongOnes, smart: false)));
              },
            ),
            _MenuTile(
              icon: Icons.bar_chart_outlined,
              title: s.t('menu_stats'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool highlighted;
  const _MenuTile({required this.icon, required this.title, required this.onTap, this.subtitle, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: highlighted ? cs.secondaryContainer : cs.surfaceContainerHighest,
        child: ListTile(
          leading: Icon(icon, color: cs.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
      ),
    );
  }
}
