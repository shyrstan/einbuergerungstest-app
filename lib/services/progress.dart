import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../exam/exam_config.dart';
import '../models/question.dart';

/// Per-question learning state (simple Leitner boxes 0..4).
class QState {
  int box; // 0 = new/wrong, 4 = mastered
  int seen;
  int right;
  int wrong;
  int lastSeen; // epoch ms
  QState({this.box = 0, this.seen = 0, this.right = 0, this.wrong = 0, this.lastSeen = 0});

  Map<String, dynamic> toJson() => {'b': box, 's': seen, 'r': right, 'w': wrong, 'l': lastSeen};
  factory QState.fromJson(Map<String, dynamic> j) => QState(
        box: j['b'] ?? 0,
        seen: j['s'] ?? 0,
        right: j['r'] ?? 0,
        wrong: j['w'] ?? 0,
        lastSeen: j['l'] ?? 0,
      );
}

class ExamResult {
  final int ts;
  final int correct;
  final int total;
  final int seconds;
  final List<String> wrongIds;
  ExamResult(this.ts, this.correct, this.total, this.seconds, this.wrongIds);
  bool get passed => correct >= ExamConfig.current.passMark;
  Map<String, dynamic> toJson() => {'t': ts, 'c': correct, 'n': total, 's': seconds, 'w': wrongIds};
  factory ExamResult.fromJson(Map<String, dynamic> j) => ExamResult(
      j['t'], j['c'], j['n'], j['s'] ?? 0, (j['w'] as List? ?? []).map((e) => e as String).toList());
}

class AppState extends ChangeNotifier {
  static const _kLand = 'land';
  static const _kLang = 'lang';
  static const _kProgress = 'progress_v1';
  static const _kExams = 'exams_v1';
  static const _kPremium = 'premium';
  static const _kOnboarded = 'onboarded';
  static const _kAnswered = 'answered_count';
  static const _kExamDay = 'exam_day';
  static const _kExamsToday = 'exams_today';

  /// Free users get this many practice exams per day; more cost a rewarded ad.
  static const freeExamsPerDay = 1;

  /// At most this many extra exams per day can be unlocked with videos, so that
  /// rewarded ads do not replace Premium in the week before the exam.
  static const adExamsPerDay = 2;

  SharedPreferences? _p;
  List<Question> _all = const [];
  final Map<String, QState> _state = {};
  List<ExamResult> _exams = [];

  /// DE: federal state; FR: CSP / CR / NAT. Stored under the historic key 'land'.
  String? land;
  String lang = ExamConfig.current.baseLang;
  bool premium = false;
  bool onboarded = false;
  int answeredCount = 0; // drives interstitial frequency

  List<Question> get all => _all;
  Map<String, QState> get stateMap => _state;
  List<ExamResult> get exams => List.unmodifiable(_exams);

  Future<void> init(List<Question> questions) async {
    _all = questions;
    _p = await SharedPreferences.getInstance();
    land = _p!.getString(_kLand);
    lang = _p!.getString(_kLang) ?? ExamConfig.current.baseLang;
    if (!ExamConfig.current.langs.contains(lang)) lang = ExamConfig.current.baseLang;
    premium = _p!.getBool(_kPremium) ?? false;
    onboarded = _p!.getBool(_kOnboarded) ?? false;
    answeredCount = _p!.getInt(_kAnswered) ?? 0;
    final raw = _p!.getString(_kProgress);
    if (raw != null) {
      (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) => _state[k] = QState.fromJson(v));
    }
    final rawEx = _p!.getString(_kExams);
    if (rawEx != null) {
      _exams = (jsonDecode(rawEx) as List).map((e) => ExamResult.fromJson(e)).toList();
    }
    notifyListeners();
  }

  // ---------- settings ----------
  Future<void> setLand(String code) async {
    land = code;
    await _p?.setString(_kLand, code);
    notifyListeners();
  }

  Future<void> setLang(String code) async {
    lang = code;
    await _p?.setString(_kLang, code);
    notifyListeners();
  }

  Future<void> setPremium(bool v) async {
    premium = v;
    await _p?.setBool(_kPremium, v);
    notifyListeners();
  }

  // ---------- daily exam allowance ----------
  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int get examsStartedToday => _p?.getString(_kExamDay) == _today() ? (_p?.getInt(_kExamsToday) ?? 0) : 0;

  /// True when the next exam can start without a rewarded ad.
  bool get canStartExamFree => premium || examsStartedToday < freeExamsPerDay;

  /// True when one more exam can still be unlocked today with a rewarded ad.
  bool get canStartExamWithAd => examsStartedToday < freeExamsPerDay + adExamsPerDay;

  Future<void> markExamStarted() async {
    final n = examsStartedToday + 1;
    await _p?.setString(_kExamDay, _today());
    await _p?.setInt(_kExamsToday, n);
    notifyListeners();
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    await _p?.setBool(_kOnboarded, true);
    notifyListeners();
  }

  // ---------- question sets ----------
  ExamConfig get exam => ExamConfig.current;

  /// Main pool: DE 300 general questions; FR official questions of the chosen permit.
  List<Question> get general => exam.mainPool(_all, land);

  /// Second pool: DE 10 questions of the state; FR situational questions.
  List<Question> get landQuestions => exam.specialPool(_all, land);

  /// All questions relevant for the user's exam.
  List<Question> get relevant => exam.relevant(_all, land);

  List<Question> byTopic(String topic) => exam.byTopic(_all, topic, land);

  QState stateOf(String id) => _state[id] ??= QState();

  List<Question> get wrongOnes {
    final r = relevant.where((q) {
      final s = _state[q.id];
      return s != null && s.wrong > 0 && s.box < 3;
    }).toList();
    return r;
  }

  List<Question> get unseen => relevant.where((q) => (_state[q.id]?.seen ?? 0) == 0).toList();

  int masteredCount() => relevant.where((q) => (_state[q.id]?.box ?? 0) >= 3).length;

  /// Smart practice order: due/wrong first, then unseen, then the rest by lowest box.
  List<Question> smartQueue(List<Question> pool, {int limit = 20}) {
    final rnd = Random();
    final scored = pool.map((q) {
      final s = _state[q.id];
      double score;
      if (s == null || s.seen == 0) {
        score = 1.0;
      } else if (s.box == 0) {
        score = 0.0;
      } else {
        score = 1.5 + s.box; // higher box -> later
      }
      return MapEntry(q, score + rnd.nextDouble() * 0.5);
    }).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  /// A random exam with the official composition of the current exam.
  List<Question> buildExam() => exam.buildExam(_all, land, Random());

  // ---------- recording ----------
  Future<void> recordAnswer(Question q, bool correct) async {
    final s = stateOf(q.id);
    s.seen++;
    s.lastSeen = DateTime.now().millisecondsSinceEpoch;
    if (correct) {
      s.right++;
      s.box = min(4, s.box + 1);
    } else {
      s.wrong++;
      s.box = 0;
    }
    answeredCount++;
    await _p?.setInt(_kAnswered, answeredCount);
    await _save();
    notifyListeners();
  }

  Future<void> recordExam(ExamResult r) async {
    _exams.insert(0, r);
    if (_exams.length > 50) _exams = _exams.sublist(0, 50);
    await _p?.setString(_kExams, jsonEncode(_exams.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> resetProgress() async {
    _state.clear();
    _exams.clear();
    answeredCount = 0;
    await _p?.remove(_kProgress);
    await _p?.remove(_kExams);
    await _p?.setInt(_kAnswered, 0);
    notifyListeners();
  }

  Future<void> _save() async {
    final m = <String, dynamic>{};
    _state.forEach((k, v) => m[k] = v.toJson());
    await _p?.setString(_kProgress, jsonEncode(m));
  }
}
