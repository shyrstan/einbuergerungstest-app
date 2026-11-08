import 'package:flutter/material.dart';

/// German (or other left-to-right) content shown inside a possibly RTL UI.
/// Keeps punctuation at the end of the sentence and aligns the block with
/// the surrounding UI.
class LtrText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const LtrText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Text(text,
        style: style,
        textDirection: TextDirection.ltr,
        textAlign: rtl ? TextAlign.right : TextAlign.left);
  }
}
