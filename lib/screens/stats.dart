import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/progress.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    var answered = 0, right = 0;
    for (final q in st.relevant) {
      final x = st.stateMap[q.id];
      if (x == null) continue;
      answered += x.seen;
      right += x.right;
    }
    final acc = answered == 0 ? 0 : (right * 100 / answered).round();
    final passed = st.exams.where((e) => e.passed).length;
    String fmt(int ts) {
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
    }

    Widget tile(String label, String value) => Expanded(
          child: Card(
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(color: cs.outline, fontSize: 12)),
              ]),
            ),
          ),
        );

    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(s.t('stats_title'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              tile(s.t('stats_answered'), '$answered'),
              const SizedBox(width: 8),
              tile(s.t('stats_accuracy'), '$acc%'),
              const SizedBox(width: 8),
              tile(s.t('stats_mastered'), '${st.masteredCount()}/${st.relevant.length}'),
            ]),
            const SizedBox(height: 16),
            Text(s.t('stats_by_topic'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final t in st.exam.topicOrder)
              if (st.byTopic(t).isNotEmpty) _TopicRow(label: s.t('topic_$t'), qs: st.byTopic(t)),
            const SizedBox(height: 16),
            Text('${s.t('stats_exams')} · $passed ${s.t('stats_passed')}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (st.exams.isEmpty) Text('—', style: TextStyle(color: cs.outline)),
            for (final e in st.exams.take(10))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(e.passed ? Icons.check_circle : Icons.cancel, color: e.passed ? Colors.green : Colors.red),
                title: Text(s.t('result_score', {'c': e.correct, 'n': e.total})),
                subtitle: Text(fmt(e.ts)),
                trailing: Text('${e.seconds ~/ 60} min', style: TextStyle(color: cs.outline)),
              ),
            const SizedBox(height: 24),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(s.t('stats_reset')),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    content: Text(s.t('stats_reset_confirm')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('delete'))),
                    ],
                  ),
                );
                if (ok == true) await st.resetProgress();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final String label;
  final List<Question> qs;
  const _TopicRow({required this.label, required this.qs});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final mastered = qs.where((q) => (st.stateMap[q.id]?.box ?? 0) >= 3).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(flex: 5, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: qs.isEmpty ? 0 : mastered / qs.length, minHeight: 8, backgroundColor: cs.surfaceContainerHighest),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 48, child: Text('$mastered/${qs.length}', textAlign: TextAlign.end, style: TextStyle(color: cs.outline, fontSize: 12))),
      ]),
    );
  }
}
