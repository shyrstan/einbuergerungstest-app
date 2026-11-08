// Renders Google Play store screenshots (1080x1920) and feature graphics (1024x500)
// for every listing language of one exam. Run in CI: see .github/workflows/screenshots.yml
//   flutter test --dart-define=EXAM=de|fr tool/screenshots/store_screenshots_test.dart
// Output: store_out/<exam>/<play-locale>/{phoneScreenshots/*.png, featureGraphic.png}
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:einbtest/exam/exam_config.dart';
import 'package:einbtest/l10n/strings.dart';
import 'package:einbtest/models/question.dart';
import 'package:einbtest/screens/exam.dart';
import 'package:einbtest/screens/home.dart';
import 'package:einbtest/screens/practice.dart';
import 'package:einbtest/screens/topics.dart';
import 'package:einbtest/services/iap.dart';
import 'package:einbtest/services/progress.dart';
import 'package:einbtest/theme.dart';
import 'package:einbtest/widgets/question_card.dart';

const kFont = 'Roboto';
const kFallback = ['NotoSansArabic', 'NotoSansSC'];
const appW = 411.0;
const appH = 860.0;
const phoneScale = 0.86;

/// Per-exam store data: language -> Play locale, captions of the 6 screenshots, feature-graphic text.
class StoreData {
  final Map<String, String> locales;
  final Map<String, List<String>> captions;
  final Map<String, String> taglines;
  final String title;
  final String segment; // segment shown in the screenshots
  const StoreData(this.locales, this.captions, this.taglines, this.title, this.segment);
}

const deStore = StoreData(
  {'de': 'de-DE', 'en': 'en-US', 'tr': 'tr-TR', 'ar': 'ar', 'ru': 'ru-RU', 'uk': 'uk'},
  {
    'de': [
      'Alle 310 Prüfungsfragen für dein Bundesland',
      'Jede Frage erklärt – auch in deiner Sprache',
      'Alle Bildfragen: Wappen, Karten, Symbole',
      'Prüfungssimulation: 33 Fragen, 60 Minuten',
      'Teste dich vor dem echten Termin',
      'Lernen nach Themen – mit Fortschritt',
    ],
    'en': [
      'All 310 exam questions for your federal state',
      'Every question explained – in your language',
      'All picture questions: coats of arms, maps, symbols',
      'Exam simulation: 33 questions, 60 minutes',
      'Test yourself before the real exam',
      'Learn by topic and track your progress',
    ],
    'tr': [
      'Eyaletin için 310 sınav sorusunun tamamı',
      'Her soru açıklamalı – kendi dilinde',
      'Tüm resimli sorular: armalar, haritalar, semboller',
      'Sınav simülasyonu: 33 soru, 60 dakika',
      'Gerçek sınavdan önce kendini test et',
      'Konulara göre öğren, ilerlemeni gör',
    ],
    'ar': [
      'جميع أسئلة الامتحان الـ310 لولايتك',
      'كل سؤال مع شرح – بلغتك',
      'كل الأسئلة المصوّرة: الشعارات والخرائط والرموز',
      'محاكاة الامتحان: 33 سؤالاً في 60 دقيقة',
      'اختبر نفسك قبل الامتحان الحقيقي',
      'تعلّم حسب الموضوع وتابع تقدّمك',
    ],
    'ru': [
      'Все 310 экзаменационных вопросов для твоей земли',
      'Каждый вопрос с объяснением — на твоём языке',
      'Все вопросы с картинками: гербы, карты, символы',
      'Симуляция экзамена: 33 вопроса, 60 минут',
      'Проверь себя до настоящего экзамена',
      'Учись по темам и следи за прогрессом',
    ],
    'uk': [
      'Усі 310 запитань іспиту для твоєї землі',
      'Кожне запитання з поясненням — твоєю мовою',
      'Усі запитання з малюнками: герби, мапи, символи',
      'Симуляція іспиту: 33 запитання, 60 хвилин',
      'Перевір себе до справжнього іспиту',
      'Навчайся за темами й стеж за прогресом',
    ],
  },
  {
    'de': 'Alle 310 Fragen · Prüfungssimulation · Erklärungen in 6 Sprachen',
    'en': 'All 310 questions · Exam simulation · Explanations in 6 languages',
    'tr': '310 sorunun tamamı · Sınav simülasyonu · 6 dilde açıklama',
    'ar': 'جميع الأسئلة الـ310 · محاكاة الامتحان · شروحات\u00a0بـ6\u00a0لغات',
    'ru': 'Все 310 вопросов · Симуляция экзамена · Объяснения на 6 языках',
    'uk': 'Усі 310 запитань · Симуляція іспиту · Пояснення 6 мовами',
  },
  'Einbürgerungstest\n2026',
  'BE',
);

const frStore = StoreData(
  {'fr': 'fr-FR', 'en': 'en-US', 'ar': 'ar', 'tr': 'tr-TR', 'ru': 'ru-RU', 'uk': 'uk', 'pt': 'pt-PT', 'zh': 'zh-CN'},
  {
    'fr': [
      'Toutes les questions officielles de votre examen',
      'Chaque réponse expliquée – aussi dans votre langue',
      'Des mises en situation, comme le jour J',
      'Examen blanc : 40 questions, 45 minutes',
      'Testez-vous avant l’examen officiel',
      'Révisez par thème et suivez vos progrès',
    ],
    'en': [
      'All official questions for your exam',
      'Every answer explained – in your language too',
      'Situational questions, just like on exam day',
      'Mock exam: 40 questions, 45 minutes',
      'Test yourself before the real exam',
      'Study by topic and track your progress',
    ],
    'ar': [
      'جميع الأسئلة الرسمية لامتحانك',
      'كل إجابة مع شرح – بلغتك أيضاً',
      'أسئلة مواقف كما في يوم الامتحان',
      'امتحان تجريبي: 40 سؤالاً في 45 دقيقة',
      'اختبر نفسك قبل الامتحان الرسمي',
      'راجع حسب الموضوع وتابع تقدّمك',
    ],
    'tr': [
      'Sınavın için tüm resmi sorular',
      'Her cevap açıklamalı – kendi dilinde de',
      'Sınav günündeki gibi durum soruları',
      'Deneme sınavı: 40 soru, 45 dakika',
      'Resmi sınavdan önce kendini test et',
      'Konulara göre çalış, ilerlemeni gör',
    ],
    'ru': [
      'Все официальные вопросы твоего экзамена',
      'Каждый ответ с объяснением — и на твоём языке',
      'Ситуационные вопросы, как на экзамене',
      'Пробный экзамен: 40 вопросов, 45 минут',
      'Проверь себя до настоящего экзамена',
      'Учись по темам и следи за прогрессом',
    ],
    'uk': [
      'Усі офіційні запитання твого іспиту',
      'Кожна відповідь з поясненням — і твоєю мовою',
      'Ситуаційні запитання, як на іспиті',
      'Пробний іспит: 40 запитань, 45 хвилин',
      'Перевір себе до справжнього іспиту',
      'Навчайся за темами й стеж за прогресом',
    ],
    'pt': [
      'Todas as perguntas oficiais do seu exame',
      'Cada resposta explicada – também no seu idioma',
      'Perguntas de situação, como no dia do exame',
      'Simulação: 40 perguntas, 45 minutos',
      'Teste-se antes do exame oficial',
      'Estude por tema e acompanhe o progresso',
    ],
    'zh': [
      '你的考试的全部官方题目',
      '每个答案都有解释，也有你的语言',
      '情景题，和考试当天一样',
      '模拟考试：40 题，45 分钟',
      '正式考试前先测试自己',
      '按主题复习，查看学习进度',
    ],
  },
  {
    'fr': 'Questions officielles · Examen blanc · Explications en 8 langues',
    'en': 'Official questions · Mock exam · Explanations in 8 languages',
    'ar': 'الأسئلة الرسمية · امتحان تجريبي · شروحات\u00a0بـ8\u00a0لغات',
    'tr': 'Resmi sorular · Deneme sınavı · 8 dilde açıklama',
    'ru': 'Официальные вопросы · Пробный экзамен · Объяснения на 8 языках',
    'uk': 'Офіційні запитання · Пробний іспит · Пояснення 8 мовами',
    'pt': 'Perguntas oficiais · Simulação · Explicações em 8 idiomas',
    'zh': '官方题目 · 模拟考试 · 8 种语言解释',
  },
  'Examen civique\n2026',
  'NAT',
);

late ExamConfig exam;
late StoreData store;

late List<Question> questions;
final shotKey = GlobalKey();

Future<void> loadFonts() async {
  // Everything declared in the font manifest (MaterialIcons).
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final fam in manifest) {
    final loader = FontLoader(fam['family'] as String);
    for (final f in fam['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(f['asset'] as String));
    }
    await loader.load();
  }
  // Roboto + Arabic fallback, collected by the CI step into tool/screenshots/fonts.
  final roboto = FontLoader(kFont);
  final arabic = FontLoader(kFallback.first);
  final chinese = FontLoader(kFallback[1]);
  var nR = 0, nA = 0, nC = 0;
  for (final f in Directory('tool/screenshots/fonts').listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last.toLowerCase();
    final data = Future.value(ByteData.view(Uint8List.fromList(f.readAsBytesSync()).buffer));
    if (name.contains('arabic')) {
      arabic.addFont(data);
      nA++;
    } else if (name.contains('notosanssc') || name.contains('cjk')) {
      chinese.addFont(data);
      nC++;
    } else if (name.startsWith('roboto') &&
        !['condensed', 'mono', 'slab', 'flex', 'serif'].any(name.contains)) {
      roboto.addFont(data);
      nR++;
    }
  }
  print('fonts loaded: roboto=$nR arabic=$nA chinese=$nC');
  if (nR == 0) throw StateError('No Roboto font files in tool/screenshots/fonts');
  await roboto.load();
  if (nA > 0) await arabic.load();
  if (nC > 0) await chinese.load();
}

Question byId(String id) => questions.firstWhere((q) => q.id == id);

Map<String, dynamic> fakeProgress() {
  final rel = exam.relevant(questions, store.segment);
  final m = <String, dynamic>{};
  for (var i = 0; i < rel.length; i++) {
    final r = i % 50;
    if (r < 41) {
      m[rel[i].id] = {'b': 3, 's': 3, 'r': 3, 'w': 0, 'l': 0};
    } else if (r < 45) {
      m[rel[i].id] = {'b': 0, 's': 2, 'r': 1, 'w': 1, 'l': 0};
    }
  }
  return m;
}

Future<AppState> makeState(String lang) async {
  final now = DateTime(2026, 11, 8, 18).millisecondsSinceEpoch;
  SharedPreferences.setMockInitialValues({
    'land': store.segment,
    'lang': lang,
    'premium': true, // no ads in store screenshots
    'onboarded': true,
    'answered_count': 1240,
    'progress_v1': jsonEncode(fakeProgress()),
    'exams_v1': jsonEncode([
      {'t': now, 'c': exam.examSize - 3, 'n': exam.examSize, 's': 1560, 'w': <String>[]},
      {'t': now - 86400000, 'c': exam.passMark + 1, 'n': exam.examSize, 's': 1820, 'w': <String>[]},
      {'t': now - 3 * 86400000, 'c': exam.passMark - 3, 'n': exam.examSize, 's': 2240, 'w': <String>[]},
      {'t': now - 6 * 86400000, 'c': exam.passMark - 8, 'n': exam.examSize, 's': 2400, 'w': <String>[]},
    ]),
  });
  final st = AppState();
  await st.init(questions);
  return st;
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: kFont, fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1B1B1F));
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Text('9:41', style: style),
          Spacer(),
          Icon(Icons.signal_cellular_alt, size: 15, color: Color(0xFF1B1B1F)),
          SizedBox(width: 4),
          Icon(Icons.wifi, size: 15, color: Color(0xFF1B1B1F)),
          SizedBox(width: 4),
          Icon(Icons.battery_full, size: 15, color: Color(0xFF1B1B1F)),
        ]),
      ),
    );
  }
}

Widget innerApp(AppState st, Widget home) {
  return MediaQuery(
    data: const MediaQueryData(
      size: Size(appW, appH),
      devicePixelRatio: 3,
      padding: EdgeInsets.only(top: 28),
      viewPadding: EdgeInsets.only(top: 28),
      textScaler: TextScaler.noScaling,
    ),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: st),
        Provider<IapService>.value(value: IapService(st)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(fontFamily: kFont, fontFamilyFallback: kFallback),
        locale: Locale(st.lang),
        supportedLocales: [for (final l in exam.langs) Locale(l)],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
}

Widget phone(Widget app) {
  return Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: const Color(0xFF111318),
      borderRadius: BorderRadius.circular(40),
      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 12))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        width: appW * phoneScale,
        height: appH * phoneScale,
        child: FittedBox(
          child: SizedBox(
            width: appW,
            height: appH,
            child: Stack(fit: StackFit.expand, children: [
              app,
              const Positioned(left: 0, right: 0, top: 0, height: 28, child: _StatusBar()),
            ]),
          ),
        ),
      ),
    ),
  );
}

Widget storeFrame({required String caption, required bool rtl, required Widget app}) {
  const style = TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFallback,
    color: Colors.white,
    fontSize: 31,
    fontWeight: FontWeight.w700,
    height: 1.2,
    decoration: TextDecoration.none,
  );
  return Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: RepaintBoundary(
      key: shotKey,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F3A5F), Color(0xFF3A6EA5)],
          ),
        ),
        child: Column(children: [
          SizedBox(
            height: 172,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 24, 30, 6),
                child: Text(caption, textAlign: TextAlign.center, maxLines: 3, style: style),
              ),
            ),
          ),
          Expanded(child: Align(alignment: Alignment.topCenter, child: phone(app))),
          const SizedBox(height: 14),
        ]),
      ),
    ),
  );
}

Widget featureGraphic({required String tagline, required bool rtl, required Uint8List icon}) {
  return Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: RepaintBoundary(
      key: shotKey,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F3A5F), Color(0xFF3A6EA5)],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 64),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(56),
            child: Image.memory(icon, width: 280, height: 280),
          ),
          const SizedBox(width: 48),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.title,
                    style: const TextStyle(
                        fontFamily: kFont,
                        fontSize: 62,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        decoration: TextDecoration.none)),
                const SizedBox(height: 22),
                Text(tagline,
                    style: const TextStyle(
                        fontFamily: kFont,
                        fontFamilyFallback: kFallback,
                        fontSize: 27,
                        height: 1.3,
                        color: Color(0xFFDCE6F2),
                        decoration: TextDecoration.none)),
              ],
            ),
          ),
        ]),
      ),
    ),
  );
}

Future<void> precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final el in find.byType(Image).evaluate()) {
      final w = el.widget as Image;
      await precacheImage(w.image, el);
    }
  });
  await tester.pump();
}

Future<void> capture(WidgetTester tester, String path, {double pixelRatio = 2}) async {
  await tester.runAsync(() async {
    final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  print('wrote $path');
}

void reportException(WidgetTester tester, String where) {
  final e = tester.takeException();
  if (e != null) print('EXCEPTION at $where: $e');
}

Finder optionText(String text) =>
    find.descendant(of: find.byType(QuestionCard), matching: find.text(text)).first;

List<Question> examQuestions() {
  if (exam.id == 'de') {
    final first = ['G003', 'G012', 'G017', 'G031', 'G044', 'G061', 'G096', 'G022'];
    final ids = <String>[...first];
    for (final q in questions) {
      if (ids.length >= 30) break;
      if (q.segments == null && q.images.isEmpty && !ids.contains(q.id) && q.num % 9 == 0) ids.add(q.id);
    }
    ids.addAll(['BE07', 'BE03', 'BE09']);
    return ids.map(byId).toList();
  }
  // FR: a fixed random exam, short questions first so the screen looks tidy
  final list = exam.buildExam(questions, store.segment, Random(7));
  list.sort((a, b) => a.question.length.compareTo(b.question.length));
  return list;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    exam = ExamConfig.fromFlavor();
    ExamConfig.current = exam;
    store = exam.id == 'fr' ? frStore : deStore;
    await loadFonts();
    await S.load(exam);
    final raw = await rootBundle.loadString(exam.questionsAsset);
    questions = (jsonDecode(raw) as List).map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
  });

  for (final lang in (const String.fromEnvironment('EXAM') == 'fr' ? frStore : deStore).locales.keys) {
    testWidgets('store screenshots $lang', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final st = (await tester.runAsync(() => makeState(lang)))!;
      final s = S(lang);
      final rtl = lang == 'ar';
      final cap = store.captions[lang]!;
      final dir = 'store_out/${exam.id}/${store.locales[lang]}';

      Future<void> shot(int n, Widget home, {Future<void> Function()? act}) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(KeyedSubtree(
          key: ValueKey('$lang-$n'),
          child: storeFrame(caption: cap[n - 1], rtl: rtl, app: innerApp(st, home)),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        reportException(tester, '$lang/$n build');
        if (act != null) await act();
        await precacheImages(tester);
        await tester.pump(const Duration(milliseconds: 300));
        reportException(tester, '$lang/$n act');
        await capture(tester, '$dir/phoneScreenshots/0${n}_${lang}.png');
      }

      // 1. Home with progress
      await shot(1, const HomeScreen());

      Future<void> answerAndScroll(Question q, double dy) async {
        await precacheImages(tester);
        await tester.tap(optionText(q.options[q.correct]));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(s.t('check')));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(find.byType(Scrollable).first, Offset(0, dy));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
      }

      // Scrolls just enough to show the explanation, but never past the top padding,
      // so the first line of the question is not cut off (translations make cards taller).
      Future<void> answerAndReveal(Question q) async {
        await precacheImages(tester);
        await tester.tap(optionText(q.options[q.correct]));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(s.t('check')));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        pos.jumpTo(min(pos.maxScrollExtent, 12.0));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
      }

      List<Question> poolStartingWith(Question q, Iterable<Question> rest) =>
          [q, ...rest.where((x) => x.id != q.id).take(19)];

      if (exam.id == 'de') {
        // 2. Practice: answered correctly, explanation visible
        final q1 = byId('G001');
        await shot(2, PracticeScreen(title: s.t('topic_grundrechte'), pool: poolStartingWith(q1, questions.where((q) => q.topic == q1.topic)), smart: false, shuffle: false),
            act: () => answerAndScroll(q1, -210));
        // 3. Picture question (coat of arms of Berlin)
        final q2 = byId('BE01');
        await shot(3, PracticeScreen(title: 'Berlin', pool: poolStartingWith(q2, exam.specialPool(questions, 'BE')), smart: false, shuffle: false),
            act: () => answerAndScroll(q2, -150));
      } else {
        // 2. Official question answered, explanation (and translation) visible
        // Short items so question, answers and both explanations fit on one screen in every language.
        final q1 = byId('F377');
        await shot(2, PracticeScreen(title: s.t('topic_principes'), pool: poolStartingWith(q1, exam.byTopic(questions, 'principes', store.segment)), smart: false, shuffle: false),
            act: () => answerAndReveal(q1));
        // 3. Situational question
        final q2 = byId('S055');
        await shot(3, PracticeScreen(title: s.t('menu_situations'), pool: poolStartingWith(q2, exam.specialPool(questions, store.segment)), smart: false, shuffle: false),
            act: () => answerAndReveal(q2));
      }

      // 4. Exam simulation in progress (question 8)
      final examQs = examQuestions();
      await shot(4, ExamScreen(questions: examQs), act: () async {
        for (var k = 0; k < 7; k++) {
          final q = examQs[k];
          await tester.tap(optionText(q.options[q.correct]));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.widgetWithText(FilledButton, s.t('next')));
          await tester.pump(const Duration(milliseconds: 400));
        }
        final q = examQs[7];
        await tester.tap(optionText(q.options[q.correct]));
        await tester.pump(const Duration(milliseconds: 400));
      });

      // 5. Exam result
      final wrong = [examQs[4].id, examQs[11].id, examQs[20].id];
      await shot(
        5,
        ExamResultScreen(
          result: ExamResult(DateTime(2026, 11, 8, 18).millisecondsSinceEpoch, exam.examSize - 3, exam.examSize, 1560, wrong),
          questions: examQs,
          answers: const {},
        ),
      );

      // 6. Topics with progress
      await shot(6, const TopicsScreen());

      // Feature graphic 1024x500
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(1024, 500);
      tester.view.devicePixelRatio = 1.0;
      final icon = File('assets/icon/${exam.id}/icon.png').readAsBytesSync();
      await tester.pumpWidget(featureGraphic(tagline: store.taglines[lang]!, rtl: rtl, icon: icon));
      await precacheImages(tester);
      await tester.pump();
      reportException(tester, '$lang/feature');
      await capture(tester, '$dir/featureGraphic.png', pixelRatio: 1);

      await tester.pumpWidget(const SizedBox());
    });
  }
}
