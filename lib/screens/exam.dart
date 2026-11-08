import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/ads.dart';
import '../services/progress.dart';
import '../widgets/question_card.dart';

class ExamIntroScreen extends StatelessWidget {
  const ExamIntroScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(s.t('exam_intro_title'))),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.timer_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(s.t('exam_intro_text'), style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              const Spacer(),
              if (st.exams.isNotEmpty) ...[
                Text('${s.t('stats_exams')}: ${st.exams.length} · ${s.t('stats_passed')}: ${st.exams.where((e) => e.passed).length}',
                    textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ExamScreen())),
                child: Text(s.t('exam_start')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamScreen extends StatefulWidget {
  /// Fixed question list (used for store screenshots); random exam if null.
  final List<Question>? questions;
  const ExamScreen({super.key, this.questions});
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  static const duration = Duration(minutes: 60);
  late final List<Question> _qs;
  final Map<int, int> _answers = {};
  int _i = 0;
  late DateTime _start;
  Timer? _timer;
  Duration _left = duration;

  @override
  void initState() {
    super.initState();
    _qs = widget.questions ?? context.read<AppState>().buildExam();
    _start = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = duration - DateTime.now().difference(_start);
      if (left.isNegative) {
        _timer?.cancel();
        _finish(timeUp: true);
      } else {
        setState(() => _left = left);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _finish({bool timeUp = false}) async {
    _timer?.cancel();
    final st = context.read<AppState>();
    var correct = 0;
    final wrong = <String>[];
    for (var k = 0; k < _qs.length; k++) {
      final ok = _answers[k] == _qs[k].correct;
      if (ok) {
        correct++;
      } else {
        wrong.add(_qs[k].id);
      }
      if (_answers.containsKey(k)) await st.recordAnswer(_qs[k], ok);
    }
    final res = ExamResult(DateTime.now().millisecondsSinceEpoch, correct, _qs.length,
        DateTime.now().difference(_start).inSeconds, wrong);
    await st.recordExam(res);
    if (!mounted) return;
    await AdService.instance.maybeShowInterstitial(premium: st.premium);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => ExamResultScreen(result: res, questions: _qs, answers: _answers, timeUp: timeUp)));
  }

  Future<void> _confirmSubmit() async {
    final s = S.read(context);
    final open = _qs.length - _answers.length;
    if (open == 0) return _finish();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.t('exam_confirm_submit', {'n': open})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('exam_submit'))),
        ],
      ),
    );
    if (ok == true) _finish();
  }

  String _fmt(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final q = _qs[_i];
    final urgent = _left.inMinutes < 5;
    return Directionality(
      textDirection: s.direction,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final leave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              content: Text(s.t('exam_confirm_submit', {'n': _qs.length - _answers.length})),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('exam_submit'))),
              ],
            ),
          );
          if (leave == true) _finish();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(s.t('question_n_of', {'i': _i + 1, 'n': _qs.length})),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(_fmt(_left),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: urgent ? Colors.red : null)),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _qs.length,
                  itemBuilder: (_, k) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                    child: ChoiceChip(
                      label: Text('${k + 1}'),
                      selected: k == _i,
                      avatar: _answers.containsKey(k) ? const Icon(Icons.check, size: 14) : null,
                      onSelected: (_) => setState(() => _i = k),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    QuestionCard(
                      q: q,
                      selected: _answers[_i],
                      reveal: false,
                      lang: st.lang,
                      showTranslation: st.premium,
                      onSelect: (v) => setState(() => _answers[_i] = v),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: _i == 0 ? null : () => setState(() => _i--),
                        child: const Icon(Icons.chevron_left),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _i + 1 < _qs.length
                            ? FilledButton(onPressed: () => setState(() => _i++), child: Text(s.t('next')))
                            : FilledButton(onPressed: _confirmSubmit, child: Text(s.t('exam_submit'))),
                      ),
                      const SizedBox(width: 8),
                      TextButton(onPressed: _confirmSubmit, child: Text(s.t('exam_submit'))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamResultScreen extends StatelessWidget {
  final ExamResult result;
  final List<Question> questions;
  final Map<int, int> answers;
  final bool timeUp;
  const ExamResultScreen({super.key, required this.result, required this.questions, required this.answers, this.timeUp = false});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final passed = result.passed;
    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(s.t('exam_intro_title')), automaticallyImplyLeading: false),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(passed ? Icons.emoji_events : Icons.sentiment_dissatisfied, size: 80, color: passed ? Colors.green : Colors.red),
              const SizedBox(height: 12),
              Text(passed ? s.t('result_passed') : s.t('result_failed'),
                  style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(s.t('result_score', {'c': result.correct, 'n': result.total}),
                  style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              if (timeUp) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.t('exam_time_up'), textAlign: TextAlign.center)),
              if (!passed) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.t('result_need'), textAlign: TextAlign.center)),
              const Spacer(),
              if (result.wrongIds.isNotEmpty)
                OutlinedButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ExamReviewScreen(questions: questions, answers: answers))),
                  child: Text(s.t('result_review')),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ExamScreen())),
                child: Text(s.t('result_again')),
              ),
              TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: Text(s.t('result_home'))),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamReviewScreen extends StatelessWidget {
  final List<Question> questions;
  final Map<int, int> answers;
  const ExamReviewScreen({super.key, required this.questions, required this.answers});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final wrongIdx = [for (var k = 0; k < questions.length; k++) if (answers[k] != questions[k].correct) k];
    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        appBar: AppBar(title: Text(s.t('result_review'))),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: wrongIdx.length,
          separatorBuilder: (_, __) => const Divider(height: 32),
          itemBuilder: (_, n) {
            final k = wrongIdx[n];
            final q = questions[k];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${k + 1}. ${q.id}', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 6),
                QuestionCard(q: q, selected: answers[k], reveal: true, lang: st.lang, showTranslation: st.premium, onSelect: null),
                if ((q.explanation['de'] ?? '').isNotEmpty)
                  Text(q.explanationFor(st.premium ? st.lang : 'de'), style: const TextStyle(height: 1.35)),
              ],
            );
          },
        ),
      ),
    );
  }
}
