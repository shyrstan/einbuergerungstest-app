import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../exam/exam_config.dart';
import '../services/progress.dart';

/// Minimal JSON-backed localization. `S.of(context).t('key', {'n': 5})`.
///
/// Shared engine strings live in assets/data/strings.json; each exam can
/// override or add keys in assets/<exam>/strings.json.
class S {
  static Map<String, Map<String, String>> _tables = {};

  /// Languages offered by the current exam, in display order (code -> native name).
  static Map<String, String> languages = {};
  static String _base = 'de';

  static Future<void> load([ExamConfig? exam]) async {
    final ex = exam ?? ExamConfig.current;
    _base = ex.baseLang;
    final shared = jsonDecode(await rootBundle.loadString('assets/data/strings.json')) as Map<String, dynamic>;
    Map<String, dynamic> own = {};
    try {
      own = jsonDecode(await rootBundle.loadString(ex.stringsAsset)) as Map<String, dynamic>;
    } catch (_) {}
    final names = (shared['_languages'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    languages = {for (final l in ex.langs) if (names.containsKey(l)) l: names[l]!};
    _tables = {};
    for (final src in [shared, own]) {
      src.forEach((lang, table) {
        if (lang.startsWith('_')) return;
        final t = _tables.putIfAbsent(lang, () => {});
        (table as Map<String, dynamic>).forEach((k, v) => t[k] = v as String);
      });
    }
  }

  final String lang;
  const S(this.lang);

  static S of(BuildContext context) => S(context.watch<AppState>().lang);
  static S read(BuildContext context) => S(context.read<AppState>().lang);

  String t(String key, [Map<String, Object>? args]) {
    var s = _tables[lang]?[key] ?? _tables['en']?[key] ?? _tables[_base]?[key] ?? key;
    args?.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  bool get isRtl => lang == 'ar';
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;
}
