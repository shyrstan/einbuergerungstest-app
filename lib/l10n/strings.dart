import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/progress.dart';

/// Minimal JSON-backed localization. `S.of(context).t('key', {'n': 5})`.
class S {
  static Map<String, Map<String, String>> _tables = {};
  static Map<String, String> languages = {};

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/data/strings.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    languages = (j['_languages'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    _tables = {};
    j.forEach((lang, table) {
      if (lang.startsWith('_')) return;
      _tables[lang] = (table as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    });
  }

  final String lang;
  const S(this.lang);

  static S of(BuildContext context) => S(context.watch<AppState>().lang);
  static S read(BuildContext context) => S(context.read<AppState>().lang);

  String t(String key, [Map<String, Object>? args]) {
    var s = _tables[lang]?[key] ?? _tables['de']?[key] ?? key;
    args?.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  bool get isRtl => lang == 'ar';
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;
}
