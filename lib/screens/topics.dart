import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/progress.dart';
import 'practice.dart';

class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(s.t('topics_title'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final t in kTopicOrder)
              if (st.byTopic(t).isNotEmpty) _TopicTile(topic: t, questions: st.byTopic(t)),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final String topic;
  final List<Question> questions;
  const _TopicTile({required this.topic, required this.questions});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final mastered = questions.where((q) => (st.stateMap[q.id]?.box ?? 0) >= 3).length;
    final seen = questions.where((q) => (st.stateMap[q.id]?.seen ?? 0) > 0).length;
    final ratio = questions.isEmpty ? 0.0 : mastered / questions.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: cs.surfaceContainerHighest,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PracticeScreen(title: s.t('topic_$topic'), pool: questions, smart: true))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(s.t('topic_$topic'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                    Text('$mastered/${questions.length}', style: TextStyle(color: cs.outline)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: cs.surface),
                ),
                if (seen > 0 && seen < questions.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${s.t('stats_answered')}: $seen', style: TextStyle(fontSize: 12, color: cs.outline)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
