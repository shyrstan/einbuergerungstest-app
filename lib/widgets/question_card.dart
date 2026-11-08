import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import 'ltr_text.dart';

/// Renders question text, optional images and the four options.
/// [selected] is the user's pick, [reveal] shows right/wrong colouring.
class QuestionCard extends StatelessWidget {
  final Question q;
  final int? selected;
  final bool reveal;
  final ValueChanged<int>? onSelect;
  final String lang;
  final bool showTranslation;

  const QuestionCard({
    super.key,
    required this.q,
    required this.selected,
    required this.reveal,
    required this.onSelect,
    required this.lang,
    this.showTranslation = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = S(lang);
    final tr = showTranslation && lang != 'de' ? q.questionTr[lang] : null;
    final optTr = showTranslation && lang != 'de' ? q.optionsTr[lang] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LtrText(q.question, style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.3)),
        if (tr != null) ...[
          const SizedBox(height: 6),
          Text(tr, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.outline)),
        ],
        if (q.hasImages) ...[
          const SizedBox(height: 16),
          _Images(images: q.images, hint: (i) => s.t('image_hint', {'i': i})),
        ],
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++) _Option(
          index: i,
          text: q.options[i],
          translation: optTr != null && i < optTr.length ? optTr[i] : null,
          state: _stateFor(i),
          onTap: onSelect == null || reveal ? null : () => onSelect!(i),
        ),
      ],
    );
  }

  _OptState _stateFor(int i) {
    if (!reveal) return selected == i ? _OptState.selected : _OptState.idle;
    if (i == q.correct) return _OptState.correct;
    if (selected == i) return _OptState.wrong;
    return _OptState.idle;
  }
}

enum _OptState { idle, selected, correct, wrong }

class _Option extends StatelessWidget {
  final int index;
  final String text;
  final String? translation;
  final _OptState state;
  final VoidCallback? onTap;
  const _Option({required this.index, required this.text, required this.state, required this.onTap, this.translation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bg = cs.surfaceContainerHighest;
    Color border = Colors.transparent;
    IconData? icon;
    switch (state) {
      case _OptState.selected:
        border = cs.primary;
        bg = cs.primaryContainer.withValues(alpha: 0.5);
        break;
      case _OptState.correct:
        bg = const Color(0xFFDFF5E1);
        border = const Color(0xFF2E7D32);
        icon = Icons.check_circle;
        break;
      case _OptState.wrong:
        bg = const Color(0xFFFDE2E1);
        border = const Color(0xFFC62828);
        icon = Icons.cancel;
        break;
      case _OptState.idle:
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 2)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.surface,
                  child: Text(String.fromCharCode(65 + index), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LtrText(text, style: const TextStyle(fontSize: 16, height: 1.3)),
                      if (translation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(translation!, style: TextStyle(fontSize: 13, color: cs.outline)),
                        ),
                    ],
                  ),
                ),
                if (icon != null) Icon(icon, color: border),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Images extends StatelessWidget {
  final List<String> images;
  final String Function(int) hint;
  const _Images({required this.images, required this.hint});

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/images/${images.first}', fit: BoxFit.contain, height: 240),
      );
    }
    // 4 separate images: label 1..4
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.2,
      children: [
        for (var i = 0; i < images.length; i++)
          Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/images/${images[i]}', fit: BoxFit.contain),
                ),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              ),
            ],
          ),
      ],
    );
  }
}
