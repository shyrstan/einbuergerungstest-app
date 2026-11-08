import 'dart:math';

import 'package:flutter/services.dart' show appFlavor;

import '../l10n/strings.dart';
import '../models/question.dart';

/// A selectable sub-group of the exam: a German federal state (DE) or the
/// permit the candidate applies for (FR: CSP / CR / NAT).
class SegmentInfo {
  final String code;
  final String? fixedName; // shown as is (German state names)
  const SegmentInfo(this.code, [this.fixedName]);
  String name(S s) => fixedName ?? s.t('seg_$code');
}

/// Everything that differs between the exams lives here; screens and services
/// only talk to [ExamConfig.current].
abstract class ExamConfig {
  static late ExamConfig current;

  /// Picks the exam from the Android build flavor (`--flavor de|fr`).
  static ExamConfig fromFlavor([String? flavor]) {
    final f = flavor ?? appFlavor ?? const String.fromEnvironment('EXAM', defaultValue: 'de');
    return f == 'fr' ? FrExam() : DeExam();
  }

  String get id;
  String get baseLang; // language of the exam itself
  List<String> get langs; // UI / explanation languages, base first
  String get questionsAsset => 'assets/$id/questions.json';
  String get stringsAsset => 'assets/$id/strings.json';
  String get defaultPrivacyUrl;
  String get defaultImprintUrl;

  List<SegmentInfo> get segments;
  List<String> get topicOrder;
  int get examSize;
  int get passMark;
  Duration get examDuration;

  /// Main pool ("all questions" tile) for the chosen segment.
  List<Question> mainPool(List<Question> all, String? seg);

  /// Second tile on the home screen (state questions / situations).
  List<Question> specialPool(List<Question> all, String? seg);
  String specialTitle(S s, String? seg);

  List<Question> relevant(List<Question> all, String? seg) => [...mainPool(all, seg), ...specialPool(all, seg)];

  List<Question> byTopic(List<Question> all, String topic, String? seg) =>
      relevant(all, seg).where((q) => q.topic == topic).toList();

  List<Question> buildExam(List<Question> all, String? seg, Random rnd);

  String segmentName(S s, String? seg) {
    for (final x in segments) {
      if (x.code == seg) return x.name(s);
    }
    return '';
  }
}

// ---------------------------------------------------------------- Germany --

class DeExam extends ExamConfig {
  @override
  String get id => 'de';
  @override
  String get baseLang => 'de';
  @override
  List<String> get langs => const ['de', 'en', 'tr', 'ar', 'ru', 'uk'];
  @override
  String get defaultPrivacyUrl => 'https://shyrstan.github.io/einbtest-legal/privacy.html';
  @override
  String get defaultImprintUrl => 'https://shyrstan.github.io/einbtest-legal/imprint.html';

  @override
  List<SegmentInfo> get segments => const [
        SegmentInfo('BW', 'Baden-Württemberg'),
        SegmentInfo('BY', 'Bayern'),
        SegmentInfo('BE', 'Berlin'),
        SegmentInfo('BB', 'Brandenburg'),
        SegmentInfo('HB', 'Bremen'),
        SegmentInfo('HH', 'Hamburg'),
        SegmentInfo('HE', 'Hessen'),
        SegmentInfo('MV', 'Mecklenburg-Vorpommern'),
        SegmentInfo('NI', 'Niedersachsen'),
        SegmentInfo('NW', 'Nordrhein-Westfalen'),
        SegmentInfo('RP', 'Rheinland-Pfalz'),
        SegmentInfo('SL', 'Saarland'),
        SegmentInfo('SN', 'Sachsen'),
        SegmentInfo('ST', 'Sachsen-Anhalt'),
        SegmentInfo('SH', 'Schleswig-Holstein'),
        SegmentInfo('TH', 'Thüringen'),
      ];

  @override
  List<String> get topicOrder => const [
        'grundrechte', 'demokratie', 'staatsorgane', 'foederalismus', 'rechtsstaat', 'parteien',
        'sozialstaat', 'ns_zeit', 'nachkrieg_ddr', 'europa', 'familie', 'alltag',
        'religion_kultur', 'migration', 'symbole', 'bundesland',
      ];

  @override
  int get examSize => 33;
  @override
  int get passMark => 17;
  @override
  Duration get examDuration => const Duration(minutes: 60);

  @override
  List<Question> mainPool(List<Question> all, String? seg) => all.where((q) => q.segments == null).toList();

  @override
  List<Question> specialPool(List<Question> all, String? seg) =>
      seg == null ? const [] : all.where((q) => q.segments?.contains(seg) ?? false).toList();

  @override
  String specialTitle(S s, String? seg) => s.t('menu_land', {'land': segmentName(s, seg)});

  @override
  List<Question> byTopic(List<Question> all, String topic, String? seg) =>
      topic == 'bundesland' ? specialPool(all, seg) : mainPool(all, seg).where((q) => q.topic == topic).toList();

  /// 33 questions = 30 general + 3 from the user's state; 60 minutes; pass at 17.
  @override
  List<Question> buildExam(List<Question> all, String? seg, Random rnd) {
    final g = [...mainPool(all, seg)]..shuffle(rnd);
    final l = [...specialPool(all, seg)]..shuffle(rnd);
    return [...g.take(30), ...l.take(3)]..shuffle(rnd);
  }
}

// ----------------------------------------------------------------- France --

class FrExam extends ExamConfig {
  @override
  String get id => 'fr';
  @override
  String get baseLang => 'fr';
  @override
  List<String> get langs => const ['fr', 'ar', 'en', 'tr', 'ru', 'uk', 'pt', 'zh'];
  @override
  String get defaultPrivacyUrl => 'https://shyrstan.github.io/einbtest-legal/fr/privacy.html';
  @override
  String get defaultImprintUrl => 'https://shyrstan.github.io/einbtest-legal/fr/imprint.html';

  @override
  List<SegmentInfo> get segments => const [SegmentInfo('CSP'), SegmentInfo('CR'), SegmentInfo('NAT')];

  /// Knowledge themes, then the two groups of situational questions.
  @override
  List<String> get topicOrder =>
      const ['principes', 'institutions', 'droits', 'histoire', 'societe', 'sit_principes', 'sit_droits'];

  /// Questions per theme in the real exam (arrêté du 10 octobre 2025):
  /// 28 knowledge questions + 12 situations = 40.
  static const knowledgePerTheme = {'principes': 5, 'institutions': 6, 'droits': 5, 'histoire': 8, 'societe': 4};
  static const situationsPerTheme = {'sit_principes': 6, 'sit_droits': 6};

  @override
  int get examSize => 40;
  @override
  int get passMark => 32;
  @override
  Duration get examDuration => const Duration(minutes: 45);

  @override
  List<Question> mainPool(List<Question> all, String? seg) =>
      all.where((q) => q.kind == 'official' && (seg == null || (q.segments?.contains(seg) ?? false))).toList();

  @override
  List<Question> specialPool(List<Question> all, String? seg) => all.where((q) => q.kind == 'situation').toList();

  @override
  String specialTitle(S s, String? seg) => s.t('menu_situations');

  @override
  List<Question> buildExam(List<Question> all, String? seg, Random rnd) {
    final main = mainPool(all, seg);
    final sit = specialPool(all, seg);
    final out = <Question>[];
    knowledgePerTheme.forEach((t, n) => out.addAll((main.where((q) => q.topic == t).toList()..shuffle(rnd)).take(n)));
    situationsPerTheme.forEach((t, n) => out.addAll((sit.where((q) => q.topic == t).toList()..shuffle(rnd)).take(n)));
    return out..shuffle(rnd);
  }
}
