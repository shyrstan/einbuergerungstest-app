class Question {
  final String id; // G001 .. G300, BW01 .. TH10
  final int num; // 1..300 general, 1..10 per Land
  final String? land; // DE only: null for general, else BW/BY/BE/...
  /// Segments this question belongs to (DE: its state; FR: CSP/CR/NAT). null = every segment.
  final List<String>? segments;
  final String kind; // 'official' | 'situation'
  final String topic; // grundrechte, demokratie, ..., bundesland
  final String field; // demokratie | geschichte | gesellschaft | bundesland
  final String question;
  final List<String> options; // exactly 4, official order
  final int correct; // 0..3
  final List<String> images; // asset file names, 0, 1 or 4
  final Map<String, String> explanation; // lang -> text (de always present)
  final Map<String, String> questionTr; // lang -> translated question (optional)
  final Map<String, List<String>> optionsTr; // lang -> translated options (optional)

  const Question({
    required this.id,
    required this.num,
    required this.land,
    required this.segments,
    this.kind = 'official',
    required this.topic,
    required this.field,
    required this.question,
    required this.options,
    required this.correct,
    required this.images,
    required this.explanation,
    required this.questionTr,
    required this.optionsTr,
  });

  bool get isGeneral => segments == null;
  bool get hasImages => images.isNotEmpty;

  factory Question.fromJson(Map<String, dynamic> j) {
    final expl = <String, String>{};
    (j['explanation'] as Map<String, dynamic>? ?? {}).forEach((k, v) => expl[k] = v as String);
    final qtr = <String, String>{};
    (j['question_tr'] as Map<String, dynamic>? ?? {}).forEach((k, v) => qtr[k] = v as String);
    final otr = <String, List<String>>{};
    (j['options_tr'] as Map<String, dynamic>? ?? {})
        .forEach((k, v) => otr[k] = (v as List).map((e) => e as String).toList());
    return Question(
      id: j['id'] as String,
      num: j['num'] as int,
      land: j['land'] as String?,
      segments: (j['segments'] as List?)?.map((e) => e as String).toList() ??
          (j['land'] == null ? null : [j['land'] as String]),
      kind: (j['kind'] as String?) ?? 'official',
      topic: (j['topic'] as String?) ?? (j['land'] == null ? 'sonstiges' : 'bundesland'),
      field: (j['field'] as String?) ?? (j['land'] == null ? 'demokratie' : 'bundesland'),
      question: j['question'] as String,
      options: (j['options'] as List).map((e) => e as String).toList(),
      correct: j['correct'] as int,
      images: (j['images'] as List? ?? []).map((e) => e as String).toList(),
      explanation: expl,
      questionTr: qtr,
      optionsTr: otr,
    );
  }

  /// Explanation in [lang], falling back to the exam's own language.
  String explanationFor(String lang, String baseLang) => explanation[lang] ?? explanation[baseLang] ?? '';
}
