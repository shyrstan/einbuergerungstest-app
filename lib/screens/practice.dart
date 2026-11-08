import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../exam/exam_config.dart';
import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/ads.dart';
import '../services/progress.dart';
import '../widgets/ltr_text.dart';
import '../widgets/question_card.dart';
import 'settings.dart';

/// Practice mode: answer -> immediate feedback -> explanation -> next.
/// Interstitial every 10 answered questions (frequency-capped in AdService).
class PracticeScreen extends StatefulWidget {
  final String title;
  final List<Question> pool;
  final bool smart; // use Leitner ordering
  final bool shuffle;

  const PracticeScreen({super.key, required this.title, required this.pool, required this.smart, this.shuffle = true});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late List<Question> _queue;
  int _i = 0;
  int? _selected;
  bool _revealed = false;
  bool _unlockedTranslation = false; // per-question reward

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _queue = widget.smart ? st.smartQueue(widget.pool, limit: 20) : (widget.shuffle ? (List.of(widget.pool)..shuffle()) : List.of(widget.pool));
    if (!widget.smart && _queue.length > 40) _queue = _queue.take(40).toList();
  }

  Question get _q => _queue[_i];

  Future<void> _check() async {
    if (_selected == null) return;
    final st = context.read<AppState>();
    final ok = _selected == _q.correct;
    setState(() => _revealed = true);
    await st.recordAnswer(_q, ok);
    if (st.answeredCount % 10 == 0) {
      await AdService.instance.maybeShowInterstitial(premium: st.premium);
    }
  }

  void _next() {
    if (_i + 1 >= _queue.length) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _i++;
      _selected = null;
      _revealed = false;
      _unlockedTranslation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = S.of(context);
    final lang = st.lang;
    final canSeeForeign = lang == ExamConfig.current.baseLang || st.premium || _unlockedTranslation;

    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_i + (_revealed ? 1 : 0)) / _queue.length),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Text(s.t('question_n_of', {'i': _i + 1, 'n': _queue.length}),
                          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                      const Spacer(),
                      Text(_q.id, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  QuestionCard(
                    q: _q,
                    selected: _selected,
                    reveal: _revealed,
                    lang: lang,
                    showTranslation: canSeeForeign,
                    onSelect: (i) => setState(() => _selected = i),
                  ),
                  if (_revealed) _Feedback(q: _q, correct: _selected == _q.correct, lang: lang, unlocked: canSeeForeign,
                      onUnlock: () => setState(() => _unlockedTranslation = true)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _revealed
                    ? FilledButton(onPressed: _next, child: Text(_i + 1 >= _queue.length ? s.t('finish') : s.t('next')))
                    : FilledButton(onPressed: _selected == null ? null : _check, child: Text(s.t('check'))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  final Question q;
  final bool correct;
  final String lang;
  final bool unlocked;
  final VoidCallback onUnlock;
  const _Feedback({required this.q, required this.correct, required this.lang, required this.unlocked, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final s = S(lang);
    final cs = Theme.of(context).colorScheme;
    final base = ExamConfig.current.baseLang;
    final de = q.explanation[base] ?? '';
    final foreign = lang == base ? null : q.explanation[lang];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        color: correct ? const Color(0xFFDFF5E1) : const Color(0xFFFDE2E1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(correct ? Icons.check_circle : Icons.cancel, color: correct ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                const SizedBox(width: 8),
                Text(correct ? s.t('correct') : s.t('wrong'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              if (!correct) ...[
                const SizedBox(height: 8),
                Text(s.t('correct_answer_is'), style: TextStyle(color: cs.outline)),
                LtrText(q.options[q.correct], style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              if (de.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(s.t('explanation'), style: TextStyle(color: cs.outline)),
                const SizedBox(height: 4),
                LtrText(de, style: const TextStyle(height: 1.35)),
              ],
              if (foreign != null && foreign.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (unlocked)
                  Text(foreign, style: const TextStyle(height: 1.35, fontStyle: FontStyle.italic))
                else
                  _UnlockBox(s: s, onUnlock: onUnlock),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnlockBox extends StatelessWidget {
  final S s;
  final VoidCallback onUnlock;
  const _UnlockBox({required this.s, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.translate, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(s.t('explanation_locked'), style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: Text(s.t('unlock_by_ad')),
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              AdService.instance.showRewarded(
                onReward: onUnlock,
                onUnavailable: () => messenger.showSnackBar(SnackBar(content: Text(s.t('ad_unavailable')))),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            child: Text(s.t('unlock_premium')),
          ),
        ],
      ),
    );
  }
}
