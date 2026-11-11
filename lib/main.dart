// ============================================================================
//  TUITION AI ML SUPER-APP  -  single-file main.dart
//
//  Theme   : app-wide dark theme with a multi-accent, colorful widget palette
//            (see AppColors / AppTheme below).
//  State   : provider (ChangeNotifier) + shared_preferences  ->  AppState
//            (last opened page, loyalty coins, visit counters, daily bonus).
//            The calendar module additionally stores its reminders with
//            shared_preferences.
//  Mobile  : portrait-first layouts, no nested MaterialApps, safe-area aware.
//
//  pubspec.yaml  ->  dependencies:
//    flutter:
//      sdk: flutter
//    provider: ^6.1.2
//    shared_preferences: ^2.3.2
//    http: ^1.2.2                 # online compiler (Judge0)
//    speech_to_text: ^7.0.0       # voice answers / voice chat
//    flutter_tts: ^4.2.0          # spoken replies
//    share_plus: ^10.1.4          # share interview result
//    pdf: ^3.11.0                 # PDF report card
//    printing: ^5.13.0            # download / share the PDF
//    url_launcher: ^6.3.0         # mailto links
//    camera: ^0.11.0+2            # AI Mock Interview (live camera + recording)
//    video_player: ^2.9.2         # interview video preview
//    path_provider: ^2.1.4
//    file_saver: ^0.2.14          # download PDF / CSV / video
//    flutter_email_sender: ^6.0.3 # e-mail with attachments (mobile)
//    file_picker: ^8.1.2          # AI Resume Builder - ATS upload
//    archive: ^3.6.1              # DOCX text extraction
//    syncfusion_flutter_pdf: ^27.1.48  # PDF text extraction
//    syncfusion_flutter_pdfviewer: ^27.1.48  # interactive PDF reader
//    audioplayers: ^6.1.0         # Shruthi Box
//
//  AI Mock Interview keys (never hard-code them):
//    flutter run --dart-define=ANTHROPIC_API_KEY=... --dart-define=OPENAI_API_KEY=...
//    Android also needs CAMERA permission (minSdk 21+); iOS needs
//    NSCameraUsageDescription.
//
//  Optional assets (the app has built-in fallbacks when they are missing):
//    assets/questions.json, assets/topics.json, assets/participants.json
//
//  Android  : android/app/src/main/AndroidManifest.xml  (inside <manifest>)
//    <uses-permission android:name="android.permission.INTERNET"/>
//    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
//    <uses-permission android:name="android.permission.BLUETOOTH"/>
//    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
//    <queries>
//      <intent><action android:name="android.speech.RecognitionService"/></intent>
//      <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
//    </queries>
//    and set minSdkVersion 24 in android/app/build.gradle
//  iOS      : ios/Runner/Info.plist
//    NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
// ============================================================================

// ignore_for_file: deprecated_member_use, unused_element, unused_field
// ignore_for_file: unused_local_variable, unnecessary_import, use_key_in_widget_constructors
// ignore_for_file: prefer_const_constructors, avoid_print, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui show TextDirection;

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart'
    show AudioPlayer, BytesSource, ReleaseMode;
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart'
    show FilePicker, FileType, PlatformFile;
import 'package:file_saver/file_saver.dart' show FileSaver, MimeType;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, compute;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart'
    show Email, FlutterEmailSender;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart'
    show VideoPlayer, VideoPlayerController;
import 'platform_io_stub.dart'
    if (dart.library.io) 'platform_io.dart' as platform_io;

// ============================================================================
//  ENTRY POINT
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be configured for each target with FlutterFire CLI.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register the background FCM handler before runApp.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS)) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  await NotificationService.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final appState = AppState();
  await appState.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<SuiteState>(
          create: (_) => SuiteState()..initialize(),
        ),
      ],
      child: const TuitionAiMlApp(),
    ),
  );
}

// ============================================================================
//  SHARED DARK + MULTI-ACCENT PALETTE
// ============================================================================

class AppColors {
  AppColors._();

  // Dark surfaces keep the interface calm; accents make each module distinct.
  static const Color background = Color(0xFF0A1020);
  static const Color surface = Color(0xFF111A2B);
  static const Color card = Color(0xFF172338);
  static const Color cardAlt = Color(0xFF1D2B43);
  static const Color field = Color(0xFF121E31);
  static const Color text = Color(0xFFF3F6FF);
  static const Color ink = text;
  static const Color inkSoft = Color(0xFFD5DDF0);
  static const Color muted = Color(0xFFA8B5CC);
  static const Color faint = Color(0xFF8190AA);
  static const Color line = Color(0xFF2B3A55);

  static const Color blue = Color(0xFF69A8FF);
  static const Color blueDark = Color(0xFF3C83E8);
  static const Color sky = Color(0xFF42D7F5);
  static const Color blueSoft = Color(0xFF1A3555);
  static const Color pink = Color(0xFFFF79B8);
  static const Color pinkDark = Color(0xFFE45C9F);
  static const Color rose = Color(0xFFFFA0C8);
  static const Color pinkSoft = Color(0xFF45243B);
  static const Color purple = Color(0xFFB99CFF);
  static const Color purpleSoft = Color(0xFF30264B);
  static const Color greenSoft = Color(0xFF17392F);
  static const Color amberSoft = Color(0xFF3B2B17);
  static const Color teal = Color(0xFF52DEC7);
  static const Color green = Color(0xFF62DDA6);
  static const Color amber = Color(0xFFFFC76A);
  static const Color orange = Color(0xFFFF9C6B);
  static const Color red = Color(0xFFFF7185);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.blue,
      onPrimary: const Color(0xFF071326),
      secondary: AppColors.pink,
      onSecondary: const Color(0xFF25101D),
      tertiary: AppColors.teal,
      onTertiary: const Color(0xFF06201D),
      error: AppColors.red,
      onError: const Color(0xFF2A0810),
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.card,
      surfaceContainerHigh: AppColors.cardAlt,
      surfaceContainerHighest: AppColors.cardAlt,
      primaryContainer: AppColors.blueSoft,
      onPrimaryContainer: const Color(0xFFD9EAFF),
      secondaryContainer: AppColors.pinkSoft,
      onSecondaryContainer: const Color(0xFFFFD8E9),
      outline: AppColors.line,
      outlineVariant: const Color(0xFF25334C),
      surfaceTint: Colors.transparent,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      cardColor: AppColors.card,
      dividerColor: AppColors.line,
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      iconTheme: const IconThemeData(color: AppColors.blue),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.sky),
        actionsIconTheme: IconThemeData(color: AppColors.pink),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        hintStyle: const TextStyle(color: AppColors.faint),
        labelStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border(AppColors.line),
        enabledBorder: border(AppColors.line),
        focusedBorder: border(AppColors.blue, 1.6),
        errorBorder: border(AppColors.red),
        focusedErrorBorder: border(AppColors.red, 1.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blueDark,
          foregroundColor: const Color(0xFF071326),
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.faint,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blueDark,
          foregroundColor: const Color(0xFF071326),
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.faint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sky,
          side: const BorderSide(color: AppColors.blue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.pink),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.pink,
        foregroundColor: Color(0xFF24101C),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.cardAlt,
        selectedColor: AppColors.purpleSoft,
        disabledColor: AppColors.surface,
        checkmarkColor: AppColors.text,
        labelStyle: const TextStyle(color: AppColors.text),
        secondaryLabelStyle: const TextStyle(color: AppColors.inkSoft),
        side: const BorderSide(color: AppColors.line),
        shape: const StadiumBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.sky,
        unselectedItemColor: AppColors.faint,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.purpleSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.purple
              : AppColors.faint,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.text
              : AppColors.muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        )),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: AppColors.inkSoft),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        modalBackgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.cardAlt,
        contentTextStyle: TextStyle(color: AppColors.text),
        actionTextColor: AppColors.amber,
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.sky,
        textColor: AppColors.text,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.teal,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.pink,
        overlayColor: AppColors.pink.withOpacity(0.15),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.teal,
        linearTrackColor: AppColors.line,
        circularTrackColor: AppColors.line,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.pink,
        selectionColor: AppColors.blue.withOpacity(0.28),
        selectionHandleColor: AppColors.pink,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.text : AppColors.faint,
        ),
        trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.teal : AppColors.line,
        ),
      ),
    );
  }
}

// ============================================================================
//  GLOBAL STATE  (provider + shared_preferences)
// ============================================================================

class AppState extends ChangeNotifier {
  static const List<String> bottomBarKeys = [
    'dashboard',
    'chatbot',
    'coding',
    'progress',
    'calender',
  ];

  static const String _kPage = 'app_current_page';
  static const String _kCoins = 'app_coins';
  static const String _kVisits = 'app_visits';
  static const String _kBonusDay = 'app_bonus_day';

  SharedPreferences? _prefs;
  String _currentPageKey = 'dashboard';
  int _coins = 100;
  Map<String, int> _visits = <String, int>{};
  String _lastBonusDay = '';
  bool _ready = false;

  bool get ready => _ready;
  String get currentPageKey => _currentPageKey;
  int get coins => _coins;
  Map<String, int> get visits => Map<String, int>.unmodifiable(_visits);
  int get modulesExplored => _visits.length;
  int get bottomIndex {
    final int i = bottomBarKeys.indexOf(_currentPageKey);
    return i < 0 ? 0 : i;
  }

  Future<void> load() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      _prefs = p;
      _currentPageKey = p.getString(_kPage) ?? 'dashboard';
      _coins = p.getInt(_kCoins) ?? 100;
      _lastBonusDay = p.getString(_kBonusDay) ?? '';
      final String? raw = p.getString(_kVisits);
      if (raw != null && raw.isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map) {
          _visits = decoded.map(
                (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          );
        }
      }
    } catch (_) {
      // Storage unavailable: keep the in-memory defaults.
    }
    _ready = true;
    notifyListeners();
  }

  void navigate(String key) {
    if (key == _currentPageKey) return;
    _currentPageKey = key;
    final int seen = _visits[key] ?? 0;
    _visits[key] = seen + 1;
    if (seen == 0) _coins += 5; // first visit of a module rewards 5 tokens
    _persist();
    notifyListeners();
  }

  void addCoins(int amount) {
    _coins += amount;
    _persist();
    notifyListeners();
  }

  String _today() {
    final DateTime n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  bool get canClaimDailyBonus => _lastBonusDay != _today();

  bool claimDailyBonus() {
    if (!canClaimDailyBonus) return false;
    _lastBonusDay = _today();
    _coins += 20;
    _persist();
    notifyListeners();
    return true;
  }

  Future<void> resetProgress() async {
    _coins = 100;
    _visits = <String, int>{};
    _lastBonusDay = '';
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences p =
          _prefs ?? await SharedPreferences.getInstance();
      _prefs = p;
      await p.setString(_kPage, _currentPageKey);
      await p.setInt(_kCoins, _coins);
      await p.setString(_kBonusDay, _lastBonusDay);
      await p.setString(_kVisits, jsonEncode(_visits));
    } catch (_) {}
  }
}

// ============================================================================
//  APP ROOT
// ============================================================================

class TuitionAiMlApp extends StatelessWidget {
  const TuitionAiMlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuition AI ML Super-App',
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.2,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const FirebaseAuthGate(child: MainNavigationShell()),
    );
  }
}

// ==========================================================================
//  MODULE: Navigation shell & core pages
// ==========================================================================

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  AppState get _app => context.read<AppState>();
  int get _currentBottomIndex => _app.bottomIndex;
  String get _currentPageKey => _app.currentPageKey;

  // Navigation categorization for the massive Menu Bar (Drawer)
  final Map<String, List<Map<String, dynamic>>> _menuCategories = {
    'Core Channels': [
      {'key': 'dashboard', 'title': 'Dashboard Hub', 'icon': Icons.dashboard},
      {'key': 'chatbot', 'title': 'AI Study Companion', 'icon': Icons.chat},
      {
        'key': 'progress',
        'title': 'Global Progress Tracker',
        'icon': Icons.analytics,
      },
      {
        'key': 'calender',
        'title': 'Academic Calendar',
        'icon': Icons.calendar_month,
      },
    ],
    'AI & Interview Prep Engine': [
      {
        'key': 'resume_ai',
        'title': 'AI Resume Smart-Upload',
        'icon': Icons.cloud_upload,
      },
      {
        'key': 'real_time_interview',
        'title': 'AI Real-Time Mock Interview',
        'icon': Icons.videocam,
      },
      {
        'key': 'hr_round',
        'title': 'AI HR Simulation Round',
        'icon': Icons.people_alt,
      },
      {
        'key': 'ai_visa_interview',
        'title': 'AI Visa Clearance Protocol',
        'icon': Icons.flight_takeoff,
      },
      {
        'key': 'precheck_interview',
        'title': 'Pre-Check Gatekeeper Assessment',
        'icon': Icons.verified_user,
      },
      {
        'key': 'group_discussion',
        'title': 'AI Group Discussion Arena',
        'icon': Icons.forum,
      },
    ],
    'Testing, Assessments & Practice': [
      {'key': 'coding', 'title': 'Cloud Compiler IDE', 'icon': Icons.code},
      {'key': 'mcq', 'title': 'Adaptive MCQ Simulator', 'icon': Icons.quiz},
      {
        'key': 'aptitude',
        'title': 'Quantitative Aptitude Matrix',
        'icon': Icons.functions,
      },
      {
        'key': 'foundation_mcq',
        'title': 'Foundation MCQ Generative Engine',
        'icon': Icons.auto_awesome,
      },
      {
        'key': 'fill_in_blanks',
        'title': 'Contextual Fill-in-the-Blanks',
        'icon': Icons.text_fields,
      },
      {
        'key': 'omr_test',
        'title': 'OMR Sheet Digital Scanner',
        'icon': Icons.camera_alt,
      },
      {
        'key': 'ocr_evaluation',
        'title': 'OCR Automated Handwritten Grading',
        'icon': Icons.document_scanner,
      },
    ],
    'Utility & Builders': [
      {
        'key': 'cover_letter',
        'title': 'AI Cover Letter Generator',
        'icon': Icons.description,
      },
      {
        'key': 'portfolio',
        'title': 'Dynamic Portfolio Generator',
        'icon': Icons.web,
      },
      {
        'key': 'documents',
        'title': 'Encrypted Credentials Vault',
        'icon': Icons.folder_special,
      },
      {
        'key': 'marks_tracker',
        'title': 'Granular Marks Gradebook',
        'icon': Icons.score,
      },
      {
        'key': 'answer_key',
        'title': 'Verified Explanatory Answer Keys',
        'icon': Icons.fact_check,
      },
      {
        'key': 'unlock_coins',
        'title': 'Gamified Token Loyalty Portal',
        'icon': Icons.monetization_on,
      },
    ],
    'E-Learning & Digital Library': [
      {'key': 'learning_hub', 'title': 'E-Learning & Digital Library Hub', 'icon': Icons.school},
      {
        'key': 'book_pdf',
        'title': 'E-Book PDF Interactive Reader',
        'icon': Icons.menu_book,
      },
      {
        'key': 'questions_from_book',
        'title': 'AI Book-Context Question Extractor',
        'icon': Icons.find_in_page,
      },
      {
        'key': 'video_classes',
        'title': 'VOD High-Definition Streaming Grid',
        'icon': Icons.smart_display,
      },
      {
        'key': 'class_recording',
        'title': 'Archived Lecture Playback Stream',
        'icon': Icons.video_library,
      },
      {
        'key': 'virtual_lab',
        'title': 'Interactive 3D Physics/Chemistry Lab',
        'icon': Icons.science,
      },
      {
        'key': 'typewriting',
        'title': 'Typing Speed KPM Engine',
        'icon': Icons.keyboard,
      },
      {
        'key': 'tanpura_droid',
        'title': 'Tanpura Droid Acoustic Engine',
        'icon': Icons.music_note,
      },
    ],
    'Support & Communications': [
      {
        'key': 'doubt_panel',
        'title': 'Peer-to-Peer Resolution Board',
        'icon': Icons.live_help,
      },
      {
        'key': 'doubt_chatbot',
        'title': '24/7 NLP Doubt-Buster Chatbot',
        'icon': Icons.support_agent,
      },
    ],
    'Management & Control Centers': [
      {
        'key': 'teacher_dashboard',
        'title': 'Educator Command Deck',
        'icon': Icons.assignment_ind,
      },
      {
        'key': 'student_monitor',
        'title': 'Real-Time Proctor & Attendance Monitor',
        'icon': Icons.visibility,
      },
      {
        'key': 'scheduling_events',
        'title': 'Live Class Institutional Scheduler',
        'icon': Icons.schedule,
      },
      {
        'key': 'center_teacher',
        'title': 'Geospatial Center-Teacher Evaluator',
        'icon': Icons.map,
      },
      {
        'key': 'exam_analytics',
        'title': 'Statistical Exam Multi-Graph Analytics',
        'icon': Icons.bar_chart,
      },
      {
        'key': 'usage_analytics',
        'title': 'Infrastructure Resource Usage Analytics',
        'icon': Icons.pie_chart,
      },
      {
        'key': 'parent_pane',
        'title': 'Parent Supervision Gateway',
        'icon': Icons.family_restroom,
      },
      {
        'key': 'admin_panel',
        'title': 'Global Enterprise Administration',
        'icon': Icons.admin_panel_settings,
      },
      {
        'key': 'superadmin_panel',
        'title': 'Root Configuration System Kernel',
        'icon': Icons.gavel,
      },
    ],
  };

  // Quick navigation mapping for the bottom navbar items
  final List<String> _bottomBarKeys = AppState.bottomBarKeys;

  Widget _renderActivePage() {
    switch (_currentPageKey) {
      case 'dashboard':
        return const StudentDashboardApp();
      case 'chatbot':
        return const LocalAIChatbotApp();
      case 'progress':
        return const ProgressApp();
      case 'calender':
        return Calender();
      case 'resume_ai':
        return const AiResumeBuilder();
      case 'real_time_interview':
        return const AiMockInterview();
      case 'hr_round':
        return const HrSimApp();
      case 'ai_visa_interview':
        return const VisaDemoApp();
      case 'precheck_interview':
        return const PrecheckGatekeeperTab();
      case 'group_discussion':
        return const GDArenaApp();
      case 'coding':
        return const MultiCompilerApp();
      case 'mcq':
        return const MCQPage();
      case 'aptitude':
        return const AptitudePage();
      case 'foundation_mcq':
        return const QuizApp();
      case 'fill_in_blanks':
        return const FillBlankQuizApp();
      case 'omr_test':
        return const OmrExamApp();
      case 'ocr_evaluation':
        return const OcrPage();
      case 'cover_letter':
        return const CoverLetterPage();
      case 'portfolio':
        return const PortfolioPage();
      case 'documents':
        return const DocumentsPage();
      case 'marks_tracker':
        return const MarksPage();
      case 'answer_key':
        return const AnswerKeyPage();
      case 'unlock_coins':
        return const UnlockCoinsPage();
      case 'learning_hub':
        return const LearningHubPage();
      case 'book_pdf':
        return const LearningEbookPage();
      case 'questions_from_book':
        return const LearningRagPage();
      case 'video_classes':
        return const LearningVideoPage();
      case 'class_recording':
        return const LearningArchivePage();
      case 'virtual_lab':
        return const LearningLabPage();
      case 'typewriting':
        return const LearningTypingPage();
      case 'tanpura_droid':
        return const ShruthiBox();
      case 'doubt_panel':
        return const PeerResolutionBoardTab();
      case 'doubt_chatbot':
        return const DoubtBusterTab();
      case 'teacher_dashboard':
        return const EducatorCommandDeckPage();
      case 'student_monitor':
        return const ProctorAttendancePage();
      case 'scheduling_events':
        return const InstitutionalSchedulerPage();
      case 'center_teacher':
        return const GeospatialCentrePage();
      case 'exam_analytics':
        return const StatisticalExamAnalyticsPage();
      case 'usage_analytics':
        return const InfrastructureUsagePage();
      case 'parent_pane':
        return const ParentSupervisionGatewayPage();
      case 'admin_panel':
        return const GlobalEnterpriseAdminPage();
      case 'superadmin_panel':
        return const SuperAdminKernelPage();
      default:
        return const DashboardPage();
    }
  }

  void _navigateToKey(String key) {
    context.read<AppState>().navigate(key);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentPageKey.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _navigateToKey('unlock_coins'),
            icon: const Icon(Icons.stars, color: AppColors.pink),
            label: Text(
              '${app.coins}',
              style: const TextStyle(
                color: AppColors.pink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _navigateToKey('parent_pane'),
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: AppColors.card,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.blueDark, AppColors.pinkDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'TUITION AI ML',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFFFFF),
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Omni-Channel Adaptive Learning Platform',
                      style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  if (user == null) return const SizedBox.shrink();
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.verified_user, color: AppColors.teal),
                        title: Text(user.email ?? 'Signed in',
                            style: const TextStyle(color: AppColors.text)),
                        subtitle: const Text('Firebase account',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_active, color: AppColors.pink),
                        title: const Text('Send test notification',
                            style: TextStyle(color: AppColors.text)),
                        onTap: () async {
                          Navigator.pop(context);
                          await NotificationService.showLocal(
                            'Tuition AI notification',
                            'Firebase notifications are configured on this device.',
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout, color: AppColors.red),
                        title: const Text('Sign out',
                            style: TextStyle(color: AppColors.text)),
                        onTap: () async {
                          Navigator.pop(context);
                          await FirebaseAuth.instance.signOut();
                        },
                      ),
                      const Divider(color: AppColors.line),
                    ],
                  );
                },
              ),
              ..._menuCategories.entries.map((category) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 9),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.key.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Text(
                            '${category.value.length} modules',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: category.value.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 9,
                        mainAxisSpacing: 9,
                        childAspectRatio: 1.32,
                      ),
                      itemBuilder: (context, index) {
                        final item = category.value[index];
                        final bool isSelected =
                            _currentPageKey == item['key'];
                        return Material(
                          color: isSelected
                              ? AppColors.blue.withOpacity(0.10)
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: () {
                              Navigator.pop(context);
                              _navigateToKey(item['key']);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.pink
                                      : AppColors.line,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    color: isSelected
                                        ? AppColors.pink
                                        : AppColors.blue,
                                    size: 25,
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    item['title'] as String,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.sky
                                          : AppColors.ink,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(color: AppColors.line, height: 22),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _renderActivePage(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomIndex,
        onTap: (index) => _navigateToKey(_bottomBarKeys[index]),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.sky,
        unselectedItemColor: AppColors.faint,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'AI Chat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.code),
            label: 'IDE Compiler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Metrics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
} // Global reusable modular card design pattern for pages

class ModuleCard extends StatelessWidget {
  final String title;
  final Widget child;
  const ModuleCard({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ==========================================
// 1. DASHBOARD PAGE
// ==========================================
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ModuleCard(
          title: "AI Adaptive Skill Matrix Status",
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.bolt, color: AppColors.pink),
                title: Text("Current ML Skill Index: 84.6%"),
                subtitle: Text("Top Performance: Python & NLP Pipelines"),
              ),
            ],
          ),
        ),
        ModuleCard(
          title: "Quick Action Gateways",
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.model_training),
                label: const Text("Launch AI Mock"),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.bug_report),
                label: const Text("Debug Code Workspace"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. CHATBOT PAGE
// ==========================================
class ChatbotPage extends StatelessWidget {
  const ChatbotPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "[AI Model]: Welcome back! Paste your mathematical equations or code lines here for contextual verification.",
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Query LLM Agent...",
              suffixIcon: const Icon(Icons.send),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. PROGRESS PAGE
// ==========================================
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: const [
          ModuleCard(
            title: "Velocity & Retention Vectors",
            child: Text(
              "Linear progression tracking shows a 14% retention delta increase through continuous reinforcement loops.",
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. CALENDAR PAGE
// ==========================================
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: const [
          ModuleCard(
            title: "Chronological Class Maps",
            child: Text(
              "Next live sync: Deep Learning Architecture optimization session at 14:00 UTC.",
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. RESUME AI UPLOAD PAGE
// ==========================================
class ResumeAiPage extends StatelessWidget {
  const ResumeAiPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_done,
              size: 64,
              color: AppColors.blue,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Select PDF Resume for ATS Evaluation Matrix"),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. REAL TIME INTERVIEW PAGE
// ==========================================
class RealTimeInterviewPage extends StatelessWidget {
  const RealTimeInterviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 200,
            color: AppColors.blueSoft,
            child: const Center(
              child: Text(
                "Camera Feed Simulation [Active Target Verification State]",
                style: TextStyle(color: AppColors.pink),
              ),
            ),
          ),
          const Expanded(
            child: ModuleCard(
              title: "AI Audio Prompter Queue",
              child: Text(
                "Question 1: Explain the structural architectural delta between transformer mechanisms and recurrent networks.",
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 7. HR ROUND PAGE
// ==========================================
class HrRoundPage extends StatelessWidget {
  const HrRoundPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Behavioral & Soft Skill Evaluation Environment Ready."),
      ),
    );
  }
}

// ==========================================
// 8. AI VISA INTERVIEW PAGE
// ==========================================
class AiVisaInterviewPage extends StatelessWidget {
  const AiVisaInterviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Consular Compliance Verification & Document Authentication Engine",
        ),
      ),
    );
  }
}

// ==========================================
// 9. PRECHECK INTERVIEW PAGE
// ==========================================
class PrecheckInterviewPage extends StatelessWidget {
  const PrecheckInterviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Initial Pre-Screening Clearance Pipeline Modules"),
      ),
    );
  }
}

// ==========================================
// 10. GROUP DISCUSSION PAGE
// ==========================================
class GroupDiscussionPage extends StatelessWidget {
  const GroupDiscussionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Multi-Agent NLP Group Discussion Simulation Lobby"),
      ),
    );
  }
}

// ==========================================
// 11. CODING PAGE
// ==========================================
class CodingPage extends StatelessWidget {
  const CodingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.card,
              child: const TextField(
                maxLines: null,
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: AppColors.blue,
                ),
                decoration: InputDecoration.collapsed(
                  hintText:
                  "def train_model(data):\n    # Inject hyperparameter architecture matrix code...",
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            child: const Text("Compile & Run Tests Across Remote Workers"),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 12. ADAPTIVE MCQ SIMULATOR — 40 QUESTIONS
// ==========================================
class _AdaptiveQuestion {
  final String topic;
  final String difficulty;
  final String prompt;
  final List<String> options;
  final int answer;
  final String explanation;

  const _AdaptiveQuestion({
    required this.topic,
    required this.difficulty,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.explanation,
  });
}

const List<_AdaptiveQuestion> _adaptiveQuestions = [
  _AdaptiveQuestion(topic: 'Machine Learning', difficulty: 'Easy', prompt: 'Which technique limits the magnitude of gradients during backpropagation to reduce exploding-gradient problems?', options: ['Gradient clipping', 'Stochastic dropout', 'Batch shuffling', 'Feature scaling'], answer: 0, explanation: 'Gradient clipping caps the gradient norm or values before the optimizer update, helping prevent unstable parameter updates.'),
  _AdaptiveQuestion(topic: 'Machine Learning', difficulty: 'Easy', prompt: 'A model performs very well on training data but poorly on unseen data. Which issue is most likely?', options: ['Underfitting', 'Overfitting', 'Data normalization', 'Early convergence'], answer: 1, explanation: 'Overfitting occurs when a model learns training-specific patterns that do not generalize.'),
  _AdaptiveQuestion(topic: 'Statistics', difficulty: 'Easy', prompt: 'If a fair coin is tossed twice, what is the probability of getting exactly one head?', options: ['1/4', '1/2', '3/4', '1'], answer: 1, explanation: 'The outcomes are HH, HT, TH and TT. Two of four contain exactly one head, so the probability is 2/4 = 1/2.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Easy', prompt: 'A value increases from 80 to 100. What is the percentage increase?', options: ['20%', '25%', '30%', '40%'], answer: 1, explanation: 'Increase = 20. Percentage increase = 20/80 × 100 = 25%.'),
  _AdaptiveQuestion(topic: 'Critical Reasoning', difficulty: 'Easy', prompt: 'A company introduced flexible hours and productivity rose. Which fact most weakens the claim that flexible hours caused the rise?', options: ['Employees liked the policy', 'The company also introduced new automation at the same time', 'The policy applied to all teams', 'Productivity was measured monthly'], answer: 1, explanation: 'A simultaneous automation change is an alternative explanation for the productivity increase.'),
  _AdaptiveQuestion(topic: 'Machine Learning', difficulty: 'Medium', prompt: 'Which regularization method randomly disables a subset of units during training?', options: ['Dropout', 'Gradient clipping', 'PCA', 'Label encoding'], answer: 0, explanation: 'Dropout randomly suppresses activations during training to reduce co-adaptation and overfitting.'),
  _AdaptiveQuestion(topic: 'Statistics', difficulty: 'Medium', prompt: 'A dataset has mean 18 and standard deviation 3. What is the z-score of an observation of 24?', options: ['1', '2', '3', '6'], answer: 1, explanation: 'z = (24 − 18)/3 = 2.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Medium', prompt: 'A train travels 180 km in 2.5 hours. What is its average speed?', options: ['60 km/h', '70 km/h', '72 km/h', '75 km/h'], answer: 2, explanation: 'Average speed = distance/time = 180/2.5 = 72 km/h.'),
  _AdaptiveQuestion(topic: 'Critical Reasoning', difficulty: 'Medium', prompt: 'All analysts are graduates. Some graduates are designers. Which conclusion must be true?', options: ['All designers are analysts', 'Some analysts are designers', 'All analysts are graduates', 'No designers are analysts'], answer: 2, explanation: 'The first statement directly guarantees that every analyst is a graduate. The overlap between analysts and designers is not established.'),
  _AdaptiveQuestion(topic: 'Data Sufficiency', difficulty: 'Medium', prompt: 'Is integer n even? (1) n² is even. (2) n is divisible by 4.', options: ['Statement 1 alone is sufficient', 'Statement 2 alone is sufficient', 'Both together are required', 'Each statement alone is sufficient'], answer: 3, explanation: 'If n² is even, n must be even. Divisibility by 4 also guarantees n is even. Each statement independently answers the question.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Medium', prompt: 'A mixture contains milk and water in the ratio 5:3. If the mixture is 32 litres, how much water does it contain?', options: ['10 L', '12 L', '15 L', '20 L'], answer: 1, explanation: 'There are 8 total parts. Water = 3/8 × 32 = 12 litres.'),
  _AdaptiveQuestion(topic: 'Statistics', difficulty: 'Medium', prompt: 'If two independent events have probabilities 0.4 and 0.5, what is the probability that both occur?', options: ['0.1', '0.2', '0.45', '0.9'], answer: 1, explanation: 'For independent events, P(A and B) = P(A)P(B) = 0.4 × 0.5 = 0.2.'),
  _AdaptiveQuestion(topic: 'Machine Learning', difficulty: 'Hard', prompt: 'A neural network exhibits exploding gradients. Which intervention directly constrains the norm of the gradient vector before an optimizer step?', options: ['Increase learning rate', 'Global-norm gradient clipping', 'Remove validation data', 'Increase batch-label noise'], answer: 1, explanation: 'Global-norm clipping rescales the full gradient vector when its norm exceeds a chosen threshold.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Hard', prompt: 'A and B can complete a task in 12 and 18 days respectively. Working together at constant rates, how long will they take?', options: ['6 days', '7.2 days', '8 days', '15 days'], answer: 1, explanation: 'Combined rate = 1/12 + 1/18 = 5/36 task/day. Time = 36/5 = 7.2 days.'),
  _AdaptiveQuestion(topic: 'Critical Reasoning', difficulty: 'Hard', prompt: 'A city claims a new bus lane reduced commute times because average journey time fell after launch. Which evidence most strengthens the claim?', options: ['Fuel prices rose during the period', 'Comparable routes without bus lanes showed no reduction, while bus-lane routes did', 'More residents bought bicycles', 'The bus lane was painted blue'], answer: 1, explanation: 'A comparison group with no similar improvement helps isolate the bus lane effect from broader time trends.'),
  _AdaptiveQuestion(topic: 'Data Sufficiency', difficulty: 'Hard', prompt: 'Is x greater than y? (1) x − y is positive. (2) x² > y².', options: ['Statement 1 alone is sufficient', 'Statement 2 alone is sufficient', 'Both together are sufficient', 'Neither is sufficient'], answer: 0, explanation: 'Statement 1 explicitly says x − y > 0, which is equivalent to x > y. Statement 2 alone is not sufficient.'),
  _AdaptiveQuestion(topic: 'Statistics', difficulty: 'Hard', prompt: 'A normal distribution has mean 50 and standard deviation 10. Approximately what percentage of observations lie between 40 and 60?', options: ['34%', '50%', '68%', '95%'], answer: 2, explanation: 'The empirical rule places about 68% of observations within one standard deviation of the mean.'),
  _AdaptiveQuestion(topic: 'Machine Learning', difficulty: 'Hard', prompt: 'Why can batch normalization permit more stable training with larger learning rates?', options: ['It removes all model parameters', 'It stabilizes intermediate activation distributions during training', 'It guarantees zero training error', 'It converts classification into regression'], answer: 1, explanation: 'Batch normalization normalizes layer inputs using batch statistics and learns scale/shift parameters, often improving optimization stability.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Hard', prompt: 'A sum is invested at 10% compound interest annually. What is the growth factor after 3 years?', options: ['1.30', '1.331', '1.3001', '1.33'], answer: 1, explanation: 'The growth factor is (1 + 0.10)^3 = 1.331.'),
  _AdaptiveQuestion(topic: 'Critical Reasoning', difficulty: 'Hard', prompt: 'A study finds that people who exercise regularly report better sleep. Which assumption is required to infer exercise improves sleep?', options: ['Sleep quality is unrelated to age', 'The association is not fully explained by confounding factors such as health or schedule', 'Every participant exercises equally', 'The survey has exactly 100 participants'], answer: 1, explanation: 'A causal inference requires that plausible confounders do not explain the observed association.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Easy', prompt: 'What is 15% of 240?', options: ['24', '30', '36', '42'], answer: 2, explanation: '0.15 × 240 = 36.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Easy', prompt: 'If 3x = 27, what is x?', options: ['6', '8', '9', '12'], answer: 2, explanation: 'Divide both sides by 3: x = 9.'),
  _AdaptiveQuestion(topic: 'Logic', difficulty: 'Easy', prompt: 'Find the next number: 2, 4, 8, 16, __.', options: ['18', '24', '30', '32'], answer: 3, explanation: 'Each term doubles, so the next term is 32.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Easy', prompt: 'The average of 6, 8 and 10 is:', options: ['7', '8', '9', '10'], answer: 1, explanation: '(6 + 8 + 10)/3 = 8.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Medium', prompt: 'A shop gives a 20% discount on an item marked ₹1,500. What is the selling price?', options: ['₹1,100', '₹1,200', '₹1,250', '₹1,300'], answer: 1, explanation: 'Discount = ₹300, so selling price = ₹1,200.'),
  _AdaptiveQuestion(topic: 'Logic', difficulty: 'Medium', prompt: 'If every P is Q and no Q is R, which statement must be true?', options: ['Some P are R', 'No P is R', 'Every R is P', 'Some Q are P'], answer: 1, explanation: 'Since P is a subset of Q and Q has no overlap with R, P cannot overlap with R.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Medium', prompt: 'A number is increased by 20% and then decreased by 20%. What is the net change?', options: ['No change', '4% decrease', '4% increase', '2% decrease'], answer: 1, explanation: '1.2 × 0.8 = 0.96, so the final value is 4% lower.'),
  _AdaptiveQuestion(topic: 'Statistics', difficulty: 'Medium', prompt: 'The median of 3, 7, 9, 12, 20 is:', options: ['7', '9', '10', '12'], answer: 1, explanation: 'The middle value in the ordered list is 9.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Medium', prompt: 'A car covers equal distances at 30 km/h and 60 km/h. What is its average speed for the whole journey?', options: ['40 km/h', '45 km/h', '48 km/h', '50 km/h'], answer: 0, explanation: 'For equal distances, average speed = 2ab/(a+b) = 2×30×60/90 = 40 km/h.'),
  _AdaptiveQuestion(topic: 'Logic', difficulty: 'Hard', prompt: 'In a code, TRAIN is written as USBJO by shifting each letter one place forward. How is PLANE written?', options: ['QMBNF', 'QKZMD', 'OKZMD', 'QMBME'], answer: 0, explanation: 'Each letter moves one position forward: P→Q, L→M, A→B, N→O, E→F.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Hard', prompt: 'If 5 workers complete a job in 12 days, how many days will 8 workers take at the same rate?', options: ['6.5', '7', '7.5', '8'], answer: 2, explanation: 'Total work = 5×12 = 60 worker-days. 60/8 = 7.5 days.'),
  _AdaptiveQuestion(topic: 'Statistics', difficulty: 'Hard', prompt: 'A test has 5 independent questions, each answered correctly with probability 0.8. What is the probability all five are correct?', options: ['0.32768', '0.4096', '0.64', '0.8'], answer: 0, explanation: '0.8⁵ = 0.32768.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Hard', prompt: 'A rectangle has perimeter 54 cm and length 16 cm. What is its area?', options: ['160 cm²', '168 cm²', '176 cm²', '192 cm²'], answer: 2, explanation: '2(L+W)=54, so W=11; area = 16×11 = 176 cm².',),
  _AdaptiveQuestion(topic: 'Logic', difficulty: 'Easy', prompt: 'Which item does not belong: square, triangle, circle, cube?', options: ['Square', 'Triangle', 'Circle', 'Cube'], answer: 3, explanation: 'Cube is three-dimensional; the others are two-dimensional shapes.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Easy', prompt: 'A dozen pens cost ₹96. What is the cost of one pen?', options: ['₹6', '₹8', '₹9', '₹12'], answer: 1, explanation: '₹96 ÷ 12 = ₹8.'),
  _AdaptiveQuestion(topic: 'Logic', difficulty: 'Medium', prompt: 'Find the missing term: AZ, BY, CX, DW, __.', options: ['EV', 'EU', 'FV', 'EX'], answer: 0, explanation: 'The first letter moves forward and the second moves backward: E and V.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Medium', prompt: 'A sum of ₹5,000 earns simple interest at 6% per year for 2 years. Find the interest.', options: ['₹500', '₹550', '₹600', '₹650'], answer: 2, explanation: 'SI = PRT/100 = 5000×6×2/100 = ₹600.'),
  _AdaptiveQuestion(topic: 'Logic', difficulty: 'Hard', prompt: 'Five people sit in a row. A is left of B, C is right of B, D is left of A, and E is right of C. Which order is forced?', options: ['D-A-B-C-E', 'A-D-B-C-E', 'D-B-A-C-E', 'D-A-C-B-E'], answer: 0, explanation: 'The constraints create the sequence D before A before B before C before E.'),
  _AdaptiveQuestion(topic: 'Quantitative', difficulty: 'Hard', prompt: 'A pipe fills a tank in 6 hours and a drain empties it in 9 hours. If both are open, how long to fill an empty tank?', options: ['12 h', '15 h', '18 h', '24 h'], answer: 2, explanation: 'Net rate = 1/6 − 1/9 = 1/18 tank per hour, so 18 hours.'),
  _AdaptiveQuestion(topic: 'Logic', difficulty: 'Medium', prompt: 'If yesterday was Wednesday, what day will it be 100 days from today?', options: ['Friday', 'Saturday', 'Sunday', 'Monday'], answer: 1, explanation: 'Yesterday Wednesday means today Thursday. 100 mod 7 = 2; two days after Thursday is Saturday.'),
];

class MCQPage extends StatefulWidget {
  const MCQPage({super.key});
  @override
  State<MCQPage> createState() => _MCQPageState();
}

class _MCQPageState extends State<MCQPage> {
  static const _historyKey = 'adaptive_mcq_history_v1';
  int _index = 0;
  List<int> _sequence = List<int>.generate(_adaptiveQuestions.length, (i) => i);
  int? _selected;
  int _score = 0;
  int _answered = 0;
  int _secondsLeft = 40 * 60;
  int _level = 1;
  bool _submitted = false;
  bool _showReview = false;
  Timer? _timer;
  final List<Map<String, dynamic>> _review = [];

  _AdaptiveQuestion get _question => _adaptiveQuestions[_sequence[_index]];
  String get _levelName => _level == 1 ? 'Foundation' : (_level == 2 ? 'Intermediate' : 'Advanced');

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _submitted) return;
      if (_secondsLeft <= 1) {
        setState(() => _secondsLeft = 0);
        _finish();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _choose(int value) {
    if (_selected != null || _submitted) return;
    setState(() => _selected = value);
  }

  Future<void> _next() async {
    if (_selected == null || _submitted) return;
    final q = _question;
    final correct = _selected == q.answer;
    _answered++;
    if (correct) {
      _score++;
      if (_level < 3) _level++;
    } else if (_level > 1) {
      _level--;
    }
    _review.add({
      'number': _index + 1,
      'topic': q.topic,
      'difficulty': q.difficulty,
      'question': q.prompt,
      'selected': q.options[_selected!],
      'correct': q.options[q.answer],
      'isCorrect': correct,
      'explanation': q.explanation,
    });
    if (_index == _adaptiveQuestions.length - 1) {
      await _finish();
    } else {
      setState(() {
        // Reorder only unanswered questions so the next item matches the
        // learner's current target level as closely as possible.
        final completed = _sequence.take(_index + 1).toList();
        final remaining = _sequence.skip(_index + 1).toList();
        final target = _level == 1 ? 'Easy' : (_level == 2 ? 'Medium' : 'Hard');
        remaining.sort((a, b) {
          final da = _adaptiveQuestions[a].difficulty == target ? 0 : 1;
          final db = _adaptiveQuestions[b].difficulty == target ? 0 : 1;
          return da.compareTo(db);
        });
        _sequence = [...completed, ...remaining];
        _index++;
        _selected = null;
      });
    }
  }

  Future<void> _finish() async {
    if (_submitted) return;
    _timer?.cancel();
    setState(() => _submitted = true);
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? <String>[];
    history.insert(0, jsonEncode({
      'date': DateTime.now().toIso8601String(),
      'score': _score,
      'total': _answered,
      'accuracy': _answered == 0 ? 0 : (_score / _answered * 100).round(),
      'timeRemaining': _secondsLeft,
      'review': _review,
    }));
    await prefs.setStringList(_historyKey, history.take(30).toList());
    if (mounted) setState(() {});
  }

  Future<void> _restart() async {
    _timer?.cancel();
    setState(() {
      _index = 0; _sequence = List<int>.generate(_adaptiveQuestions.length, (i) => i); _selected = null; _score = 0; _answered = 0;
      _secondsLeft = 40 * 60; _level = 1; _submitted = false;
      _showReview = false; _review.clear();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _submitted) return;
      if (_secondsLeft <= 1) {
        setState(() => _secondsLeft = 0);
        _finish();
      } else { setState(() => _secondsLeft--); }
    });
  }

  Future<void> _showHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? <String>[];
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .75,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Attempt history', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.blue)),
              if (history.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No completed attempts yet.')),
              ...history.map((raw) {
                final item = jsonDecode(raw) as Map<String, dynamic>;
                final date = DateTime.tryParse(item['date']?.toString() ?? '');
                return Card(child: ListTile(
                  leading: const Icon(Icons.history, color: AppColors.pink),
                  title: Text('Score: ${item['score']}/${item['total']}  •  ${item['accuracy']}%'),
                  subtitle: Text(date == null ? '' : date.toLocal().toString().substring(0, 16)),
                ));
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _answered / _adaptiveQuestions.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: Text('Adaptive GMAT-style simulator', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.blue))),
          IconButton(onPressed: _showHistory, icon: const Icon(Icons.history), tooltip: 'Attempt history'),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _statChip('Question ${_index + 1}/40', Icons.quiz),
          _statChip('Score $_score', Icons.stars),
          _statChip(_timeText, Icons.timer, color: _secondsLeft < 300 ? AppColors.pink : AppColors.blue),
          _statChip(_levelName, Icons.trending_up),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress, minHeight: 7, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: 16),
        if (_submitted) ...[
          ModuleCard(title: 'Assessment complete', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Final score: $_score / $_answered', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.blue)),
            Text('Accuracy: ${_answered == 0 ? 0 : (_score / _answered * 100).round()}%'),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _restart, icon: const Icon(Icons.refresh), label: const Text('Start new attempt')),
            OutlinedButton.icon(onPressed: () => setState(() => _showReview = !_showReview), icon: const Icon(Icons.fact_check), label: Text(_showReview ? 'Hide review' : 'Review answers')),
          ])),
          if (_showReview) ..._review.map((r) => ModuleCard(title: 'Q${r['number']} • ${r['topic']} • ${r['isCorrect'] ? 'Correct' : 'Incorrect'}', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r['question'].toString()),
            Text('Your answer: ${r['selected']}'),
            Text('Correct answer: ${r['correct']}', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold)),
            Text(r['explanation'].toString()),
          ]))),
        ] else ...[
          ModuleCard(title: '${_question.topic} • ${_question.difficulty}', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_question.prompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...List.generate(_question.options.length, (i) => Card(
              color: _selected == i ? AppColors.blueSoft : AppColors.card,
              child: RadioListTile<int>(
                value: i, groupValue: _selected, onChanged: _selected == null ? (v) { if (v != null) _choose(v); } : null,
                title: Text(_question.options[i]),
                activeColor: AppColors.pink,
                dense: true,
              ),
            )),
          ])),
          FilledButton.icon(onPressed: _selected == null ? null : _next, icon: const Icon(Icons.arrow_forward), label: Text(_index == 39 ? 'Finish assessment' : 'Submit & next')),
          Text('Adaptive rule: correct answers raise the target level; incorrect answers lower it. Questions are served from the offline 40-question bank.', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _statChip(String label, IconData icon, {Color color = AppColors.blue}) => Chip(
    avatar: Icon(icon, size: 17, color: color),
    label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    backgroundColor: AppColors.blueSoft,
  );
}

// ==========================================
// 13. QUANTITATIVE APTITUDE MATRIX ENGINE
// ==========================================
class AptitudePage extends StatefulWidget {
  const AptitudePage({super.key});
  @override
  State<AptitudePage> createState() => _AptitudePageState();
}

class _AptitudePageState extends State<AptitudePage> {
  String _category = 'Quantitative';
  int _index = 0;
  int _score = 0;
  int? _selected;

  final Map<String, List<Map<String, dynamic>>> _banks = {
    'Quantitative': [
      {'q': 'A sum of ₹8,000 is invested at 5% simple interest for 3 years. Find the interest.', 'o': ['₹1,000', '₹1,200', '₹1,400', '₹1,600'], 'a': 1, 'e': 'SI = PRT/100 = 8000×5×3/100 = ₹1,200.'},
      {'q': 'A train 150 m long crosses a pole in 10 seconds. Find its speed.', 'o': ['36 km/h', '45 km/h', '54 km/h', '60 km/h'], 'a': 2, 'e': 'Speed = 150/10 = 15 m/s = 54 km/h.'},
      {'q': 'The ratio of two numbers is 7:9 and their sum is 80. Find the larger number.', 'o': ['35', '40', '45', '50'], 'a': 2, 'e': '16 parts = 80, so one part = 5; larger = 9×5 = 45.'},
      {'q': 'A can finish work in 10 days and B in 15 days. Together they finish in:', 'o': ['5 days', '6 days', '7 days', '8 days'], 'a': 1, 'e': 'Combined rate = 1/10 + 1/15 = 1/6 job/day.'},
    ],
    'Logic Matrix': [
      {'q': 'Complete the matrix: 2, 4, 8 / 3, 6, 12 / 5, 10, ?', 'o': ['15', '18', '20', '25'], 'a': 2, 'e': 'Each row doubles across: 5, 10, 20.'},
      {'q': 'Find the missing number: 4, 9, 16, 25, ?', 'o': ['30', '32', '36', '49'], 'a': 2, 'e': 'These are squares 2², 3², 4², 5²; next is 6² = 36.'},
      {'q': 'If NORTH is coded as OPSUI, how is SOUTH coded using the same rule?', 'o': ['TPVUI', 'RNTUG', 'TPVTH', 'TPVUI'], 'a': 0, 'e': 'Shift each letter one position forward: SOUTH → TPVUI.'},
    ],
    'Vector Calculus': [
      {'q': 'For f(x,y)=x²+y², what is the gradient ∇f?', 'o': ['(2x, 2y)', '(x, y)', '(2, 2)', '(x², y²)'], 'a': 0, 'e': 'The gradient is the vector of partial derivatives: (∂f/∂x, ∂f/∂y) = (2x,2y).'},
      {'q': 'What is the divergence of F=(x², y², z²)?', 'o': ['2x+2y+2z', 'x+y+z', '2xyz', '0'], 'a': 0, 'e': 'Divergence = ∂x²/∂x + ∂y²/∂y + ∂z²/∂z = 2x+2y+2z.'},
      {'q': 'The curl of a gradient field (where derivatives are continuous) is:', 'o': ['Always zero', 'Always one', 'Always infinite', 'Equal to divergence'], 'a': 0, 'e': 'For a sufficiently smooth scalar field, ∇×(∇f)=0.'},
    ],
    'Railway Exams': [
      {'q': 'A train moving at 72 km/h crosses a 200 m platform in 20 seconds. Find the train length.', 'o': ['100 m', '150 m', '200 m', '250 m'], 'a': 2, 'e': '72 km/h = 20 m/s. Distance in 20 s = 400 m; train length = 400−200 = 200 m.'},
      {'q': 'Find the next term: 7, 14, 28, 56, __.', 'o': ['84', '98', '112', '120'], 'a': 2, 'e': 'Each term doubles; next is 112.'},
      {'q': 'A person walks 5 km north and then 12 km east. How far are they from the start?', 'o': ['13 km', '15 km', '17 km', '7 km'], 'a': 0, 'e': 'By Pythagoras, distance = √(5²+12²)=13 km.'},
    ],
  };

  List<Map<String, dynamic>> get _items => _banks[_category]!;
  Map<String, dynamic> get _current => _items[_index % _items.length];

  void _answer(int value) {
    if (_selected != null) return;
    setState(() {
      _selected = value;
      if (value == _current['a']) _score++;
    });
  }

  void _next() => setState(() {
    _index = (_index + 1) % _items.length;
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Quantitative Aptitude Matrix Engine', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.blue)),
      const SizedBox(height: 8),
      Text('Practice score: $_score', style: const TextStyle(color: AppColors.pink, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: _banks.keys.map((name) => ChoiceChip(
        label: Text(name), selected: _category == name,
        onSelected: (_) => setState(() { _category = name; _index = 0; _selected = null; }),
        selectedColor: AppColors.pinkSoft,
      )).toList()),
      const SizedBox(height: 16),
      ModuleCard(title: '$_category • Question ${_index + 1}/${_items.length}', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_current['q'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...List.generate((_current['o'] as List).length, (i) => RadioListTile<int>(
          value: i, groupValue: _selected, onChanged: _selected == null ? (v) { if (v != null) _answer(v); } : null,
          title: Text((_current['o'] as List)[i].toString()), activeColor: AppColors.pink, dense: true,
        )),
        if (_selected != null) ...[
          const Divider(),
          Text(_selected == _current['a'] ? 'Correct answer' : 'Not quite — review the solution', style: TextStyle(fontWeight: FontWeight.bold, color: _selected == _current['a'] ? AppColors.blue : AppColors.pink)),
          Text(_current['e'].toString()),
        ],
      ])),
      FilledButton.icon(onPressed: _selected == null ? null : _next, icon: const Icon(Icons.skip_next), label: const Text('Next question')),
    ]);
  }
}


// ==========================================
// 14. FOUNDATION MCQ PAGE
// ==========================================
class FoundationMcqPage extends StatelessWidget {
  const FoundationMcqPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Generative Model: Building custom fundamental baseline testing structures...",
        ),
      ),
    );
  }
}

// ==========================================
// 15. FILL IN BLANKS PAGE
// ==========================================
class FillInBlanksPage extends StatelessWidget {
  const FillInBlanksPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Natural Language Processing Cloze Deletion Evaluation Environment.",
        ),
      ),
    );
  }
}

// ==========================================
// 16. OMR TEST PAGE
// ==========================================
class OmrTestPage extends StatelessWidget {
  const OmrTestPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Computer Vision OMR Matrix Scanner Interface")),
    );
  }
}

// ==========================================
// 17. OCR EVALUATION PAGE
// ==========================================
class OcrEvaluationPage extends StatelessWidget {
  const OcrEvaluationPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Handwritten Script Recognition & Automated Scoring Infrastructure",
        ),
      ),
    );
  }
}

// ==========================================// 18. COVER LETTER PAGE// ==========================================
class CoverLetterPage extends StatefulWidget {
  const CoverLetterPage({super.key});
  @override State<CoverLetterPage> createState() => _CoverLetterPageState();
}
class _CoverLetterPageState extends State<CoverLetterPage> {
  final name=TextEditingController(), role=TextEditingController(), company=TextEditingController(), skills=TextEditingController(), experience=TextEditingController(), job=TextEditingController();
  String tone='Professional'; String draft='';
  @override void dispose(){ for(final c in [name,role,company,skills,experience,job]){c.dispose();} super.dispose(); }
  void generate(){
    if(name.text.trim().isEmpty || role.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter your name and target role first.')));return;}
    setState(() {
      draft = '''${name.text.trim()}

Dear Hiring Manager,

I am writing to express my interest in the ${role.text.trim()} position${company.text.trim().isEmpty ? '' : ' at ${company.text.trim()}'}. My background includes ${experience.text.trim().isEmpty ? 'relevant academic and practical experience' : experience.text.trim()}. I bring strengths in ${skills.text.trim().isEmpty ? 'problem solving, communication and continuous learning' : skills.text.trim()}.

The opportunity appeals to me because it aligns with my skills and professional goals. ${job.text.trim().isEmpty ? 'I would welcome the opportunity to contribute to your team.' : 'Your role requirements particularly interest me: ${job.text.trim()}.'} I would be pleased to discuss how my experience can support your organisation.

Thank you for your time and consideration.

Sincerely,
${name.text.trim()}

[Tone: $tone]''';
    });
  }
  @override Widget build(BuildContext context)=>_builderScaffold(context,'AI Cover Letter Generator','Context-aware application narrative builder',Icons.description,ListView(padding:const EdgeInsets.all(16),children:[_appField(name,'Full name'),_appField(role,'Target role'),_appField(company,'Company / institution'),_appField(skills,'Skills (comma separated)'),_appField(experience,'Experience / education',max:3),_appField(job,'Job description or selection criteria',max:4),DropdownButtonFormField<String>(value:tone,decoration:const InputDecoration(labelText:'Writing tone',border:OutlineInputBorder()),items:['Professional','Confident','Academic','Entry-level'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>tone=v??tone)),const SizedBox(height:12),FilledButton.icon(onPressed:generate,icon:const Icon(Icons.auto_awesome),label:const Text('Generate cover letter')),if(draft.isNotEmpty)...[const SizedBox(height:16),_resultPanel('Generated draft',draft),OutlinedButton.icon(onPressed:()=>_copyText(context,draft),icon:const Icon(Icons.copy),label:const Text('Copy letter'))]]));
}
// ==========================================// 19. PORTFOLIO PAGE// ==========================================

class PortfolioPage extends StatefulWidget { const PortfolioPage({super.key}); @override State<PortfolioPage> createState()=>_PortfolioPageState(); }
class _PortfolioPageState extends State<PortfolioPage>{
 final name=TextEditingController(), headline=TextEditingController(), about=TextEditingController(), skills=TextEditingController(), projects=TextEditingController(), email=TextEditingController(), github=TextEditingController();
 @override void dispose(){for(final c in [name,headline,about,skills,projects,email,github]){c.dispose();}super.dispose();}
 String get html=>'''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${_html(name.text)} | Portfolio</title><style>body{font-family:Arial;margin:0;background:#f7f8ff;color:#172554}header{background:linear-gradient(120deg,#1d4ed8,#db2777);color:white;padding:60px 8%}main{max-width:900px;margin:30px auto;padding:24px}section{background:white;padding:24px;border-radius:16px;margin:18px 0;box-shadow:0 5px 24px #17255412}a{color:#1d4ed8}</style></head><body><header><h1>${_html(name.text)}</h1><h2>${_html(headline.text)}</h2></header><main><section><h2>About</h2><p>${_html(about.text)}</p></section><section><h2>Skills</h2><p>${_html(skills.text)}</p></section><section><h2>Projects</h2><p>${_html(projects.text).replaceAll('\n','<br>')}</p></section><section><h2>Contact</h2><p>${_html(email.text)}</p><p>${_html(github.text)}</p></section></main></body></html>''';
 Future<void> export() async {final page=utf8.encode(html);final readme=utf8.encode('Static portfolio website\n\nOpen index.html locally or publish this folder with GitHub Pages / any static web host.\n');final archive=Archive()..addFile(ArchiveFile('index.html',page.length,page))..addFile(ArchiveFile('README.txt',readme.length,readme));final bytes=ZipEncoder().encode(archive);await FileSaver.instance.saveFile(name:'portfolio_website',bytes:Uint8List.fromList(bytes),ext:'zip',mimeType:MimeType.custom,customMimeType:'application/zip');}
 @override Widget build(BuildContext context)=>_builderScaffold(context,'Dynamic Portfolio Generator','Create a static website and export a repository-ready ZIP',Icons.web,ListView(padding:const EdgeInsets.all(16),children:[_appField(name,'Display name'),_appField(headline,'Professional headline'),_appField(about,'About me',max:4),_appField(skills,'Skills',max:2),_appField(projects,'Projects (one per line)',max:4),_appField(email,'Contact email'),_appField(github,'GitHub / LinkedIn URL'),FilledButton.icon(onPressed:export,icon:const Icon(Icons.archive),label:const Text('Export static website ZIP')),const SizedBox(height:8),const Text('The ZIP contains a ready-to-host index.html. Extract it into a repository and publish with GitHub Pages or any static hosting provider.') ]));
}
// ==========================================// 20. DOCUMENTS PAGE// ==========================================

class DocumentsPage extends StatefulWidget { const DocumentsPage({super.key}); @override State<DocumentsPage> createState()=>_DocumentsPageState(); }
class _DocumentsPageState extends State<DocumentsPage>{
 static const _storage=FlutterSecureStorage(); static const _keyName='bluepink_vault_aes_key_v1'; static const _dataKey='bluepink_vault_ciphertext_v1'; final _crypto=AesGcm.with256bits(); final title=TextEditingController(), username=TextEditingController(), secret=TextEditingController(), notes=TextEditingController(); List<Map<String,String>> entries=[]; bool unlocked=false, busy=false;
 Future<SecretKey> _getKey() async {var raw=await _storage.read(key:_keyName);if(raw==null){final key=await _crypto.newSecretKey();final b=await key.extractBytes();raw=base64Encode(b);await _storage.write(key:_keyName,value:raw);}return SecretKey(base64Decode(raw));}
 Future<void> _load() async {setState(()=>busy=true);try{final prefs=await SharedPreferences.getInstance();final packed=prefs.getString(_dataKey);if(packed!=null){final m=jsonDecode(packed) as Map<String,dynamic>;final box=SecretBox(base64Decode(m['cipher'] as String),nonce:base64Decode(m['nonce'] as String),mac:Mac(base64Decode(m['mac'] as String)));final clear=await _crypto.decrypt(box, secretKey:await _getKey());entries=(jsonDecode(utf8.decode(clear)) as List).map((e)=>Map<String,String>.from(e)).toList();}setState(()=>unlocked=true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Vault could not be opened: $e')));}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> _save() async {final prefs=await SharedPreferences.getInstance();final box=await _crypto.encrypt(utf8.encode(jsonEncode(entries)),secretKey:await _getKey());await prefs.setString(_dataKey,jsonEncode({'nonce':base64Encode(box.nonce),'cipher':base64Encode(box.cipherText),'mac':base64Encode(box.mac.bytes)}));}
 Future<void> _add() async {if(title.text.trim().isEmpty||secret.text.isEmpty)return;entries.add({'title':title.text.trim(),'username':username.text,'secret':secret.text,'notes':notes.text});await _save();title.clear();username.clear();secret.clear();notes.clear();setState((){});}
 Future<void> _delete(int i) async {entries.removeAt(i);await _save();setState((){});}
 @override void dispose(){for(final c in [title,username,secret,notes]){c.dispose();}super.dispose();}
 @override Widget build(BuildContext context)=>_builderScaffold(context,'Encrypted Credentials Vault','AES-256-GCM encrypted academic credential repository',Icons.lock,ListView(padding:const EdgeInsets.all(16),children:[if(!unlocked) ...[const Icon(Icons.enhanced_encryption,size:56,color:Colors.blue),const Text('Credentials are encrypted locally using AES-256-GCM. The encryption key is stored with the platform secure-storage facility.',textAlign:TextAlign.center),const SizedBox(height:12),FilledButton(onPressed:busy?null:_load,child:Text(busy?'Opening…':'Unlock / Create vault'))] else ...[_appField(title,'Credential title'),_appField(username,'Username / ID'),_appField(secret,'Password / credential value',obscure:true),_appField(notes,'Notes (optional)',max:2),FilledButton.icon(onPressed:_add,icon:const Icon(Icons.add),label:const Text('Encrypt and save')),const Divider(height:28),Text('Saved credentials (${entries.length})',style:Theme.of(context).textTheme.titleMedium),...entries.asMap().entries.map((e)=>Card(child:ListTile(leading:const Icon(Icons.verified_user),title:Text(e.value['title']??''),subtitle:Text('${e.value['username']??''}\n••••••••',maxLines:2),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>_delete(e.key)),onTap:()=>showDialog(context:context,builder:(_)=>AlertDialog(title:Text(e.value['title']??''),content:SelectableText('Username: ${e.value['username']}\nCredential: ${e.value['secret']}\nNotes: ${e.value['notes']}'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))])))))] ]));
}
// ==========================================// 21. MARKS TRACKER PAGE// ==========================================

class MarksTrackerPage extends StatelessWidget {
  const MarksTrackerPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Historical Academic Grade Distribution Matrices"),
      ),
    );
  }
}
// ==========================================// 22. ANSWER KEY PAGE// ==========================================

class AnswerKeyPage extends StatefulWidget { const AnswerKeyPage({super.key}); @override State<AnswerKeyPage> createState()=>_AnswerKeyPageState(); }
class _AnswerKeyPageState extends State<AnswerKeyPage>{final question=TextEditingController(), answer=TextEditingController(), working=TextEditingController();String result='';
 void verify() {
    final a = answer.text.trim();
    final w = working.text.trim();
    setState(() {
      result = '''Problem: ${question.text}

Step 1 — Identify the requirement
Restate what must be found and list the given information.

Step 2 — Select a method
Choose the relevant formula, rule or logical principle.

Step 3 — Show the working
${w.isEmpty ? 'No working was supplied. Add the calculation or reasoning to make the solution auditable.' : w}

Step 4 — State the proposed answer
$a

Step 5 — Verification
Substitute the answer back into the original condition or independently recompute it. Confirm units, signs and assumptions.

Verification status: ${w.isEmpty ? 'NOT VERIFIED — working required' : 'REVIEW REQUIRED — the supplied working is displayed, but this offline tool does not independently prove arbitrary answers.'}''';
    });
  }
 @override void dispose(){question.dispose();answer.dispose();working.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>_builderScaffold(context,'Verified Explanatory Answer Keys','Structured step-by-step rationale and verification worksheet',Icons.fact_check,ListView(padding:const EdgeInsets.all(16),children:[_appField(question,'Question / problem statement',max:4),_appField(working,'Your solution steps / calculation',max:5),_appField(answer,'Final answer'),FilledButton.icon(onPressed:verify,icon:const Icon(Icons.rule),label:const Text('Build explanation and verification checklist')),if(result.isNotEmpty)...[const SizedBox(height:16),_resultPanel('Solution rationale',result),OutlinedButton.icon(onPressed:()=>_copyText(context,result),icon:const Icon(Icons.copy),label:const Text('Copy solution'))],const SizedBox(height:12),const Text('Integrity note: this module creates a transparent solution structure. It does not label a response mathematically verified unless an independent checker or trusted answer source confirms it.') ]));
}
// ==========================================// 23. UNLOCK COINS PAGE// ==========================================

class UnlockCoinsPage extends StatelessWidget {
  const UnlockCoinsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ModuleCard(
          title: "Gamification Engine Loyalty Vault: Claim Resource Tokens",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: AppColors.pink,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${app.coins} tokens',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Modules explored: ${app.modulesExplored}  •  '
                    'Each new module you open earns 5 tokens.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: app.canClaimDailyBonus
                      ? () {
                    app.claimDailyBonus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Daily bonus claimed: +20 tokens'),
                      ),
                    );
                  }
                      : null,
                  icon: const Icon(Icons.card_giftcard),
                  label: Text(
                    app.canClaimDailyBonus
                        ? 'Claim daily bonus (+20)'
                        : 'Daily bonus already claimed today',
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => app.resetProgress(),
                  child: const Text('Reset tokens & progress'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================// 24. BOOK PDF PAGE// ==========================================
class BookPdfPage extends StatelessWidget {
  const BookPdfPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("PDF Core Reader Subsystem Engine Active")),
    );
  }
}
// ==========================================// 25. QUESTIONS FROM BOOK PAGE// ==========================================

class QuestionsFromBookPage extends StatelessWidget {
  const QuestionsFromBookPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Retrieval-Augmented Generation (RAG) Document Query Engine",
        ),
      ),
    );
  }
}
// ==========================================// 26. VIDEO CLASSES PAGE// ==========================================

class VideoClassesPage extends StatelessWidget {
  const VideoClassesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("HD Multi-Bitrate HLS Video Delivery Grid Network"),
      ),
    );
  }
}
// ==========================================// 27. CLASS RECORDING PAGE// ==========================================

class ClassRecordingPage extends StatelessWidget {
  const ClassRecordingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Cold Storage Cloud Video Lecture Storage Vault"),
      ),
    );
  }
}
// ==========================================// 28. VIRTUAL LAB PAGE// ==========================================

class VirtualLabPage extends StatelessWidget {
  const VirtualLabPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Vector Animation Laboratory Physics Workbench Canvas"),
      ),
    );
  }
}
// ==========================================// 29. TYPEWRITING PAGE// ==========================================

class TypewritingPage extends StatelessWidget {
  const TypewritingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Typing Performance telemetry tracking active (WPM/Accuracy metrics).",
        ),
      ),
    );
  }
}
// ==========================================// 30. TANPURA DROID PAGE// ==========================================

class TanpuraDroidPage extends StatelessWidget {
  const TanpuraDroidPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Algorithmic Fine Acoustic Tanpura Synthesis System Engine Running",
        ),
      ),
    );
  }
}
// ==========================================// 31. DOUBT PANEL PAGE// ==========================================

class DoubtPanelPage extends StatelessWidget {
  const DoubtPanelPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Global Shared Resolution Forum Hub Pipeline")),
    );
  }
}
// ==========================================// 32. DOUBT CHATBOT PAGE// ==========================================

class DoubtChatbotPage extends StatelessWidget {
  const DoubtChatbotPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "High-Availability Real-Time Dedicated Math/Code Transformer Chatbot Agent",
        ),
      ),
    );
  }
}
// ==========================================// 33. TEACHER DASHBOARD PAGE// ==========================================

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Educator Core Assignment Engine & Grading Pipelines"),
      ),
    );
  }
}
// ==========================================// 34. STUDENT MONITOR PAGE// ==========================================

class StudentMonitorPage extends StatelessWidget {
  const StudentMonitorPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Real-Time Automated Proctor Verification Protocol Panel Mode",
        ),
      ),
    );
  }
}
// ==========================================// 35. SCHEDULING EVENTS PAGE// ==========================================

class SchedulingEventsPage extends StatelessWidget {
  const SchedulingEventsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Live Sync Multi-Tenant Calendar Management Platform Configuration",
        ),
      ),
    );
  }
}
// ==========================================// 36. CENTER TEACHER PAGE// ==========================================

class CenterTeacherPage extends StatelessWidget {
  const CenterTeacherPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Geospatial Resource Distribution & Institutional Location Matrix Mapping",
        ),
      ),
    );
  }
}
// ==========================================// 37. EXAM ANALYTICS PAGE// ==========================================

class ExamAnalyticsPage extends StatelessWidget {
  const ExamAnalyticsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Advanced Performance Metric Distributions & Graph Engines",
        ),
      ),
    );
  }
}
// ==========================================// 38. USAGE ANALYTICS PAGE// ==========================================

class UsageAnalyticsPage extends StatelessWidget {
  const UsageAnalyticsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Infrastructure Computing Resource & Storage Telemetry Metrics",
        ),
      ),
    );
  }
}
// ==========================================// 39. PARENT PANE PAGE// ==========================================

class ParentPanePage extends StatelessWidget {
  const ParentPanePage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Parent Supervisory Tracking, Progress Auditing & Gateway Permissions",
        ),
      ),
    );
  }
}
// ==========================================// 40. ADMIN PANEL PAGE// ==========================================

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "System Settings Control Base, DB Query Routers & User Authorizations",
        ),
      ),
    );
  }
}
// ==========================================// 41. SUPERADMIN PANEL PAGE// ==========================================

class SuperadminPanelPage extends StatelessWidget {
  const SuperadminPanelPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Kernel Level Control, Tenant Allocations & System API Firewalls Instance",
        ),
      ),
    );
  }
}
// ==========================================// 42. FALLBACK/UNKNOWN ROUTE ROUTER STATE// ==========================================

class UnknownFallbackPage extends StatelessWidget {
  const UnknownFallbackPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Error 404: The specified AI module structure could not be resolved safely.",
        ),
      ),
    );
  }
}

// Progress Tracker + 7 charts for 100 demo people.
// Single file, NO extra packages: all charts are drawn with CustomPaint.
// Copy this over lib/main.dart and run:  flutter run -d chrome

// ==========================================================================
//  MODULE: Progress tracker + charts
// ==========================================================================

// void main() => runApp(const ProgressApp());

// ─────────────────────────────────────────────────────────────
// DEMO DATA (100 people, deterministic: same data on every run)
// ─────────────────────────────────────────────────────────────

const List<String> kBatches = ['Batch A', 'Batch B', 'Batch C', 'Batch D'];
const List<String> kStatuses = ['Completed', 'On track', 'Behind', 'At risk'];
const List<String> kSkills = [
  'MCQ',
  'Typing',
  'Coding',
  'Projects',
  'Revision',
];
const int kWeeks = 12;

const List<Color> kPalette = [
  Color(0xFF4DA3FF),
  Color(0xFF1E5BFF),
  Color(0xFFFF6FAE),
  Color(0xFFD81B72),
  Color(0xFF1740B8),
  Color(0xFFFF9EC9),
];

Color statusColor(String status) {
  switch (status) {
    case 'Completed':
      return const Color(0xFF1E5BFF);
    case 'On track':
      return const Color(0xFF4DA3FF);
    case 'Behind':
      return const Color(0xFFFF6FAE);
    default:
      return const Color(0xFFD81B72);
  }
}

class Person {
  final int id;
  final String name;
  final String batch;
  final List<double> weekly; // cumulative progress % for each of 12 weeks
  final double hours; // total hours studied
  final double score; // average test score
  final List<double> skills; // 5 skill levels (0..100)

  Person({
    required this.id,
    required this.name,
    required this.batch,
    required this.weekly,
    required this.hours,
    required this.score,
    required this.skills,
  });

  double get progress => weekly.last;

  String get status {
    if (progress >= 80) return 'Completed';
    if (progress >= 50) return 'On track';
    if (progress >= 25) return 'Behind';
    return 'At risk';
  }

  String get initials {
    final parts = name.split(' ');
    return '${parts.first[0]}${parts.last[0]}';
  }
}

List<Person> generatePeople() {
  final rnd = math.Random(42);
  const first = [
    'Aarav',
    'Vivaan',
    'Aditya',
    'Diya',
    'Ananya',
    'Ishaan',
    'Kavya',
    'Rohan',
    'Meera',
    'Arjun',
    'Sneha',
    'Karthik',
    'Priya',
    'Rahul',
    'Divya',
    'Vikram',
    'Nisha',
    'Suresh',
    'Lakshmi',
    'Manoj',
  ];
  const last = [
    'Kumar',
    'Sharma',
    'Reddy',
    'Iyer',
    'Nair',
    'Patel',
    'Singh',
    'Menon',
    'Das',
    'Gupta',
    'Rao',
  ];

  return List.generate(100, (i) {
    final pace = 1.5 + rnd.nextDouble() * 8.5; // average % gained per week
    double current = 0;
    final weekly = <double>[];
    for (var w = 0; w < kWeeks; w++) {
      current += pace * (0.5 + rnd.nextDouble());
      if (current > 100) current = 100;
      weekly.add(current);
    }
    final progress = weekly.last;
    final hours = 20 + pace * 12 + rnd.nextDouble() * 40;
    final score = (35 + progress * 0.5 + rnd.nextDouble() * 15)
        .clamp(0.0, 100.0)
        .toDouble();
    final skills = List.generate(
      kSkills.length,
          (_) => (progress * 0.6 + 20 + rnd.nextDouble() * 20)
          .clamp(0.0, 100.0)
          .toDouble(),
    );
    return Person(
      id: i + 1,
      name:
      '${first[i % first.length]} ${last[(i * 3 + i ~/ 20) % last.length]}',
      batch: kBatches[i % kBatches.length],
      weekly: weekly,
      hours: hours,
      score: score,
      skills: skills,
    );
  });
}

final List<Person> kPeople = generatePeople();

double avg(Iterable<double> values) {
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a + b) / values.length;
}

// ─────────────────────────────────────────────────────────────
// APP + TABS
// ─────────────────────────────────────────────────────────────

class ProgressApp extends StatelessWidget {
  const ProgressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress Tracker · 100 learners'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.insights), text: 'Dashboard'),
              Tab(icon: Icon(Icons.people), text: 'Tracker'),
              Tab(icon: Icon(Icons.psychology), text: 'AI Insights'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [ProgressDashboardPage(), TrackerPage(), AiInsightsPage()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DASHBOARD: KPI cards + 7 charts
// ─────────────────────────────────────────────────────────────

class ProgressDashboardPage extends StatelessWidget {
  const ProgressDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final people = kPeople;
    final sorted = [...people]
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final top10 = sorted.take(10).toList();
    final bottom10 = sorted.reversed.take(10).toList();

    // Chart 1: average progress per batch
    final avgByBatch = kBatches
        .map(
          (b) => avg(people.where((p) => p.batch == b).map((p) => p.progress)),
    )
        .toList();

    // Chart 2: weekly average (all / top 10 / bottom 10)
    List<double> weeklyAvg(List<Person> group) =>
        List.generate(kWeeks, (w) => avg(group.map((p) => p.weekly[w])));
    final weekLabels = List.generate(kWeeks, (w) => 'W${w + 1}');

    // Chart 3: status counts
    final statusCounts = kStatuses
        .map((s) => people.where((p) => p.status == s).length.toDouble())
        .toList();

    // Chart 4: score histogram (30-40 ... 90-100)
    final buckets = List<double>.filled(7, 0);
    for (final p in people) {
      final idx = ((p.score - 30) / 10).floor().clamp(0, 6).toInt();
      buckets[idx] += 1;
    }
    final bucketLabels = List.generate(
      7,
          (i) => '${30 + i * 10}-${40 + i * 10}',
    );

    // Chart 5: scatter (hours vs score)
    final scatterPts = people.map((p) => Offset(p.hours, p.score)).toList();
    final scatterColors = people
        .map((p) => kPalette[kBatches.indexOf(p.batch)].withAlpha(190))
        .toList();

    // Chart 7: radar (skills: everyone vs top 10)
    final skillAll = List.generate(
      kSkills.length,
          (s) => avg(people.map((p) => p.skills[s])),
    );
    final skillTop = List.generate(
      kSkills.length,
          (s) => avg(top10.map((p) => p.skills[s])),
    );

    final completed = people.where((p) => p.status == 'Completed').length;
    final atRisk = people.where((p) => p.status == 'At risk').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 900;
        final cardWidth = twoCols
            ? (constraints.maxWidth - 16 * 3) / 2
            : constraints.maxWidth - 32;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Kpi(
                  label: 'People',
                  value: '${people.length}',
                  icon: Icons.groups,
                  color: kPalette[0],
                ),
                Kpi(
                  label: 'Avg progress',
                  value:
                  '${avg(people.map((p) => p.progress)).toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: kPalette[1],
                ),
                Kpi(
                  label: 'Completed',
                  value: '$completed',
                  icon: Icons.verified,
                  color: kPalette[2],
                ),
                Kpi(
                  label: 'At risk',
                  value: '$atRisk',
                  icon: Icons.warning_amber,
                  color: kPalette[3],
                ),
                Kpi(
                  label: 'Avg score',
                  value: avg(people.map((p) => p.score)).toStringAsFixed(1),
                  icon: Icons.grade,
                  color: kPalette[4],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // 1. BAR
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: '1 · Bar chart',
                    subtitle: 'Average progress % by batch',
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: BarChartPainter(
                        values: avgByBatch,
                        labels: kBatches,
                        maxY: 100,
                        colors: kPalette,
                        valueSuffix: '%',
                      ),
                    ),
                  ),
                ),
                // 2. MULTI-LINE
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: '2 · Line chart',
                    subtitle:
                    'Weekly cumulative progress: all vs top 10 vs bottom 10',
                    footer: Legend(
                      labels: const ['All', 'Top 10', 'Bottom 10'],
                      colors: [kPalette[0], kPalette[1], kPalette[3]],
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: LineChartPainter(
                        series: [
                          LineSeries('All', weeklyAvg(people), kPalette[0]),
                          LineSeries('Top 10', weeklyAvg(top10), kPalette[1]),
                          LineSeries(
                            'Bottom 10',
                            weeklyAvg(bottom10),
                            kPalette[3],
                          ),
                        ],
                        xLabels: weekLabels,
                        maxY: 100,
                      ),
                    ),
                  ),
                ),
                // 3. DONUT
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: '3 · Donut chart',
                    subtitle: 'Status distribution',
                    child: Row(
                      children: [
                        SizedBox(
                          width: 170,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: DonutPainter(
                              values: statusCounts,
                              colors: kStatuses.map(statusColor).toList(),
                              centerText: '${people.length}',
                              centerSub: 'people',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < kStatuses.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: statusColor(kStatuses[i]),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(kStatuses[i])),
                                      Text(
                                        '${statusCounts[i].toInt()}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 4. HISTOGRAM
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: '4 · Histogram',
                    subtitle:
                    'Test score distribution (number of people per score range)',
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: BarChartPainter(
                        values: buckets,
                        labels: bucketLabels,
                        maxY: ((buckets.reduce(math.max) / 5).ceil() * 5)
                            .toDouble(),
                        colors: [kPalette[5]],
                        gapFraction: 0.05,
                      ),
                    ),
                  ),
                ),
                // 5. SCATTER
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: '5 · Scatter plot',
                    subtitle:
                    'Hours studied (x) vs test score (y), colored by batch',
                    footer: Legend(
                      labels: kBatches,
                      colors: kPalette.take(4).toList(),
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: ScatterPainter(
                        points: scatterPts,
                        colors: scatterColors,
                        maxX: 200,
                      ),
                    ),
                  ),
                ),
                // 6. HORIZONTAL BAR
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: '6 · Horizontal bar chart',
                    subtitle: 'Top 10 learners by progress %',
                    height: 300,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: HBarPainter(
                        labels: top10.map((p) => p.name).toList(),
                        values: top10.map((p) => p.progress).toList(),
                        color: kPalette[1],
                      ),
                    ),
                  ),
                ),
                // 7. RADAR
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: '7 · Radar chart',
                    subtitle: 'Average skill levels: everyone vs top 10',
                    height: 300,
                    footer: Legend(
                      labels: const ['Everyone', 'Top 10'],
                      colors: [kPalette[0], kPalette[2]],
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: RadarPainter(
                        axes: kSkills,
                        series: [skillAll, skillTop],
                        colors: [kPalette[0], kPalette[2]],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TRACKER: searchable, filterable list of all 100 people
// ─────────────────────────────────────────────────────────────

class TrackerPage extends StatefulWidget {
  const TrackerPage({super.key});

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  String query = '';
  String statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final list = kPeople
        .where(
          (p) =>
      (statusFilter == 'All' || p.status == statusFilter) &&
          p.name.toLowerCase().contains(query.toLowerCase()),
    )
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final s in ['All', ...kStatuses])
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: statusFilter == s,
                    onSelected: (_) => setState(() => statusFilter = s),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${list.length} people',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) => PersonTile(person: list[i]),
          ),
        ),
      ],
    );
  }
}

class PersonTile extends StatelessWidget {
  final Person person;
  const PersonTile({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(person.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showPersonSheet(context, person),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(60),
                child: Text(person.initials),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '#${person.id}  ${person.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '${person.progress.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${person.batch} · ${person.status}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: person.progress / 100,
                        minHeight: 8,
                        color: color,
                        backgroundColor: AppColors.line,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showPersonSheet(BuildContext context, Person p) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${p.batch} · ${p.status} · ${p.hours.toStringAsFixed(0)} h studied · score ${p.score.toStringAsFixed(1)}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          const Text(
            'Weekly progress',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              size: Size.infinite,
              painter: LineChartPainter(
                series: [
                  LineSeries('Progress', p.weekly, statusColor(p.status)),
                ],
                xLabels: List.generate(kWeeks, (w) => 'W${w + 1}'),
                maxY: 100,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Skills', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < kSkills.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(kSkills[i])),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: p.skills[i] / 100,
                        minHeight: 8,
                        color: kPalette[i % kPalette.length],
                        backgroundColor: AppColors.line,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(p.skills[i].toStringAsFixed(0)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'AI insights',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Forecast at week 20: ${kMl.forecasts[p.id - 1].at(20).toStringAsFixed(0)}%  ·  '
                'completion probability: ${(kMl.completeProb[p.id - 1] * 100).toStringAsFixed(0)}%  ·  '
                'group: ${kClusterNames[kMl.clusters.assignment[p.id - 1]]}',
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          for (final tip in coachTips(p))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: AppColors.pink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip)),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const Kpi({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final double height;
  const ChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            SizedBox(height: height, width: double.infinity, child: child),
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }
}

class Legend extends StatelessWidget {
  final List<String> labels;
  final List<Color> colors;
  const Legend({super.key, required this.labels, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (var i = 0; i < labels.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(labels[i], style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ML / AI ENGINE (pure Dart, trains on-device in milliseconds)
//  1. Linear regression  -> forecast each person's progress
//  2. Logistic regression -> probability of completing the course
//  3. K-means clustering  -> group learners by behaviour
//  4. Rule-based coach    -> personalised recommendations
// ─────────────────────────────────────────────────────────────

const List<String> kClusterNames = [
  'Top performers',
  'Steady learners',
  'Slow starters',
  'Need support',
];
const List<String> kClusterShort = ['Top', 'Steady', 'Slow', 'Support'];
const List<String> kFeatureNames = [
  'Week-6 progress',
  'Early weekly pace',
  'Hours studied',
  'Test score',
];

final List<Color> kClusterColors = [
  statusColor('Completed'),
  statusColor('On track'),
  statusColor('Behind'),
  statusColor('At risk'),
];

double sigmoid(double z) => 1 / (1 + math.exp(-z));

// ---- 1. Linear regression (least squares) ----

class Forecast {
  final double slope; // % progress gained per week
  final double intercept;
  const Forecast(this.slope, this.intercept);

  double at(int week) =>
      (intercept + slope * week).clamp(0.0, 100.0).toDouble();

  /// Week in which the trend line reaches 100%, or null if there is no upward trend.
  double? get etaWeek {
    if (slope < 0.05) return null;
    return (100 - intercept) / slope;
  }
}

Forecast fitLine(List<double> ys) {
  final n = ys.length;
  final mx = (n + 1) / 2;
  final my = avg(ys);
  var sxy = 0.0;
  var sxx = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = (i + 1) - mx;
    sxy += dx * (ys[i] - my);
    sxx += dx * dx;
  }
  final slope = sxx == 0 ? 0.0 : sxy / sxx;
  return Forecast(slope, my - slope * mx);
}

// ---- 2. Logistic regression (gradient descent) ----

/// Features use only the FIRST 6 WEEKS, to predict who finishes (>= 80%).
List<double> mlFeatures(Person p) => [
  p.weekly[5],
  fitLine(p.weekly.sublist(0, 6)).slope,
  p.hours,
  p.score,
];

class TrainResult {
  final List<double> w;
  final double b;
  final List<double> mean;
  final List<double> std;
  final List<double> trainAcc;
  final List<double> testAcc;

  TrainResult(this.w, this.b, this.mean, this.std, this.trainAcc, this.testAcc);

  double predict(List<double> x) {
    var s = b;
    for (var j = 0; j < w.length; j++) {
      s += w[j] * (x[j] - mean[j]) / std[j];
    }
    return sigmoid(s);
  }
}

TrainResult trainLogistic(List<Person> people) {
  final xs = people.map(mlFeatures).toList();
  final ys = people.map((p) => p.progress >= 80 ? 1.0 : 0.0).toList();

  // 70% train / 30% test split
  final trainIdx = <int>[];
  final testIdx = <int>[];
  for (var i = 0; i < people.length; i++) {
    if (i % 10 < 7) {
      trainIdx.add(i);
    } else {
      testIdx.add(i);
    }
  }

  final d = xs.first.length;
  final mean = List<double>.filled(d, 0);
  final std = List<double>.filled(d, 1);
  for (var j = 0; j < d; j++) {
    final col = trainIdx.map((i) => xs[i][j]).toList();
    final m = avg(col);
    final variance = avg(col.map((v) => (v - m) * (v - m)));
    mean[j] = m;
    std[j] = variance < 1e-9 ? 1.0 : math.sqrt(variance);
  }

  final z = xs
      .map((x) => List.generate(d, (j) => (x[j] - mean[j]) / std[j]))
      .toList();

  final w = List<double>.filled(d, 0);
  var b = 0.0;
  const lr = 0.4;
  const epochs = 400;

  double prob(int i) {
    var s = b;
    for (var j = 0; j < d; j++) {
      s += w[j] * z[i][j];
    }
    return sigmoid(s);
  }

  double accuracy(List<int> idx) {
    var ok = 0;
    for (final i in idx) {
      if ((prob(i) >= 0.5) == (ys[i] == 1.0)) ok++;
    }
    return 100 * ok / idx.length;
  }

  final trainAcc = <double>[];
  final testAcc = <double>[];
  for (var e = 1; e <= epochs; e++) {
    final gw = List<double>.filled(d, 0);
    var gb = 0.0;
    for (final i in trainIdx) {
      final err = prob(i) - ys[i];
      for (var j = 0; j < d; j++) {
        gw[j] += err * z[i][j];
      }
      gb += err;
    }
    for (var j = 0; j < d; j++) {
      w[j] -= lr * gw[j] / trainIdx.length;
    }
    b -= lr * gb / trainIdx.length;
    if (e % 20 == 0) {
      trainAcc.add(accuracy(trainIdx));
      testAcc.add(accuracy(testIdx));
    }
  }
  return TrainResult(w, b, mean, std, trainAcc, testAcc);
}

// ---- 3. K-means clustering ----

class ClusterResult {
  final List<int> assignment; // cluster rank per person (0 = best group)
  final List<int> sizes;
  final List<double> avgProgress;
  final List<double> avgScore;
  final List<double> avgHours;
  ClusterResult(
      this.assignment,
      this.sizes,
      this.avgProgress,
      this.avgScore,
      this.avgHours,
      );
}

ClusterResult kMeans(List<Person> people, int k) {
  const d = 3;
  final raw =
  people.map((p) => <double>[p.progress, p.score, p.hours]).toList();

  final mean = List<double>.filled(d, 0);
  final std = List<double>.filled(d, 1);
  for (var j = 0; j < d; j++) {
    final col = raw.map((r) => r[j]).toList();
    final m = avg(col);
    final variance = avg(col.map((v) => (v - m) * (v - m)));
    mean[j] = m;
    std[j] = variance < 1e-9 ? 1.0 : math.sqrt(variance);
  }
  final z = raw
      .map((r) => List<double>.generate(d, (j) => (r[j] - mean[j]) / std[j]))
      .toList();

  // Deterministic initial centroids: k distinct random people
  final rnd = math.Random(7);
  final chosen = <int>[];
  while (chosen.length < k) {
    final i = rnd.nextInt(people.length);
    if (!chosen.contains(i)) chosen.add(i);
  }
  final cent = chosen.map((i) => List<double>.from(z[i])).toList();
  final assign = List<int>.filled(people.length, 0);

  for (var iter = 0; iter < 30; iter++) {
    for (var i = 0; i < people.length; i++) {
      var best = 0;
      var bestDist = double.infinity;
      for (var c = 0; c < k; c++) {
        var dist = 0.0;
        for (var j = 0; j < d; j++) {
          final diff = z[i][j] - cent[c][j];
          dist += diff * diff;
        }
        if (dist < bestDist) {
          bestDist = dist;
          best = c;
        }
      }
      assign[i] = best;
    }
    final sums = List.generate(k, (_) => List<double>.filled(d, 0));
    final counts = List<int>.filled(k, 0);
    for (var i = 0; i < people.length; i++) {
      counts[assign[i]]++;
      for (var j = 0; j < d; j++) {
        sums[assign[i]][j] += z[i][j];
      }
    }
    for (var c = 0; c < k; c++) {
      if (counts[c] > 0) {
        for (var j = 0; j < d; j++) {
          cent[c][j] = sums[c][j] / counts[c];
        }
      }
    }
  }

  // Rank clusters by average progress so rank 0 = strongest group
  final rawAvgProgress = List.generate(k, (c) {
    final members = [
      for (var i = 0; i < people.length; i++)
        if (assign[i] == c) people[i].progress,
    ];
    return avg(members);
  });
  final order = List<int>.generate(k, (c) => c)
    ..sort((a, b) => rawAvgProgress[b].compareTo(rawAvgProgress[a]));
  final rankOf = List<int>.filled(k, 0);
  for (var r = 0; r < k; r++) {
    rankOf[order[r]] = r;
  }
  final ranked = assign.map((c) => rankOf[c]).toList();

  List<double> groupAvg(double Function(Person) pick) => List.generate(k, (r) {
    final members = [
      for (var i = 0; i < people.length; i++)
        if (ranked[i] == r) pick(people[i]),
    ];
    return avg(members);
  });

  return ClusterResult(
    ranked,
    List.generate(k, (r) => ranked.where((x) => x == r).length),
    groupAvg((p) => p.progress),
    groupAvg((p) => p.score),
    groupAvg((p) => p.hours),
  );
}

// ---- Run everything once ----

class MlResult {
  final List<Forecast> forecasts; // index = person id - 1
  final List<double> completeProb; // probability of finishing (>= 80%)
  final TrainResult model;
  final ClusterResult clusters;
  MlResult(this.forecasts, this.completeProb, this.model, this.clusters);
}

MlResult runMl(List<Person> people) {
  final model = trainLogistic(people);
  return MlResult(
    people.map((p) => fitLine(p.weekly)).toList(),
    people.map((p) => model.predict(mlFeatures(p))).toList(),
    model,
    kMeans(people, 4),
  );
}

final MlResult kMl = runMl(kPeople);

// ---- 4. Rule-based coach ----

List<String> coachTips(Person p) {
  final i = p.id - 1;
  final prob = kMl.completeProb[i];
  final f = kMl.forecasts[i];
  final tips = <String>[];

  if (p.progress < 80 && prob < 0.4) {
    tips.add(
      'High risk of not finishing (${((1 - prob) * 100).round()}%). Arrange a mentor check-in this week.',
    );
  }
  if (p.progress < 80 && f.slope < 5) {
    tips.add(
      'Pace is ${f.slope.toStringAsFixed(1)}% per week. Add about 30 minutes of daily practice.',
    );
  }
  var weakest = 0;
  for (var s = 1; s < kSkills.length; s++) {
    if (p.skills[s] < p.skills[weakest]) weakest = s;
  }
  if (p.skills[weakest] < 55) {
    tips.add(
      'Weakest skill is ${kSkills[weakest]} (${p.skills[weakest].toStringAsFixed(0)}). Give it extra practice.',
    );
  }
  if (p.progress >= 80) {
    tips.add(
      'Course nearly done. Suggest an advanced module or a peer-mentor role.',
    );
  }
  if (tips.isEmpty) {
    tips.add('Healthy pace. Keep the current routine.');
  }
  return tips;
}

// ─────────────────────────────────────────────────────────────
// AI INSIGHTS PAGE
// ─────────────────────────────────────────────────────────────

class AiInsightsPage extends StatelessWidget {
  const AiInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final people = kPeople;
    final ml = kMl;
    final model = ml.model;

    final finishers = ml.forecasts.where((f) => f.at(20) >= 80).length;
    final highRisk = people
        .where((p) => p.progress < 80 && ml.completeProb[p.id - 1] < 0.4)
        .length;

    // Feature importance (share of |weight|)
    final absW = model.w.map((v) => v.abs()).toList();
    final totalW = absW.fold<double>(0, (a, b) => a + b);
    final importance =
    absW.map((v) => totalW == 0 ? 0.0 : v / totalW * 100).toList();

    // Forecast chart: weeks 1-12 actual, 13-20 predicted
    final actualAvg = List.generate(
      kWeeks,
          (w) => avg(people.map((p) => p.weekly[w])),
    );
    final forecastAvg = List.generate(
      20,
          (w) =>
      w < kWeeks ? actualAvg[w] : avg(ml.forecasts.map((f) => f.at(w + 1))),
    );
    final labels20 = List.generate(20, (w) => 'W${w + 1}');

    // Watchlist: lowest completion probability among unfinished learners
    final watch = people.where((p) => p.progress < 80).toList()
      ..sort(
            (a, b) =>
            ml.completeProb[a.id - 1].compareTo(ml.completeProb[b.id - 1]),
      );
    final top = watch.take(10).toList();

    final cl = ml.clusters;
    final maxSize = cl.sizes.reduce(math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 900;
        final cardWidth = twoCols
            ? (constraints.maxWidth - 16 * 3) / 2
            : constraints.maxWidth - 32;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Kpi(
                  label: 'Test accuracy',
                  value: '${model.testAcc.last.toStringAsFixed(0)}%',
                  icon: Icons.fact_check,
                  color: kPalette[1],
                ),
                Kpi(
                  label: 'Train accuracy',
                  value: '${model.trainAcc.last.toStringAsFixed(0)}%',
                  icon: Icons.school,
                  color: kPalette[0],
                ),
                Kpi(
                  label: 'Finish by wk 20',
                  value: '$finishers',
                  icon: Icons.flag,
                  color: kPalette[2],
                ),
                Kpi(
                  label: 'High-risk',
                  value: '$highRisk',
                  icon: Icons.warning_amber,
                  color: kPalette[3],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Interactive predictor
                SizedBox(width: cardWidth, child: const PredictorCard()),

                // Learning curve
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: 'Model learning curve',
                    subtitle:
                    'Logistic regression accuracy (%) vs training epoch',
                    footer: Legend(
                      labels: const ['Train (70 people)', 'Test (30 people)'],
                      colors: [kPalette[0], kPalette[2]],
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: LineChartPainter(
                        series: [
                          LineSeries('Train', model.trainAcc, kPalette[0]),
                          LineSeries('Test', model.testAcc, kPalette[2]),
                        ],
                        xLabels: List.generate(
                          model.trainAcc.length,
                              (i) => '${(i + 1) * 20}',
                        ),
                        maxY: 100,
                      ),
                    ),
                  ),
                ),

                // Feature importance
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: 'What drives completion?',
                    subtitle: 'Feature importance (share of model weight)',
                    height: 200,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: HBarPainter(
                        labels: kFeatureNames,
                        values: importance,
                        color: kPalette[4],
                      ),
                    ),
                  ),
                ),

                // Forecast
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: 'Progress forecast to week 20',
                    subtitle: 'Average of per-person linear regression trends',
                    footer: Legend(
                      labels: const ['Actual (W1-W12)', 'Forecast (W13-W20)'],
                      colors: [kPalette[0], kPalette[2]],
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: LineChartPainter(
                        series: [
                          LineSeries('Forecast', forecastAvg, kPalette[2]),
                          LineSeries('Actual', actualAvg, kPalette[0]),
                        ],
                        xLabels: labels20,
                        maxY: 100,
                      ),
                    ),
                  ),
                ),

                // K-means scatter
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: 'K-means learner groups',
                    subtitle:
                    'Hours studied (x) vs test score (y), colored by cluster',
                    footer: Legend(
                      labels: kClusterNames,
                      colors: kClusterColors,
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: ScatterPainter(
                        points: people
                            .map((p) => Offset(p.hours, p.score))
                            .toList(),
                        colors: [
                          for (final c in cl.assignment)
                            kClusterColors[c].withAlpha(210),
                        ],
                        maxX: 200,
                      ),
                    ),
                  ),
                ),

                // Cluster sizes + table
                SizedBox(
                  width: cardWidth,
                  child: ChartCard(
                    title: 'Cluster sizes',
                    subtitle: 'People per group, with group averages below',
                    height: 180,
                    footer: Column(
                      children: [
                        for (var c = 0; c < kClusterNames.length; c++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: kClusterColors[c],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    kClusterNames[c],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  '${cl.avgProgress[c].toStringAsFixed(0)}% · ${cl.avgScore[c].toStringAsFixed(0)} pts · ${cl.avgHours[c].toStringAsFixed(0)} h',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: BarChartPainter(
                        values: cl.sizes.map((s) => s.toDouble()).toList(),
                        labels: kClusterShort,
                        maxY: ((maxSize / 10).ceil() * 10).toDouble(),
                        colors: kClusterColors,
                      ),
                    ),
                  ),
                ),

                // Watchlist
                SizedBox(
                  width: cardWidth,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI watchlist',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            '10 learners least likely to finish. Tap for details.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final p in top) WatchTile(person: p),
                        ],
                      ),
                    ),
                  ),
                ),

                // How it works
                SizedBox(
                  width: cardWidth,
                  child: const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How the AI works',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Linear regression fits a trend line through each person\'s 12 weekly points and extends it to week 20.',
                          ),
                          SizedBox(height: 6),
                          Text(
                            '• Logistic regression learns from week-1 to week-6 data (progress, pace, hours, score) to predict who finishes at 80% or more. It trains on 70 people and is checked on 30 unseen people.',
                          ),
                          SizedBox(height: 6),
                          Text(
                            '• K-means groups people into 4 clusters by progress, score and hours.',
                          ),
                          SizedBox(height: 6),
                          Text(
                            '• Rules turn the results into coaching tips. Everything runs on-device, with no packages and no server.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class WatchTile extends StatelessWidget {
  final Person person;
  const WatchTile({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final i = person.id - 1;
    final risk = (1 - kMl.completeProb[i]) * 100;
    final f = kMl.forecasts[i];
    final eta = f.etaWeek;
    final etaText = eta == null
        ? 'no upward trend'
        : (eta > 52 ? 'finish after week 52' : 'finish ~week ${eta.ceil()}');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: () => showPersonSheet(context, person),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: statusColor('At risk').withAlpha(60),
        child: Text(person.initials, style: const TextStyle(fontSize: 11)),
      ),
      title: Text('#${person.id}  ${person.name}'),
      subtitle: Text(
        'Now ${person.progress.toStringAsFixed(0)}% · week 20: ${f.at(20).toStringAsFixed(0)}% · $etaText\n${coachTips(person).first}',
        style: const TextStyle(fontSize: 12),
      ),
      isThreeLine: true,
      trailing: Text(
        '${risk.toStringAsFixed(0)}%\nrisk',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: statusColor('At risk'),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Interactive "what-if" predictor using the trained logistic model.
class PredictorCard extends StatefulWidget {
  const PredictorCard({super.key});

  @override
  State<PredictorCard> createState() => _PredictorCardState();
}

class _PredictorCardState extends State<PredictorCard> {
  double week6 = 35;
  double pace = 6;
  double hours = 100;
  double score = 70;

  Widget slider(
      String label,
      double value,
      double min,
      double max,
      ValueChanged<double> onChanged,
      String suffix,
      ) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '${value.toStringAsFixed(0)}$suffix',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prob = kMl.model.predict([week6, pace, hours, score]);
    final color = prob >= 0.7
        ? statusColor('Completed')
        : (prob >= 0.4 ? statusColor('Behind') : statusColor('At risk'));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Try the model',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Move the sliders to predict a new learner\'s chance of finishing',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            slider(
              'Week-6 progress',
              week6,
              0,
              70,
                  (v) => setState(() => week6 = v),
              '%',
            ),
            slider(
              'Weekly pace',
              pace,
              0,
              15,
                  (v) => setState(() => pace = v),
              '%',
            ),
            slider(
              'Hours studied',
              hours,
              0,
              200,
                  (v) => setState(() => hours = v),
              'h',
            ),
            slider(
              'Test score',
              score,
              30,
              100,
                  (v) => setState(() => score = v),
              '',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${(prob * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'chance of completing (80%+)',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: prob,
                          minHeight: 10,
                          color: color,
                          backgroundColor: AppColors.line,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHART PAINTERS
// ─────────────────────────────────────────────────────────────

void drawText(
    Canvas canvas,
    String text,
    Offset offset, {
      double size = 10,
      Color color = const Color(0xB312224A),
      TextAlign align = TextAlign.left,
      double? maxWidth,
      FontWeight? weight,
    }) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, color: color, fontWeight: weight),
    ),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);

  var dx = offset.dx;
  if (align == TextAlign.center) {
    dx -= tp.width / 2;
  } else if (align == TextAlign.right) {
    dx -= tp.width;
  }
  tp.paint(canvas, Offset(dx, offset.dy - tp.height / 2));
}

void drawYGrid(
    Canvas canvas,
    Rect plot,
    double maxY,
    int steps, {
      String suffix = '',
    }) {
  final paint = Paint()
    ..color = const Color(0x2212224A)
    ..strokeWidth = 1;
  for (var i = 0; i <= steps; i++) {
    final y = plot.bottom - plot.height * i / steps;
    canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    drawText(
      canvas,
      '${(maxY * i / steps).round()}$suffix',
      Offset(plot.left - 6, y),
      align: TextAlign.right,
    );
  }
}

/// Used for chart 1 (bar) and chart 4 (histogram).
class BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double maxY;
  final List<Color> colors;
  final double gapFraction;
  final String valueSuffix;

  BarChartPainter({
    required this.values,
    required this.labels,
    required this.maxY,
    required this.colors,
    this.gapFraction = 0.35,
    this.valueSuffix = '',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(36, 14, size.width - 8, size.height - 26);
    drawYGrid(canvas, plot, maxY, 4);
    final n = values.length;
    final slot = plot.width / n;
    final barW = slot * (1 - gapFraction);

    for (var i = 0; i < n; i++) {
      final x = plot.left + slot * i + (slot - barW) / 2;
      final h = plot.height * (values[i] / maxY).clamp(0.0, 1.0);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, plot.bottom - h, barW, h),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = colors[i % colors.length]);
      final text = values[i] % 1 == 0
          ? values[i].toStringAsFixed(0)
          : values[i].toStringAsFixed(1);
      drawText(
        canvas,
        '$text$valueSuffix',
        Offset(x + barW / 2, plot.bottom - h - 8),
        align: TextAlign.center,
        color: AppColors.ink,
      );
      drawText(
        canvas,
        labels[i],
        Offset(x + barW / 2, plot.bottom + 12),
        align: TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineSeries {
  final String name;
  final List<double> values;
  final Color color;
  const LineSeries(this.name, this.values, this.color);
}

/// Used for chart 2 (multi-line) and the per-person weekly chart.
class LineChartPainter extends CustomPainter {
  final List<LineSeries> series;
  final List<String> xLabels;
  final double maxY;

  LineChartPainter({
    required this.series,
    required this.xLabels,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(40, 14, size.width - 12, size.height - 26);
    drawYGrid(canvas, plot, maxY, 4, suffix: '%');
    final n = xLabels.length;
    final step = n > 8 ? 2 : 1;
    double xAt(int i) => plot.left + plot.width * i / (n - 1);

    for (var i = 0; i < n; i += step) {
      drawText(
        canvas,
        xLabels[i],
        Offset(xAt(i), plot.bottom + 12),
        align: TextAlign.center,
      );
    }

    for (final s in series) {
      final path = Path();
      for (var i = 0; i < s.values.length; i++) {
        final y =
            plot.bottom - plot.height * (s.values[i] / maxY).clamp(0.0, 1.0);
        if (i == 0) {
          path.moveTo(xAt(i), y);
        } else {
          path.lineTo(xAt(i), y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < s.values.length; i++) {
        final y =
            plot.bottom - plot.height * (s.values[i] / maxY).clamp(0.0, 1.0);
        canvas.drawCircle(Offset(xAt(i), y), 3, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Chart 3.
class DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final String centerText;
  final String centerSub;

  DonutPainter({
    required this.values,
    required this.colors,
    required this.centerText,
    required this.centerSub,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final stroke = radius * 0.35;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    ).deflate(stroke / 2);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(
        rect,
        start,
        math.max(sweep - 0.03, 0.001),
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
    drawText(
      canvas,
      centerText,
      center.translate(0, -8),
      size: 24,
      color: AppColors.ink,
      align: TextAlign.center,
      weight: FontWeight.bold,
    );
    drawText(
      canvas,
      centerSub,
      center.translate(0, 14),
      size: 11,
      align: TextAlign.center,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Chart 5.
class ScatterPainter extends CustomPainter {
  final List<Offset> points; // dx = hours, dy = score
  final List<Color> colors;
  final double maxX;

  ScatterPainter({
    required this.points,
    required this.colors,
    required this.maxX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(36, 14, size.width - 12, size.height - 26);
    drawYGrid(canvas, plot, 100, 4);
    for (var i = 0; i <= 4; i++) {
      final x = plot.left + plot.width * i / 4;
      drawText(
        canvas,
        '${(maxX * i / 4).round()}h',
        Offset(x, plot.bottom + 12),
        align: TextAlign.center,
      );
    }
    for (var i = 0; i < points.length; i++) {
      final x = plot.left + plot.width * (points[i].dx / maxX).clamp(0.0, 1.0);
      final y =
          plot.bottom - plot.height * (points[i].dy / 100).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Chart 6.
class HBarPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color color;

  HBarPainter({
    required this.labels,
    required this.values,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelW = 104.0;
    final plot = Rect.fromLTRB(labelW, 4, size.width - 40, size.height - 4);
    final n = values.length;
    final rowH = plot.height / n;
    final gridPaint = Paint()
      ..color = const Color(0x2212224A)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = plot.left + plot.width * i / 4;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
    }
    for (var i = 0; i < n; i++) {
      final cy = plot.top + rowH * i + rowH / 2;
      final w = plot.width * (values[i] / 100).clamp(0.0, 1.0);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(plot.left, cy - rowH * 0.3, w, rowH * 0.6),
        topRight: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      drawText(
        canvas,
        labels[i],
        Offset(plot.left - 8, cy),
        align: TextAlign.right,
        maxWidth: labelW - 12,
        size: 11,
      );
      drawText(
        canvas,
        '${values[i].toStringAsFixed(0)}%',
        Offset(plot.left + w + 6, cy),
        color: AppColors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Chart 7.
class RadarPainter extends CustomPainter {
  final List<String> axes;
  final List<List<double>> series;
  final List<Color> colors;

  RadarPainter({
    required this.axes,
    required this.series,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 32;
    final n = axes.length;

    Offset point(int i, double fraction) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      return center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * fraction);
    }

    final ringPaint = Paint()
      ..color = const Color(0x3312224A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = point(i, ring / 4);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, ringPaint);
    }

    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, point(i, 1), ringPaint);
      drawText(
        canvas,
        axes[i],
        point(i, 1 + 18 / radius),
        align: TextAlign.center,
        size: 11,
        color: AppColors.ink,
      );
    }

    for (var s = 0; s < series.length; s++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = point(i, (series[s][i] / 100).clamp(0.0, 1.0));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = colors[s].withAlpha(60));
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[s]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================================================
//  MODULE: OMR exam
// ==========================================================================

// ============================================================
// APP
// ============================================================

class OmrExamApp extends StatelessWidget {
  const OmrExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const OmrExamPage();
  }
}

// ============================================================
// QUESTION MODEL
// ============================================================

class OmrQuestion {
  final int number;
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final int marks;

  const OmrQuestion({
    required this.number,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.marks = 1,
  });
}

// ============================================================
// EXAM DATA
// ============================================================

class OmrExamData {
  static const List<OmrQuestion> questions = [
    OmrQuestion(
      number: 1,
      question: 'What is the SI unit of force?',
      options: ['Joule', 'Newton', 'Watt', 'Pascal'],
      correctAnswer: 1,
      explanation: 'The SI unit of force is Newton (N).',
    ),
    OmrQuestion(
      number: 2,
      question:
      'Which law states that every action has an equal and opposite reaction?',
      options: [
        'Newton First Law',
        'Newton Second Law',
        'Newton Third Law',
        'Law of Gravitation',
      ],
      correctAnswer: 2,
      explanation:
      'Newton Third Law states that every action has an equal and opposite reaction.',
    ),
    OmrQuestion(
      number: 3,
      question: 'What is the formula for force?',
      options: ['F = mv', 'F = ma', 'F = m/a', 'F = a/m'],
      correctAnswer: 1,
      explanation: 'According to Newton Second Law, F = ma.',
    ),
    OmrQuestion(
      number: 4,
      question: 'Which quantity is a vector quantity?',
      options: ['Mass', 'Temperature', 'Velocity', 'Time'],
      correctAnswer: 2,
      explanation: 'Velocity has both magnitude and direction.',
    ),
    OmrQuestion(
      number: 5,
      question:
      'What is the approximate acceleration due to gravity near Earth?',
      options: ['9.8 m/s²', '5.6 m/s²', '15.2 m/s²', '20 m/s²'],
      correctAnswer: 0,
      explanation:
      'The acceleration due to gravity near Earth is approximately 9.8 m/s².',
    ),
    OmrQuestion(
      number: 6,
      question: 'Which of the following is a scalar quantity?',
      options: ['Velocity', 'Force', 'Displacement', 'Mass'],
      correctAnswer: 3,
      explanation: 'Mass has magnitude but no direction, so it is a scalar.',
    ),
    OmrQuestion(
      number: 7,
      question: 'What is the SI unit of energy?',
      options: ['Newton', 'Joule', 'Watt', 'Volt'],
      correctAnswer: 1,
      explanation: 'The SI unit of energy is Joule (J).',
    ),
    OmrQuestion(
      number: 8,
      question: 'Which instrument is used to measure electric current?',
      options: ['Voltmeter', 'Ammeter', 'Barometer', 'Thermometer'],
      correctAnswer: 1,
      explanation: 'An ammeter measures electric current.',
    ),
    OmrQuestion(
      number: 9,
      question: 'What is the approximate speed of light in vacuum?',
      options: ['3 × 10⁸ m/s', '3 × 10⁶ m/s', '3 × 10⁴ m/s', '3 × 10² m/s'],
      correctAnswer: 0,
      explanation: 'The speed of light in vacuum is approximately 3 × 10⁸ m/s.',
    ),
    OmrQuestion(
      number: 10,
      question: 'Which particle has a negative electric charge?',
      options: ['Proton', 'Neutron', 'Electron', 'Photon'],
      correctAnswer: 2,
      explanation: 'An electron has a negative electric charge.',
    ),
  ];
}

// ============================================================
// MAIN EXAM PAGE
// ============================================================

class OmrExamPage extends StatefulWidget {
  const OmrExamPage({super.key});

  @override
  State<OmrExamPage> createState() => _OmrExamPageState();
}

class _OmrExamPageState extends State<OmrExamPage> {
  int currentQuestionIndex = 0;

  final Map<int, int> selectedAnswers = {};

  final Set<int> markedForReview = {};

  bool submitted = false;

  OmrQuestion get currentQuestion {
    return OmrExamData.questions[currentQuestionIndex];
  }

  // ==========================================================
  // ANSWER
  // ==========================================================

  void selectAnswer(int optionIndex) {
    if (submitted) return;

    setState(() {
      selectedAnswers[currentQuestionIndex] = optionIndex;
    });
  }

  void clearAnswer() {
    if (submitted) return;

    setState(() {
      selectedAnswers.remove(currentQuestionIndex);
    });
  }

  // ==========================================================
  // REVIEW
  // ==========================================================

  void toggleReview() {
    if (submitted) return;

    setState(() {
      if (markedForReview.contains(currentQuestionIndex)) {
        markedForReview.remove(currentQuestionIndex);
      } else {
        markedForReview.add(currentQuestionIndex);
      }
    });
  }

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  void nextQuestion() {
    if (currentQuestionIndex < OmrExamData.questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    }
  }

  void previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
      });
    }
  }

  void goToQuestion(int index) {
    setState(() {
      currentQuestionIndex = index;
    });
  }

  // ==========================================================
  // CALCULATIONS
  // ==========================================================

  int calculateScore() {
    int score = 0;

    for (int i = 0; i < OmrExamData.questions.length; i++) {
      final selected = selectedAnswers[i];

      if (selected != null &&
          selected == OmrExamData.questions[i].correctAnswer) {
        score += OmrExamData.questions[i].marks;
      }
    }

    return score;
  }

  int calculateCorrect() {
    int count = 0;

    for (int i = 0; i < OmrExamData.questions.length; i++) {
      final selected = selectedAnswers[i];

      if (selected != null &&
          selected == OmrExamData.questions[i].correctAnswer) {
        count++;
      }
    }

    return count;
  }

  int calculateWrong() {
    int count = 0;

    for (int i = 0; i < OmrExamData.questions.length; i++) {
      final selected = selectedAnswers[i];

      if (selected != null &&
          selected != OmrExamData.questions[i].correctAnswer) {
        count++;
      }
    }

    return count;
  }

  int calculateUnanswered() {
    return OmrExamData.questions.length - selectedAnswers.length;
  }

  // ==========================================================
  // SUBMIT
  // ==========================================================

  void showSubmitDialog() {
    final answered = selectedAnswers.length;

    final total = OmrExamData.questions.length;

    final unanswered = total - answered;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Submit Examination',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogRow(Icons.quiz_outlined, 'Total Questions', '$total'),
              _dialogRow(Icons.check_circle_outline, 'Answered', '$answered'),
              _dialogRow(Icons.help_outline, 'Unanswered', '$unanswered'),
              _dialogRow(
                Icons.bookmark_outline,
                'Marked for Review',
                '${markedForReview.length}',
              ),
              const SizedBox(height: 15),
              const Text(
                'Are you sure you want to submit the examination?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                setState(() {
                  submitted = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5BFF),
                foregroundColor: AppColors.background,
              ),
              child: const Text('SUBMIT'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1E5BFF)),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ==========================================================
  // RESET
  // ==========================================================

  void restartExam() {
    setState(() {
      currentQuestionIndex = 0;
      selectedAnswers.clear();
      markedForReview.clear();
      submitted = false;
    });
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      return buildResultScreen();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Physics Examination',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'OMR Test',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Question Palette',
            onPressed: showQuestionPalette,
            icon: const Icon(Icons.grid_view_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            buildMobileHeader(),
            Expanded(child: buildQuestionArea()),
            buildMobileBottomNavigation(),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // MOBILE HEADER
  // ==========================================================

  Widget buildMobileHeader() {
    final total = OmrExamData.questions.length;

    final answered = selectedAnswers.length;

    final progress = answered / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Physics',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Question ${currentQuestion.number} of $total',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _headerStat('Answered', '$answered', const Color(0xFF1E5BFF)),
              const SizedBox(width: 16),
              _headerStat(
                'Review',
                '${markedForReview.length}',
                const Color(0xFFFF6FAE),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1E5BFF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      ],
    );
  }

  // ==========================================================
  // QUESTION AREA
  // ==========================================================

  Widget buildQuestionArea() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      child: Column(children: [buildQuestionCard()]),
    );
  }

  Widget buildQuestionCard() {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5BFF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    'Question ${currentQuestion.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${currentQuestion.marks} Mark',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              currentQuestion.question,
              style: const TextStyle(
                fontSize: 19,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            ...List.generate(currentQuestion.options.length, (index) {
              return buildMobileOption(index, currentQuestion.options[index]);
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: clearAnswer,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: toggleReview,
                    icon: Icon(
                      markedForReview.contains(currentQuestionIndex)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 18,
                    ),
                    label: Text(
                      markedForReview.contains(currentQuestionIndex)
                          ? 'Reviewed'
                          : 'Review',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                      markedForReview.contains(currentQuestionIndex)
                          ? const Color(0xFFFF6FAE)
                          : null,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // MOBILE OMR OPTION
  // ==========================================================

  Widget buildMobileOption(int optionIndex, String optionText) {
    final selected = selectedAnswers[currentQuestionIndex] == optionIndex;

    final letter = String.fromCharCode(65 + optionIndex);

    return GestureDetector(
      onTap: () {
        selectAnswer(optionIndex);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueSoft : AppColors.card,
          border: Border.all(
            color: selected ? const Color(0xFF1E5BFF) : AppColors.line,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected
              ? [
            const BoxShadow(
              color: Color(0x141E5BFF),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.blueDark : AppColors.cardAlt,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1E5BFF)
                      : const Color(0xFF9CA3AF),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: selected ? AppColors.background : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                optionText,
                style: const TextStyle(fontSize: 16, height: 1.3),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF1E5BFF),
                size: 23,
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // MOBILE BOTTOM NAVIGATION
  // ==========================================================

  Widget buildMobileBottomNavigation() {
    final isLast = currentQuestionIndex == OmrExamData.questions.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: currentQuestionIndex == 0 ? null : previousQuestion,
              icon: const Icon(Icons.arrow_back, size: 19),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: isLast
                ? ElevatedButton.icon(
              onPressed: showSubmitDialog,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5BFF),
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
                : ElevatedButton.icon(
              onPressed: nextQuestion,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // QUESTION PALETTE BOTTOM SHEET
  // ==========================================================

  void showQuestionPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Question Palette',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${selectedAnswers.length}/${OmrExamData.questions.length}',
                        style: const TextStyle(
                          color: Color(0xFF1E5BFF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: OmrExamData.questions.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      return buildPaletteButton(index);
                    },
                  ),
                  const SizedBox(height: 25),
                  buildLegend(const Color(0xFF1E5BFF), 'Answered'),
                  buildLegend(const Color(0xFFFF6FAE), 'Marked for Review'),
                  buildLegend(AppColors.line, 'Not Answered'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildPaletteButton(int index) {
    final answered = selectedAnswers.containsKey(index);

    final review = markedForReview.contains(index);

    final active = currentQuestionIndex == index;

    Color background;

    if (review) {
      background = const Color(0xFFFF6FAE);
    } else if (answered) {
      background = const Color(0xFF1E5BFF);
    } else {
      background = AppColors.line;
    }

    return GestureDetector(
      onTap: () {
        goToQuestion(index);
        Navigator.pop(context);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: active ? Border.all(color: AppColors.sky, width: 2) : null,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: answered || review ? AppColors.background : AppColors.inkSoft,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLegend(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // ==========================================================
  // RESULT SCREEN
  // ==========================================================

  Widget buildResultScreen() {
    final score = calculateScore();

    final correct = calculateCorrect();

    final wrong = calculateWrong();

    final unanswered = calculateUnanswered();

    final totalMarks = OmrExamData.questions.fold<int>(
      0,
          (sum, question) => sum + question.marks,
    );

    final percentage = totalMarks == 0 ? 0.0 : score / totalMarks * 100;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Exam Result',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // SCORE CARD
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          color: AppColors.pinkSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 45,
                          color: AppColors.pink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Examination Completed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$score / $totalMarks',
                        style: const TextStyle(
                          fontSize: 45,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E5BFF),
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // STATISTICS
              Row(
                children: [
                  Expanded(
                    child: buildResultStat(
                      'Correct',
                      '$correct',
                      AppColors.blue,
                      Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildResultStat(
                      'Wrong',
                      '$wrong',
                      AppColors.pink,
                      Icons.cancel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildResultStat(
                      'Unanswered',
                      '$unanswered',
                      AppColors.muted,
                      Icons.remove_circle,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OmrAnswerReviewPage(
                          answers: selectedAnswers,
                          markedForReview: markedForReview,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rate_review),
                  label: const Text('Review All Answers'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: restartExam,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Take Examination Again'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildResultStat(
      String title,
      String value,
      Color color,
      IconData icon,
      ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ANSWER REVIEW PAGE
// ============================================================

class OmrAnswerReviewPage extends StatelessWidget {
  final Map<int, int> answers;

  final Set<int> markedForReview;

  const OmrAnswerReviewPage({
    super.key,
    required this.answers,
    required this.markedForReview,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Answer Review',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: OmrExamData.questions.length,
        itemBuilder: (context, index) {
          final question = OmrExamData.questions[index];

          final selected = answers[index];

          final isAnswered = selected != null;

          final isCorrect = isAnswered && selected == question.correctAnswer;

          final isMarked = markedForReview.contains(index);

          return buildReviewCard(
            question,
            selected,
            isCorrect,
            isAnswered,
            isMarked,
          );
        },
      ),
    );
  }

  Widget buildReviewCard(
      OmrQuestion question,
      int? selectedAnswer,
      bool isCorrect,
      bool isAnswered,
      bool marked,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: !isAnswered
                      ? AppColors.faint
                      : isCorrect
                      ? AppColors.blue
                      : AppColors.pink,
                  child: Text(
                    '${question.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (marked)
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Icon(Icons.bookmark, color: AppColors.rose),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(question.options.length, (optionIndex) {
              return buildReviewOption(question, optionIndex, selectedAnswer);
            }),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: !isAnswered
                    ? AppColors.cardAlt
                    : isCorrect
                    ? AppColors.blueSoft
                    : AppColors.pinkSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                !isAnswered
                    ? 'Not Answered'
                    : isCorrect
                    ? 'Correct Answer'
                    : 'Wrong Answer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: !isAnswered
                      ? AppColors.faint
                      : isCorrect
                      ? AppColors.blue
                      : AppColors.pink,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explanation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5BFF),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    question.explanation,
                    style: const TextStyle(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildReviewOption(
      OmrQuestion question,
      int optionIndex,
      int? selectedAnswer,
      ) {
    final isCorrect = optionIndex == question.correctAnswer;

    final isSelected = optionIndex == selectedAnswer;

    Color background = AppColors.card;

    Color border = AppColors.line;

    if (isCorrect) {
      background = AppColors.blueSoft;
      border = AppColors.blue;
    } else if (isSelected && !isCorrect) {
      background = AppColors.pinkSoft;
      border = AppColors.pink;
    }

    final letter = String.fromCharCode(65 + optionIndex);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              question.options[optionIndex],
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (isCorrect)
            const Icon(Icons.check_circle, color: AppColors.blue, size: 21)
          else if (isSelected)
            const Icon(Icons.cancel, color: AppColors.pink, size: 21),
        ],
      ),
    );
  }
}

// ==========================================================================
//  MODULE: AI HR round simulator
// ==========================================================================

// ============================================================================
//  AI HR ROUND SIMULATOR (VOICE EDITION)
//  single-file Flutter app: Web + Android + iOS + Desktop, black theme
//
//  pubspec.yaml
//    dependencies:
//      flutter:
//        sdk: flutter
//      speech_to_text: ^7.0.0     # speech recognition (microphone answers)
//      flutter_tts: ^4.2.0        # voice output (Aria speaks)
//      share_plus: ^10.1.4        # publish / share the result
//      pdf: ^3.11.0               # builds the PDF report card
//      printing: ^5.13.0          # download / share / email the PDF
//      url_launcher: ^6.3.0       # opens the email app on web (mailto)
//
//  Run:  flutter pub get
//        flutter run -d chrome     (web: use Chrome or Edge, https or localhost)
//        flutter run               (mobile)
//
//  Platform setup (one time):
//   Android  android/app/src/main/AndroidManifest.xml  (inside <manifest>)
//     <uses-permission android:name="android.permission.RECORD_AUDIO"/>
//     <uses-permission android:name="android.permission.INTERNET"/>
//     <uses-permission android:name="android.permission.BLUETOOTH"/>
//     <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
//     <queries>
//       <intent><action android:name="android.speech.RecognitionService"/></intent>
//       <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
//     </queries>
//     and set minSdkVersion 24 in android/app/build.gradle
//   iOS      ios/Runner/Info.plist
//     NSMicrophoneUsageDescription        = "Used to hear your interview answers"
//     NSSpeechRecognitionUsageDescription = "Used to turn your voice into text"
//   Web      nothing to configure; Chrome/Edge ask for microphone access.
//
//  ML engine (pure Dart, runs identically on web and mobile):
//   - tokenising + stemming, TF-IDF vectors and cosine similarity against
//     model answers, keyword coverage, STAR-structure detection,
//     filler / hedge detection, sentiment lexicon, sentence-length analysis
//   - speaking pace (words per minute) measured from the microphone time
//  Google ML Kit packages are not available on web, so they are not used.
// ============================================================================

//void main() => runApp(const HrSimApp());

// ----------------------------------------------------------------------------
//  THEME
// ----------------------------------------------------------------------------
class C {
  static const bg = AppColors.background;
  static const card = AppColors.card;
  static const card2 = AppColors.cardAlt;
  static const border = AppColors.line;
  static const accent = AppColors.blue;
  static const good = AppColors.green;
  static const warn = AppColors.amber;
  static const bad = AppColors.red;
  static const text = AppColors.text;
  static const muted = AppColors.muted;
  static Color score(double v) => v >= 75 ? good : (v >= 55 ? warn : bad);
}

Color a(Color c, double o) => c.withAlpha((o * 255).round());

class HrSimApp extends StatelessWidget {
  const HrSimApp({super.key});
  @override
  Widget build(BuildContext context) => const SetupScreen();
}

// ----------------------------------------------------------------------------
//  MODELS
// ----------------------------------------------------------------------------
class InterviewConfig {
  final String name, role, level;
  final int rounds;
  final bool voice;
  const InterviewConfig({
    required this.name,
    required this.role,
    required this.level,
    required this.rounds,
    required this.voice,
  });
}

class Question {
  final String text, category;
  final List<String> keywords;
  const Question(this.text, this.category, this.keywords);
}

class Scores {
  final double clarity, relevance, structure, confidence, positivity;
  const Scores(this.clarity, this.relevance, this.structure, this.confidence,
      this.positivity);
  static const labels = [
    'Clarity',
    'Relevance',
    'Structure',
    'Confidence',
    'Positivity'
  ];
  List<double> get list =>
      [clarity, relevance, structure, confidence, positivity];
  double get overall =>
      clarity * .2 +
          relevance * .3 +
          structure * .2 +
          confidence * .15 +
          positivity * .15;
  static Scores average(List<Scores> s) {
    if (s.isEmpty) return const Scores(0, 0, 0, 0, 0);
    double f(double Function(Scores) g) =>
        s.map(g).reduce((x, y) => x + y) / s.length;
    return Scores(f((x) => x.clarity), f((x) => x.relevance),
        f((x) => x.structure), f((x) => x.confidence), f((x) => x.positivity));
  }
}

class Turn {
  final Question q;
  final String answer, feedback;
  final Scores scores;
  final List<String> tips;
  final int seconds;
  final double? wpm; // speaking pace, null when the answer was typed
  const Turn(
      this.q, this.answer, this.scores, this.feedback, this.tips, this.seconds,
      {this.wpm});
  int get words => LocalEngine.tokens(answer).length;
}

// ----------------------------------------------------------------------------
//  QUESTION BANK
// ----------------------------------------------------------------------------
const kIntro = Question(
  'Let\'s begin. Tell me about yourself.',
  'Introduction',
  [
    'experience',
    'skills',
    'background',
    'currently',
    'project',
    'education',
    'passion',
    'role'
  ],
);

const List<Question> kBank = [
  Question('Why do you want to work for our company?', 'Motivation', [
    'company',
    'mission',
    'values',
    'growth',
    'culture',
    'product',
    'contribute',
    'impact'
  ]),
  Question('What are your greatest strengths?', 'Self-awareness', [
    'strength',
    'example',
    'skill',
    'result',
    'team',
    'improved',
    'feedback',
    'delivered'
  ]),
  Question('What is your biggest weakness, and how are you working on it?',
      'Self-awareness', [
        'weakness',
        'improve',
        'learning',
        'course',
        'feedback',
        'progress',
        'mentor',
        'working'
      ]),
  Question(
      'Describe a time you had a conflict with a teammate. How did you resolve it?',
      'Behavioral', [
    'situation',
    'conflict',
    'listened',
    'resolved',
    'communication',
    'outcome',
    'compromise',
    'understand'
  ]),
  Question(
      'Tell me about a failure and what you learned from it.', 'Behavioral', [
    'failed',
    'mistake',
    'learned',
    'lesson',
    'responsibility',
    'changed',
    'improved',
    'result'
  ]),
  Question('Where do you see yourself in five years?', 'Career goals', [
    'grow',
    'goal',
    'lead',
    'skills',
    'learn',
    'contribute',
    'responsibility',
    'company'
  ]),
  Question('How do you handle pressure and tight deadlines?', 'Resilience', [
    'prioritize',
    'plan',
    'deadline',
    'calm',
    'organized',
    'communicate',
    'delivered',
    'schedule'
  ]),
  Question('Describe a time you showed leadership, even without a title.',
      'Leadership', [
        'led',
        'team',
        'initiative',
        'motivated',
        'decision',
        'delegated',
        'result',
        'ownership'
      ]),
  Question(
      'Why are you leaving your current role, or why did you pick this path?',
      'Motivation', [
    'opportunity',
    'growth',
    'challenge',
    'learn',
    'looking',
    'skills',
    'career',
    'next'
  ]),
  Question(
      'How do you work in a team with people who think very differently from you?',
      'Teamwork', [
    'listen',
    'respect',
    'perspective',
    'collaborate',
    'diverse',
    'communication',
    'common',
    'goal'
  ]),
  Question('What are your salary expectations?', 'Negotiation', [
    'market',
    'range',
    'research',
    'flexible',
    'compensation',
    'value',
    'negotiable',
    'experience'
  ]),
  Question('Why should we hire you over other candidates?', 'Closing', [
    'unique',
    'value',
    'skills',
    'results',
    'fit',
    'contribute',
    'experience',
    'team'
  ]),
];

// ----------------------------------------------------------------------------
//  ON-DEVICE NLP / SCORING ENGINE
// ----------------------------------------------------------------------------
class LocalEngine {
  static const _fillers = [
    'um',
    'uh',
    'like',
    'you know',
    'basically',
    'actually',
    'kind of',
    'sort of',
    'literally',
    'i mean'
  ];
  static const _hedges = [
    'maybe',
    'perhaps',
    'i think',
    'probably',
    'i guess',
    'not sure',
    'hopefully',
    'might',
    'sort of'
  ];
  static const _positive = [
    'achieved',
    'improved',
    'learned',
    'successful',
    'excited',
    'passionate',
    'enjoy',
    'proud',
    'growth',
    'opportunity',
    'delivered',
    'collaborated',
    'motivated',
    'solved',
    'strong',
    'confident',
    'great',
    'helped',
    'win'
  ];
  static const _negative = [
    'hate',
    'terrible',
    'worst',
    'boring',
    'useless',
    'stupid',
    'lazy',
    'blame',
    'fired',
    'toxic',
    'awful',
    "can't",
    'never',
    'impossible'
  ];
  static const _strongVerbs = [
    'led',
    'built',
    'delivered',
    'achieved',
    'managed',
    'created',
    'improved',
    'launched',
    'designed',
    'owned',
    'increased',
    'reduced',
    'resolved',
    'implemented',
    'organized',
    'trained'
  ];
  static const _star = {
    'Situation': [
      'when',
      'during',
      'situation',
      'project',
      'team',
      'once',
      'at my',
      'while'
    ],
    'Task': [
      'task',
      'responsible',
      'goal',
      'needed',
      'had to',
      'objective',
      'assigned',
      'challenge'
    ],
    'Action': [
      'i did',
      'i decided',
      'i led',
      'i built',
      'i created',
      'i started',
      'i organized',
      'i talked',
      'i implemented',
      'i worked',
      'so i',
      'i took'
    ],
    'Result': [
      'result',
      'outcome',
      'achieved',
      'improved',
      'increased',
      'reduced',
      'learned',
      'successfully',
      'ended up',
      '%'
    ],
  };

  static List<String> tokens(String s) => RegExp(r"[a-zA-Z']+")
      .allMatches(s.toLowerCase())
      .map((m) => m.group(0)!)
      .toList();

  static int _count(String lower, List<String> phrases) {
    var n = 0;
    for (final p in phrases) {
      n += RegExp('\\b${RegExp.escape(p)}\\b').allMatches(lower).length;
    }
    return n;
  }

  static double _c(num v) => v.clamp(0, 100).toDouble();

  static int fillerCount(String text) => _count(text.toLowerCase(), _fillers);

  static Scores score(Question q, String answer) {
    final lower = answer.toLowerCase();
    final toks = tokens(answer);
    final n = toks.length;
    if (n == 0) return const Scores(0, 0, 0, 0, 0);

    final sentences = answer
        .split(RegExp(r'[.!?\n]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final avgSent = n / math.max(1, sentences.length);
    final fillers = _count(lower, _fillers);
    final hedges = _count(lower, _hedges);

    // length quality (ideal 60-180 words)
    double lenScore;
    if (n < 15) {
      lenScore = n / 15 * 35;
    } else if (n < 60) {
      lenScore = 35 + (n - 15) / 45 * 65;
    } else if (n <= 180) {
      lenScore = 100;
    } else {
      lenScore = math.max(55, 100 - (n - 180) * .3);
    }
    final sentScore = (avgSent >= 8 && avgSent <= 26)
        ? 100.0
        : (avgSent < 8
        ? avgSent / 8 * 100
        : math.max(50, 100 - (avgSent - 26) * 4));
    final fillerPenalty = (fillers / n * 100 * 6).clamp(0, 40);
    final clarity = _c(.55 * lenScore + .45 * sentScore - fillerPenalty);

    // relevance: stem-level keyword coverage
    final hits = q.keywords
        .where((k) => lower.contains(k.length > 5 ? k.substring(0, 5) : k))
        .length;
    final kwScore = _c(hits / 4 * 85 + (n >= 25 ? 15 : n / 25 * 15));
    final ideal = kIdeal[q.category] ?? kIdeal['Behavioral']!;
    final sim = TfIdf.cosine(answer, '$ideal ${q.keywords.join(' ')}');
    final relevance = _c(.6 * kwScore + .4 * _c(sim * 330));

    // structure: STAR coverage + quantification
    var groups = 0;
    _star.forEach((_, words) {
      if (words.any((w) => lower.contains(w))) groups++;
    });
    final hasNumber = RegExp(r'\d').hasMatch(answer);
    final structure = _c(groups / 4 * 85 + (hasNumber ? 15 : 0));

    // confidence
    final strong = toks.where(_strongVerbs.contains).length;
    final usesI = RegExp(r'\bi\b').hasMatch(lower);
    final confidence =
    _c(85 - hedges * 12 - fillers * 5 + strong * 4 - (usesI ? 0 : 10));

    // sentiment / positivity
    final pos = toks.where(_positive.contains).length;
    final neg = toks.where(_negative.contains).length;
    final positivity = _c(math.max(25, 60 + pos * 8 - neg * 12));

    return Scores(clarity, relevance, structure, confidence, positivity);
  }

  static (String, List<String>) coach(Scores s, Question q, {double? wpm}) {
    final names = Scores.labels;
    final l = s.list;
    var hi = 0, lo = 0;
    for (var i = 0; i < l.length; i++) {
      if (l[i] > l[hi]) hi = i;
      if (l[i] < l[lo]) lo = i;
    }
    final o = s.overall;
    final head = o >= 80
        ? 'Excellent answer.'
        : o >= 65
        ? 'Solid answer with room to sharpen.'
        : o >= 50
        ? 'Decent start, but it needs more substance.'
        : 'This answer needs significant work.';
    final fb = '$head Your strongest area was ${names[hi].toLowerCase()}; '
        '${names[lo].toLowerCase()} needs the most attention.';
    final tips = <String>[];
    if (s.clarity < 65) {
      tips.add(
          'Aim for 60-150 words in 3-6 clear sentences and cut filler words.');
    }
    if (s.relevance < 65) {
      tips.add(
          'Tie your answer to the question: mention ideas like ${q.keywords.take(3).join(', ')}.');
    }
    if (s.structure < 65) {
      tips.add(
          'Use STAR: Situation, Task, Action, Result, and quantify the result.');
    }
    if (s.confidence < 65) {
      tips.add(
          'Remove hedges ("maybe", "I think") and own your impact: "I led", "I delivered".');
    }
    if (s.positivity < 65) {
      tips.add('Frame challenges positively and end on what you learned.');
    }
    if (wpm != null) {
      if (wpm < 100) {
        tips.add(
            'Your pace was ${wpm.round()} words per minute. Speak a little faster, around 120-150, to sound energetic.');
      } else if (wpm > 170) {
        tips.add(
            'Your pace was ${wpm.round()} words per minute. Slow down to 120-150 so every point lands.');
      }
    }
    if (tips.isEmpty)
      tips.add(
          'Keep this energy. Add one concrete metric to make it unforgettable.');
    return (fb, tips);
  }

  static String verdict(double o) => o >= 80
      ? 'Strong Hire'
      : o >= 68
      ? 'Hire'
      : o >= 55
      ? 'Borderline'
      : 'Needs Improvement';

  static String summary(List<Turn> t) {
    if (t.isEmpty) return 'No answers were recorded.';
    final avg = Scores.average(t.map((e) => e.scores).toList());
    final l = avg.list;
    var hi = 0, lo = 0;
    for (var i = 0; i < l.length; i++) {
      if (l[i] > l[hi]) hi = i;
      if (l[i] < l[lo]) lo = i;
    }
    final words = t.map((e) => e.words).reduce((x, y) => x + y) / t.length;
    return 'Overall score ${avg.overall.round()}/100 (${verdict(avg.overall)}). '
        'Your best skill was ${Scores.labels[hi].toLowerCase()} (${l[hi].round()}), '
        'while ${Scores.labels[lo].toLowerCase()} (${l[lo].round()}) is the main growth area. '
        'Your answers averaged ${words.round()} words. '
        'Practise one STAR story per theme and rehearse out loud before the real round.';
  }
}

// ----------------------------------------------------------------------------
//  ML: TF-IDF + COSINE SIMILARITY (pure Dart)
// ----------------------------------------------------------------------------
const Map<String, String> kIdeal = {
  'Introduction':
  'I have a strong education and background in my field. My projects built skills and hands-on experience. Currently I work on projects where I contribute to the team, deliver results and keep learning. I am passionate about this role and want to grow and add value to the company.',
  'Motivation':
  'I admire the company mission, products and culture, and its values match mine. The role offers growth, learning and a chance to contribute and create impact for customers and the team. My skills and experience fit what the company needs.',
  'Self-awareness':
  'My strength is delivering results while collaborating with the team. For example I improved a process and received positive feedback. I am also aware of my weakness and I am improving it through learning, a course, mentor feedback and steady progress.',
  'Behavioral':
  'The situation was a project where my team faced a challenge. My task was to resolve it. I listened to everyone, communicated clearly, took action with a plan and reached a compromise. The result was a successful outcome, better collaboration and a lesson I learned.',
  'Career goals':
  'In five years I want to grow my skills, take more responsibility and lead projects. I plan to keep learning and contribute to the company goals while advancing my career with greater impact.',
  'Resilience':
  'Under pressure and tight deadlines I stay calm, prioritize tasks, plan a schedule, communicate with my team and stay organized. This helped me deliver projects on time with quality.',
  'Leadership':
  'I took the initiative and led the team without a title. I motivated people, delegated tasks, made decisions and took ownership. The result was a delivered project and a stronger team.',
  'Teamwork':
  'I listen, respect different perspectives and collaborate with diverse people. We find common ground, communicate openly and focus on the shared goal to achieve the team result.',
  'Negotiation':
  'Based on market research for this role and my experience, I expect a compensation range that reflects the value I bring. I am flexible and open to negotiate with the full package considered.',
  'Closing':
  'You should hire me because my skills, experience and results fit this role. I bring unique value, learn fast, work well in a team and will contribute to the company from day one.',
};

class TfIdf {
  static const _stop = {
    'the',
    'and',
    'for',
    'that',
    'with',
    'this',
    'are',
    'was',
    'you',
    'your',
    'have',
    'has',
    'had',
    'but',
    'not',
    'from',
    'they',
    'them',
    'our',
    'who',
    'what',
    'when',
    'how',
    'can',
    'will',
    'would',
    'could',
    'should',
    'about',
    'into',
    'also',
    'more',
    'very',
    'just',
    'than',
    'then',
    'been',
    'were',
    'their',
    'there',
    'which',
    'while',
    'because',
    'its',
    'his',
    'her',
    'she',
    'him',
    'out',
    'all',
    'any',
    'get',
    'got'
  };

  static String _stem(String w) {
    for (final suf in const ['ing', 'ed', 'es', 's', 'ly']) {
      if (w.length > suf.length + 3 && w.endsWith(suf)) {
        return w.substring(0, w.length - suf.length);
      }
    }
    return w;
  }

  static List<String> terms(String s) => LocalEngine.tokens(s)
      .where((w) => w.length > 2 && !_stop.contains(w))
      .map(_stem)
      .toList();

  static final Map<String, double> _idf = _buildIdf();

  static Map<String, double> _buildIdf() {
    final docs = kIdeal.values.map((d) => terms(d).toSet()).toList();
    final df = <String, int>{};
    for (final d in docs) {
      for (final t in d) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final n = docs.length;
    return {
      for (final e in df.entries) e.key: math.log((n + 1) / (e.value + 1)) + 1
    };
  }

  static Map<String, double> _vec(List<String> ts) {
    final tf = <String, double>{};
    for (final t in ts) {
      tf[t] = (tf[t] ?? 0) + 1;
    }
    return tf.map((k, v) => MapEntry(k, (1 + math.log(v)) * (_idf[k] ?? 1.0)));
  }

  static double cosine(String a, String b) {
    final va = _vec(terms(a)), vb = _vec(terms(b));
    if (va.isEmpty || vb.isEmpty) return 0;
    var dot = 0.0;
    va.forEach((k, v) {
      final w = vb[k];
      if (w != null) dot += v * w;
    });
    double norm(Map<String, double> m) =>
        math.sqrt(m.values.fold(0.0, (x, y) => x + y * y));
    final d = norm(va) * norm(vb);
    return d == 0 ? 0 : dot / d;
  }
}

// ----------------------------------------------------------------------------
//  VOICE: speech recognition + text-to-speech
// ----------------------------------------------------------------------------
final VoiceService voice = VoiceService();

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool sttReady = false, ttsReady = false;
  bool _inited = false, _talking = false;
  void Function(String status)? onStatus;
  void Function(String error, bool permanent)? onError;
  void Function(double level)? onLevel;
  Completer<void>? _done;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      sttReady = await _stt.initialize(
        onStatus: (st) => onStatus?.call(st),
        onError: (e) => onError?.call(e.errorMsg, e.permanent),
      );
    } catch (_) {
      sttReady = false;
    }
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts
            .setIosAudioCategory(IosTextToSpeechAudioCategory.playAndRecord, [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ]);
      }
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _tts.setCompletionHandler(_finish);
      _tts.setCancelHandler(_finish);
      _tts.setErrorHandler((_) => _finish());
      ttsReady = true;
    } catch (_) {
      ttsReady = false;
    }
  }

  void _finish() {
    _talking = false;
    final c = _done;
    _done = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Speaks [text] and completes when finished (or after a safety timeout,
  /// because some browsers never fire the completion event).
  Future<void> speak(String text) async {
    if (!ttsReady || text.trim().isEmpty) return;
    if (_talking) {
      await stopSpeaking();
      await Future.delayed(const Duration(milliseconds: 180));
    }
    final c = Completer<void>();
    _done = c;
    _talking = true;
    try {
      await _tts.speak(text);
    } catch (_) {
      _finish();
    }
    await c.future.timeout(Duration(milliseconds: 3000 + text.length * 95),
        onTimeout: () {});
    if (identical(_done, c)) {
      _done = null;
      _talking = false;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _finish();
  }

  Future<void> listen(void Function(String words, bool isFinal) onWords) async {
    await _stt.listen(
      onResult: (r) => onWords(r.recognizedWords, r.finalResult),
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 6),
      onSoundLevelChange: (l) =>
          onLevel?.call(((l + 2) / 12).clamp(0.0, 1.0).toDouble()),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  Future<void> stopAll() async {
    await stopListening();
    await stopSpeaking();
  }
}

// ----------------------------------------------------------------------------
//  SHARED WIDGETS
// ----------------------------------------------------------------------------
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderColor,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? C.border),
    ),
    child: child,
  );
}

class Chip2 extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Chip2(this.text, {super.key, this.color = C.muted, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: a(color, .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: a(color, .35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
      ],
      Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

class ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  const ScoreBar(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(
          width: 86,
          child: Text(label,
              style: const TextStyle(color: C.muted, fontSize: 12.5))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 6,
            backgroundColor: C.card2,
            valueColor: AlwaysStoppedAnimation(C.score(value)),
          ),
        ),
      ),
      SizedBox(
          width: 38,
          child: Text('${value.round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600))),
    ]),
  );
}

class RingPainter extends CustomPainter {
  final double value; // 0..100
  final Color color;
  RingPainter(this.value, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: c, radius: r);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = C.card2;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * (value / 100), false, fg);
  }

  @override
  bool shouldRepaint(RingPainter o) => o.value != value || o.color != color;
}

class ScoreRing extends StatelessWidget {
  final double value;
  final double size;
  final String? caption;
  const ScoreRing(this.value, {super.key, this.size = 130, this.caption});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: RingPainter(value, C.score(value)),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${value.round()}',
              style: TextStyle(
                  fontSize: size * .30, fontWeight: FontWeight.w800)),
          if (caption != null)
            Text(caption!,
                style: const TextStyle(color: C.muted, fontSize: 11.5)),
        ]),
      ),
    ),
  );
}

class HrRadarPainter extends CustomPainter {
  final List<double> values;
  HrRadarPainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 32;
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = C.border;
    Offset pt(int i, double rr) {
      final ang = -math.pi / 2 + i * 2 * math.pi / n;
      return c + Offset(math.cos(ang), math.sin(ang)) * rr;
    }

    for (var lv = 1; lv <= 4; lv++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = pt(i, r * lv / 4);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, pt(i, r), grid);
      final tp = TextPainter(
        text: TextSpan(
            text: Scores.labels[i],
            style: const TextStyle(color: C.muted, fontSize: 11)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final p = pt(i, r + 16);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    final data = Path();
    for (var i = 0; i < n; i++) {
      final p = pt(i, r * (values[i].clamp(0, 100)) / 100);
      i == 0 ? data.moveTo(p.dx, p.dy) : data.lineTo(p.dx, p.dy);
    }
    data.close();
    canvas.drawPath(data, Paint()..color = a(C.accent, .22));
    canvas.drawPath(
        data,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = C.accent);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(pt(i, r * (values[i].clamp(0, 100)) / 100), 3.5,
          Paint()..color = C.accent);
    }
  }

  @override
  bool shouldRepaint(HrRadarPainter o) => o.values != values;
}

class Radar extends StatelessWidget {
  final List<double> values;
  final double height;
  const Radar(this.values, {super.key, this.height = 240});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: HrRadarPainter(values)),
  );
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final t = (math.sin((_c.value * 2 * math.pi) - i * .8) + 1) / 2;
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: a(C.text, .25 + .6 * t)),
        );
      }),
    ),
  );
}

String fmtTime(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

// ----------------------------------------------------------------------------
//  SCREEN 1 - SETUP
// ----------------------------------------------------------------------------
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _custom = TextEditingController();
  static const _roles = [
    'Software Engineer',
    'Data Scientist',
    'ML Engineer',
    'Product Manager',
    'Marketing Executive',
    'Custom'
  ];
  String _role = 'ML Engineer';
  String _level = 'Fresher';
  double _rounds = 5;
  bool _voice = true;

  @override
  void dispose() {
    _name.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _start() {
    final role = _role == 'Custom' && _custom.text.trim().isNotEmpty
        ? _custom.text.trim()
        : (_role == 'Custom' ? 'Professional' : _role);
    final cfg = InterviewConfig(
      name: _name.text.trim().isEmpty ? 'Candidate' : _name.text.trim(),
      role: role,
      level: _level,
      rounds: _rounds.round(),
      voice: _voice,
    );
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => InterviewScreen(cfg: cfg)));
  }

  Widget _hero() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: a(C.accent, .5)),
          color: a(C.accent, .1),
        ),
        child: const Icon(Icons.record_voice_over_rounded,
            color: C.accent, size: 28),
      ),
      const SizedBox(height: 22),
      const Text('Practice your HR round\nbefore it counts.',
          style: TextStyle(
              fontSize: 38, height: 1.12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      const Text(
          'Answer real HR questions out loud or by typing, and hear Aria reply. Every answer is scored on clarity, relevance, structure, confidence and tone, then rolled into a hiring verdict.',
          style: TextStyle(color: C.muted, fontSize: 15.5, height: 1.5)),
      const SizedBox(height: 24),
      const Wrap(spacing: 8, runSpacing: 8, children: [
        Chip2('Voice answers', icon: Icons.mic_rounded),
        Chip2('Spoken feedback', icon: Icons.volume_up_rounded),
        Chip2('Shareable result', icon: Icons.ios_share_rounded),
      ]),
    ],
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 16),
    child: Text(t,
        style: const TextStyle(
            color: C.muted, fontSize: 13, fontWeight: FontWeight.w600)),
  );

  Widget _form() => Panel(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(
              labelText: 'Your name', hintText: 'e.g. Priya'),
        ),
        _label('Role you are interviewing for'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _roles
              .map((r) => ChoiceChip(
            label: Text(r),
            selected: _role == r,
            onSelected: (_) => setState(() => _role = r),
            selectedColor: a(C.accent, .22),
            backgroundColor: C.card2,
            side:
            BorderSide(color: _role == r ? C.accent : C.border),
            labelStyle: TextStyle(
                color: _role == r ? C.accent : C.text,
                fontSize: 13),
            showCheckmark: false,
          ))
              .toList(),
        ),
        if (_role == 'Custom') ...[
          const SizedBox(height: 10),
          TextField(
              controller: _custom,
              decoration:
              const InputDecoration(hintText: 'Type your role')),
        ],
        _label('Experience level'),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'Fresher', label: Text('Fresher')),
            ButtonSegment(value: 'Mid-level', label: Text('Mid-level')),
            ButtonSegment(value: 'Senior', label: Text('Senior')),
          ],
          selected: {_level},
          onSelectionChanged: (s) => setState(() => _level = s.first),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((st) =>
            st.contains(WidgetState.selected)
                ? a(C.accent, .22)
                : C.card2),
            foregroundColor: WidgetStateProperty.resolveWith((st) =>
            st.contains(WidgetState.selected) ? C.accent : C.text),
            side: const WidgetStatePropertyAll(BorderSide(color: C.border)),
          ),
        ),
        _label('Number of questions: ${_rounds.round()}'),
        Slider(
          value: _rounds,
          min: 3,
          max: 8,
          divisions: 5,
          activeColor: C.accent,
          inactiveColor: C.border,
          onChanged: (v) => setState(() => _rounds = v),
        ),
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: C.accent,
          value: _voice,
          onChanged: (v) => setState(() => _voice = v),
          title: const Text('Voice mode',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text(
              'Aria speaks the questions and feedback, and you can answer with the microphone. On web, use Chrome or Edge.',
              style: TextStyle(color: C.muted, fontSize: 12.5)),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start interview',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: C.accent,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 900;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: wide ? 40 : 18, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: wide
                    ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                        flex: 10,
                        child: Padding(
                            padding: const EdgeInsets.only(right: 56),
                            child: _hero())),
                    Expanded(flex: 9, child: _form()),
                  ],
                )
                    : Column(children: [
                  _hero(),
                  const SizedBox(height: 26),
                  _form(),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
//  SCREEN 2 - LIVE INTERVIEW
// ----------------------------------------------------------------------------
class _Msg {
  final int kind; // 0 = HR, 1 = candidate, 2 = coach card, 3 = system note
  final String text;
  final Turn? turn;
  final String? tag;
  _Msg(this.kind, this.text, {this.turn, this.tag});
}

class InterviewScreen extends StatefulWidget {
  final InterviewConfig cfg;
  const InterviewScreen({super.key, required this.cfg});
  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  final _msgs = <_Msg>[];
  final _turns = <Turn>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  late final List<Question> _plan;
  Question? _current;
  int _asked = 0;
  bool _typing = false, _grading = false, _followUpUsed = false, _ended = false;
  bool _voiceOut = true;
  bool _speaking = false, _wantListen = false, _listening = false;
  bool _restarting = false;
  bool _finishing = false, _opened = false;
  String? _summary;
  double _level = 0;
  String _base = '';
  DateTime? _micStart;
  int _speakMs = 0;
  Timer? _timer;
  int _sec = 0;

  InterviewConfig get cfg => widget.cfg;

  late final String _greet =
      'Hi ${cfg.name}, I\'m Aria from the talent team. Today\'s a short HR round for the ${cfg.level} ${cfg.role} position. Take your time, answer naturally, and I\'ll coach you after every answer.';

  @override
  void initState() {
    super.initState();
    _voiceOut = cfg.voice;
    final pool = List<Question>.from(kBank)..shuffle();
    _plan = [kIntro, ...pool.take(cfg.rounds - 1)];
    _msgs.add(_Msg(0, _greet));
    voice.onStatus = _onStatus;
    voice.onError = _onError;
    voice.onLevel = (l) {
      if (mounted && _wantListen) setState(() => _level = l);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (cfg.voice) {
        await voice.init();
        if (!mounted) return;
        if (!voice.sttReady) {
          setState(() => _msgs.add(_Msg(3,
              'Microphone unavailable. You can still type your answers. On web, use Chrome or Edge and allow microphone access.')));
        }
      }
      _askNext();
    });
  }

  @override
  void dispose() {
    _ended = true;
    _timer?.cancel();
    voice.onStatus = null;
    voice.onError = null;
    voice.onLevel = null;
    voice.stopAll();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------- speech out ----------
  Future<void> _say(String text) async {
    if (!_voiceOut || !voice.ttsReady || _ended) return;
    setState(() => _speaking = true);
    await voice.speak(text);
    if (mounted) setState(() => _speaking = false);
  }

  // ---------- speech in ----------
  Future<void> _toggleMic() async {
    if (_current == null) return;
    if (_wantListen) {
      await _stopMic();
      return;
    }
    if (!voice.sttReady) {
      _snack(
          'Speech recognition is not available. Allow microphone access, or use Chrome/Edge on web.');
      return;
    }
    await voice.stopSpeaking();
    if (!mounted) return;
    _wantListen = true;
    _base = _input.text.trim();
    _micStart = DateTime.now();
    setState(() {
      _speaking = false;
      _listening = true;
    });
    await _startSession();
  }

  Future<void> _startSession() async {
    try {
      await voice.listen((w, fin) {
        if (!mounted || _current == null) return;
        final t = _base.isEmpty ? w : (w.isEmpty ? _base : '$_base $w');
        setState(() {
          _input.value = TextEditingValue(
              text: t, selection: TextSelection.collapsed(offset: t.length));
        });
        if (fin) _base = t;
      });
    } catch (_) {
      await _stopMic();
      _snack('Could not start the microphone.');
    }
  }

  Future<void> _stopMic() async {
    if (!_wantListen && !_listening) return;
    _wantListen = false;
    if (_micStart != null) {
      _speakMs += DateTime.now().difference(_micStart!).inMilliseconds;
      _micStart = null;
    }
    await voice.stopListening();
    if (mounted) {
      setState(() {
        _listening = false;
        _level = 0;
      });
    }
    await Future.delayed(const Duration(milliseconds: 280));
  }

  void _scheduleRestart() {
    if (_restarting) return;
    _restarting = true;
    Future.delayed(const Duration(milliseconds: 400), () async {
      _restarting = false;
      if (mounted && _wantListen && !_ended) {
        _base = _input.text.trim();
        await _startSession();
      }
    });
  }

  void _onStatus(String st) {
    if (!mounted || !_wantListen) return;
    if (st == 'done' || st == 'notListening') _scheduleRestart();
  }

  void _onError(String msg, bool permanent) {
    if (!mounted || !_wantListen) return;
    const benign = ['error_no_match', 'error_speech_timeout', 'error_busy'];
    if (benign.contains(msg) || !permanent) {
      _scheduleRestart();
      return;
    }
    _stopMic();
    _snack('Microphone problem ($msg). Check permissions or type your answer.');
  }

  // ---------- interview flow ----------
  Future<void> _askNext({Question? forced}) async {
    if (_ended) return;
    if (_asked >= cfg.rounds && forced == null) return _finish();
    setState(() => _typing = true);
    _toBottom();
    final q = forced ?? _plan[_asked];
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted || _ended) return;
    _asked++;
    setState(() {
      _typing = false;
      _msgs.add(_Msg(0, q.text,
          tag: 'Question $_asked of ${cfg.rounds}  -  ${q.category}'));
    });
    _toBottom();
    await _say(_asked == 1 ? '$_greet ${q.text}' : q.text);
    if (!mounted || _ended) return;
    setState(() {
      _current = q;
      _sec = 0;
      _speakMs = 0;
      _base = '';
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sec++);
    });
    _focus.requestFocus();
  }

  Future<void> _send() async {
    if (_current == null || _typing || _grading) return;
    await _stopMic();
    final text = _input.text.trim();
    if (text.isEmpty || _current == null) return;
    _timer?.cancel();
    final q = _current!;
    final sec = _sec;
    final words = LocalEngine.tokens(text).length;
    final double? wpm = _speakMs > 3000 ? words / (_speakMs / 60000) : null;
    setState(() {
      _msgs.add(_Msg(1, text));
      _input.clear();
      _grading = true;
      _current = null;
      _base = '';
    });
    _toBottom();

    await Future.delayed(const Duration(milliseconds: 650));
    final turn = _localTurn(q, text, sec, wpm);
    if (!mounted || _ended) return;
    setState(() {
      _grading = false;
      _turns.add(turn);
      _msgs.add(_Msg(2, turn.feedback, turn: turn));
    });
    _toBottom();

    if (_voiceOut && voice.ttsReady) {
      await _say(
          'You scored ${turn.scores.overall.round()} out of 100. ${turn.feedback} ${turn.tips.first}');
    } else {
      await Future.delayed(const Duration(milliseconds: 900));
    }
    if (!mounted || _ended) return;

    if (turn.scores.overall < 50 && !_followUpUsed && _asked < cfg.rounds) {
      _followUpUsed = true;
      await _askNext(
          forced: Question(
              'Let me dig a little deeper. Can you give one specific example, including what you personally did and the measurable result?',
              'Follow-up',
              q.keywords));
    } else {
      await _askNext();
    }
  }

  Turn _localTurn(Question q, String text, int sec, double? wpm) {
    final s = LocalEngine.score(q, text);
    final c = LocalEngine.coach(s, q, wpm: wpm);
    return Turn(q, text, s, c.$1, c.$2, sec, wpm: wpm);
  }

  void _openReport() {
    if (!mounted || _opened) return;
    _opened = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(
            cfg: cfg,
            turns: List<Turn>.of(_turns),
            summary: _summary ?? LocalEngine.summary(_turns))));
  }

  Future<void> _finish() async {
    if (_grading || _finishing) return;
    _finishing = true;
    _ended = true;
    _timer?.cancel();
    try {
      await _stopMic();
      await voice.stopSpeaking();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _typing = true;
      _current = null;
      _msgs.add(_Msg(
          0, 'That wraps up our round. Preparing your interview report...'));
    });
    _toBottom();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _summary = LocalEngine.summary(_turns);
    setState(() {
      _typing = false;
      _msgs.add(_Msg(4, 'Your interview report is ready.'));
    });
    _toBottom();
    await Future.delayed(const Duration(milliseconds: 1400));
    _openReport();
  }

  // ---------- UI ----------
  Widget _hrBubble(_Msg m) => Padding(
    padding: const EdgeInsets.only(bottom: 14, right: 40),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _avatar(),
      const SizedBox(width: 10),
      Flexible(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.card,
            border: Border.all(color: C.border),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.tag != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(m.tag!,
                      style: const TextStyle(
                          color: C.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              SelectableText(m.text,
                  style: const TextStyle(fontSize: 15.5, height: 1.45)),
            ],
          ),
        ),
      ),
    ]),
  );

  Widget _avatar() => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: a(C.accent, .14),
        border: Border.all(color: a(C.accent, .5))),
    child:
    const Icon(Icons.support_agent_rounded, size: 19, color: C.accent),
  );

  Widget _userBubble(_Msg m) => Padding(
    padding: const EdgeInsets.only(bottom: 14, left: 60),
    child: Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.accent,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16)),
        ),
        child: SelectableText(m.text,
            style: const TextStyle(
                color: AppColors.ink, fontSize: 15.5, height: 1.45)),
      ),
    ),
  );

  Widget _coachCard(_Msg m) {
    final t = m.turn!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, left: 44, right: 12),
      child: Panel(
        borderColor: a(C.score(t.scores.overall), .45),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            Chip2('Score ${t.scores.overall.round()}',
                color: C.score(t.scores.overall), icon: Icons.insights_rounded),
            Chip2('${t.words} words  ${fmtTime(t.seconds)}'),
            if (t.wpm != null)
              Chip2('${t.wpm!.round()} wpm',
                  color: (t.wpm! < 100 || t.wpm! > 170) ? C.warn : C.good,
                  icon: Icons.graphic_eq_rounded),
          ]),
          const SizedBox(height: 10),
          for (var i = 0; i < 5; i++)
            ScoreBar(Scores.labels[i], t.scores.list[i]),
          const SizedBox(height: 8),
          Text(t.feedback, style: const TextStyle(fontSize: 14, height: 1.45)),
          const SizedBox(height: 8),
          for (final tip in t.tips)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child:
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.tips_and_updates_outlined,
                        size: 14, color: C.warn)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(tip,
                        style: const TextStyle(
                            color: C.muted, fontSize: 13.5, height: 1.4))),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _reportCard(_Msg m) => Padding(
    padding: const EdgeInsets.only(bottom: 18, left: 44, right: 12),
    child: Panel(
      borderColor: a(C.accent, .5),
      child: Row(children: [
        const Icon(Icons.assignment_turned_in_outlined, color: C.accent),
        const SizedBox(width: 12),
        Expanded(
            child: Text(m.text,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: _openReport,
          style: FilledButton.styleFrom(
              backgroundColor: C.accent, foregroundColor: AppColors.background),
          child: const Text('View report'),
        ),
      ]),
    ),
  );

  Widget _note(_Msg m) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Center(
        child: Text(m.text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.muted, fontSize: 12.5))),
  );

  Widget _chat() {
    final busy = _typing || _grading;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      itemCount: _msgs.length + (busy ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _msgs.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              _avatar(),
              const SizedBox(width: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                    color: C.card,
                    border: Border.all(color: C.border),
                    borderRadius: BorderRadius.circular(16)),
                child: const TypingDots(),
              ),
              if (_grading)
                const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text('Analysing your answer',
                        style: TextStyle(color: C.muted, fontSize: 12.5))),
            ]),
          );
        }
        final m = _msgs[i];
        switch (m.kind) {
          case 0:
            return _hrBubble(m);
          case 1:
            return _userBubble(m);
          case 2:
            return _coachCard(m);
          case 4:
            return _reportCard(m);
          default:
            return _note(m);
        }
      },
    );
  }

  Widget _micButton(bool enabled) {
    final on = _listening;
    final size = 48 + (on ? _level * 14 : 0);
    return SizedBox(
      width: 64,
      height: 64,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? a(C.bad, .22) : C.card2,
            border: Border.all(color: on ? C.bad : C.border),
          ),
          child: IconButton(
            tooltip: on ? 'Stop recording' : 'Answer with your voice',
            padding: EdgeInsets.zero,
            onPressed: enabled ? _toggleMic : null,
            icon: Icon(on ? Icons.stop_rounded : Icons.mic_rounded,
                color: on ? C.bad : (voice.sttReady ? C.text : C.muted)),
          ),
        ),
      ),
    );
  }

  Widget _voiceBar() {
    if (!_speaking && !_listening) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration:
      const BoxDecoration(border: Border(top: BorderSide(color: C.border))),
      child: Row(children: [
        Icon(_speaking ? Icons.volume_up_rounded : Icons.mic_rounded,
            size: 16, color: _speaking ? C.accent : C.bad),
        const SizedBox(width: 8),
        Text(
            _speaking
                ? 'Aria is speaking'
                : 'Listening. Tap stop when you are done',
            style: const TextStyle(color: C.muted, fontSize: 12.5)),
        const Spacer(),
        if (_speaking)
          TextButton(
            onPressed: () => voice.stopSpeaking(),
            child: const Text('Skip', style: TextStyle(fontSize: 12.5)),
          ),
      ]),
    );
  }

  Widget _composer() {
    final enabled = _current != null && !_typing && !_grading;
    final txt = _input.text;
    final words = LocalEngine.tokens(txt).length;
    final fillers = LocalEngine.fillerCount(txt);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 14),
      decoration: const BoxDecoration(
          color: C.bg, border: Border(top: BorderSide(color: C.border))),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (cfg.voice) _micButton(enabled) else const SizedBox(width: 4),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter, control: true):
                _send,
              },
              child: TextField(
                controller: _input,
                focusNode: _focus,
                enabled: enabled,
                minLines: 1,
                maxLines: 6,
                onChanged: (v) {
                  _base = v.trim();
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: !enabled
                      ? 'Wait for the next question'
                      : (_listening
                      ? 'Listening. Speak your answer'
                      : 'Type, or tap the mic. Ctrl+Enter to send'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            width: 50,
            child: FilledButton(
              onPressed: enabled && txt.trim().isNotEmpty ? _send : null,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: C.accent,
                disabledBackgroundColor: C.card2,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(children: [
            Text('$words words',
                style: TextStyle(
                    color: words >= 60 ? C.good : C.muted, fontSize: 12)),
            const SizedBox(width: 14),
            Text('$fillers filler${fillers == 1 ? '' : 's'}',
                style: TextStyle(
                    color: fillers > 2 ? C.warn : C.muted, fontSize: 12)),
            const Spacer(),
            const Text('Aim for 60-150 words',
                style: TextStyle(color: C.muted, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _sidePanel() {
    final avg = Scores.average(_turns.map((t) => t.scores).toList());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Live analysis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Updates after each answer',
            style: TextStyle(color: C.muted, fontSize: 12.5)),
        const SizedBox(height: 18),
        if (_turns.isEmpty)
          const Panel(
              child: Text(
                  'Answer the first question to see your skill profile build here.',
                  style: TextStyle(color: C.muted, height: 1.45)))
        else ...[
          Center(child: ScoreRing(avg.overall, caption: 'running score')),
          const SizedBox(height: 10),
          Radar(avg.list, height: 230),
          const SizedBox(height: 6),
          for (var i = 0; i < 5; i++) ScoreBar(Scores.labels[i], avg.list[i]),
        ],
        const SizedBox(height: 18),
        Panel(
          child: Row(children: [
            const Icon(Icons.flag_outlined, size: 18, color: C.muted),
            const SizedBox(width: 10),
            Text('${_turns.length} of ${cfg.rounds} answered',
                style: const TextStyle(color: C.muted)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final progress = (_turns.length / cfg.rounds).clamp(0.0, 1.0);
    final avg = Scores.average(_turns.map((t) => t.scores).toList());
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${cfg.role} HR round',
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('${cfg.level}  -  ${cfg.voice ? 'voice mode' : 'text mode'}',
              style: const TextStyle(color: C.muted, fontSize: 12)),
        ]),
        actions: [
          if (cfg.voice)
            IconButton(
              tooltip: _voiceOut ? 'Mute Aria' : 'Unmute Aria',
              icon: Icon(
                  _voiceOut
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: _voiceOut ? C.accent : C.muted),
              onPressed: () async {
                setState(() => _voiceOut = !_voiceOut);
                if (!_voiceOut) {
                  await voice.stopSpeaking();
                  if (mounted) setState(() => _speaking = false);
                }
              },
            ),
          if (_current != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip2(fmtTime(_sec),
                  color: _sec > 120 ? C.warn : C.muted,
                  icon: Icons.timer_outlined),
            ),
          TextButton(
            onPressed: _finish,
            child: const Text('End', style: TextStyle(color: C.bad)),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: C.border,
              valueColor: const AlwaysStoppedAnimation(C.accent)),
        ),
      ),
      body: Row(children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(children: [
                if (!wide && _turns.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: Row(children: [
                      const Text('Running score',
                          style: TextStyle(color: C.muted, fontSize: 12.5)),
                      const SizedBox(width: 10),
                      Chip2('${avg.overall.round()}',
                          color: C.score(avg.overall)),
                      const Spacer(),
                      Text('${_turns.length}/${cfg.rounds} answered',
                          style:
                          const TextStyle(color: C.muted, fontSize: 12.5)),
                    ]),
                  ),
                Expanded(child: _chat()),
                _voiceBar(),
                _composer(),
              ]),
            ),
          ),
        ),
        if (wide)
          Container(
            width: 340,
            decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: C.border))),
            child: _sidePanel(),
          ),
      ]),
    );
  }
}

// ----------------------------------------------------------------------------
//  SCREEN 3 - RESULT REPORT
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
//  PDF REPORT CARD
// ----------------------------------------------------------------------------
class PdfReport {
  static PdfColor _sc(double v) => v >= 75
      ? const PdfColor.fromInt(0xFF1E5BFF)
      : (v >= 55
      ? const PdfColor.fromInt(0xFFFF6FAE)
      : const PdfColor.fromInt(0xFFD81B72));

  static String _clip(String x, int n) =>
      x.length <= n ? x : '${x.substring(0, n)}...';

  static Future<Uint8List> build({
    required InterviewConfig cfg,
    required List<Turn> turns,
    required String summary,
    required String date,
    required List<(String, String)> details,
    required List<String> steps,
  }) async {
    final avg = Scores.average(turns.map((t) => t.scores).toList());
    final verdict = LocalEngine.verdict(avg.overall);

    pw.Font? reg, bold;
    var ok = true;
    try {
      reg = await PdfGoogleFonts.notoSansRegular();
      bold = await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      ok = false; // offline: fall back to built-in Helvetica
    }
    String t(String x) => ok ? x : x.replaceAll(RegExp(r'[^\x00-\xFF]'), '?');

    final doc = pw.Document(
      title: 'AI HR Interview Report',
      author: 'AI HR Round Simulator',
      theme: ok ? pw.ThemeData.withFont(base: reg!, bold: bold!) : null,
    );

    final body = pw.TextStyle(fontSize: 10, color: PdfColors.grey900);
    final small = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);
    final bold10 = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    final bold11 = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);

    pw.Widget h(String x) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
      child: pw.Text(x,
          style:
          pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
    );

    pw.Widget bar(String label, double v) {
      final fill = v.round().clamp(1, 100);
      final rest = 100 - fill;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.SizedBox(width: 80, child: pw.Text(label, style: small)),
          pw.Expanded(
            child: pw.Row(children: [
              pw.Expanded(
                  flex: fill, child: pw.Container(height: 7, color: _sc(v))),
              if (rest > 0)
                pw.Expanded(
                    flex: rest,
                    child: pw.Container(height: 7, color: PdfColors.grey300)),
            ]),
          ),
          pw.SizedBox(
              width: 32,
              child: pw.Text('${v.round()}',
                  textAlign: pw.TextAlign.right, style: bold10)),
        ]),
      );
    }

    final header = pw.Container(
      color: const PdfColor.fromInt(0xFF1E5BFF),
      padding: const pw.EdgeInsets.all(22),
      child:
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Interview report card',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text(t('${cfg.name}  |  ${cfg.level} ${cfg.role}'),
                    style:
                    pw.TextStyle(color: PdfColors.grey400, fontSize: 11)),
                pw.SizedBox(height: 2),
                pw.Text('Generated $date',
                    style: pw.TextStyle(color: PdfColors.grey500, fontSize: 9)),
              ]),
        ),
        pw.Column(children: [
          pw.Text('${avg.overall.round()}',
              style: pw.TextStyle(
                  color: _sc(avg.overall),
                  fontSize: 44,
                  fontWeight: pw.FontWeight.bold)),
          pw.Text('out of 100',
              style: pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
          pw.SizedBox(height: 6),
          pw.Text(verdict,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold)),
        ]),
      ]),
    );

    pw.Widget qBlock(int i, Turn q) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: .6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                      child: pw.Text(t('Q${i + 1}. ${q.q.text}'),
                          style: bold11)),
                  pw.SizedBox(width: 8),
                  pw.Text('${q.scores.overall.round()}',
                      style: pw.TextStyle(
                          color: _sc(q.scores.overall),
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                ]),
            pw.SizedBox(height: 4),
            pw.Text(
                'Clarity ${q.scores.clarity.round()}   Relevance ${q.scores.relevance.round()}   '
                    'Structure ${q.scores.structure.round()}   Confidence ${q.scores.confidence.round()}   '
                    'Positivity ${q.scores.positivity.round()}'
                    '${q.wpm != null ? '   Pace ${q.wpm!.round()} wpm' : ''}',
                style: small),
            pw.SizedBox(height: 5),
            pw.Text(t(_clip(q.answer, 600)), style: body),
            pw.SizedBox(height: 5),
            pw.Text(t(q.feedback),
                style:
                pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
          ]),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
            'AI HR Round Simulator   Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
      build: (ctx) => [
        header,
        h('Skill profile'),
        for (var i = 0; i < 5; i++) bar(Scores.labels[i], avg.list[i]),
        h('Panel summary'),
        pw.Text(t(summary),
            style: pw.TextStyle(fontSize: 10.5, lineSpacing: 3)),
        if (details.isNotEmpty) h('Report details'),
        for (final d in details)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: 130, child: pw.Text(d.$1, style: small)),
                  pw.Expanded(child: pw.Text(t(d.$2), style: bold10)),
                ]),
          ),
        if (steps.isNotEmpty) h('Next steps'),
        for (final st in steps)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(t('-  $st'), style: body),
          ),
        if (turns.isNotEmpty) h('Answer review'),
        for (var i = 0; i < turns.length; i++) qBlock(i, turns[i]),
      ],
    ));
    return doc.save();
  }
}

class ResultScreen extends StatefulWidget {
  final InterviewConfig cfg;
  final List<Turn> turns;
  final String summary;
  const ResultScreen(
      {super.key,
        required this.cfg,
        required this.turns,
        required this.summary});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _talking = false, _busy = false;
  static const _fileName = 'hr_interview_report.pdf';
  InterviewConfig get cfg => widget.cfg;
  List<Turn> get turns => widget.turns;
  String get summary => widget.summary;
  late final Scores avg = Scores.average(turns.map((t) => t.scores).toList());

  @override
  void initState() {
    super.initState();
    if (cfg.voice) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _listen();
      });
    }
  }

  @override
  void dispose() {
    voice.stopAll();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _listen() async {
    if (!voice.ttsReady) {
      _snack('Voice output is not available on this device.');
      return;
    }
    if (_talking) {
      await voice.stopSpeaking();
      if (mounted) setState(() => _talking = false);
      return;
    }
    setState(() => _talking = true);
    await voice.speak(
        'Your overall score is ${avg.overall.round()} out of 100. Verdict: ${LocalEngine.verdict(avg.overall)}. $summary');
    if (mounted) setState(() => _talking = false);
  }

  static const _focusSteps = [
    'Practise 60-150 word answers in 3-6 clear sentences and cut filler words.',
    'Mirror the question: use role-specific keywords and one concrete example.',
    'Rehearse STAR stories (Situation, Task, Action, Result) with one number each.',
    'Replace hedges like "I think" with ownership phrases like "I led" and "I delivered".',
    'Frame challenges positively and finish with what you learned.',
  ];

  String _date() {
    final d = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  List<int> _rank() {
    final l = avg.list;
    final idx = List<int>.generate(l.length, (i) => i);
    idx.sort((x, y) => l[x].compareTo(l[y]));
    return idx; // weakest first
  }

  List<String> _nextSteps() =>
      _rank().take(2).map((i) => _focusSteps[i]).toList();

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 150,
          child: Text(k,
              style: const TextStyle(color: C.muted, fontSize: 13.5))),
      Expanded(
          child: Text(v,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _details() {
    if (turns.isEmpty) {
      return const Panel(
          child: Text(
              'No answers were recorded, so there is nothing to score yet. Start a new interview and answer at least one question to get a full report.',
              style: TextStyle(color: C.muted, height: 1.5)));
    }
    final rank = _rank();
    final totalSec = turns.fold<int>(0, (x, t) => x + t.seconds);
    final avgWords = turns.fold<int>(0, (x, t) => x + t.words) / turns.length;
    final paces = turns.where((t) => t.wpm != null).map((t) => t.wpm!).toList();
    final avgWpm =
    paces.isEmpty ? null : paces.reduce((x, y) => x + y) / paces.length;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Report details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        _row('Date', _date()),
        _row('Questions answered', '${turns.length} of ${cfg.rounds}'),
        _row('Total answer time', fmtTime(totalSec)),
        _row('Average length', '${avgWords.round()} words'),
        if (avgWpm != null) _row('Average pace', '${avgWpm.round()} wpm'),
        _row('Top strength',
            '${Scores.labels[rank.last]} (${avg.list[rank.last].round()})'),
        _row('Focus area',
            '${Scores.labels[rank.first]} (${avg.list[rank.first].round()})'),
        const SizedBox(height: 12),
        const Text('Next steps',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 4),
        for (final st in _nextSteps())
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('-  $st',
                style: const TextStyle(
                    color: C.muted, height: 1.45, fontSize: 13.5)),
          ),
      ]),
    );
  }

  List<(String, String)> _detailRows() {
    if (turns.isEmpty) return [];
    final rank = _rank();
    final totalSec = turns.fold<int>(0, (x, t) => x + t.seconds);
    final avgWords = turns.fold<int>(0, (x, t) => x + t.words) / turns.length;
    final paces = turns.where((t) => t.wpm != null).map((t) => t.wpm!).toList();
    final avgWpm =
    paces.isEmpty ? null : paces.reduce((x, y) => x + y) / paces.length;
    return [
      ('Date', _date()),
      ('Questions answered', '${turns.length} of ${cfg.rounds}'),
      ('Total answer time', fmtTime(totalSec)),
      ('Average length', '${avgWords.round()} words'),
      if (avgWpm != null) ('Average pace', '${avgWpm.round()} wpm'),
      (
      'Top strength',
      '${Scores.labels[rank.last]} (${avg.list[rank.last].round()})'
      ),
      (
      'Focus area',
      '${Scores.labels[rank.first]} (${avg.list[rank.first].round()})'
      ),
    ];
  }

  Future<Uint8List> _buildPdf() => PdfReport.build(
    cfg: cfg,
    turns: turns,
    summary: summary,
    date: _date(),
    details: _detailRows(),
    steps: turns.isEmpty ? const [] : _nextSteps(),
  );

  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _downloadPdf() async {
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename: _fileName,
        subject: 'AI HR interview report',
        bounds: _origin(),
      );
      if (kIsWeb) _snack('PDF downloaded');
    } catch (e) {
      _snack('Could not create the PDF: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askEmail() {
    final c = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: C.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: C.border)),
          title: const Text('Email report as PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: 'Recipient email',
                    hintText: 'name@example.com',
                    errorText: err),
              ),
              const SizedBox(height: 12),
              Text(
                  kIsWeb
                      ? 'Your browser downloads the PDF and opens your email app. Attach the downloaded file before sending.'
                      : 'Your email app opens with the PDF attached and the recipient filled in.',
                  style: const TextStyle(
                      color: C.muted, fontSize: 12.5, height: 1.4)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: C.accent, foregroundColor: AppColors.background),
              onPressed: () {
                final v = c.text.trim();
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                  setD(() => err = 'Enter a valid email address');
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _emailPdf() async {
    final to = await _askEmail();
    if (to == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdf();
      final subject = 'AI HR interview report - ${cfg.name}';
      final text = _scorecard();
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: _fileName);
        final uri = Uri.parse(
            'mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent('$text\n\n(Attach the downloaded $_fileName before sending.)')}');
        final opened = await launchUrl(uri);
        if (!opened)
          _snack('Could not open your email app. The PDF was downloaded.');
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: _fileName,
          subject: subject,
          body: text,
          emails: [to],
          bounds: _origin(),
        );
      }
    } catch (e) {
      _snack('Could not prepare the email: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _scorecard() {
    final l = avg.list.map((e) => e.round()).toList();
    return 'I scored ${avg.overall.round()}/100 (${LocalEngine.verdict(avg.overall)}) in an AI HR mock interview for ${cfg.level} ${cfg.role}.\n'
        'Clarity ${l[0]} | Relevance ${l[1]} | Structure ${l[2]} | Confidence ${l[3]} | Positivity ${l[4]}\n'
        'Practise yours with the AI HR Round Simulator.';
  }

  String _report() {
    final b = StringBuffer()
      ..writeln('AI HR ROUND REPORT')
      ..writeln('${cfg.name} - ${cfg.level} ${cfg.role}')
      ..writeln('Date: ${_date()}')
      ..writeln(
          'Overall: ${avg.overall.round()}/100 (${LocalEngine.verdict(avg.overall)})')
      ..writeln();
    for (var i = 0; i < 5; i++) {
      b.writeln('${Scores.labels[i]}: ${avg.list[i].round()}');
    }
    b
      ..writeln()
      ..writeln(summary)
      ..writeln();
    for (var i = 0; i < turns.length; i++) {
      final t = turns[i];
      b
        ..writeln('Q${i + 1}: ${t.q.text}')
        ..writeln('Answer: ${t.answer}')
        ..writeln('Score: ${t.scores.overall.round()} - ${t.feedback}'
            '${t.wpm != null ? ' (pace ${t.wpm!.round()} wpm)' : ''}')
        ..writeln();
    }
    if (turns.isNotEmpty) {
      b.writeln('NEXT STEPS');
      for (final st in _nextSteps()) {
        b.writeln('- $st');
      }
    }
    return b.toString();
  }

  Future<void> _share(String text) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await Share.share(
        text,
        subject: 'My AI HR round result',
        sharePositionOrigin:
        box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      _snack(
          'Sharing is not supported here. Result copied to clipboard instead.');
    }
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap,
      {bool primary = false}) {
    final shape =
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const pad = EdgeInsets.symmetric(vertical: 16);
    return primary
        ? FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
          backgroundColor: C.accent,
          foregroundColor: AppColors.background,
          padding: pad,
          shape: shape),
    )
        : OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
          foregroundColor: C.text,
          side: const BorderSide(color: C.border),
          padding: pad,
          shape: shape),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = LocalEngine.verdict(avg.overall);
    final vc = C.score(avg.overall);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview report',
            style: TextStyle(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                LayoutBuilder(builder: (context, box) {
                  final wide = box.maxWidth > 700;
                  final left = Panel(
                    child: Column(children: [
                      ScoreRing(avg.overall, size: 150, caption: 'out of 100'),
                      const SizedBox(height: 14),
                      Chip2(v, color: vc, icon: Icons.verified_outlined),
                      const SizedBox(height: 12),
                      Text('${cfg.name}  -  ${cfg.level} ${cfg.role}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: C.muted, fontSize: 13)),
                    ]),
                  );
                  final right = Panel(
                    child: Column(children: [
                      Radar(avg.list, height: 220),
                      for (var i = 0; i < 5; i++)
                        ScoreBar(Scores.labels[i], avg.list[i]),
                    ]),
                  );
                  return wide
                      ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 4, child: left),
                        const SizedBox(width: 14),
                        Expanded(flex: 6, child: right),
                      ])
                      : Column(
                      children: [left, const SizedBox(height: 14), right]);
                }),
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Panel summary',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        SelectableText(summary,
                            style: const TextStyle(
                                color: C.muted, height: 1.5, fontSize: 14.5)),
                      ]),
                ),
                const SizedBox(height: 14),
                _details(),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: _btn(
                          _talking ? 'Stop voice' : 'Hear result',
                          _talking
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          _listen)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _btn('Share scorecard', Icons.ios_share_rounded,
                              () => _share(_scorecard()),
                          primary: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _btn(
                          _busy ? 'Preparing PDF...' : 'Download PDF',
                          Icons.picture_as_pdf_rounded,
                          _busy ? () {} : _downloadPdf,
                          primary: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _btn('Email PDF', Icons.mail_outline_rounded,
                          _busy ? () {} : _emailPdf,
                          primary: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _btn('Share full report',
                          Icons.description_outlined, () => _share(_report()))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _btn('Copy report text', Icons.copy_rounded, () {
                        Clipboard.setData(ClipboardData(text: _report()));
                        _snack('Report copied to clipboard');
                      })),
                ]),
                const SizedBox(height: 22),
                const Text('Answer review',
                    style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 10),
                for (var i = 0; i < turns.length; i++) _turnTile(i, turns[i]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: _btn('New interview', Icons.replay_rounded, () {
                    voice.stopAll();
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SetupScreen()),
                            (route) => route.isFirst);
                  }),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _turnTile(int i, Turn t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: C.muted,
          collapsedIconColor: C.muted,
          title: Text('Q${i + 1}. ${t.q.text}',
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              Chip2('${t.scores.overall.round()}',
                  color: C.score(t.scores.overall)),
              Chip2(t.q.category),
              if (t.wpm != null) Chip2('${t.wpm!.round()} wpm'),
            ]),
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your answer',
                style: TextStyle(color: C.muted, fontSize: 12.5)),
            const SizedBox(height: 4),
            SelectableText(t.answer, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 12),
            for (var k = 0; k < 5; k++)
              ScoreBar(Scores.labels[k], t.scores.list[k]),
            const SizedBox(height: 8),
            Text(t.feedback, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 6),
            for (final tip in t.tips)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('-  $tip',
                    style: const TextStyle(
                        color: C.muted, fontSize: 13.5, height: 1.4)),
              ),
          ],
        ),
      ),
    ),
  );
}

// ==========================================================================
//  MODULE: AI group discussion arena
// ==========================================================================

// void main() => runApp(const GDArenaApp());

class Topic {
  final String id, title, category, difficulty;
  const Topic({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
  });
  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
    id: j['id'] as String,
    title: j['title'] as String,
    category: j['category'] as String,
    difficulty: j['difficulty'] as String,
  );
}

class Participant {
  final String name, role, style, avatar;
  const Participant({
    required this.name,
    required this.role,
    required this.style,
    required this.avatar,
  });
  factory Participant.fromJson(Map<String, dynamic> j) => Participant(
    name: j['name'] as String,
    role: j['role'] as String,
    style: j['style'] as String,
    avatar: j['avatar'] as String,
  );
}

const List<Topic> _kFallbackTopics = [
  Topic(
      id: 't1',
      title: 'Is remote work better than working from an office?',
      category: 'Workplace',
      difficulty: 'Easy'),
  Topic(
      id: 't2',
      title: 'Should AI tools be allowed in school exams?',
      category: 'Technology',
      difficulty: 'Medium'),
  Topic(
      id: 't3',
      title: 'Social media: a boon or a bane for students?',
      category: 'Society',
      difficulty: 'Easy'),
  Topic(
      id: 't4',
      title: 'Will AI create more jobs than it replaces?',
      category: 'Technology',
      difficulty: 'Hard'),
  Topic(
      id: 't5',
      title: 'Is online learning as effective as classroom learning?',
      category: 'Education',
      difficulty: 'Medium'),
  Topic(
      id: 't6',
      title: 'Should coding be a compulsory school subject?',
      category: 'Education',
      difficulty: 'Medium'),
  Topic(
      id: 't7',
      title: 'Are electric vehicles the real answer to pollution?',
      category: 'Environment',
      difficulty: 'Hard'),
  Topic(
      id: 't8',
      title: 'Is a startup better than a corporate job for freshers?',
      category: 'Career',
      difficulty: 'Medium'),
];

const List<Participant> _kFallbackPeople = [
  Participant(
      name: 'Aarav', role: 'Data Analyst', style: 'analytical', avatar: 'A'),
  Participant(
      name: 'Meera', role: 'Counsellor', style: 'empathetic', avatar: 'M'),
  Participant(
      name: 'Rohan', role: 'Product Manager', style: 'practical', avatar: 'R'),
  Participant(name: 'Isha', role: 'Debater', style: 'challenging', avatar: 'I'),
];

class GDMessage {
  final String speaker, text;
  final bool user;
  const GDMessage({
    required this.speaker,
    required this.text,
    this.user = false,
  });
}

class GDArenaApp extends StatelessWidget {
  const GDArenaApp({super.key});
  @override
  Widget build(BuildContext context) => const GdHomePage();
}

class GdHomePage extends StatefulWidget {
  const GdHomePage({super.key});
  @override
  State<GdHomePage> createState() => _GdHomePageState();
}

class _GdHomePageState extends State<GdHomePage> {
  late Future<(List<Topic>, List<Participant>)> dataFuture;

  @override
  void initState() {
    super.initState();
    dataFuture = _loadData();
  }

  Future<(List<Topic>, List<Participant>)> _loadData() async {
    try {
      final topicsRaw = await rootBundle.loadString('assets/topics.json');
      final peopleRaw = await rootBundle.loadString('assets/participants.json');
      final topics = (jsonDecode(topicsRaw) as List)
          .map((e) => Topic.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final people = (jsonDecode(peopleRaw) as List)
          .map((e) => Participant.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (topics.isNotEmpty && people.isNotEmpty) return (topics, people);
    } catch (_) {
      // assets are optional: fall back to the built-in topics and panel
    }
    return (_kFallbackTopics, _kFallbackPeople);
  }

  @override
  Widget build(
      BuildContext context,
      ) =>
      FutureBuilder<(List<Topic>, List<Participant>)>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load JSON assets.\nCheck pubspec.yaml and assets/topics.json + assets/participants.json.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          final topics = snapshot.data!.$1;
          final participants = snapshot.data!.$2;
          return Scaffold(
            appBar: AppBar(
              title: const Text('AI Group Discussion Arena'),
              leading: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.groups_rounded),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [AppColors.blueSoft, AppColors.pinkSoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.record_voice_over_rounded, size: 42),
                      SizedBox(height: 12),
                      Text(
                        'Practice. Speak. Lead.',
                        style: TextStyle(
                            fontSize: 27, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Practice a timed group discussion with simulated participants. Speak or type your response, listen to replies, and review your practice score.',
                      ),
                      SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Voice input')),
                          Chip(label: Text('Spoken replies')),
                          Chip(label: Text('3-minute session')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Choose a GD topic',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                ...topics.map(
                      (t) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.pinkSoft,
                        child: Text(
                          t.category.isEmpty
                              ? '?'
                              : t.category[0].toUpperCase(),
                        ),
                      ),
                      title: Text(
                        t.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${t.category}  •  ${t.difficulty}'),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ArenaPage(topic: t, participants: participants),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class ArenaPage extends StatefulWidget {
  final Topic topic;
  final List<Participant> participants;
  const ArenaPage({super.key, required this.topic, required this.participants});
  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <GDMessage>[];
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  Timer? _timer;
  int _seconds = 180, _round = 0, _contributions = 0;
  bool _started = false,
      _finished = false,
      _sending = false,
      _speechReady = false,
      _listening = false,
      _voiceReplies = true;
  String _speechStatus = 'Voice input not initialized';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.48);
    _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initSpeech() async {
    try {
      final ready = await _speech.initialize(
        onStatus: (s) {
          if (mounted)
            setState(() {
              _listening = s == 'listening';
              _speechStatus = s;
            });
        },
        onError: (e) {
          if (mounted)
            setState(() {
              _listening = false;
              _speechStatus = e.errorMsg;
            });
        },
      );
      if (mounted)
        setState(() {
          _speechReady = ready;
          _speechStatus =
          ready ? 'Voice input ready' : 'Speech recognition unavailable';
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _speechReady = false;
          _speechStatus = 'Speech setup failed';
        });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    _tts.stop();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _started = true;
      _finished = false;
      _seconds = 180;
    });
    _messages.add(
      GDMessage(
        speaker: 'Moderator',
        text:
        'Welcome. Topic: ${widget.topic.title}. You have three minutes. Give clear points, examples, and respond respectfully.',
      ),
    );
    _aiOpening();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_seconds <= 1) {
        timer.cancel();
        _finish();
      } else {
        setState(() => _seconds--);
      }
    });
    _jump();
  }

  void _aiOpening() {
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted || _finished || widget.participants.isEmpty) return;
      final p = widget.participants[_round % widget.participants.length];
      final reply = _openingFor(p);
      setState(() {
        _messages.add(GDMessage(speaker: p.name, text: reply));
        _round++;
      });
      _jump();
      if (_voiceReplies) await _speak(reply);
    });
  }

  String _openingFor(Participant p) {
    switch (p.style) {
      case 'analytical':
        return 'I would start by looking at evidence, measurable outcomes, and both short-term and long-term effects. We should distinguish assumptions from facts.';
      case 'empathetic':
        return 'We should consider how this issue affects different groups differently. A good solution should be inclusive and practical for people.';
      case 'challenging':
        return 'I want to challenge the obvious position. What sounds attractive in theory may create unexpected costs, risks, or trade-offs in practice.';
      default:
        return 'From a practical perspective, we should ask what can actually be implemented, what it costs, and how success can be measured.';
    }
  }

  Future<void> _listen() async {
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Speech recognition is unavailable. Check microphone permission and device speech services.',
              ),
            ),
          );
        return;
      }
    }
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (_finished || !_started) return;
    await _speech.listen(
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      onResult: (result) {
        if (!mounted) return;
        setState(() => _controller.text = result.recognizedWords);
      },
    );
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _finished || !_started || _sending) return;
    if (_listening) await _speech.stop();
    _controller.clear();
    setState(() {
      _messages.add(GDMessage(speaker: 'You', text: text, user: true));
      _contributions++;
      _sending = true;
    });
    _jump();
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || _finished) return;
    final p = widget.participants[_round % widget.participants.length];
    final reply = _responseFor(p, text);
    setState(() {
      _messages.add(GDMessage(speaker: p.name, text: reply));
      _round++;
      _sending = false;
    });
    _jump();
    if (_voiceReplies) await _speak(reply);
  }

  String _responseFor(Participant p, String userText) {
    final lower = userText.toLowerCase();
    final mentionsExample = lower.contains('example') ||
        lower.contains('for instance') ||
        lower.contains('such as');
    final prefix =
    mentionsExample ? 'Your example helps make the point concrete. ' : '';
    switch (p.style) {
      case 'challenging':
        return '${prefix}That is a useful point, but what happens when the same approach is applied at scale? We should also consider the counterargument.';
      case 'analytical':
        return '${prefix}Your point would be stronger with evidence or a measurable outcome. Implementation details will determine whether the idea succeeds.';
      case 'empathetic':
        return '${prefix}I agree that perspective matters. Different stakeholders may experience the same change very differently, so inclusion is important.';
      default:
        return '${prefix}That could work if execution is practical. We should define priorities, costs, responsibilities, and measurable outcomes.';
    }
  }

  void _finish() {
    if (_finished || !_started) return;
    _timer?.cancel();
    _speech.stop();
    _tts.stop();
    setState(() {
      _finished = true;
      _sending = false;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPage(
          topic: widget.topic,
          contributions: _contributions,
          secondsUsed: 180 - _seconds,
        ),
      ),
    );
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return Scaffold(
        appBar: AppBar(title: const Text('GD Briefing')),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.topic.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.topic.category} • ${widget.topic.difficulty} difficulty',
              ),
              const SizedBox(height: 26),
              const Text(
                'Your goals',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '• Speak clearly and stay relevant\n• Build on other participants’ ideas\n• Use examples or evidence\n• Disagree respectfully\n• Keep contributions concise',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start 3-minute GD'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.topic.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip:
            _voiceReplies ? 'Mute spoken replies' : 'Enable spoken replies',
            onPressed: () => setState(() => _voiceReplies = !_voiceReplies),
            icon: Icon(
              _voiceReplies
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: _seconds / 180, minHeight: 4),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _bubble(_messages[i]),
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.all(6),
              child: Text('Participant is preparing a reply...'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Icon(
                  _speechReady ? Icons.mic_none_rounded : Icons.mic_off_rounded,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _listening ? 'Listening… speak now' : _speechStatus,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _listen,
                  child: Text(_listening ? 'Stop mic' : 'Speak'),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_finished,
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type or use Speak…',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    tooltip: 'Send contribution',
                    icon: const Icon(Icons.send_rounded),
                  ),
                  IconButton(
                    onPressed: _finish,
                    tooltip: 'Finish discussion',
                    icon: const Icon(Icons.flag_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(GDMessage m) => Align(
    alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 650),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: m.user ? AppColors.pinkSoft : AppColors.blueSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.speaker,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1740B8),
            ),
          ),
          const SizedBox(height: 5),
          Text(m.text),
          if (!m.user)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Read aloud',
                onPressed: () => _speak(m.text),
                icon: const Icon(Icons.volume_up_rounded, size: 18),
              ),
            ),
        ],
      ),
    ),
  );
}

class ReportPage extends StatelessWidget {
  final Topic topic;
  final int contributions, secondsUsed;
  const ReportPage({
    super.key,
    required this.topic,
    required this.contributions,
    required this.secondsUsed,
  });

  int get content => ((contributions * 13) + 45).clamp(0, 100);
  int get communication => ((contributions * 10) + 42).clamp(0, 100);
  int get relevance => ((contributions * 11) + 40).clamp(0, 100);
  int get teamwork => ((contributions * 9) + 48).clamp(0, 100);
  int get leadership => ((contributions * 8) + 38).clamp(0, 100);
  int get total =>
      ((content + communication + relevance + teamwork + leadership) / 5)
          .round();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Practice Report')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 56,
                  color: Color(0xFFFF6FAE),
                ),
                const SizedBox(height: 10),
                Text(
                  '$total / 100',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _grade(total),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${topic.title}\n$secondsUsed seconds • $contributions contributions',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Skill breakdown',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _score(context, 'Content Quality', content),
        _score(context, 'Communication', communication),
        _score(context, 'Relevance', relevance),
        _score(context, 'Teamwork & Listening', teamwork),
        _score(context, 'Leadership', leadership),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice feedback',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  total >= 75
                      ? 'Good practice effort. Keep arguments concise and support important claims with examples.'
                      : 'Keep practicing. Focus on structured points, responding directly to others, and contributing consistently.',
                ),
                const SizedBox(height: 10),
                const Text(
                  'Next targets:\n• Use Point → Reason → Example\n• Refer to another participant before countering\n• Avoid repeating an existing idea\n• End with a concise recommendation',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Practice another topic'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Note: this is a rule-based practice estimate, not a validated AI assessment of spoken language.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );

  Widget _score(BuildContext context, String name, int value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(name), Text('$value/100')],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: value / 100, minHeight: 8),
        ),
      ],
    ),
  );

  String _grade(int x) => x >= 90
      ? 'Outstanding'
      : x >= 75
      ? 'Strong'
      : x >= 60
      ? 'Good'
      : x >= 40
      ? 'Developing'
      : 'Needs Practice';
}

// ==========================================================================
//  MODULE: Foundation MCQ quiz
// ==========================================================================

class QuizQuestion {
  final int id;
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List).cast<Map<String, dynamic>>();
    final correct = rawOptions.indexWhere((o) => o['isCorrect'] == true);

    return QuizQuestion(
      id: json['id'] as int,
      question: json['question'] as String,
      options: rawOptions.map((o) => o['label'] as String).toList(),
      correctIndex: correct,
    );
  }
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const QuizLoader();
  }
}

class QuizLoader extends StatefulWidget {
  const QuizLoader({super.key});

  @override
  State<QuizLoader> createState() => _QuizLoaderState();
}

class _QuizLoaderState extends State<QuizLoader> {
  late Future<List<QuizQuestion>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadQuestions();
  }

  Future<List<QuizQuestion>> _loadQuestions() async {
    try {
      final text = await rootBundle.loadString('assets/questions.json');
      final list = jsonDecode(text) as List;
      final parsed = list
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList();
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      // assets/questions.json is optional: use the built-in question set
    }
    return [
      for (final q in OmrExamData.questions)
        QuizQuestion(
          id: q.number,
          question: q.question,
          options: q.options,
          correctIndex: q.correctAnswer,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuizQuestion>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load questions:\n${snapshot.error}'),
              ),
            ),
          );
        }
        return QuizPage(questions: snapshot.data!);
      },
    );
  }
}

class QuizPage extends StatefulWidget {
  final List<QuizQuestion> questions;

  const QuizPage({super.key, required this.questions});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int current = 0;
  int score = 0;
  bool finished = false;
  final Map<int, int> answers = {};

  QuizQuestion get question => widget.questions[current];

  void selectAnswer(int index) {
    setState(() {
      answers[question.id] = index;
    });
  }

  void next() {
    if (current == widget.questions.length - 1) {
      _finish();
    } else {
      setState(() => current++);
    }
  }

  void previous() {
    if (current > 0) {
      setState(() => current--);
    }
  }

  void _finish() {
    int result = 0;
    for (final q in widget.questions) {
      if (answers[q.id] == q.correctIndex) result++;
    }
    setState(() {
      score = result;
      finished = true;
    });
  }

  void restart() {
    setState(() {
      current = 0;
      score = 0;
      finished = false;
      answers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (finished) {
      return ResultPage(
        questions: widget.questions,
        answers: answers,
        score: score,
        onRestart: restart,
      );
    }

    final selected = answers[question.id];
    final progress = (current + 1) / widget.questions.length;

    return Scaffold(
      appBar: AppBar(title: const Text('100 Question Quiz'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: progress, minHeight: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${current + 1} of ${widget.questions.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${answers.length} answered'),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          question.question,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(question.options.length, (index) {
                      final isSelected = selected == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: RadioListTile<int>(
                            value: index,
                            groupValue: selected,
                            onChanged: (value) {
                              if (value != null) selectAnswer(value);
                            },
                            title: Text(question.options[index]),
                            subtitle: Text(String.fromCharCode(65 + index)),
                            selected: isSelected,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (current > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: previous,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                      ),
                    ),
                  if (current > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: selected == null ? null : next,
                      icon: Icon(
                        current == widget.questions.length - 1
                            ? Icons.check
                            : Icons.arrow_forward,
                      ),
                      label: Text(
                        current == widget.questions.length - 1
                            ? 'Submit Quiz'
                            : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultPage extends StatelessWidget {
  final List<QuizQuestion> questions;
  final Map<int, int> answers;
  final int score;
  final VoidCallback onRestart;

  const ResultPage({
    super.key,
    required this.questions,
    required this.answers,
    required this.score,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = score / questions.length * 100;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Result'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      '$score / ${questions.length}',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_message(percentage)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final q = questions[index];
                final userAnswer = answers[q.id];
                final correct = userAnswer == q.correctIndex;

                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(q.question),
                  subtitle: Text(
                    userAnswer == null
                        ? 'Not answered\nCorrect: ${q.options[q.correctIndex]}'
                        : correct
                        ? 'Your answer: ${q.options[userAnswer]}'
                        : 'Your answer: ${q.options[userAnswer]}\n'
                        'Correct: ${q.options[q.correctIndex]}',
                  ),
                  isThreeLine: true,
                  trailing: Icon(
                    correct ? Icons.check_circle : Icons.cancel,
                    color: correct ? AppColors.blue : AppColors.pink,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake Quiz'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _message(double percentage) {
    if (percentage >= 90) return 'Excellent performance!';
    if (percentage >= 75) return 'Great job!';
    if (percentage >= 60) return 'Good effort!';
    if (percentage >= 40) return 'Keep practicing!';
    return 'Practice and try again!';
  }
}

// ==========================================================================
//  MODULE: Fill in the blanks quiz
// ==========================================================================

// void main() {
//   runApp(const FillBlankQuizApp());
// }

// ============================================================
// QUESTION MODEL
// ============================================================

enum Difficulty { easy, medium, hard }

class FillQuestion {
  final String category;
  final String question;
  final String answer;
  final String explanation;
  final Difficulty difficulty;
  final String hint;

  const FillQuestion({
    required this.category,
    required this.question,
    required this.answer,
    required this.explanation,
    required this.difficulty,
    required this.hint,
  });
}

// ============================================================
// 50 QUESTION BANK
// ============================================================

const List<FillQuestion> questionBank = [
  // ==========================================================
  // PHOTONICS - 10
  // ==========================================================
  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.easy,
    question:
    'The basic particle of electromagnetic radiation is called a ______.',
    answer: 'photon',
    hint: 'It begins with "ph".',
    explanation:
    'A photon is the quantum or fundamental particle of electromagnetic radiation.',
  ),

  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.easy,
    question:
    'LASER stands for Light Amplification by Stimulated Emission of ______.',
    answer: 'Radiation',
    hint: 'The last word in LASER.',
    explanation:
    'LASER means Light Amplification by Stimulated Emission of Radiation.',
  ),

  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.medium,
    question:
    'The phenomenon in which light bends around obstacles is called ______.',
    answer: 'diffraction',
    hint: 'It is a wave phenomenon.',
    explanation:
    'Diffraction is the bending and spreading of waves around obstacles and openings.',
  ),

  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.easy,
    question: 'The refractive index of vacuum is approximately ______.',
    answer: '1',
    hint: 'It is the reference refractive index.',
    explanation: 'The refractive index of vacuum is exactly 1.',
  ),

  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.medium,
    question:
    'In an optical fiber, light is guided mainly by ______ internal reflection.',
    answer: 'total',
    hint: 'TIR stands for this.',
    explanation: 'Optical fibers guide light using total internal reflection.',
  ),

  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.hard,
    question:
    'The process by which an excited atom emits a photon due to an incoming photon is called stimulated ______.',
    answer: 'emission',
    hint: 'It is one of the key processes in lasers.',
    explanation: 'Stimulated emission is fundamental to laser operation.',
  ),

  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.easy,
    question:
    'The unit of wavelength commonly used for visible light is the ______.',
    answer: 'nanometer',
    hint: 'One billionth of a meter.',
    explanation: 'Visible wavelengths are commonly expressed in nanometers.',
  ),

  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.easy,
    question:
    'A device that converts an optical signal into an electrical signal is called a photo______.',
    answer: 'detector',
    hint: 'It detects photons.',
    explanation:
    'Photodetectors convert incident optical radiation into electrical signals.',
  ),

  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.medium,
    question: 'The speed of light in vacuum is approximately ______ m/s.',
    answer: '3 × 10^8',
    hint: 'Three hundred million meters per second.',
    explanation: 'The speed of light in vacuum is approximately 3 × 10^8 m/s.',
  ),

  FillQuestion(
    category: 'Photonics',
    difficulty: Difficulty.medium,
    question:
    'The phenomenon where two coherent light waves produce bright and dark fringes is called ______.',
    answer: 'interference',
    hint: 'Young used this phenomenon.',
    explanation: 'Interference results from superposition of coherent waves.',
  ),

  // ==========================================================
  // PHYSICS - 10
  // ==========================================================
  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.easy,
    question: 'Newton’s first law is also known as the law of ______.',
    answer: 'inertia',
    hint: 'Resistance to change in motion.',
    explanation:
    'Newton’s first law describes the tendency of objects to resist changes in motion.',
  ),

  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.easy,
    question: 'The SI unit of force is the ______.',
    answer: 'newton',
    hint: 'Named after Isaac Newton.',
    explanation: 'The SI unit of force is newton (N).',
  ),

  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.easy,
    question: 'The rate of change of velocity is called ______.',
    answer: 'acceleration',
    hint: 'It is measured in m/s².',
    explanation: 'Acceleration is the rate of change of velocity with time.',
  ),

  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.easy,
    question: 'The SI unit of electric current is the ______.',
    answer: 'ampere',
    hint: 'Symbol A.',
    explanation: 'Electric current is measured in amperes (A).',
  ),

  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.medium,
    question:
    'The force between two electric charges is described by ______ law.',
    answer: 'Coulomb',
    hint: 'Named after Charles-Augustin de Coulomb.',
    explanation: 'Coulomb’s law gives the electrostatic force between charges.',
  ),

  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.easy,
    question: 'The SI unit of energy is the ______.',
    answer: 'joule',
    hint: 'Symbol J.',
    explanation: 'Energy is measured in joules (J).',
  ),

  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.easy,
    question: 'The resistance of a conductor is measured in ______.',
    answer: 'ohms',
    hint: 'Symbol Ω.',
    explanation: 'Electrical resistance is measured in ohms (Ω).',
  ),

  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.easy,
    question:
    'The acceleration due to gravity on Earth is approximately ______ m/s².',
    answer: '9.8',
    hint: 'It is close to 10 m/s².',
    explanation: 'The standard approximate value is 9.8 m/s².',
  ),

  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.medium,
    question:
    'The momentum of an object is equal to mass multiplied by ______.',
    answer: 'velocity',
    hint: 'p = mv.',
    explanation: 'Momentum is p = mv.',
  ),

  FillQuestion(
    category: 'Physics',
    difficulty: Difficulty.easy,
    question: 'The SI unit of frequency is the ______.',
    answer: 'hertz',
    hint: 'Symbol Hz.',
    explanation: 'Frequency is measured in hertz (Hz).',
  ),

  // ==========================================================
  // MATHEMATICS - 10
  // ==========================================================
  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.easy,
    question: 'The value of π approximately equals ______.',
    answer: '3.14159',
    hint: 'The circle constant.',
    explanation: 'π is approximately 3.14159.',
  ),

  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.easy,
    question: 'The derivative of x² is ______.',
    answer: '2x',
    hint: 'Use the power rule.',
    explanation: 'Using the power rule, d(x²)/dx = 2x.',
  ),

  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.medium,
    question: 'The integral of 2x dx is ______.',
    answer: 'x² + C',
    hint: 'Reverse the derivative of x².',
    explanation: '∫2x dx = x² + C.',
  ),

  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.easy,
    question:
    'A triangle with all three sides equal is called an ______ triangle.',
    answer: 'equilateral',
    hint: 'Equal sides.',
    explanation: 'An equilateral triangle has three equal sides.',
  ),

  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.easy,
    question: 'The square root of 144 is ______.',
    answer: '12',
    hint: '12 × 12.',
    explanation: '12 × 12 = 144.',
  ),

  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.easy,
    question: 'The sum of angles in a triangle is ______ degrees.',
    answer: '180',
    hint: 'A straight angle has the same number.',
    explanation: 'The interior angles of a Euclidean triangle add up to 180°.',
  ),

  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.easy,
    question: 'The slope of a horizontal straight line is ______.',
    answer: '0',
    hint: 'There is no vertical change.',
    explanation: 'A horizontal line has slope zero.',
  ),

  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.easy,
    question: 'The factorial of 5, written as 5!, is ______.',
    answer: '120',
    hint: '5 × 4 × 3 × 2 × 1.',
    explanation: '5! = 120.',
  ),

  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.easy,
    question: 'The probability of an event that is certain is ______.',
    answer: '1',
    hint: 'Maximum probability.',
    explanation: 'A certain event has probability 1.',
  ),

  FillQuestion(
    category: 'Mathematics',
    difficulty: Difficulty.medium,
    question: 'The determinant of a 2 × 2 identity matrix is ______.',
    answer: '1',
    hint: 'Identity matrices have a special determinant.',
    explanation: 'The determinant of an identity matrix is 1.',
  ),

  // ==========================================================
  // PYTHON - 10
  // ==========================================================
  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.easy,
    question:
    'The Python function used to display output on the screen is ______.',
    answer: 'print',
    hint: 'You use it like print("Hello").',
    explanation: 'The print() function displays output.',
  ),

  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.easy,
    question: 'The keyword used to define a function in Python is ______.',
    answer: 'def',
    hint: 'Three letters.',
    explanation: 'Python functions are defined using def.',
  ),

  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.easy,
    question:
    'A collection of ordered and changeable elements in Python is called a ______.',
    answer: 'list',
    hint: 'Written using square brackets.',
    explanation: 'Python lists are ordered and mutable collections.',
  ),

  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.easy,
    question: 'The symbol used for a single-line comment in Python is ______.',
    answer: '#',
    hint: 'It is used before a comment.',
    explanation: 'Python uses # for single-line comments.',
  ),

  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.easy,
    question:
    'The function used to find the length of a Python list is ______.',
    answer: 'len',
    hint: 'Three letters.',
    explanation: 'len() returns the number of elements.',
  ),

  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.easy,
    question: 'A Python dictionary stores data using ______ and value pairs.',
    answer: 'key',
    hint: 'The first part of key-value.',
    explanation: 'Dictionaries store key-value pairs.',
  ),

  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.easy,
    question: 'The keyword used to create a class in Python is ______.',
    answer: 'class',
    hint: 'class MyClass:',
    explanation: 'Python classes are declared using class.',
  ),

  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.easy,
    question: 'The Boolean values in Python are True and ______.',
    answer: 'False',
    hint: 'Opposite of True.',
    explanation: 'Python has two Boolean values: True and False.',
  ),

  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.medium,
    question: 'The operator used for exponentiation in Python is ______.',
    answer: '**',
    hint: '2 ? 3 = 8.',
    explanation: 'For example, 2 ** 3 gives 8.',
  ),

  FillQuestion(
    category: 'Python',
    difficulty: Difficulty.easy,
    question: 'The keyword used to import a module is ______.',
    answer: 'import',
    hint: 'Example: import math.',
    explanation: 'Python uses import to load modules.',
  ),

  // ==========================================================
  // DART & FLUTTER - 10
  // ==========================================================
  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.easy,
    question:
    'Flutter applications are primarily written using the ______ programming language.',
    answer: 'Dart',
    hint: 'The language created by Google.',
    explanation: 'Flutter uses Dart as its programming language.',
  ),

  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.easy,
    question: 'The function that starts a Dart program is called ______.',
    answer: 'main',
    hint: 'void ______() {}',
    explanation: 'Dart execution begins with main().',
  ),

  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.easy,
    question:
    'The Flutter widget used for a basic screen layout is commonly called ______.',
    answer: 'Scaffold',
    hint: 'It provides appBar and body.',
    explanation: 'Scaffold provides a basic Material Design structure.',
  ),

  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.easy,
    question:
    'A widget whose state can change during its lifetime is called a ______ widget.',
    answer: 'Stateful',
    hint: 'The opposite of Stateless.',
    explanation: 'StatefulWidget is used when UI state can change.',
  ),

  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.easy,
    question:
    'A widget that does not maintain mutable state is called a ______ widget.',
    answer: 'Stateless',
    hint: 'It does not have mutable state.',
    explanation: 'StatelessWidget represents immutable UI.',
  ),

  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.easy,
    question: 'The Flutter widget used to display text is ______.',
    answer: 'Text',
    hint: 'Text("Hello").',
    explanation: 'Text displays a string of text in Flutter.',
  ),

  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.easy,
    question:
    'The Flutter widget used to arrange children vertically is ______.',
    answer: 'Column',
    hint: 'Vertical arrangement.',
    explanation: 'Column lays out its children vertically.',
  ),

  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.easy,
    question:
    'The Flutter widget used to arrange children horizontally is ______.',
    answer: 'Row',
    hint: 'Horizontal arrangement.',
    explanation: 'Row lays out its children horizontally.',
  ),

  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.medium,
    question:
    'The Dart keyword used to create a compile-time constant is ______.',
    answer: 'const',
    hint: 'Used frequently with Flutter widgets.',
    explanation: 'const creates compile-time constants.',
  ),

  FillQuestion(
    category: 'Dart & Flutter',
    difficulty: Difficulty.medium,
    question:
    'The Flutter function used to rebuild a StatefulWidget after changing state is ______.',
    answer: 'setState',
    hint: 'It tells Flutter the state changed.',
    explanation:
    'Calling setState() tells Flutter that the state has changed and the widget should rebuild.',
  ),
];

// ============================================================
// APP
// ============================================================

class FillBlankQuizApp extends StatelessWidget {
  const FillBlankQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const SetupPage();
  }
}

// ============================================================
// SETUP PAGE
// ============================================================

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  String selectedCategory = 'All';
  Difficulty? selectedDifficulty;

  int questionCount = 10;

  int timePerQuestion = 30;

  bool negativeMarking = true;
  bool showHints = true;

  final categories = const [
    'All',
    'Photonics',
    'Physics',
    'Mathematics',
    'Python',
    'Dart & Flutter',
  ];

  List<FillQuestion> get availableQuestions {
    return questionBank.where((q) {
      final categoryOK =
          selectedCategory == 'All' || q.category == selectedCategory;

      final difficultyOK =
          selectedDifficulty == null || q.difficulty == selectedDifficulty;

      return categoryOK && difficultyOK;
    }).toList();
  }

  void startQuiz() {
    if (availableQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No questions match your selected filters.'),
        ),
      );
      return;
    }

    final questions = List<FillQuestion>.from(availableQuestions)..shuffle();

    final count = min(questionCount, questions.length);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FillQuizPage(
          questions: questions.take(count).toList(),
          timePerQuestion: timePerQuestion,
          negativeMarking: negativeMarking,
          showHints: showHints,
        ),
      ),
    );
  }

  String difficultyName(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fill-in-the-Blanks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // HEADER
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.blueSoft, AppColors.pinkSoft],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.quiz, size: 45),
                      SizedBox(height: 15),
                      Text(
                        'Smart Fill-in-the-Blanks',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Photonics • Physics • Mathematics • Python • Dart & Flutter',
                        style:
                        TextStyle(color: AppColors.inkSoft, fontSize: 15),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // CATEGORY
                const Text(
                  '1. Choose Category',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: categories.map((category) {
                    final selected = selectedCategory == category;

                    return ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 30),

                // DIFFICULTY
                const Text(
                  '2. Difficulty',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('All Levels'),
                      selected: selectedDifficulty == null,
                      onSelected: (_) {
                        setState(() {
                          selectedDifficulty = null;
                        });
                      },
                    ),
                    ...Difficulty.values.map((d) {
                      return ChoiceChip(
                        label: Text(difficultyName(d)),
                        selected: selectedDifficulty == d,
                        onSelected: (_) {
                          setState(() {
                            selectedDifficulty = d;
                          });
                        },
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 30),

                // QUESTION COUNT
                const Text(
                  '3. Number of Questions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  children: [10, 25, 50].map((count) {
                    return ChoiceChip(
                      label: Text('$count Questions'),
                      selected: questionCount == count,
                      onSelected: (_) {
                        setState(() {
                          questionCount = count;
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 30),

                // TIMER
                const Text(
                  '4. Time Per Question',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<int>(
                  value: timePerQuestion,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 seconds')),
                    DropdownMenuItem(value: 30, child: Text('30 seconds')),
                    DropdownMenuItem(value: 60, child: Text('60 seconds')),
                    DropdownMenuItem(value: 120, child: Text('2 minutes')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        timePerQuestion = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 25),

                // OPTIONS
                const Text(
                  '5. Quiz Options',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Negative Marking'),
                  subtitle: const Text('Wrong answer = -0.25 marks'),
                  value: negativeMarking,
                  onChanged: (value) {
                    setState(() {
                      negativeMarking = value;
                    });
                  },
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hints'),
                  subtitle: const Text('Allow one hint per question'),
                  value: showHints,
                  onChanged: (value) {
                    setState(() {
                      showHints = value;
                    });
                  },
                ),

                const SizedBox(height: 20),

                // AVAILABLE
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.library_books, color: AppColors.sky),
                      const SizedBox(width: 12),
                      Text(
                        '${availableQuestions.length} questions available',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // START
                SizedBox(
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: startQuiz,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'START QUIZ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// QUIZ PAGE
// ============================================================

class FillQuizPage extends StatefulWidget {
  final List<FillQuestion> questions;
  final int timePerQuestion;
  final bool negativeMarking;
  final bool showHints;

  const FillQuizPage({
    super.key,
    required this.questions,
    required this.timePerQuestion,
    required this.negativeMarking,
    required this.showHints,
  });

  @override
  State<FillQuizPage> createState() => _FillQuizPageState();
}

class _FillQuizPageState extends State<FillQuizPage> {
  late List<FillQuestion> questions;

  late List<String> answers;
  late List<bool> answered;
  late List<bool> correctAnswers;
  late List<bool> hintUsed;

  int currentIndex = 0;

  late int remainingSeconds;

  Timer? timer;

  bool finished = false;

  int correct = 0;
  int wrong = 0;
  int skipped = 0;
  int hintsUsed = 0;

  double marks = 0;

  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    questions = widget.questions;

    answers = List<String>.filled(questions.length, '');

    answered = List<bool>.filled(questions.length, false);

    correctAnswers = List<bool>.filled(questions.length, false);

    hintUsed = List<bool>.filled(questions.length, false);

    remainingSeconds = widget.timePerQuestion;

    startTimer();
  }

  // ==========================================================
  // TIMER
  // ==========================================================

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || finished) return;

      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        submitCurrentAndMove();
      }
    });
  }

  void resetTimer() {
    remainingSeconds = widget.timePerQuestion;
    startTimer();
  }

  // ==========================================================
  // ANSWER CHECKING
  // ==========================================================

  bool checkAnswer(String user, String correctAnswer) {
    String normalize(String value) {
      return value
          .trim()
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('−', '-');
    }

    return normalize(user) == normalize(correctAnswer);
  }

  void saveCurrentAnswer() {
    answers[currentIndex] = controller.text.trim();
  }

  // ==========================================================
  // NEXT
  // ==========================================================

  void nextQuestion() {
    saveCurrentAnswer();

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        controller.text = answers[currentIndex];
      });

      resetTimer();
    } else {
      finishQuiz();
    }
  }

  // ==========================================================
  // PREVIOUS
  // ==========================================================

  void previousQuestion() {
    saveCurrentAnswer();

    if (currentIndex > 0) {
      setState(() {
        currentIndex--;

        controller.text = answers[currentIndex];

        remainingSeconds = widget.timePerQuestion;
      });

      resetTimer();
    }
  }

  // ==========================================================
  // AUTO MOVE WHEN TIME ENDS
  // ==========================================================

  void submitCurrentAndMove() {
    saveCurrentAnswer();

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;

        controller.text = answers[currentIndex];

        remainingSeconds = widget.timePerQuestion;
      });

      resetTimer();
    } else {
      finishQuiz();
    }
  }

  // ==========================================================
  // HINT
  // ==========================================================

  void showHint() {
    if (!widget.showHints) return;

    if (hintUsed[currentIndex]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hint already used for this question.')),
      );
      return;
    }

    hintUsed[currentIndex] = true;
    hintsUsed++;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('💡 Hint'),
          content: Text(
            questions[currentIndex].hint,
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );

    setState(() {});
  }

  // ==========================================================
  // FINISH
  // ==========================================================

  void finishQuiz() {
    if (finished) return;

    saveCurrentAnswer();

    timer?.cancel();

    correct = 0;
    wrong = 0;
    skipped = 0;
    marks = 0;

    for (int i = 0; i < questions.length; i++) {
      final answer = answers[i].trim();

      if (answer.isEmpty) {
        skipped++;
        continue;
      }

      if (checkAnswer(answer, questions[i].answer)) {
        correctAnswers[i] = true;
        correct++;
        marks += 1;
      } else {
        correctAnswers[i] = false;
        wrong++;

        if (widget.negativeMarking) {
          marks -= 0.25;
        }
      }
    }

    if (marks < 0) {
      marks = 0;
    }

    setState(() {
      finished = true;
    });
  }

  // ==========================================================
  // CATEGORY COLOR
  // ==========================================================

  Color categoryColor(String category) {
    switch (category) {
      case 'Photonics':
        return AppColors.sky;
      case 'Physics':
        return AppColors.rose;
      case 'Mathematics':
        return AppColors.blue;
      case 'Python':
        return AppColors.rose;
      default:
        return AppColors.pinkDark;
    }
  }

  // ==========================================================
  // DIFFICULTY
  // ==========================================================

  String difficultyName(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (finished) {
      return buildResults();
    }

    final q = questions[currentIndex];

    final progress = (currentIndex + 1) / questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill-in-the-Blanks'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                '${currentIndex + 1}/${questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  // PROGRESS
                  LinearProgressIndicator(value: progress, minHeight: 9),

                  const SizedBox(height: 15),

                  // TIMER
                  buildTimer(),

                  const SizedBox(height: 15),

                  // QUESTION
                  Expanded(child: buildQuestionCard(q)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // TIMER UI
  // ==========================================================

  Widget buildTimer() {
    final warning = remainingSeconds <= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color:
        warning ? AppColors.pink.withOpacity(.15) : AppColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: warning ? AppColors.pink : AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: warning ? AppColors.pink : AppColors.sky),
          const SizedBox(width: 10),
          Text(
            formatTime(remainingSeconds),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: warning ? AppColors.pink : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  // ==========================================================
  // QUESTION CARD
  // ==========================================================

  Widget buildQuestionCard(FillQuestion q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CATEGORY + DIFFICULTY
          Wrap(
            spacing: 10,
            children: [
              Chip(
                avatar: const Icon(Icons.category, size: 17),
                label: Text(q.category),
                side: BorderSide(color: categoryColor(q.category)),
              ),
              Chip(
                avatar: const Icon(Icons.bar_chart, size: 17),
                label: Text(difficultyName(q.difficulty)),
              ),
            ],
          ),

          const SizedBox(height: 25),

          Text(
            'Question ${currentIndex + 1}',
            style: const TextStyle(color: AppColors.muted),
          ),

          const SizedBox(height: 15),

          Text(
            q.question,
            style: const TextStyle(
              fontSize: 24,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 30),

          TextField(
            controller: controller,
            autofocus: true,
            onChanged: (value) {
              answers[currentIndex] = value;
            },
            style: const TextStyle(fontSize: 19),
            decoration: InputDecoration(
              labelText: 'Enter your answer',
              hintText: 'Fill in the blank...',
              prefixIcon: const Icon(Icons.edit),
              filled: true,
              fillColor: AppColors.blueSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // HINT
          if (widget.showHints)
            OutlinedButton.icon(
              onPressed: hintUsed[currentIndex] ? null : showHint,
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(hintUsed[currentIndex] ? 'Hint Used' : 'Show Hint'),
            ),

          const Spacer(),

          // NAVIGATION
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: currentIndex == 0 ? null : previousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
              const Spacer(),
              if (currentIndex < questions.length - 1)
                ElevatedButton.icon(
                  onPressed: nextQuestion,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                )
              else
                ElevatedButton.icon(
                  onPressed: finishQuiz,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Submit Quiz'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // RESULTS
  // ==========================================================

  Widget buildResults() {
    final total = questions.length;

    final percentage = (marks / total * 100).clamp(0, 100).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Analytics')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                // SCORE CARD
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.blueSoft, AppColors.pinkSoft],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events, size: 55),
                      const SizedBox(height: 15),
                      const Text(
                        'Quiz Completed!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        '${marks.toStringAsFixed(2)} / $total',
                        style: const TextStyle(
                          fontSize: 45,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // ANALYTICS
                const Text(
                  'Performance Analytics',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.7,
                  children: [
                    analyticsCard(
                      'Correct',
                      '$correct',
                      AppColors.blue,
                      Icons.check_circle,
                    ),
                    analyticsCard(
                        'Wrong', '$wrong', AppColors.pink, Icons.cancel),
                    analyticsCard(
                      'Skipped',
                      '$skipped',
                      AppColors.rose,
                      Icons.skip_next,
                    ),
                    analyticsCard(
                      'Hints Used',
                      '$hintsUsed',
                      AppColors.sky,
                      Icons.lightbulb,
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // NEGATIVE MARKING
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.sky),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.negativeMarking
                              ? 'Negative marking was enabled: -0.25 for each wrong answer.'
                              : 'Negative marking was disabled.',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // CATEGORY ANALYTICS
                const Text(
                  'Category Performance',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                ...buildCategoryAnalytics(),

                const SizedBox(height: 30),

                // QUESTION REVIEW
                const Text(
                  'Question Review',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                ...List.generate(questions.length, (index) {
                  return buildReviewCard(index);
                }),

                const SizedBox(height: 25),

                // RESTART
                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('START NEW QUIZ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ANALYTICS CARD
  // ==========================================================

  Widget analyticsCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(color: AppColors.muted)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CATEGORY ANALYTICS
  // ==========================================================

  List<Widget> buildCategoryAnalytics() {
    final Map<String, int> categoryTotal = {};
    final Map<String, int> categoryCorrect = {};

    for (int i = 0; i < questions.length; i++) {
      final category = questions[i].category;

      categoryTotal[category] = (categoryTotal[category] ?? 0) + 1;

      if (correctAnswers[i]) {
        categoryCorrect[category] = (categoryCorrect[category] ?? 0) + 1;
      }
    }

    return categoryTotal.entries.map((entry) {
      final total = entry.value;

      final correctCount = categoryCorrect[entry.key] ?? 0;

      final percentage = total == 0 ? 0.0 : correctCount / total;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('$correctCount / $total'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: percentage, minHeight: 8),
          ],
        ),
      );
    }).toList();
  }

  // ==========================================================
  // REVIEW CARD
  // ==========================================================

  Widget buildReviewCard(int index) {
    final q = questions[index];

    final correct = correctAnswers[index];

    final userAnswer = answers[index].isEmpty ? 'Not answered' : answers[index];

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: correct ? AppColors.blue : AppColors.pink,
          child: Icon(correct ? Icons.check : Icons.close, color: Colors.white),
        ),
        title: Text('Q${index + 1} • ${q.category}'),
        subtitle: Text(
          correct ? 'Correct' : 'Incorrect',
          style: TextStyle(color: correct ? AppColors.blue : AppColors.pink),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.question,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your answer: $userAnswer',
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 8),
                Text(
                  'Correct answer: ${q.answer}',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  q.explanation,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }
}

// Student Progress Dashboard: 150 students, neon-blue style, progress sliders,
// 3 pages (Dashboard, Students, AI Insights) with on-device ML (pure Dart).
// Single file, NO extra packages. Copy to lib/main.dart and run:
//   flutter run -d chrome

// ==========================================================================
//  MODULE: Student dashboard
// ==========================================================================

// void main() => runApp(const StudentDashboardApp());

// ─────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────

const Color kBgTop = AppColors.background;
const Color kBgBottom = AppColors.background;
const Color kCard = AppColors.card;
const Color kBorder = AppColors.line;
const Color kBlue = AppColors.blue;
const Color kCyan = AppColors.sky;
const Color kGreen = AppColors.green;
const Color kOrange = AppColors.orange;
const Color kRed = AppColors.red;
const Color kPurple = AppColors.purple;
const Color kMuted = AppColors.muted;

const List<Color> kPaletteSd = [kBlue, kCyan, kGreen, kOrange, kPurple];

const TextStyle kMutedStyle = TextStyle(fontSize: 12, color: kMuted);
const TextStyle kTitleStyle =
TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

// ─────────────────────────────────────────────────────────────
// DEMO DATA: 150 students (deterministic)
// ─────────────────────────────────────────────────────────────

const List<String> kBatchesSd = [
  'Batch A',
  'Batch B',
  'Batch C',
  'Batch D',
  'Batch E'
];
const List<String> kStatusesSd = ['Completed', 'On track', 'Behind', 'At risk'];
const List<String> kStatusShort = ['Done', 'On track', 'Behind', 'At risk'];
const List<String> kSkillsSd = [
  'Math',
  'Science',
  'English',
  'Coding',
  'Reasoning'
];
const int kWeeksSd = 12;

Color statusColorSd(String status) {
  switch (status) {
    case 'Completed':
      return kGreen;
    case 'On track':
      return kBlue;
    case 'Behind':
      return kOrange;
    default:
      return kRed;
  }
}

double avgSd(Iterable<double> values) {
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a + b) / values.length;
}

class Student {
  final int id;
  final String name;
  final String batch;
  final List<double> weekly; // cumulative progress % for 12 weeks
  final double hours;
  final double score;
  final double attendance;
  final List<double> skills; // 5 skill levels

  Student({
    required this.id,
    required this.name,
    required this.batch,
    required this.weekly,
    required this.hours,
    required this.score,
    required this.attendance,
    required this.skills,
  });

  double get progress => weekly.last;

  String get status {
    if (progress >= 80) return 'Completed';
    if (progress >= 50) return 'On track';
    if (progress >= 25) return 'Behind';
    return 'At risk';
  }

  String get initials {
    final parts = name.split(' ');
    return '${parts.first[0]}${parts.last[0]}';
  }
}

List<Student> generateStudents() {
  final rnd = math.Random(2026);
  const first = [
    'Aarav',
    'Vivaan',
    'Aditya',
    'Diya',
    'Ananya',
    'Ishaan',
    'Kavya',
    'Rohan',
    'Meera',
    'Arjun',
    'Sneha',
    'Karthik',
    'Priya',
    'Rahul',
    'Divya',
    'Vikram',
    'Nisha',
    'Suresh',
    'Lakshmi',
    'Manoj',
    'Pooja',
    'Naveen',
    'Harini',
    'Gokul',
    'Swathi',
  ];
  const last = [
    'Kumar',
    'Sharma',
    'Reddy',
    'Iyer',
    'Nair',
    'Patel',
    'Singh',
    'Menon',
    'Das',
    'Gupta',
    'Rao',
    'Pillai',
    'Naidu',
  ];

  return List.generate(150, (i) {
    final pace = 1.5 + rnd.nextDouble() * 8.5;
    double current = 0;
    final weekly = <double>[];
    for (var w = 0; w < kWeeksSd; w++) {
      current += pace * (0.5 + rnd.nextDouble());
      if (current > 100) current = 100;
      weekly.add(current);
    }
    final progress = weekly.last;
    final hours = 20 + pace * 12 + rnd.nextDouble() * 40;
    final score = (35 + progress * 0.5 + rnd.nextDouble() * 15)
        .clamp(0.0, 100.0)
        .toDouble();
    final attendance = (60 + progress * 0.3 + rnd.nextDouble() * 10)
        .clamp(0.0, 100.0)
        .toDouble();
    final skills = List.generate(
      kSkillsSd.length,
          (_) => (progress * 0.6 + 20 + rnd.nextDouble() * 20)
          .clamp(0.0, 100.0)
          .toDouble(),
    );
    return Student(
      id: i + 1,
      name:
      '${first[i % first.length]} ${last[(i * 2 + i ~/ first.length) % last.length]}',
      batch: kBatchesSd[i % kBatchesSd.length],
      weekly: weekly,
      hours: hours,
      score: score,
      attendance: attendance,
      skills: skills,
    );
  });
}

final List<Student> kStudents = generateStudents();

// ─────────────────────────────────────────────────────────────
// ML / AI ENGINE (pure Dart, trains on-device in milliseconds)
//  1. Linear regression   -> forecast each student's progress
//  2. Logistic regression -> probability of completing the course
//  3. K-means clustering  -> group students by behaviour
//  4. Rule-based coach    -> personalised recommendations
// ─────────────────────────────────────────────────────────────

const List<String> kClusterNamesSd = [
  'Top performers',
  'Steady learners',
  'Slow starters',
  'Need support',
];
const List<String> kClusterShortSd = ['Top', 'Steady', 'Slow', 'Support'];
const List<String> kFeatureNamesSd = [
  'Week-6 progress',
  'Early weekly pace',
  'Hours studied',
  'Test score',
];

final List<Color> kClusterColorsSd = [
  statusColorSd('Completed'),
  statusColorSd('On track'),
  statusColorSd('Behind'),
  statusColorSd('At risk'),
];

double sigmoidSd(double z) => 1 / (1 + math.exp(-z));

class ForecastSd {
  final double slope;
  final double intercept;
  const ForecastSd(this.slope, this.intercept);

  double at(int week) =>
      (intercept + slope * week).clamp(0.0, 100.0).toDouble();

  double? get etaWeek {
    if (slope < 0.05) return null;
    return (100 - intercept) / slope;
  }
}

ForecastSd fitLineSd(List<double> ys) {
  final n = ys.length;
  final mx = (n + 1) / 2;
  final my = avgSd(ys);
  var sxy = 0.0;
  var sxx = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = (i + 1) - mx;
    sxy += dx * (ys[i] - my);
    sxx += dx * dx;
  }
  final slope = sxx == 0 ? 0.0 : sxy / sxx;
  return ForecastSd(slope, my - slope * mx);
}

/// Features use only the FIRST 6 WEEKS to predict who finishes (>= 80%).
List<double> mlFeaturesSd(Student s) => [
  s.weekly[5],
  fitLineSd(s.weekly.sublist(0, 6)).slope,
  s.hours,
  s.score,
];

class TrainResultSd {
  final List<double> w;
  final double b;
  final List<double> mean;
  final List<double> std;
  final List<double> trainAcc;
  final List<double> testAcc;

  TrainResultSd(
      this.w, this.b, this.mean, this.std, this.trainAcc, this.testAcc);

  double predict(List<double> x) {
    var s = b;
    for (var j = 0; j < w.length; j++) {
      s += w[j] * (x[j] - mean[j]) / std[j];
    }
    return sigmoidSd(s);
  }
}

TrainResultSd trainLogisticSd(List<Student> students) {
  final xs = students.map(mlFeaturesSd).toList();
  final ys = students.map((s) => s.progress >= 80 ? 1.0 : 0.0).toList();

  // 70% train / 30% test
  final trainIdx = <int>[];
  final testIdx = <int>[];
  for (var i = 0; i < students.length; i++) {
    if (i % 10 < 7) {
      trainIdx.add(i);
    } else {
      testIdx.add(i);
    }
  }

  final d = xs.first.length;
  final mean = List<double>.filled(d, 0);
  final std = List<double>.filled(d, 1);
  for (var j = 0; j < d; j++) {
    final col = trainIdx.map((i) => xs[i][j]).toList();
    final m = avgSd(col);
    final variance = avgSd(col.map((v) => (v - m) * (v - m)));
    mean[j] = m;
    std[j] = variance < 1e-9 ? 1.0 : math.sqrt(variance);
  }

  final z = xs
      .map((x) => List.generate(d, (j) => (x[j] - mean[j]) / std[j]))
      .toList();

  final w = List<double>.filled(d, 0);
  var b = 0.0;
  const lr = 0.4;
  const epochs = 400;

  double prob(int i) {
    var s = b;
    for (var j = 0; j < d; j++) {
      s += w[j] * z[i][j];
    }
    return sigmoidSd(s);
  }

  double accuracy(List<int> idx) {
    var ok = 0;
    for (final i in idx) {
      if ((prob(i) >= 0.5) == (ys[i] == 1.0)) ok++;
    }
    return 100 * ok / idx.length;
  }

  final trainAcc = <double>[];
  final testAcc = <double>[];
  for (var e = 1; e <= epochs; e++) {
    final gw = List<double>.filled(d, 0);
    var gb = 0.0;
    for (final i in trainIdx) {
      final err = prob(i) - ys[i];
      for (var j = 0; j < d; j++) {
        gw[j] += err * z[i][j];
      }
      gb += err;
    }
    for (var j = 0; j < d; j++) {
      w[j] -= lr * gw[j] / trainIdx.length;
    }
    b -= lr * gb / trainIdx.length;
    if (e % 20 == 0) {
      trainAcc.add(accuracy(trainIdx));
      testAcc.add(accuracy(testIdx));
    }
  }
  return TrainResultSd(w, b, mean, std, trainAcc, testAcc);
}

class ClusterResultSd {
  final List<int> assignment; // cluster rank per student (0 = best group)
  final List<int> sizes;
  final List<double> avgProgress;
  final List<double> avgScore;
  final List<double> avgHours;
  ClusterResultSd(this.assignment, this.sizes, this.avgProgress, this.avgScore,
      this.avgHours);
}

ClusterResultSd kMeansSd(List<Student> students, int k) {
  const d = 3;
  final raw =
  students.map((s) => <double>[s.progress, s.score, s.hours]).toList();

  final mean = List<double>.filled(d, 0);
  final std = List<double>.filled(d, 1);
  for (var j = 0; j < d; j++) {
    final col = raw.map((r) => r[j]).toList();
    final m = avgSd(col);
    final variance = avgSd(col.map((v) => (v - m) * (v - m)));
    mean[j] = m;
    std[j] = variance < 1e-9 ? 1.0 : math.sqrt(variance);
  }
  final z = raw
      .map((r) => List<double>.generate(d, (j) => (r[j] - mean[j]) / std[j]))
      .toList();

  final rnd = math.Random(7);
  final chosen = <int>[];
  while (chosen.length < k) {
    final i = rnd.nextInt(students.length);
    if (!chosen.contains(i)) chosen.add(i);
  }
  final cent = chosen.map((i) => List<double>.from(z[i])).toList();
  final assign = List<int>.filled(students.length, 0);

  for (var iter = 0; iter < 30; iter++) {
    for (var i = 0; i < students.length; i++) {
      var best = 0;
      var bestDist = double.infinity;
      for (var c = 0; c < k; c++) {
        var dist = 0.0;
        for (var j = 0; j < d; j++) {
          final diff = z[i][j] - cent[c][j];
          dist += diff * diff;
        }
        if (dist < bestDist) {
          bestDist = dist;
          best = c;
        }
      }
      assign[i] = best;
    }
    final sums = List.generate(k, (_) => List<double>.filled(d, 0));
    final counts = List<int>.filled(k, 0);
    for (var i = 0; i < students.length; i++) {
      counts[assign[i]]++;
      for (var j = 0; j < d; j++) {
        sums[assign[i]][j] += z[i][j];
      }
    }
    for (var c = 0; c < k; c++) {
      if (counts[c] > 0) {
        for (var j = 0; j < d; j++) {
          cent[c][j] = sums[c][j] / counts[c];
        }
      }
    }
  }

  // Rank clusters by average progress so rank 0 = strongest group
  final rawAvgProgress = List.generate(k, (c) {
    final members = [
      for (var i = 0; i < students.length; i++)
        if (assign[i] == c) students[i].progress
    ];
    return avgSd(members);
  });
  final order = List<int>.generate(k, (c) => c)
    ..sort((a, b) => rawAvgProgress[b].compareTo(rawAvgProgress[a]));
  final rankOf = List<int>.filled(k, 0);
  for (var r = 0; r < k; r++) {
    rankOf[order[r]] = r;
  }
  final ranked = assign.map((c) => rankOf[c]).toList();

  List<double> groupAvg(double Function(Student) pick) => List.generate(k, (r) {
    final members = [
      for (var i = 0; i < students.length; i++)
        if (ranked[i] == r) pick(students[i])
    ];
    return avgSd(members);
  });

  return ClusterResultSd(
    ranked,
    List.generate(k, (r) => ranked.where((x) => x == r).length),
    groupAvg((s) => s.progress),
    groupAvg((s) => s.score),
    groupAvg((s) => s.hours),
  );
}

class MlResultSd {
  final List<ForecastSd> forecasts; // index = student id - 1
  final List<double> completeProb;
  final TrainResultSd model;
  final ClusterResultSd clusters;
  MlResultSd(this.forecasts, this.completeProb, this.model, this.clusters);
}

MlResultSd runMlSd(List<Student> students) {
  final model = trainLogisticSd(students);
  return MlResultSd(
    students.map((s) => fitLineSd(s.weekly)).toList(),
    students.map((s) => model.predict(mlFeaturesSd(s))).toList(),
    model,
    kMeansSd(students, 4),
  );
}

final MlResultSd kMlSd = runMlSd(kStudents);

List<String> coachTipsSd(Student s) {
  final i = s.id - 1;
  final prob = kMlSd.completeProb[i];
  final f = kMlSd.forecasts[i];
  final tips = <String>[];

  if (s.progress < 80 && prob < 0.4) {
    tips.add(
        'High risk of not finishing (${((1 - prob) * 100).round()}%). Arrange a mentor check-in this week.');
  }
  if (s.progress < 80 && f.slope < 5) {
    tips.add(
        'Pace is ${f.slope.toStringAsFixed(1)}% per week. Add about 30 minutes of daily practice.');
  }
  var weakest = 0;
  for (var k = 1; k < kSkillsSd.length; k++) {
    if (s.skills[k] < s.skills[weakest]) weakest = k;
  }
  if (s.skills[weakest] < 55) {
    tips.add(
        'Weakest subject is ${kSkillsSd[weakest]} (${s.skills[weakest].toStringAsFixed(0)}). Give it extra practice.');
  }
  if (s.attendance < 70) {
    tips.add(
        'Attendance is ${s.attendance.toStringAsFixed(0)}%. Follow up with the student.');
  }
  if (s.progress >= 80) {
    tips.add(
        'Course nearly done. Suggest an advanced module or a peer-mentor role.');
  }
  if (tips.isEmpty) {
    tips.add('Healthy pace. Keep the current routine.');
  }
  return tips;
}

// ─────────────────────────────────────────────────────────────
// APP SHELL: sidebar, header, right gear rail
// ─────────────────────────────────────────────────────────────

class StudentDashboardApp extends StatelessWidget {
  const StudentDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardShell();
  }
}

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int page = 0;
  String batch = 'All';
  double riskThreshold = 0.4;

  static const titles = [
    'Student Progress Dashboard',
    'Students',
    'AI Insights'
  ];

  List<Student> get scope => batch == 'All'
      ? kStudents
      : kStudents.where((s) => s.batch == batch).toList();

  void openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'High-risk threshold: completion probability below ${(riskThreshold * 100).round()}%',
              ),
              Slider(
                value: riskThreshold,
                min: 0.2,
                max: 0.7,
                divisions: 10,
                onChanged: (v) {
                  setState(() => riskThreshold = v);
                  setSheet(() {});
                },
              ),
              const Text(
                'Students whose predicted chance of finishing is below this value are flagged high-risk on the AI Insights page.',
                style: kMutedStyle,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = scope;
    final pages = <Widget>[
      StudentDashboardPage(students: students),
      StudentsPage(students: students),
      AiPage(students: students, riskThreshold: riskThreshold),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBgTop, kBgBottom],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final extended = c.maxWidth >= 1000;
            final showRail = c.maxWidth >= 700;
            final narrow = c.maxWidth < 600;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!narrow)
                  Sidebar(
                    extended: extended,
                    selected: page,
                    onSelect: (i) => setState(() => page = i),
                    onSettings: openSettings,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(titles[page],
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: kBorder),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('${students.length} students',
                                      style: kMutedStyle),
                                ),
                                const SizedBox(width: 10),
                                const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: kBlue,
                                  child: Icon(Icons.person,
                                      size: 18, color: AppColors.ink),
                                ),
                                if (narrow)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.settings_rounded),
                                    onPressed: openSettings,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (narrow)
                              SizedBox(
                                height: 40,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (var i = 0; i < titles.length; i++)
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          avatar:
                                          Icon(Sidebar.icons[i], size: 16),
                                          label: Text(Sidebar.labels[i]),
                                          selected: page == i,
                                          onSelected: (_) =>
                                              setState(() => page = i),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            SizedBox(
                              height: 40,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final b in ['All', ...kBatchesSd])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(b),
                                        selected: batch == b,
                                        onSelected: (_) =>
                                            setState(() => batch = b),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: pages[page]),
                    ],
                  ),
                ),
                if (showRail) GearRail(onTap: openSettings),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class Sidebar extends StatelessWidget {
  final bool extended;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;
  const Sidebar({
    super.key,
    required this.extended,
    required this.selected,
    required this.onSelect,
    required this.onSettings,
  });

  static const icons = [
    Icons.dashboard_rounded,
    Icons.groups_rounded,
    Icons.psychology_rounded
  ];
  static const labels = ['Dashboard', 'Students', 'AI Insights'];

  Widget item(
      IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? kBlue.withAlpha(70) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
            Border.all(color: isSelected ? kCyan : kBorder.withAlpha(120)),
          ),
          child: Row(
            mainAxisAlignment:
            extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isSelected ? kCyan : kMuted),
              if (extended) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 190 : 64,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder, width: 1.2),
        boxShadow: [BoxShadow(color: kBorder.withAlpha(60), blurRadius: 14)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment:
              extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                const Icon(Icons.school_rounded, color: kCyan, size: 26),
                if (extended) ...[
                  const SizedBox(width: 8),
                  const Text('EduPulse',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          const Divider(color: AppColors.line),
          for (var i = 0; i < icons.length; i++)
            item(icons[i], labels[i], selected == i, () => onSelect(i)),
          const Spacer(),
          item(Icons.settings_rounded, 'Settings', false, onSettings),
        ],
      ),
    );
  }
}

class GearRail extends StatelessWidget {
  final VoidCallback onTap;
  const GearRail({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: InkResponse(
                onTap: onTap,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kCard,
                    border: Border.all(color: kBorder, width: 1.4),
                    boxShadow: [
                      BoxShadow(color: kBorder.withAlpha(90), blurRadius: 12)
                    ],
                  ),
                  child: const Icon(Icons.settings, color: kCyan, size: 24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────

class NeonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const NeonCard(
      {super.key,
        required this.child,
        this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder, width: 1.2),
        boxShadow: [BoxShadow(color: kBorder.withAlpha(50), blurRadius: 14)],
      ),
      child: child,
    );
  }
}

class ResponsiveWrap extends StatelessWidget {
  final double minWidth;
  final double gap;
  final List<Widget> children;
  const ResponsiveWrap({
    super.key,
    required this.minWidth,
    required this.children,
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = math.max(1, ((c.maxWidth + gap) / (minWidth + gap)).floor());
      final w = ((c.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: kMutedStyle),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            Icon(icon, color: color, size: 26),
          ],
        ),
      ),
    );
  }
}

class DonutTile extends StatelessWidget {
  final List<int> counts;
  final int total;
  const DonutTile({super.key, required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                size: Size.infinite,
                painter: DonutPainterSd(
                  values: counts.map((c) => c.toDouble()).toList(),
                  colors: kStatusesSd.map(statusColorSd).toList(),
                  centerText: '$total',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < kStatusesSd.length; i++)
                    Text('${kStatusShort[i]} ${counts[i]}',
                        style: TextStyle(
                            fontSize: 10.5,
                            height: 1.25,
                            color: statusColorSd(kStatusesSd[i]))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final double height;
  const ChartPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.height = 230,
  });

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kTitleStyle),
          const SizedBox(height: 2),
          Text(subtitle, style: kMutedStyle),
          const SizedBox(height: 12),
          SizedBox(height: height, width: double.infinity, child: child),
          if (footer != null) ...[const SizedBox(height: 8), footer!],
        ],
      ),
    );
  }
}

class LegendSd extends StatelessWidget {
  final List<String> labels;
  final List<Color> colors;
  const LegendSd({super.key, required this.labels, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (var i = 0; i < labels.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                BoxDecoration(color: colors[i], shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(labels[i], style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}

/// The "progress slider indicator": a track, a gradient fill and a round handle.
class ProgressSlider extends StatelessWidget {
  final double value; // 0..100
  final Color color;
  const ProgressSlider({super.key, required this.value, this.color = kBlue});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      width: double.infinity,
      child: CustomPaint(
        painter:
        _SliderPainter((value / 100).clamp(0.0, 1.0).toDouble(), color),
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  final double value;
  final Color color;
  _SliderPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const r = 7.0;
    final cy = size.height / 2;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - 3, size.width, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(track, Paint()..color = const Color(0x2E12224A));

    final tx = r + (size.width - 2 * r) * value;
    final fillRect = Rect.fromLTWH(0, cy - 3, math.max(tx, 1), 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fillRect, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(colors: [color.withAlpha(110), color])
            .createShader(fillRect),
    );

    canvas.drawCircle(
        Offset(tx, cy), r + 4, Paint()..color = color.withAlpha(60));
    canvas.drawCircle(Offset(tx, cy), r, Paint()..color = AppColors.pink);
    canvas.drawCircle(
      Offset(tx, cy),
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final double labelWidth;
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    this.color = kBlue,
    this.labelWidth = 76,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
          Expanded(child: ProgressSlider(value: value, color: color)),
          const SizedBox(width: 8),
          SizedBox(
            width: 38,
            child: Text('${value.round()}%',
                textAlign: TextAlign.right,
                style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAGE 1: DASHBOARD
// ─────────────────────────────────────────────────────────────

class StudentDashboardPage extends StatelessWidget {
  final List<Student> students;
  const StudentDashboardPage({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    final n = students.length;
    final avgProgress = avgSd(students.map((s) => s.progress));
    final completed = students.where((s) => s.status == 'Completed').length;
    final atRisk = students.where((s) => s.status == 'At risk').length;
    final counts = kStatusesSd
        .map((st) => students.where((s) => s.status == st).length)
        .toList();

    List<double> weeklyAvg(List<Student> g) =>
        List.generate(kWeeksSd, (w) => avgSd(g.map((s) => s.weekly[w])));

    final sorted = [...students]
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final groupSize = math.max(1, (n * 0.1).round());
    final top = sorted.take(groupSize).toList();
    final bottom = sorted.reversed.take(groupSize).toList();

    final batchAvg = kBatchesSd
        .map((b) =>
        avgSd(kStudents.where((s) => s.batch == b).map((s) => s.progress)))
        .toList();
    final skillAvg = List.generate(
        kSkillsSd.length, (k) => avgSd(students.map((s) => s.skills[k])));
    final attendanceAvg = avgSd(students.map((s) => s.attendance));
    final scoreAvg = avgSd(students.map((s) => s.score));
    final weekLabels = List.generate(kWeeksSd, (w) => 'W${w + 1}');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ResponsiveWrap(
          minWidth: 170,
          children: [
            KpiTile(
                label: 'Students',
                value: '$n',
                icon: Icons.groups,
                color: kCyan),
            KpiTile(
                label: 'Avg progress',
                value: '${avgProgress.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                color: kGreen),
            KpiTile(
                label: 'Completed',
                value: '$completed',
                icon: Icons.verified,
                color: kBlue),
            KpiTile(
                label: 'At risk',
                value: '$atRisk',
                icon: Icons.warning_amber_rounded,
                color: kRed),
            DonutTile(counts: counts, total: n),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveWrap(
          minWidth: 400,
          children: [
            ChartPanel(
              title: 'Weekly progress trend',
              subtitle: 'Cumulative progress: all vs top 10% vs bottom 10%',
              footer: const LegendSd(
                labels: ['All students', 'Top 10%', 'Bottom 10%'],
                colors: [kBlue, kGreen, kRed],
              ),
              child: CustomPaint(
                size: Size.infinite,
                painter: NeonLinePainter(
                  series: [
                    LineSeriesSd(weeklyAvg(students), kBlue, fill: true),
                    LineSeriesSd(weeklyAvg(top), kGreen),
                    LineSeriesSd(weeklyAvg(bottom), kRed),
                  ],
                  xLabels: weekLabels,
                ),
              ),
            ),
            ChartPanel(
              title: 'Average progress by batch',
              subtitle: 'All 150 students',
              child: CustomPaint(
                size: Size.infinite,
                painter: NeonBarPainter(
                  values: batchAvg,
                  labels: const ['A', 'B', 'C', 'D', 'E'],
                  maxY: 100,
                  colors: kPaletteSd,
                  valueSuffix: '%',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveWrap(
          minWidth: 300,
          children: [
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Batch progress', style: kTitleStyle),
                  const Text('Average completion per batch',
                      style: kMutedStyle),
                  const SizedBox(height: 8),
                  for (var i = 0; i < kBatchesSd.length; i++)
                    SliderRow(
                        label: kBatchesSd[i],
                        value: batchAvg[i],
                        color: kPaletteSd[i]),
                ],
              ),
            ),
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subject mastery', style: kTitleStyle),
                  const Text('Average skill level in this view',
                      style: kMutedStyle),
                  const SizedBox(height: 8),
                  for (var k = 0; k < kSkillsSd.length; k++)
                    SliderRow(
                        label: kSkillsSd[k],
                        value: skillAvg[k],
                        color: kPaletteSd[k]),
                  SliderRow(
                      label: 'Attendance', value: attendanceAvg, color: kCyan),
                  SliderRow(label: 'Avg score', value: scoreAvg, color: kGreen),
                ],
              ),
            ),
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top performers', style: kTitleStyle),
                  const Text('Highest progress right now', style: kMutedStyle),
                  const SizedBox(height: 8),
                  for (final s in sorted.take(6))
                    SliderRow(
                      label: s.name,
                      value: s.progress,
                      color: kGreen,
                      labelWidth: 100,
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAGE 2: STUDENTS (search, filter, progress slider per student)
// ─────────────────────────────────────────────────────────────

class StudentsPage extends StatefulWidget {
  final List<Student> students;
  const StudentsPage({super.key, required this.students});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String query = '';
  String status = 'All';

  @override
  Widget build(BuildContext context) {
    final list = widget.students
        .where((s) =>
    (status == 'All' || s.status == status) &&
        s.name.toLowerCase().contains(query.toLowerCase()))
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search student name…',
              filled: true,
              fillColor: kCard,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder),
              ),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final s in ['All', ...kStatusesSd])
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: status == s,
                    onSelected: (_) => setState(() => status = s),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${list.length} students · tap one for AI details',
                style: kMutedStyle),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => StudentTile(student: list[i]),
          ),
        ),
      ],
    );
  }
}

class StudentTile extends StatelessWidget {
  final Student student;
  const StudentTile({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final color = statusColorSd(student.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showStudentSheet(context, student),
        child: NeonCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withAlpha(60),
                child: Text(student.initials,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('#${student.id}  ${student.name}',
                              overflow: TextOverflow.ellipsis,
                              style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Text(student.status,
                            style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text(
                        '${student.batch} · attendance ${student.attendance.toStringAsFixed(0)}%',
                        style: kMutedStyle),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                            child: ProgressSlider(
                                value: student.progress, color: color)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 38,
                          child: Text('${student.progress.round()}%',
                              textAlign: TextAlign.right,
                              style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showStudentSheet(BuildContext context, Student s) {
  final i = s.id - 1;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name,
              style:
              const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '${s.batch} · ${s.status} · ${s.hours.toStringAsFixed(0)} h studied · score ${s.score.toStringAsFixed(1)} · attendance ${s.attendance.toStringAsFixed(0)}%',
            style: kMutedStyle,
          ),
          const SizedBox(height: 16),
          const Text('Weekly progress', style: kTitleStyle),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              size: Size.infinite,
              painter: NeonLinePainter(
                series: [
                  LineSeriesSd(s.weekly, statusColorSd(s.status), fill: true)
                ],
                xLabels: List.generate(kWeeksSd, (w) => 'W${w + 1}'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Subjects', style: kTitleStyle),
          for (var k = 0; k < kSkillsSd.length; k++)
            SliderRow(
                label: kSkillsSd[k], value: s.skills[k], color: kPaletteSd[k]),
          const SizedBox(height: 12),
          const Text('AI insights', style: kTitleStyle),
          const SizedBox(height: 6),
          Text(
            'Forecast at week 20: ${kMlSd.forecasts[i].at(20).toStringAsFixed(0)}%  ·  '
                'completion probability: ${(kMlSd.completeProb[i] * 100).toStringAsFixed(0)}%  ·  '
                'group: ${kClusterNamesSd[kMlSd.clusters.assignment[i]]}',
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          for (final tip in coachTipsSd(s))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: kOrange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip)),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// PAGE 3: AI INSIGHTS
// ─────────────────────────────────────────────────────────────

class AiPage extends StatelessWidget {
  final List<Student> students;
  final double riskThreshold;
  const AiPage(
      {super.key, required this.students, required this.riskThreshold});

  @override
  Widget build(BuildContext context) {
    final ml = kMlSd;
    final model = ml.model;
    final cl = ml.clusters;

    final finishers =
        students.where((s) => ml.forecasts[s.id - 1].at(20) >= 80).length;
    final highRisk = students
        .where(
            (s) => s.progress < 80 && ml.completeProb[s.id - 1] < riskThreshold)
        .length;

    final absW = model.w.map((v) => v.abs()).toList();
    final totalW = absW.fold<double>(0, (a, b) => a + b);
    final importance =
    absW.map((v) => totalW == 0 ? 0.0 : v / totalW * 100).toList();

    final actualAvg =
    List.generate(kWeeksSd, (w) => avgSd(students.map((s) => s.weekly[w])));
    final forecastAvg = List.generate(
      20,
          (w) => w < kWeeksSd
          ? actualAvg[w]
          : avgSd(students.map((s) => ml.forecasts[s.id - 1].at(w + 1))),
    );
    final labels20 = List.generate(20, (w) => 'W${w + 1}');

    final watch = students.where((s) => s.progress < 80).toList()
      ..sort((a, b) =>
          ml.completeProb[a.id - 1].compareTo(ml.completeProb[b.id - 1]));
    final topWatch = watch.take(8).toList();

    final scopeSizes = List.generate(
      4,
          (c) => students.where((s) => cl.assignment[s.id - 1] == c).length,
    );
    final maxSize = math.max(10, scopeSizes.reduce(math.max));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ResponsiveWrap(
          minWidth: 170,
          children: [
            KpiTile(
                label: 'Test accuracy',
                value: '${model.testAcc.last.toStringAsFixed(0)}%',
                icon: Icons.fact_check,
                color: kGreen),
            KpiTile(
                label: 'Train accuracy',
                value: '${model.trainAcc.last.toStringAsFixed(0)}%',
                icon: Icons.school,
                color: kBlue),
            KpiTile(
                label: 'Finish by wk 20',
                value: '$finishers',
                icon: Icons.flag,
                color: kOrange),
            KpiTile(
                label: 'High-risk',
                value: '$highRisk',
                icon: Icons.warning_amber_rounded,
                color: kRed),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveWrap(
          minWidth: 400,
          children: [
            const PredictorCardSd(),
            ChartPanel(
              title: 'Model learning curve',
              subtitle: 'Logistic regression accuracy (%) per training epoch',
              footer: const LegendSd(
                labels: ['Train (105 students)', 'Test (45 students)'],
                colors: [kBlue, kOrange],
              ),
              child: CustomPaint(
                size: Size.infinite,
                painter: NeonLinePainter(
                  series: [
                    LineSeriesSd(model.trainAcc, kBlue),
                    LineSeriesSd(model.testAcc, kOrange),
                  ],
                  xLabels: List.generate(
                      model.trainAcc.length, (i) => '${(i + 1) * 20}'),
                ),
              ),
            ),
            ChartPanel(
              title: 'What drives completion?',
              subtitle: 'Feature importance (share of model weight)',
              height: 190,
              child: CustomPaint(
                size: Size.infinite,
                painter: HBarPainterSd(
                  labels: kFeatureNamesSd,
                  values: importance,
                  color: kPurple,
                ),
              ),
            ),
            ChartPanel(
              title: 'Progress forecast to week 20',
              subtitle: 'Average of per-student linear regression trends',
              footer: const LegendSd(
                labels: ['Actual (W1-W12)', 'Forecast (W13-W20)'],
                colors: [kCyan, kOrange],
              ),
              child: CustomPaint(
                size: Size.infinite,
                painter: NeonLinePainter(
                  series: [
                    LineSeriesSd(forecastAvg, kOrange),
                    LineSeriesSd(actualAvg, kCyan, fill: true),
                  ],
                  xLabels: labels20,
                ),
              ),
            ),
            ChartPanel(
              title: 'K-means student groups',
              subtitle:
              'Hours studied (x) vs test score (y), colored by cluster',
              footer:
              LegendSd(labels: kClusterNamesSd, colors: kClusterColorsSd),
              child: CustomPaint(
                size: Size.infinite,
                painter: ScatterPainterSd(
                  points:
                  students.map((s) => Offset(s.hours, s.score)).toList(),
                  colors: [
                    for (final s in students)
                      kClusterColorsSd[cl.assignment[s.id - 1]].withAlpha(220)
                  ],
                  maxX: 200,
                ),
              ),
            ),
            ChartPanel(
              title: 'Cluster sizes',
              subtitle: 'Students per group in this view, with group averages',
              height: 170,
              footer: Column(
                children: [
                  for (var c = 0; c < kClusterNamesSd.length; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: kClusterColorsSd[c],
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(kClusterNamesSd[c],
                                  style: const TextStyle(fontSize: 12))),
                          Text(
                            '${cl.avgProgress[c].toStringAsFixed(0)}% · ${cl.avgScore[c].toStringAsFixed(0)} pts · ${cl.avgHours[c].toStringAsFixed(0)} h',
                            style: kMutedStyle,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              child: CustomPaint(
                size: Size.infinite,
                painter: NeonBarPainter(
                  values: scopeSizes.map((v) => v.toDouble()).toList(),
                  labels: kClusterShortSd,
                  maxY: ((maxSize / 10).ceil() * 10).toDouble(),
                  colors: kClusterColorsSd,
                ),
              ),
            ),
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI watchlist', style: kTitleStyle),
                  const Text(
                      'Students least likely to finish. Tap for details.',
                      style: kMutedStyle),
                  const SizedBox(height: 8),
                  for (final s in topWatch) WatchTileSd(student: s),
                ],
              ),
            ),
            const NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How the AI works', style: kTitleStyle),
                  SizedBox(height: 8),
                  Text(
                      '• Linear regression fits a trend line through each student\'s 12 weekly points and extends it to week 20.'),
                  SizedBox(height: 6),
                  Text(
                      '• Logistic regression learns from weeks 1-6 (progress, pace, hours, score) to predict who finishes at 80% or more. It trains on 105 students and is checked on 45 unseen students.'),
                  SizedBox(height: 6),
                  Text(
                      '• K-means groups all 150 students into 4 clusters by progress, score and hours.'),
                  SizedBox(height: 6),
                  Text(
                      '• Rules turn the results into coaching tips. Everything runs on-device with no packages and no server.'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WatchTileSd extends StatelessWidget {
  final Student student;
  const WatchTileSd({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final i = student.id - 1;
    final risk = (1 - kMlSd.completeProb[i]) * 100;
    final f = kMlSd.forecasts[i];
    final eta = f.etaWeek;
    final etaText = eta == null
        ? 'no upward trend'
        : (eta > 52 ? 'finish after week 52' : 'finish ~week ${eta.ceil()}');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      isThreeLine: true,
      onTap: () => showStudentSheet(context, student),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: kRed.withAlpha(60),
        child: Text(student.initials, style: const TextStyle(fontSize: 11)),
      ),
      title: Text('#${student.id}  ${student.name}'),
      subtitle: Text(
        'Now ${student.progress.toStringAsFixed(0)}% · week 20: ${f.at(20).toStringAsFixed(0)}% · $etaText\n${coachTipsSd(student).first}',
        style: const TextStyle(fontSize: 12, color: kMuted),
      ),
      trailing: Text('${risk.toStringAsFixed(0)}%\nrisk',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kRed, fontWeight: FontWeight.bold)),
    );
  }
}

/// Interactive "what-if" predictor using the trained logistic model.
class PredictorCardSd extends StatefulWidget {
  const PredictorCardSd({super.key});

  @override
  State<PredictorCardSd> createState() => _PredictorCardStateSd();
}

class _PredictorCardStateSd extends State<PredictorCardSd> {
  double week6 = 35;
  double pace = 6;
  double hours = 100;
  double score = 70;

  Widget slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String suffix) {
    return Row(
      children: [
        SizedBox(
            width: 108,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kCyan,
              inactiveTrackColor: AppColors.line,
              thumbColor: AppColors.pink,
              overlayColor: kCyan.withAlpha(50),
            ),
            child:
            Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text('${value.toStringAsFixed(0)}$suffix',
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prob = kMlSd.model.predict([week6, pace, hours, score]);
    final color = prob >= 0.7 ? kGreen : (prob >= 0.4 ? kOrange : kRed);
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Try the model', style: kTitleStyle),
          const Text(
              'Move the sliders to predict a new student\'s chance of finishing',
              style: kMutedStyle),
          const SizedBox(height: 8),
          slider('Week-6 progress', week6, 0, 70,
                  (v) => setState(() => week6 = v), '%'),
          slider(
              'Weekly pace', pace, 0, 15, (v) => setState(() => pace = v), '%'),
          slider('Hours studied', hours, 0, 200,
                  (v) => setState(() => hours = v), 'h'),
          slider('Test score', score, 30, 100, (v) => setState(() => score = v),
              ''),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${(prob * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('chance of completing (80%+)',
                        style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    ProgressSlider(value: prob * 100, color: color),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHART PAINTERS (neon style)
// ─────────────────────────────────────────────────────────────

void drawTextSd(
    Canvas canvas,
    String text,
    Offset offset, {
      double size = 10,
      Color color = kMuted,
      TextAlign align = TextAlign.left,
      double? maxWidth,
      FontWeight? weight,
    }) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, color: color, fontWeight: weight),
    ),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);

  var dx = offset.dx;
  if (align == TextAlign.center) {
    dx -= tp.width / 2;
  } else if (align == TextAlign.right) {
    dx -= tp.width;
  }
  tp.paint(canvas, Offset(dx, offset.dy - tp.height / 2));
}

void drawYGridSd(Canvas canvas, Rect plot, double maxY, int steps,
    {String suffix = ''}) {
  final paint = Paint()
    ..color = const Color(0x2A1E5BFF)
    ..strokeWidth = 1;
  for (var i = 0; i <= steps; i++) {
    final y = plot.bottom - plot.height * i / steps;
    canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    drawTextSd(canvas, '${(maxY * i / steps).round()}$suffix',
        Offset(plot.left - 6, y),
        align: TextAlign.right);
  }
}

class LineSeriesSd {
  final List<double> values;
  final Color color;
  final bool fill;
  const LineSeriesSd(this.values, this.color, {this.fill = false});
}

class NeonLinePainter extends CustomPainter {
  final List<LineSeriesSd> series;
  final List<String> xLabels;
  final double maxY;
  final String suffix;

  NeonLinePainter({
    required this.series,
    required this.xLabels,
    this.maxY = 100,
    this.suffix = '%',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(42, 10, size.width - 10, size.height - 24);
    drawYGridSd(canvas, plot, maxY, 4, suffix: suffix);
    final n = xLabels.length;
    final step = n > 8 ? 2 : 1;
    double xAt(int i) => plot.left + plot.width * i / (n - 1);
    double yAt(double v) =>
        plot.bottom - plot.height * (v / maxY).clamp(0.0, 1.0);

    for (var i = 0; i < n; i += step) {
      drawTextSd(canvas, xLabels[i], Offset(xAt(i), plot.bottom + 12),
          align: TextAlign.center);
    }

    for (final s in series) {
      if (s.values.length < 2) continue;
      final path = Path();
      for (var i = 0; i < s.values.length; i++) {
        final x = xAt(i);
        final y = yAt(s.values[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      if (s.fill) {
        final area = Path.from(path)
          ..lineTo(xAt(s.values.length - 1), plot.bottom)
          ..lineTo(xAt(0), plot.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [s.color.withAlpha(110), s.color.withAlpha(0)],
            ).createShader(plot),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color.withAlpha(55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < s.values.length; i++) {
        canvas.drawCircle(
            Offset(xAt(i), yAt(s.values[i])), 3.5, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class NeonBarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double maxY;
  final List<Color> colors;
  final String valueSuffix;

  NeonBarPainter({
    required this.values,
    required this.labels,
    required this.maxY,
    required this.colors,
    this.valueSuffix = '',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(36, 14, size.width - 8, size.height - 26);
    drawYGridSd(canvas, plot, maxY, 4);
    final n = values.length;
    final slot = plot.width / n;
    final barW = slot * 0.6;

    for (var i = 0; i < n; i++) {
      final x = plot.left + slot * i + (slot - barW) / 2;
      final h = plot.height * (values[i] / maxY).clamp(0.0, 1.0);
      final rect = Rect.fromLTWH(x, plot.bottom - h, barW, h);
      final color = colors[i % colors.length];
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, color.withAlpha(70)],
          ).createShader(rect),
      );
      final text = values[i] % 1 == 0
          ? values[i].toStringAsFixed(0)
          : values[i].toStringAsFixed(1);
      drawTextSd(canvas, '$text$valueSuffix',
          Offset(x + barW / 2, plot.bottom - h - 8),
          align: TextAlign.center, color: AppColors.ink);
      drawTextSd(canvas, labels[i], Offset(x + barW / 2, plot.bottom + 12),
          align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DonutPainterSd extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final String centerText;

  DonutPainterSd(
      {required this.values, required this.colors, required this.centerText});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final stroke = radius * 0.3;
    final rect =
    Rect.fromCircle(center: center, radius: radius).deflate(stroke / 2);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = const Color(0x2212224A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(
        rect,
        start,
        math.max(sweep - 0.04, 0.001),
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
    drawTextSd(canvas, centerText, center,
        size: 14,
        color: AppColors.ink,
        align: TextAlign.center,
        weight: FontWeight.bold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ScatterPainterSd extends CustomPainter {
  final List<Offset> points; // dx = hours, dy = score
  final List<Color> colors;
  final double maxX;

  ScatterPainterSd(
      {required this.points, required this.colors, required this.maxX});

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(36, 14, size.width - 12, size.height - 26);
    drawYGridSd(canvas, plot, 100, 4);
    for (var i = 0; i <= 4; i++) {
      final x = plot.left + plot.width * i / 4;
      drawTextSd(
          canvas, '${(maxX * i / 4).round()}h', Offset(x, plot.bottom + 12),
          align: TextAlign.center);
    }
    for (var i = 0; i < points.length; i++) {
      final x = plot.left + plot.width * (points[i].dx / maxX).clamp(0.0, 1.0);
      final y =
          plot.bottom - plot.height * (points[i].dy / 100).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(x, y), 7, Paint()..color = colors[i].withAlpha(40));
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HBarPainterSd extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color color;

  HBarPainterSd(
      {required this.labels, required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const labelW = 112.0;
    final plot = Rect.fromLTRB(labelW, 4, size.width - 40, size.height - 4);
    final n = values.length;
    final rowH = plot.height / n;
    final gridPaint = Paint()
      ..color = const Color(0x2A1E5BFF)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = plot.left + plot.width * i / 4;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
    }
    for (var i = 0; i < n; i++) {
      final cy = plot.top + rowH * i + rowH / 2;
      final w = plot.width * (values[i] / 100).clamp(0.0, 1.0);

      final rect = Rect.fromLTWH(plot.left, cy - rowH * 0.28, w, rowH * 0.56);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topRight: const Radius.circular(5),
          bottomRight: const Radius.circular(5),
        ),
        Paint()
          ..shader = LinearGradient(colors: [color.withAlpha(90), color])
              .createShader(rect),
      );
      drawTextSd(canvas, labels[i], Offset(plot.left - 8, cy),
          align: TextAlign.right,
          maxWidth: labelW - 12,
          size: 11,
          color: AppColors.ink);
      drawTextSd(canvas, '${values[i].toStringAsFixed(0)}%',
          Offset(plot.left + w + 6, cy),
          color: AppColors.ink);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================================================
//  MODULE: Academic calendar
// ==========================================================================

// void main() {
//   runApp(Calender());
// }

class Calender extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Mycalender();
  }
}

// Calendar entry widget (uses the app-wide blue/pink theme)
class Mycalender extends StatefulWidget {
  const Mycalender({super.key});

  @override
  State<Mycalender> createState() => _MycalenderState();
}

class _MycalenderState extends State<Mycalender> {
  @override
  Widget build(BuildContext context) {
    return CustomCalendarPage1(isDarkMode: false, onThemeToggle: () {});
  }
}

// Model class to hold reminder data
class Reminder {
  String id;
  String title;
  DateTime date;

  Reminder({required this.id, required this.title, required this.date});

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'date': date.toIso8601String()};
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'],
      date: DateTime.parse(map['date']),
    );
  }
}

class CustomCalendarPage1 extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const CustomCalendarPage1({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<CustomCalendarPage1> createState() => _CustomCalendarPage1State();
}

class _CustomCalendarPage1State extends State<CustomCalendarPage1> {
  late DateTime _focusedDate;
  late DateTime _selectedDate;
  List<Reminder> _reminders = [];
  List<Reminder>? _previousRemindersState;
  bool _showRemindersEnabled = true;

  final List<String> _daysOfWeek = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _focusedDate = DateTime.now();
    _selectedDate = DateTime(
      _focusedDate.year,
      _focusedDate.month,
      _focusedDate.day,
    );
    _loadReminders();
    _loadReminderToggleState();
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _getStartingDayOfWeek(int year, int month) {
    int weekday = DateTime(year, month, 1).weekday;
    return weekday - 1;
  }

  // SharedPreferences मधून रिमाइंडर टॉगल स्टेट लोड करणे
  Future<void> _loadReminderToggleState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showRemindersEnabled = prefs.getBool('show_reminders_enabled') ?? true;
    });
  }

  // रिमाइंडर टॉगल बदलणे आणि SharedPreferences मध्ये सेव्ह करणे
  Future<void> _toggleReminderSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showRemindersEnabled = !_showRemindersEnabled;
      prefs.setBool('show_reminders_enabled', _showRemindersEnabled);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _showRemindersEnabled
              ? 'Reminders Visibility On'
              : 'Reminders Visibility Off',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveRemindersToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList =
    _reminders.map((r) => jsonEncode(r.toMap())).toList();
    await prefs.setStringList('saved_reminders', jsonList);
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList('saved_reminders');
    if (jsonList != null) {
      setState(() {
        _reminders =
            jsonList.map((item) => Reminder.fromMap(jsonDecode(item))).toList();
      });
    }
  }

  void _saveStateForUndo() {
    _previousRemindersState = _reminders
        .map((r) => Reminder(id: r.id, title: r.title, date: r.date))
        .toList();
  }

  void _undo() {
    if (_previousRemindersState != null) {
      setState(() {
        _reminders = List.from(_previousRemindersState!);
        _previousRemindersState = null;
      });
      _saveRemindersToStorage();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action undone successfully!')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to undo!')));
    }
  }

  void _showReminderDialog({Reminder? existingReminder}) {
    final titleController = TextEditingController(
      text: existingReminder?.title ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existingReminder == null ? 'New Reminder' : 'Edit Reminder',
        ),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: 'Enter reminder title...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;

              setState(() {
                if (existingReminder != null) {
                  existingReminder.title = titleController.text.trim();
                } else {
                  _reminders.add(
                    Reminder(
                      id: DateTime.now().toString(),
                      title: titleController.text.trim(),
                      date: _selectedDate,
                    ),
                  );
                }
              });
              _saveRemindersToStorage();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteReminder(Reminder reminder) {
    _saveStateForUndo();
    setState(() {
      _reminders.remove(reminder);
    });
    _saveRemindersToStorage();
  }

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = _getDaysInMonth(
      _focusedDate.year,
      _focusedDate.month,
    );
    final int startingEmptySlots = _getStartingDayOfWeek(
      _focusedDate.year,
      _focusedDate.month,
    );
    final int totalGridItems = daysInMonth + startingEmptySlots;

    final currentDayReminders = _showRemindersEnabled
        ? _reminders
        .where(
          (r) =>
      r.date.year == _selectedDate.year &&
          r.date.month == _selectedDate.month &&
          r.date.day == _selectedDate.day,
    )
        .toList()
        : <Reminder>[];

    // Theme color references for clean styling
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Almanac'),
        actions: [
          IconButton(
            icon: Icon(
              _showRemindersEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
            ),
            onPressed: _toggleReminderSetting,
            tooltip:
            _showRemindersEnabled ? 'Hide Reminders' : 'Show Reminders',
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undo,
            tooltip: 'Undo last action',
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                      () => _focusedDate = DateTime(
                    _focusedDate.year,
                    _focusedDate.month - 1,
                  ),
                ),
              ),
              Text(
                '${_months[_focusedDate.month - 1]} ${_focusedDate.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(
                      () => _focusedDate = DateTime(
                    _focusedDate.year,
                    _focusedDate.month + 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _daysOfWeek
                .map(
                  (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
                .toList(),
          ),
          const SizedBox(height: 10),
          Expanded(
            flex: 3,
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
              ),
              itemCount: totalGridItems,
              itemBuilder: (context, index) {
                if (index < startingEmptySlots) {
                  return const SizedBox.shrink();
                }

                final int dayNumber = index - startingEmptySlots + 1;
                final DateTime cellDate = DateTime(
                  _focusedDate.year,
                  _focusedDate.month,
                  dayNumber,
                );
                final bool isSelected = cellDate.year == _selectedDate.year &&
                    cellDate.month == _selectedDate.month &&
                    cellDate.day == _selectedDate.day;

                final bool hasReminder = _showRemindersEnabled &&
                    _reminders.any(
                          (r) =>
                      r.date.year == cellDate.year &&
                          r.date.month == cellDate.month &&
                          r.date.day == cellDate.day,
                    );

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = cellDate;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                      isSelected ? AppColors.blue.withOpacity(0.3) : null,
                      border: Border.all(
                        color: AppColors.line,
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (hasReminder)
                          Positioned(
                            bottom: 5,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.pink,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            flex: 2,
            child: currentDayReminders.isEmpty
                ? const Center(child: Text('No reminders for this day.'))
                : ListView.builder(
              itemCount: currentDayReminders.length,
              itemBuilder: (context, index) {
                final reminder = currentDayReminders[index];
                return ListTile(
                  // Expanded आणि Ellipsis वापरून मजकूर सुरक्षित केला आहे
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          reminder.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:
                        const Icon(Icons.edit, color: AppColors.blue),
                        onPressed: () => _showReminderDialog(
                          existingReminder: reminder,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: AppColors.pink),
                        onPressed: () => _deleteReminder(reminder),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReminderDialog(),
        tooltip: 'Add Reminder',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==========================================================================
//  MODULE: AI study companion chat
// ==========================================================================

// ============================================================
// APP
// ============================================================

class LocalAIChatbotApp extends StatelessWidget {
  const LocalAIChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatPage();
  }
}

// ============================================================
// MESSAGE MODEL
// ============================================================

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, required this.time});
}

// ============================================================
// CHAT PAGE
// ============================================================

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final stt.SpeechToText _speech = stt.SpeechToText();

  final FlutterTts _tts = FlutterTts();

  final List<ChatMessage> _messages = [];

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  // ==========================================================
  // INITIALIZATION
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _initializeSpeech();
    _initializeTts();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;

        setState(() {
          _isListening = status == 'listening';
        });
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _isListening = false;
        });
      },
    );

    if (!mounted) return;

    setState(() {
      _speechAvailable = available;
    });
  }

  Future<void> _initializeTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (!mounted) return;

      setState(() {
        _isSpeaking = true;
      });
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;

      setState(() {
        _isSpeaking = false;
      });
    });

    _tts.setCancelHandler(() {
      if (!mounted) return;

      setState(() {
        _isSpeaking = false;
      });
    });
  }

  // ==========================================================
  // SPEECH TO TEXT
  // ==========================================================

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      await _initializeSpeech();
    }

    if (!_speechAvailable) {
      _showSnackBar('Speech recognition is not available.');
      return;
    }

    if (_isListening) {
      await _speech.stop();

      if (!mounted) return;

      setState(() {
        _isListening = false;
      });

      return;
    }

    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );

    if (!mounted) return;

    setState(() {
      _isListening = true;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    setState(() {
      _textController.text = result.recognizedWords;

      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    });
  }

  // ==========================================================
  // TEXT TO SPEECH
  // ==========================================================

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;

    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _isSpeaking = true;
    });

    await _tts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  // ==========================================================
  // SEND
  // ==========================================================

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();

    if (text.isEmpty) return;

    _textController.clear();

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, time: DateTime.now()),
      );
    });

    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 500));

    final answer = _generateLocalAIResponse(text);

    setState(() {
      _messages.add(
        ChatMessage(text: answer, isUser: false, time: DateTime.now()),
      );
    });

    _scrollToBottom();
  }

  // ==========================================================
  // LOCAL AI ENGINE
  // ==========================================================

  String _generateLocalAIResponse(String input) {
    final text = input.toLowerCase().trim();

    // --------------------------------------------------------
    // GREETING
    // --------------------------------------------------------

    if (_containsAny(text, ['hello', 'hi', 'hey', 'namaste'])) {
      return '''
Hello! 👋

I am your local AI Tutor.

You can ask me about:
• Physics
• Photonics
• Astronomy
• Mathematics
• Flutter
• Dart
• Programming
• Science
• OMR questions

You can also speak to me using the microphone.
''';
    }

    // --------------------------------------------------------
    // FLUTTER
    // --------------------------------------------------------

    if (_containsAny(text, ['flutter', 'flutter code'])) {
      return '''
Flutter is Google's UI framework for building
applications from a single Dart codebase.

A basic Flutter application contains:

MaterialApp
    ↓
Scaffold
    ↓
AppBar
    ↓
Body
    ↓
Widgets

Example:

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello Flutter'),
        ),
      ),
    ),
  );
}

Flutter uses widgets to construct the user interface.
''';
    }

    // --------------------------------------------------------
    // DART
    // --------------------------------------------------------

    if (_containsAny(text, ['dart', 'constructor', 'inheritance'])) {
      return '''
Dart is the programming language used by Flutter.

Example class:

class Animal {
  String name;

  Animal(this.name);

  void speak() {
    print('Animal speaks');
  }
}

A subclass can inherit from Animal:

class Dog extends Animal {
  Dog(String name) : super(name);

  @override
  void speak() {
    print('Dog barks');
  }
}
''';
    }

    // --------------------------------------------------------
    // PHYSICS
    // --------------------------------------------------------

    if (_containsAny(text, ['physics', 'force', 'newton', 'mechanics'])) {
      return '''
Newton's second law relates force, mass and acceleration:

F = ma

where:

F = force
m = mass
a = acceleration

The SI unit of force is the newton (N).
''';
    }

    // --------------------------------------------------------
    // PHOTONICS
    // --------------------------------------------------------

    if (_containsAny(text, [
      'photonics',
      'laser',
      'optics',
      'fiber',
      'fibre',
    ])) {
      return '''
Photonics is the science and technology of
generating, controlling and detecting photons.

Important topics include:

• Lasers
• Optical fibers
• Waveguides
• Photodetectors
• Interferometry
• Optical communications
• Quantum optics

For a laser, stimulated emission produces photons
that can contribute to coherent optical amplification.
''';
    }

    // --------------------------------------------------------
    // ASTRONOMY
    // --------------------------------------------------------

    if (_containsAny(text, [
      'astronomy',
      'galaxy',
      'galactic',
      'jeans equation',
      'dark matter',
    ])) {
      return '''
In galactic dynamics, the Jeans equations describe
the evolution of velocity moments of a collisionless
stellar system.

For an axisymmetric disk, the circular velocity is
related to the gravitational potential by:

Vc² = R ∂Φ/∂R

where:

Vc = circular velocity
R  = Galactocentric radius
Φ  = gravitational potential

Stellar velocity dispersion can cause the mean stellar
azimuthal velocity to differ from the circular velocity.
This effect is known as asymmetric drift.
''';
    }

    // --------------------------------------------------------
    // QUANTUM
    // --------------------------------------------------------

    if (_containsAny(text, [
      'quantum',
      'wavefunction',
      'schrodinger',
      'heisenberg',
    ])) {
      return '''
In quantum mechanics, a system is described by a
wavefunction ψ.

The probability density is:

|ψ(x)|²

The Heisenberg uncertainty principle states that
position and momentum cannot both be known with
arbitrarily small uncertainty.

A common expression is:

Δx Δp ≥ ℏ/2
''';
    }

    // --------------------------------------------------------
    // MATHEMATICS
    // --------------------------------------------------------

    if (_containsAny(text, [
      'math',
      'mathematics',
      'derivative',
      'integral',
      'calculus',
    ])) {
      return '''
Calculus studies change and accumulation.

For example:

d/dx (x²) = 2x

and

∫ 2x dx = x² + C

Derivatives describe rates of change,
while integrals describe accumulation.
''';
    }

    // --------------------------------------------------------
    // OMR
    // --------------------------------------------------------

    if (_containsAny(text, ['omr', 'exam', 'question', 'mcq'])) {
      return '''
An OMR examination can contain:

• Question number
• Four answer choices
• Selected answer
• Mark for review
• Question palette
• Automatic scoring
• Negative marking
• Answer review

For example:

Question:
Which quantity represents quantum probability density?

A. ψ
B. ψ²
C. |ψ|²
D. dψ/dx

Correct answer:

C. |ψ|²
''';
    }

    // --------------------------------------------------------
    // HELP
    // --------------------------------------------------------

    if (_containsAny(text, ['help', 'what can you do'])) {
      return '''
I can provide explanations for:

🔬 Science
⚛️ Quantum physics
🌌 Astronomy
💡 Photonics
📐 Mathematics
💻 Dart
📱 Flutter
📝 OMR examinations

Try asking:

"Explain the Jeans equation"

or

"Give me Flutter code for a chatbot."
''';
    }

    // --------------------------------------------------------
    // DEFAULT
    // --------------------------------------------------------

    return '''
I understood your question as:

"$input"

I am currently running without a backend or external AI
model, so my answers are generated by the local knowledge
rules built into this Flutter application.

You can ask me about:

• Physics
• Quantum physics
• Photonics
• Astronomy
• Jeans equations
• Dark matter
• Mathematics
• Dart
• Flutter
• OMR examinations

To make this a true generative AI tutor later, an
on-device language model can be connected without
requiring a conventional FastAPI backend.
''';
  }

  // ==========================================================
  // HELPER
  // ==========================================================

  bool _containsAny(String text, List<String> words) {
    for (final word in words) {
      if (text.contains(word)) {
        return true;
      }
    }

    return false;
  }

  // ==========================================================
  // SCROLL
  // ==========================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ==========================================================
  // CLEAR
  // ==========================================================

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  // ==========================================================
  // SNACKBAR
  // ==========================================================

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.blue, AppColors.pinkDark],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Tutor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Local • Voice enabled',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _welcome()
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _messageBubble(_messages[index]);
                },
              ),
            ),
            _inputArea(),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // WELCOME
  // ==========================================================

  Widget _welcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.blue, AppColors.pinkDark],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child:
              const Icon(Icons.auto_awesome, size: 46, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Voice Tutor',
              style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Type or speak your question',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _suggestion('Explain quantum physics'),
                _suggestion('Explain photonics'),
                _suggestion('Explain Jeans equation'),
                _suggestion('Give Flutter code'),
                _suggestion('Create an OMR question'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestion(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _textController.text = text;
        _sendMessage();
      },
    );
  }

  // ==========================================================
  // MESSAGE BUBBLE
  // ==========================================================

  Widget _messageBubble(ChatMessage message) {
    final bool user = message.isUser;

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: user ? AppColors.pinkSoft : AppColors.blueSoft,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 4),
            bottomRight: Radius.circular(user ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(user ? Icons.person : Icons.smart_toy, size: 18),
                const SizedBox(width: 8),
                Text(
                  user ? 'You' : 'AI Tutor',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              message.text,
              style: const TextStyle(fontSize: 15, height: 1.55),
            ),
            if (!user)
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    tooltip: 'Read answer',
                    onPressed: () {
                      _speak(message.text);
                    },
                    icon: const Icon(Icons.volume_up),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // INPUT
  // ==========================================================

  Widget _inputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: AppColors.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Type or speak...',
                filled: true,
                fillColor: AppColors.blueSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: IconButton(
                  tooltip: _isListening ? 'Stop' : 'Speak',
                  onPressed: _toggleListening,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? AppColors.pink : AppColors.inkSoft,
                  ),
                ),
                suffixIcon: _isSpeaking
                    ? IconButton(
                  tooltip: 'Stop speaking',
                  onPressed: _stopSpeaking,
                  icon: const Icon(
                    Icons.stop_circle,
                    color: AppColors.rose,
                  ),
                )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 54,
            height: 54,
            child: FloatingActionButton(
              heroTag: 'send',
              onPressed: _sendMessage,
              backgroundColor: AppColors.blue,
              child: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}

// ==========================================================================
//  MODULE: Cloud compiler IDE
// ==========================================================================

// void main() {
//   runApp(const MultiCompilerApp());
// }

class CompilerLanguage {
  final String name;
  final String icon;
  final int judge0Id;
  final String starterCode;

  const CompilerLanguage({
    required this.name,
    required this.icon,
    required this.judge0Id,
    required this.starterCode,
  });
}

const languages = <CompilerLanguage>[
  CompilerLanguage(
    name: 'Rust',
    icon: '🦀',
    judge0Id: 73,
    starterCode: '''fn main() {
    println!("Hello from Rust!");
}''',
  ),
  CompilerLanguage(
    name: 'Go',
    icon: '🐹',
    judge0Id: 60,
    starterCode: '''package main

import "fmt"

func main() {
    fmt.Println("Hello from Go!")
}''',
  ),
  CompilerLanguage(
    name: 'PHP',
    icon: '🐘',
    judge0Id: 68,
    starterCode: '''<?php
\$name = "World";

echo "Hello, \$name!";

?>''',
  ),
  CompilerLanguage(
    name: 'Swift',
    icon: '🍎',
    judge0Id: 83,
    starterCode: '''import Foundation

print("Hello from Swift!")''',
  ),
  CompilerLanguage(
    name: 'Scala',
    icon: '🔷',
    judge0Id: 81,
    starterCode: '''object Main extends App {
    println("Hello from Scala!")
}''',
  ),
  CompilerLanguage(
    name: 'Ruby',
    icon: '💎',
    judge0Id: 72,
    starterCode: '''name = "World"

puts "Hello, #{name}!"''',
  ),
];

class MultiCompilerApp extends StatelessWidget {
  const MultiCompilerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CompilerPage();
  }
}

class CompilerPage extends StatefulWidget {
  const CompilerPage({super.key});

  @override
  State<CompilerPage> createState() => _CompilerPageState();
}

class _CompilerPageState extends State<CompilerPage> {
  static const String judge0Url = 'https://ce.judge0.com/submissions';

  int selectedIndex = 0;

  late TextEditingController codeController;
  final TextEditingController inputController = TextEditingController();

  String output = '';
  String error = '';

  bool running = false;

  int? executionTime;

  @override
  void initState() {
    super.initState();

    codeController = TextEditingController(text: languages[0].starterCode);
  }

  CompilerLanguage get selectedLanguage => languages[selectedIndex];

  @override
  void dispose() {
    codeController.dispose();
    inputController.dispose();
    super.dispose();
  }

  void changeLanguage(int index) {
    setState(() {
      selectedIndex = index;

      codeController.text = languages[index].starterCode;

      output = '';
      error = '';
      executionTime = null;
    });
  }

  Future<void> runCode() async {
    if (codeController.text.trim().isEmpty) {
      setState(() {
        error = 'Please enter some code.';
        output = '';
      });
      return;
    }

    setState(() {
      running = true;
      output = '';
      error = '';
      executionTime = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      /*
       * SUBMIT CODE
       */

      final submitResponse = await http
          .post(
        Uri.parse('$judge0Url?base64_encoded=false&wait=false'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'language_id': selectedLanguage.judge0Id,
          'source_code': codeController.text,
          'stdin': inputController.text,
        }),
      )
          .timeout(const Duration(seconds: 20));

      if (submitResponse.statusCode != 201) {
        throw Exception(
          'Submission failed.\n'
              'HTTP ${submitResponse.statusCode}\n'
              '${submitResponse.body}',
        );
      }

      final submission = jsonDecode(submitResponse.body);

      final token = submission['token'];

      if (token == null) {
        throw Exception('No submission token received.');
      }

      /*
       * WAIT FOR RESULT
       */

      Map<String, dynamic>? result;

      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 800));

        final response = await http
            .get(Uri.parse('$judge0Url/$token?base64_encoded=false'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          throw Exception(
            'Unable to retrieve result.\n'
                'HTTP ${response.statusCode}',
          );
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final status = data['status'];

        if (status != null) {
          final id = status['id'];

          /*
           * 1 = In Queue
           * 2 = Processing
           * 3+ = Finished
           */

          if (id != 1 && id != 2) {
            result = data;
            break;
          }
        }
      }

      stopwatch.stop();

      if (result == null) {
        throw Exception('Execution timed out.');
      }

      final stdout = result['stdout'] ?? '';

      final stderr = result['stderr'] ?? '';

      final compileOutput = result['compile_output'] ?? '';

      final message = result['message'] ?? '';

      final status = result['status'];

      final statusDescription =
      status != null ? status['description'] ?? '' : '';

      final errors = <String>[];

      if (compileOutput.toString().isNotEmpty) {
        errors.add(compileOutput.toString());
      }

      if (stderr.toString().isNotEmpty) {
        errors.add(stderr.toString());
      }

      if (message.toString().isNotEmpty) {
        errors.add(message.toString());
      }

      if (errors.isEmpty &&
          statusDescription.toString().isNotEmpty &&
          statusDescription != 'Accepted') {
        errors.add(statusDescription.toString());
      }

      if (!mounted) return;

      setState(() {
        executionTime = stopwatch.elapsedMilliseconds;

        output = stdout.toString();

        error = errors.join('\n');
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        error = 'Request timed out.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    } finally {
      stopwatch.stop();

      if (!mounted) return;

      setState(() {
        running = false;
      });
    }
  }

  void clearEditor() {
    setState(() {
      codeController.clear();
      inputController.clear();
      output = '';
      error = '';
      executionTime = null;
    });
  }

  void loadExample() {
    final language = selectedLanguage.name;

    if (language == 'Rust') {
      codeController.text = '''fn main() {
    let a = 10;
    let b = 20;

    println!("Sum = {}", a + b);
}''';
    }

    if (language == 'Go') {
      codeController.text = '''package main

import "fmt"

func main() {
    a := 10
    b := 20

    fmt.Println("Sum =", a+b)
}''';
    }

    if (language == 'PHP') {
      codeController.text = '''<?php

\$a = 10;
\$b = 20;

echo "Sum = " . (\$a + \$b);

?>''';
    }

    if (language == 'Swift') {
      codeController.text = '''import Foundation

let a = 10
let b = 20

print("Sum = \\(a + b)")''';
    }

    if (language == 'Scala') {
      codeController.text = '''object Main extends App {

    val a = 10
    val b = 20

    println("Sum = " + (a + b))
}''';
    }

    if (language == 'Ruby') {
      codeController.text = '''a = 10
b = 20

puts "Sum = #{a + b}"''';
    }

    setState(() {
      output = '';
      error = '';
    });
  }

  Widget languageSelector() {
    return Container(
      width: 230,
      color: AppColors.card,
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'ONLINE COMPILER',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final language = languages[index];

                final selected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => changeLanguage(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.pinkSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            language.icon,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            language.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget languageChips() {
    return Container(
      height: 56,
      color: AppColors.card,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final language = languages[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${language.icon} ${language.name}'),
              selected: selectedIndex == index,
              onSelected: (_) => changeLanguage(index),
            ),
          );
        },
      ),
    );
  }

  Widget editor() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  selectedLanguage.icon,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  '${selectedLanguage.name} Code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Example',
                  onPressed: loadExample,
                  icon: const Icon(Icons.lightbulb_outline),
                ),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: clearEditor,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: codeController,
              expands: true,
              maxLines: null,
              minLines: null,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                hintText: 'Write your code here...',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget inputBox() {
    return Container(
      height: 145,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                Icon(Icons.input, color: Color(0xFF1E5BFF)),
                SizedBox(width: 8),
                Text(
                  'Standard Input',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: inputController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
                hintText: 'Program input...',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget outputBox() {
    final hasError = error.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  hasError ? Icons.error_outline : Icons.terminal,
                  color: hasError ? AppColors.pink : const Color(0xFF1E5BFF),
                ),
                const SizedBox(width: 10),
                Text(
                  hasError ? 'Error' : 'Output',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (executionTime != null)
                  Text(
                    '$executionTime ms',
                    style:
                    const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                hasError
                    ? error
                    : output.isEmpty
                    ? 'Output will appear here...'
                    : output,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.5,
                  color: hasError
                      ? AppColors.pink
                      : output.isEmpty
                      ? AppColors.faint
                      : AppColors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget runButton() {
    return FilledButton.icon(
      onPressed: running ? null : runCode,
      icon: running
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : const Icon(Icons.play_arrow),
      label: Text(running ? 'Running...' : 'Run Code'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE91E8C),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (!narrow) languageSelector(),
            Expanded(
              child: Column(
                children: [
                  if (narrow) languageChips(),
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.line,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.code, color: Color(0xFF1E5BFF)),
                        const SizedBox(width: 10),
                        Text(
                          selectedLanguage.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        runButton(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 900) {
                            return Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      Expanded(child: editor()),
                                      const SizedBox(height: 12),
                                      inputBox(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(flex: 4, child: outputBox()),
                              ],
                            );
                          }

                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(height: 500, child: editor()),
                                const SizedBox(height: 12),
                                inputBox(),
                                const SizedBox(height: 12),
                                SizedBox(height: 350, child: outputBox()),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
//  MODULE: AI Resume Builder
// ==========================================================================

// ==========================================================================
//  AI RESUME BUILDER  (build a resume + download PDF, and ATS check)
//  Entry point:  const AiResumeBuilder()
// ==========================================================================

Color _bpAlpha(Color c, double o) => c.withAlpha((o * 255).round());

/// Card with the shared blue/pink styling.
class BpCard extends StatelessWidget {
  final Widget child;
  const BpCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.card,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.line),
    ),
    child: child,
  );
}

class AiResumeBuilder extends StatefulWidget {
  const AiResumeBuilder({super.key});

  @override
  State<AiResumeBuilder> createState() => _AiResumeBuilderState();
}

class _AiResumeBuilderState extends State<AiResumeBuilder>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  SharedPreferences? _prefs;

  // ---------------- builder form ----------------
  static const List<String> _fields = [
    'name',
    'role',
    'email',
    'phone',
    'location',
    'links',
    'summary',
    'skills',
    'experience',
    'education',
    'projects',
    'certs',
  ];
  final Map<String, TextEditingController> _c = {
    for (final k in _fields) k: TextEditingController(),
  };
  RbAtsResult? builtResult;
  Uint8List? builtPdf;
  bool building = false;

  // ---------------- ATS checker ----------------
  String? fileName;
  Uint8List? resumeBytes;
  String extractedText = '';
  RbAtsResult? result;
  bool analyzing = false;
  bool generating = false;
  static const reportFile = 'ATS_Resume_Report.pdf';

  String get email => _c['email']!.text.trim();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      for (final k in _fields) {
        final v = p.getString('rb_$k');
        if (v != null && v.isNotEmpty) _c[k]!.text = v;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _savePrefs() {
    final p = _prefs;
    if (p == null) return;
    for (final k in _fields) {
      p.setString('rb_$k', _c[k]!.text);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String get _safeName {
    final n = _c['name']!.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return n.isEmpty ? 'My' : n;
  }

  // ======================================================================
  //  RESUME BUILDER
  // ======================================================================

  String _composeText() {
    String t(String k) => _c[k]!.text.trim();
    final b = StringBuffer()
      ..writeln(t('name'))
      ..writeln(t('role'))
      ..writeln([t('email'), t('phone'), t('location')]
          .where((e) => e.isNotEmpty)
          .join(' | '))
      ..writeln(t('links'));
    void sec(String title, String key) {
      if (t(key).isEmpty) return;
      b
        ..writeln()
        ..writeln(title)
        ..writeln(t(key));
    }

    sec('Professional Summary', 'summary');
    sec('Technical Skills', 'skills');
    sec('Work Experience', 'experience');
    sec('Education', 'education');
    sec('Projects', 'projects');
    sec('Certifications', 'certs');
    return b.toString();
  }

  List<pw.Widget> _pdfBlock(String title, String body) {
    if (body.trim().isEmpty) return [];
    const pink = gen_pdf_pink;
    final lines = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return [
      pw.SizedBox(height: 14),
      pw.Text(title,
          style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold, color: pink)),
      pw.Divider(color: pink, thickness: 1, height: 8),
      for (final l in lines)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            RegExp(r'^[-*\u2022]').hasMatch(l)
                ? '- ${l.replaceFirst(RegExp(r'^[-*\u2022]\s*'), '')}'
                : l,
            style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2),
          ),
        ),
    ];
  }

  Future<Uint8List> _buildResumePdf() async {
    String t(String k) => _c[k]!.text.trim();
    final doc = pw.Document(title: '${t('name')} - Resume', author: t('name'));
    const blue = gen_pdf_blue;
    final contact = [t('email'), t('phone'), t('location')]
        .where((e) => e.isNotEmpty)
        .join('   |   ');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (ctx) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: blue,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(t('name').isEmpty ? 'Your Name' : t('name'),
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold)),
                if (t('role').isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(t('role'),
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 13)),
                ],
                pw.SizedBox(height: 8),
                if (contact.isNotEmpty)
                  pw.Text(contact,
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 10)),
                if (t('links').isNotEmpty)
                  pw.Text(t('links'),
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 10)),
              ],
            ),
          ),
          ..._pdfBlock('PROFESSIONAL SUMMARY', t('summary')),
          ..._pdfBlock('TECHNICAL SKILLS', t('skills')),
          ..._pdfBlock('WORK EXPERIENCE', t('experience')),
          ..._pdfBlock('EDUCATION', t('education')),
          ..._pdfBlock('PROJECTS', t('projects')),
          ..._pdfBlock('CERTIFICATIONS', t('certs')),
        ],
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  Future<void> generateResume() async {
    if (_c['name']!.text.trim().isEmpty) {
      showMessage('Enter your full name first.');
      return;
    }
    setState(() => building = true);
    try {
      _savePrefs();
      final bytes = await _buildResumePdf();
      final evaluation = RbAtsAnalyzer.analyze(_composeText());
      if (!mounted) return;
      setState(() {
        builtPdf = bytes;
        builtResult = evaluation;
        building = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => building = false);
      showMessage('Could not build the resume.\n$e');
    }
  }

  Future<void> downloadResume() async {
    final bytes = builtPdf;
    if (bytes == null) {
      showMessage('Generate the resume first.');
      return;
    }
    try {
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${_safeName}_Resume.pdf',
        subject: 'Resume - ${_c['name']!.text.trim()}',
        bounds: _origin(),
      );
      if (kIsWeb) showMessage('Resume PDF downloaded.');
    } catch (e) {
      showMessage('Could not save the PDF.\n$e');
    }
  }

  Future<void> printResume() async {
    final bytes = builtPdf;
    if (bytes == null) return;
    try {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      showMessage('Print preview failed.\n$e');
    }
  }

  Widget _field(String key, String label,
      {int lines = 1, String? hint, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c[key],
        keyboardType: type ?? (lines > 1 ? TextInputType.multiline : null),
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 4,
        onChanged: (_) => _savePrefs(),
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _buildBuilderTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _gradientHeader(Icons.edit_document, 'AI Resume Builder',
            'Fill the form, build your resume, then download it as PDF.'),
        const SizedBox(height: 16),
        BpCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Personal details',
                    style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _field('name', 'Full name'),
                _field('role', 'Target role', hint: 'AI / ML Engineer'),
                _field('email', 'Email', type: TextInputType.emailAddress),
                _field('phone', 'Phone', type: TextInputType.phone),
                _field('location', 'Location'),
                _field('links', 'Links',
                    hint: 'linkedin.com/in/you | github.com/you'),
                const Text('Content',
                    style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _field('summary', 'Professional summary', lines: 3),
                _field('skills', 'Skills',
                    lines: 2, hint: 'Python, TensorFlow, SQL, Flutter'),
                _field('experience', 'Work experience',
                    lines: 4, hint: 'Role - Company (2023-2024)\n- Built ...'),
                _field('education', 'Education', lines: 2),
                _field('projects', 'Projects', lines: 3),
                _field('certs', 'Certifications', lines: 2),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    icon: building
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome),
                    label: Text(building ? 'Building...' : 'Build my resume'),
                    onPressed: building ? null : generateResume,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (builtPdf != null && builtResult != null) ...[
          const SizedBox(height: 16),
          _buildResumePreview(),
          const SizedBox(height: 16),
          _buildScoreCard(builtResult!, 'RESUME ATS SCORE'),
          const SizedBox(height: 16),
          _buildSuggestions(builtResult!),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildResumePreview() {
    String t(String k) => _c[k]!.text.trim();
    Widget block(String title, String body) => body.isEmpty
        ? const SizedBox.shrink()
        : Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.pink,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const Divider(color: AppColors.pink, height: 8),
          Text(body, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
    return BpCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.blue, AppColors.pink]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('name'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  if (t('role').isNotEmpty)
                    Text(t('role'),
                        style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    [t('email'), t('phone'), t('location')]
                        .where((e) => e.isNotEmpty)
                        .join('  |  '),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            block('PROFESSIONAL SUMMARY', t('summary')),
            block('TECHNICAL SKILLS', t('skills')),
            block('WORK EXPERIENCE', t('experience')),
            block('EDUCATION', t('education')),
            block('PROJECTS', t('projects')),
            block('CERTIFICATIONS', t('certs')),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF resume'),
                  onPressed: downloadResume,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Print / preview'),
                  onPressed: printResume,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientHeader(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.blue, AppColors.pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(sub,
                    style:
                    const TextStyle(color: Colors.white, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  ATS CHECKER  (upload a resume, evaluate, download / share / email)
  // ======================================================================

  Future<void> pickResume() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        showMessage('Could not read the selected file. Try another file.');
        return;
      }
      setState(() {
        fileName = file.name;
        resumeBytes = bytes;
        extractedText = '';
        result = null;
      });
      await analyzeResume();
    } catch (e) {
      showMessage('Could not select the resume.\n$e');
    }
  }

  Future<String> extractPdfText(Uint8List bytes) async {
    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: bytes);
      return sf.PdfTextExtractor(document).extractText(layoutText: false);
    } finally {
      document?.dispose();
    }
  }

  String extractDocxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.files.firstWhere(
          (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('This is not a valid DOCX file.'),
    );
    final xml = utf8.decode(entry.content as List<int>, allowMalformed: true);
    return xml
        .replaceAll('</w:p>', '\n')
        .replaceAll('<w:tab/>', ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  String extractLegacyDocText(Uint8List bytes) {
    final raw = String.fromCharCodes(bytes);
    return RegExp(r'[\x20-\x7E]{4,}')
        .allMatches(raw)
        .map((m) => m.group(0)!)
        .join(' ');
  }

  Future<void> analyzeResume() async {
    final bytes = resumeBytes;
    if (bytes == null) {
      showMessage('Select a resume first.');
      return;
    }
    setState(() => analyzing = true);
    try {
      final name = (fileName ?? '').toLowerCase();
      String text;
      if (name.endsWith('.pdf')) {
        text = await extractPdfText(bytes);
      } else if (name.endsWith('.docx')) {
        text = extractDocxText(bytes);
      } else {
        text = extractLegacyDocText(bytes);
      }
      if (text.trim().length < 30) {
        if (!mounted) return;
        setState(() => analyzing = false);
        showMessage('No readable text found. Scanned/image resumes are not '
            'supported, please upload a text-based PDF or DOCX.');
        return;
      }
      final evaluation = RbAtsAnalyzer.analyze(text);
      if (!mounted) return;
      setState(() {
        extractedText = text;
        result = evaluation;
        analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => analyzing = false);
      showMessage('Resume analysis failed.\n$e');
    }
  }

  Future<Uint8List> createATSReport() async {
    final r = result;
    if (r == null) throw Exception('No ATS result available.');
    final document = pw.Document(
      title: 'AI Resume ATS Evaluation',
      author: 'AI Resume Builder',
    );
    const blue = gen_pdf_blue;
    const pink = gen_pdf_pink;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: blue,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('AI RESUME ATS EVALUATION',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('AI Resume Builder',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Candidate Resume',
              style:
              pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(fileName ?? 'Resume'),
          pw.SizedBox(height: 18),
          pw.Text('Registered Email',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(email),
          pw.SizedBox(height: 24),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: pink, width: 1.5),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              children: [
                pw.Text('${r.score}/100',
                    style: pw.TextStyle(
                        fontSize: 38,
                        fontWeight: pw.FontWeight.bold,
                        color: pink)),
                pw.SizedBox(height: 5),
                pw.Text(r.rating,
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          _pdfSection('ATS MATRIX', [
            'Contact Information: ${r.contactScore}/15',
            'Professional Summary: ${r.summaryScore}/10',
            'Skills: ${r.skillsScore}/20',
            'Experience: ${r.experienceScore}/20',
            'Education: ${r.educationScore}/15',
            'Keywords: ${r.keywordScore}/10',
            'Resume Structure: ${r.structureScore}/10',
          ]),
          pw.SizedBox(height: 18),
          _pdfSection(
            'MATCHED KEYWORDS',
            r.matchedKeywords.isEmpty
                ? ['No configured keywords detected.']
                : [r.matchedKeywords.join(', ')],
          ),
          pw.SizedBox(height: 18),
          _pdfSection(
            'MISSING / RECOMMENDED KEYWORDS',
            r.missingKeywords.isEmpty
                ? ['No major keyword gaps detected.']
                : [r.missingKeywords.join(', ')],
          ),
          pw.SizedBox(height: 18),
          _pdfSection('IMPROVEMENT SUGGESTIONS', r.suggestions),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('Generated by AI Resume Builder',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _pdfSection(String title, List<String> lines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Text('- $line', style: const pw.TextStyle(fontSize: 10)),
          ),
      ],
    );
  }

  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> downloadReport() async {
    if (result == null) {
      showMessage('Analyze a resume first.');
      return;
    }
    setState(() => generating = true);
    try {
      final bytes = await createATSReport();
      await Printing.sharePdf(
        bytes: bytes,
        filename: reportFile,
        subject: 'AI Resume ATS Evaluation Report',
        bounds: _origin(),
      );
      if (kIsWeb) showMessage('ATS report downloaded.');
    } catch (e) {
      showMessage('Could not create the PDF.\n$e');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> shareReport() async {
    if (result == null) {
      showMessage('Analyze a resume first.');
      return;
    }
    setState(() => generating = true);
    try {
      final bytes = await createATSReport();
      await Printing.sharePdf(
        bytes: bytes,
        filename: reportFile,
        subject: 'AI Resume ATS Evaluation Report',
        body: 'AI Resume ATS Evaluation Report\n'
            'Candidate: ${fileName ?? "Resume"}\n'
            'ATS Score: ${result!.score}/100',
        bounds: _origin(),
      );
    } catch (e) {
      showMessage('Sharing failed.\n$e');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> emailReport() async {
    final r = result;
    if (r == null) {
      showMessage('Analyze a resume first.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      showMessage(
          'Enter a valid email address in the Resume Builder tab first.');
      return;
    }
    setState(() => generating = true);
    try {
      final bytes = await createATSReport();
      const subject = 'AI Resume ATS Evaluation Report';
      final body = 'Hello,\n\n'
          'Your AI Resume ATS evaluation is ready.\n\n'
          'Resume: ${fileName ?? 'Resume'}\n'
          'ATS Score: ${r.score}/100\n'
          'Rating: ${r.rating}\n\n'
          'Regards,\nAI Resume Builder';
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: reportFile);
        final uri = Uri.parse(
          'mailto:$email?subject=${Uri.encodeComponent(subject)}'
              '&body=${Uri.encodeComponent('$body\n\n(Attach the downloaded $reportFile before sending.)')}',
        );
        final opened = await launchUrl(uri);
        if (!opened) {
          showMessage('No email app found. The PDF was downloaded instead.');
        }
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: reportFile,
          subject: subject,
          body: body,
          emails: [email],
          bounds: _origin(),
        );
      }
    } catch (e) {
      showMessage('Could not prepare the email.\n$e');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Widget _buildAtsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _gradientHeader(Icons.psychology_outlined, 'ATS Resume Check',
            'Upload a PDF / DOC / DOCX resume and get an ATS score.'),
        const SizedBox(height: 16),
        _buildUploadCard(),
        const SizedBox(height: 16),
        if (analyzing)
          const BpCard(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Reading and evaluating resume...'),
                  ],
                ),
              ),
            ),
          ),
        if (result != null && !analyzing) ...[
          _buildScoreCard(result!, 'ATS SCORE'),
          const SizedBox(height: 16),
          _buildMatrix(result!),
          const SizedBox(height: 16),
          _buildKeywords(result!),
          const SizedBox(height: 16),
          _buildSuggestions(result!),
          const SizedBox(height: 16),
          _buildActions(),
        ],
        if (extractedText.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildExtractedText(),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUploadCard() {
    return BpCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resume Upload',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined,
                      color: AppColors.pink, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fileName ?? 'No resume selected',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Select Resume'),
                onPressed: analyzing ? null : pickResume,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(RbAtsResult r, String heading) {
    return BpCard(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Text(heading,
                  style: const TextStyle(
                      letterSpacing: 2,
                      color: AppColors.pink,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('${r.score}',
                  style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue)),
              const Text('/100', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              Chip(
                avatar: Icon(
                  r.score >= 80
                      ? Icons.check_circle
                      : r.score >= 60
                      ? Icons.warning
                      : Icons.error,
                  size: 18,
                ),
                label: Text(r.rating),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatrix(RbAtsResult r) {
    return BpCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ATS Evaluation Matrix',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _matrixRow('Contact Information', r.contactScore, 15),
            _matrixRow('Professional Summary', r.summaryScore, 10),
            _matrixRow('Skills', r.skillsScore, 20),
            _matrixRow('Experience', r.experienceScore, 20),
            _matrixRow('Education', r.educationScore, 15),
            _matrixRow('Keywords', r.keywordScore, 10),
            _matrixRow('Resume Structure', r.structureScore, 10),
          ],
        ),
      ),
    );
  }

  Widget _matrixRow(String title, int value, int max) {
    final percentage = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text('$value/$max',
                  style: const TextStyle(
                      color: AppColors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              color: percentage >= 0.7 ? AppColors.blue : AppColors.pink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywords(RbAtsResult r) {
    return BpCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Keyword Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              const Text('Detected',
                  style: TextStyle(
                      color: AppColors.blue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (r.matchedKeywords.isEmpty)
                const Text('No configured keywords detected.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final word in r.matchedKeywords)
                      Chip(label: Text(word)),
                  ],
                ),
              const SizedBox(height: 16),
              const Text('Recommended',
                  style: TextStyle(
                      color: AppColors.pink, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (r.missingKeywords.isEmpty)
                const Text('No major keyword gaps detected.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final word in r.missingKeywords)
                      Chip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: Text(word),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(RbAtsResult r) {
    return BpCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Improvement Suggestions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              for (int i = 0; i < r.suggestions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: _bpAlpha(AppColors.pink, .15),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.pink)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(r.suggestions[i])),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return BpCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              const Text('ATS Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: Text(generating ? 'Generating...' : 'Download PDF'),
                    onPressed: generating ? null : downloadReport,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share Report'),
                    onPressed: generating ? null : shareReport,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email Report'),
                    onPressed: generating ? null : emailReport,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                email.isEmpty
                    ? 'Add your email in the Resume Builder tab to email the report.'
                    : 'Report destination: $email',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtractedText() {
    return BpCard(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: const Text('Extracted Resume Text'),
        subtitle: const Text('Used for the local ATS evaluation'),
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 400),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: SelectableText(
                extractedText,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.blue,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.pink,
            tabs: const [
              Tab(icon: Icon(Icons.edit_document), text: 'Resume Builder'),
              Tab(icon: Icon(Icons.fact_check_outlined), text: 'ATS Check'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_buildBuilderTab(), _buildAtsTab()],
          ),
        ),
      ],
    );
  }
}

const PdfColor gen_pdf_blue = PdfColor.fromInt(0xFF1E5BFF);
const PdfColor gen_pdf_pink = PdfColor.fromInt(0xFFE91E8C);

// ------------------------------ ATS result ------------------------------

class RbAtsResult {
  final int score;
  final int contactScore;
  final int summaryScore;
  final int skillsScore;
  final int experienceScore;
  final int educationScore;
  final int keywordScore;
  final int structureScore;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final List<String> suggestions;

  RbAtsResult({
    required this.score,
    required this.contactScore,
    required this.summaryScore,
    required this.skillsScore,
    required this.experienceScore,
    required this.educationScore,
    required this.keywordScore,
    required this.structureScore,
    required this.matchedKeywords,
    required this.missingKeywords,
    required this.suggestions,
  });

  String get rating {
    if (score >= 90) return 'Excellent ATS Readiness';
    if (score >= 80) return 'Strong ATS Readiness';
    if (score >= 70) return 'Good ATS Readiness';
    if (score >= 60) return 'Needs Improvement';
    return 'Low ATS Readiness';
  }
}

class RbAtsAnalyzer {
  static const List<String> keywords = [
    'python',
    'java',
    'javascript',
    'typescript',
    'dart',
    'flutter',
    'react',
    'angular',
    'node',
    'sql',
    'mysql',
    'postgresql',
    'mongodb',
    'firebase',
    'aws',
    'azure',
    'gcp',
    'docker',
    'kubernetes',
    'git',
    'github',
    'machine learning',
    'deep learning',
    'artificial intelligence',
    'data science',
    'nlp',
    'computer vision',
    'tensorflow',
    'pytorch',
    'scikit-learn',
    'pandas',
    'numpy',
    'power bi',
    'tableau',
    'excel',
    'communication',
    'leadership',
    'problem solving',
    'project management',
  ];

  static String normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool containsAny(String text, List<String> words) {
    for (final word in words) {
      if (text.contains(word)) return true;
    }
    return false;
  }

  /// Whole-word match so "java" does not match "javascript".
  static bool hasWord(String text, String word) => RegExp(
    '(^|[^a-z0-9])${RegExp.escape(word)}(?![a-z0-9])',
  ).hasMatch(text);

  static RbAtsResult analyze(String originalText) {
    final text = normalize(originalText);

    var contact = 0;
    if (RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false)
        .hasMatch(originalText)) {
      contact += 8;
    }
    if (RegExp(r'(\+?\d[\d\s().-]{7,}\d)').hasMatch(originalText)) {
      contact += 7;
    }

    var summary = 0;
    if (containsAny(
        text, ['summary', 'profile', 'objective', 'professional summary'])) {
      summary += 10;
    }

    var skills = 0;
    if (containsAny(text, ['skills', 'technical skills'])) skills += 5;
    final matched = <String>[];
    for (final k in keywords) {
      if (hasWord(text, k)) matched.add(k);
    }
    skills += min(15, (matched.length * 15 / 12).round());
    skills = min(20, skills);

    var experience = 0;
    if (containsAny(text, [
      'experience',
      'work experience',
      'professional experience',
      'employment'
    ])) {
      experience += 8;
    }
    if (containsAny(text, [
      'intern',
      'developer',
      'engineer',
      'manager',
      'analyst',
      'consultant',
      'project'
    ])) {
      experience += 6;
    }
    if (containsAny(text, [
      'responsible',
      'developed',
      'implemented',
      'designed',
      'managed',
      'created',
      'built'
    ])) {
      experience += 6;
    }
    experience = min(20, experience);

    var education = 0;
    if (containsAny(text, [
      'education',
      'bachelor',
      'master',
      'b.tech',
      'm.tech',
      'degree',
      'university',
      'college'
    ])) {
      education += 10;
    }
    if (containsAny(text, ['cgpa', 'gpa', 'percentage', 'graduated'])) {
      education += 5;
    }
    education = min(15, education);

    final keywordScore = min(10, matched.length);

    const sections = [
      'summary',
      'skills',
      'experience',
      'education',
      'projects',
      'certifications'
    ];
    var found = 0;
    for (final s in sections) {
      if (text.contains(s)) found++;
    }
    final structure = min(10, (found * 10 / sections.length).round());

    final total = min(
      100,
      contact +
          summary +
          skills +
          experience +
          education +
          keywordScore +
          structure,
    );

    final missing = <String>[];
    for (final k in keywords) {
      if (!matched.contains(k)) missing.add(k);
      if (missing.length >= 12) break;
    }

    final suggestions = <String>[];
    if (contact < 15) {
      suggestions.add(
          'Add a professional email address and phone number in the header.');
    }
    if (summary < 10) {
      suggestions.add(
          'Add a concise professional summary containing your target role and strongest skills.');
    }
    if (skills < 15) {
      suggestions.add(
          'Create a clearly labelled Technical Skills section and include technologies relevant to the target job.');
    }
    if (experience < 15) {
      suggestions.add(
          'Strengthen experience entries with action verbs, measurable achievements and project outcomes.');
    }
    if (education < 10) {
      suggestions.add(
          'Add education details including degree, institution and relevant academic information.');
    }
    if (keywordScore < 7) {
      suggestions.add(
          'Add job-specific keywords naturally throughout the resume instead of relying on a generic skills list.');
    }
    if (structure < 8) {
      suggestions.add(
          'Use standard ATS-friendly section headings such as Summary, Skills, Experience, Education and Projects.');
    }
    if (suggestions.isEmpty) {
      suggestions.add(
          'The resume has a strong basic ATS structure. Tailor keywords and achievements for every individual job description.');
    }

    return RbAtsResult(
      score: total,
      contactScore: contact,
      summaryScore: summary,
      skillsScore: skills,
      experienceScore: experience,
      educationScore: education,
      keywordScore: keywordScore,
      structureScore: structure,
      matchedKeywords: matched,
      missingKeywords: missing,
      suggestions: suggestions,
    );
  }
}

// ==========================================================================
//  MODULE: AI Mock Interview  (NO API KEYS - everything runs on-device)
// ==========================================================================
//  15 spoken questions, live camera + recording, on-device smart marking,
//  PDF + CSV + video download, e-mail with attachments.
//  Entry point:  const AiMockInterview()
//
//  HOW MARKING WORKS (no server, no keys)
//   1. While you answer, the phone's speech recognition (speech_to_text)
//      writes your words into the "Your answer" box. You can also type or
//      edit the text, which is useful if the microphone is busy recording.
//   2. When the interview ends, MiScorer compares every answer with the
//      question's key points (rubric) using stemming, keyword coverage and
//      TF-IDF cosine similarity, and adds delivery checks (length vs time
//      allowed, filler words). It returns a 0-10 score plus feedback.
//   3. Scores can still be adjusted with the sliders, then downloaded/e-mailed.
//
//  REPLACE the whole old "MODULE: AI Mock Interview" section with this file
//  (everything from that header down to just before "MODULE: Shruthi Box").
//  It re-uses LocalEngine, TfIdf, gen_pdf_blue and gen_pdf_pink which already
//  exist elsewhere in main.dart. The old kMiAnthropicKey, kMiOpenAiKey,
//  kMiClaudeModel, kMiWhisperModel and _miAiConfigured are deleted.
// ==========================================================================

/// Lower this (e.g. ResolutionPreset.low) to shrink the long recording.
const ResolutionPreset kMiVideoPreset = ResolutionPreset.medium;

List<CameraDescription> _miCameras = [];

class MiQuestion {
  final String text;
  final String category;
  final int answerSeconds;
  final String rubric; // key points separated by ';'
  const MiQuestion(this.text,
      {this.category = 'General', this.answerSeconds = 60, this.rubric = ''});
}

class MiAnswer {
  final MiQuestion question;
  final double startSec;
  final double durationSec;
  double score;
  String notes;
  String transcript;
  MiAnswer({
    required this.question,
    required this.startSec,
    required this.durationSec,
    this.score = 0,
    this.notes = '',
    this.transcript = '',
  });
}

class _MiAtt {
  final String name;
  final String mime;
  final Uint8List bytes;
  _MiAtt(this.name, this.mime, this.bytes);
}

enum MiStep { idle, running, done, failed, skipped }

enum MiPhase { setup, running, finishing, review }

// --------------------------------------------------------------------------
//  ON-DEVICE SCORER
// --------------------------------------------------------------------------

class MiScore {
  final double score; // 0..10 in steps of 0.5
  final String feedback;
  const MiScore(this.score, this.feedback);
}

class MiScorer {
  static List<String> _points(String rubric) => rubric
      .split(RegExp(r'[;.]'))
      .map((s) => s.trim())
      .where((s) => s.length > 3)
      .toList();

  static MiScore score(MiQuestion q, String text, double seconds) {
    final toks = LocalEngine.tokens(text);
    final n = toks.length;
    if (n < 3) {
      return const MiScore(0,
          'No answer was captured. Speak clearly, or type your answer in the box.');
    }

    final ansTerms = TfIdf.terms(text).toSet();
    final points = _points(q.rubric);

    // 1) key-point coverage with partial credit
    var credit = 0.0;
    final missing = <String>[];
    for (final p in points) {
      final terms = TfIdf.terms(p).toSet();
      if (terms.isEmpty) continue;
      final hit = terms.where(ansTerms.contains).length;
      final frac = hit / terms.length;
      credit += math.min(1.0, frac / 0.5);
      if (frac < 0.34) missing.add(p);
    }
    final pointCov =
    points.isEmpty ? 0.5 : (credit / points.length).clamp(0.0, 1.0);

    // 2) overall keyword coverage + TF-IDF similarity
    final allTerms = TfIdf.terms(q.rubric).toSet();
    final termHit = allTerms.where(ansTerms.contains).length;
    final termCov = allTerms.isEmpty
        ? 0.5
        : (termHit / allTerms.length * 1.6).clamp(0.0, 1.0);
    final sim = (TfIdf.cosine(text, q.rubric) * 3).clamp(0.0, 1.0);

    // 3) delivery: length vs time allowed, filler words
    final target = q.answerSeconds * 1.0; // about 1 word per allowed second
    var lenScore = math.min(1.0, n / target);
    if (n > target * 3) lenScore = 0.8;
    final fillers = LocalEngine.fillerCount(text);
    final fillerPenalty = (fillers / n * 8).clamp(0.0, 0.5);
    final delivery =
    (0.75 * lenScore + 0.25 * (1 - fillerPenalty * 2)).clamp(0.0, 1.0);

    final content = 0.55 * pointCov + 0.20 * termCov + 0.25 * sim;
    final raw = 10 * (0.8 * content + 0.2 * delivery);
    final score = ((raw * 2).round() / 2).clamp(0.0, 10.0).toDouble();

    // feedback
    final b = StringBuffer();
    b.write(score >= 8
        ? 'Excellent, well-covered answer. '
        : score >= 6
        ? 'Good answer with room to add detail. '
        : score >= 4
        ? 'Partly correct; important points are missing. '
        : 'The answer needs much more substance. ');
    if (missing.isNotEmpty) {
      b.write('Try to also mention: ${missing.take(2).join('; ')}. ');
    }
    if (lenScore < 0.5) {
      b.write('Speak for longer and give an example. ');
    }
    if (fillers > 2) {
      b.write('Cut filler words such as "like" and "you know". ');
    }
    return MiScore(score, b.toString().trim());
  }

  static String overall(List<MiAnswer> rs) {
    if (rs.isEmpty) return 'No answers were recorded.';
    final total = rs.fold(0.0, (a, r) => a + r.score);
    final pct = total / (rs.length * 10) * 100;
    final byCat = <String, List<double>>{};
    for (final r in rs) {
      byCat.putIfAbsent(r.question.category, () => []).add(r.score);
    }
    String best = '', worst = '';
    var bestV = -1.0, worstV = 11.0;
    byCat.forEach((k, v) {
      final a = v.reduce((x, y) => x + y) / v.length;
      if (a > bestV) {
        bestV = a;
        best = k;
      }
      if (a < worstV) {
        worstV = a;
        worst = k;
      }
    });
    final unanswered = rs.where((r) => r.score == 0).length;
    return 'You scored ${pct.toStringAsFixed(0)}% overall. '
        'Strongest area: $best (${bestV.toStringAsFixed(1)}/10). '
        'Weakest area: $worst (${worstV.toStringAsFixed(1)}/10). '
        '${unanswered > 0 ? '$unanswered question(s) had no captured answer. ' : ''}'
        'Practise the missing key points out loud and use the STAR method for behavioural questions.';
  }
}

// --------------------------------------------------------------------------
//  QUESTIONS
// --------------------------------------------------------------------------

const List<MiQuestion> kMiQuestions = [
  MiQuestion('Please introduce yourself and summarise your background.',
      category: 'Introduction',
      answerSeconds: 60,
      rubric:
      'Clear structure; education and experience; key skills; relevance to AI and ML roles; concise.'),
  MiQuestion(
      'What is the difference between supervised and unsupervised learning? Give an example of each.',
      category: 'ML Basics',
      answerSeconds: 60,
      rubric:
      'Labeled versus unlabeled data; supervised is classification and regression; unsupervised is clustering and dimensionality reduction; correct examples.'),
  MiQuestion('Explain overfitting and two ways to prevent it.',
      category: 'ML Basics',
      answerSeconds: 60,
      rubric:
      'Model memorises training data and generalises poorly; regularisation; more data; cross-validation; early stopping; dropout; simpler model.'),
  MiQuestion('What is the bias-variance trade-off?',
      category: 'ML Basics',
      answerSeconds: 60,
      rubric:
      'Bias is underfitting from oversimplification; variance is sensitivity to training data; trade-off with model complexity; total error.'),
  MiQuestion(
      'Which metrics would you use to evaluate a classifier, and when is accuracy misleading?',
      category: 'Evaluation',
      answerSeconds: 60,
      rubric:
      'Precision, recall, F1, ROC-AUC, confusion matrix; accuracy is misleading on imbalanced data; choose the metric by the cost of errors.'),
  MiQuestion('Explain gradient descent and the role of the learning rate.',
      category: 'Optimisation',
      answerSeconds: 60,
      rubric:
      'Iteratively minimise the loss using gradients; learning rate is the step size; too high diverges, too low is slow; variants SGD, mini-batch, Adam.'),
  MiQuestion(
      'How would you explain a neural network to a non-technical person?',
      category: 'Communication',
      answerSeconds: 60,
      rubric:
      'Plain-language analogy; layers of simple units; learns from examples by adjusting weights; avoids jargon; clear.'),
  MiQuestion(
      'How do you clean data and engineer features before training a model?',
      category: 'Data',
      answerSeconds: 60,
      rubric:
      'Missing values, outliers, duplicates; scaling and normalisation; encoding categorical variables; feature selection and creation; avoid leakage; train and test split.'),
  MiQuestion('When would you use a CNN, an RNN, or a Transformer?',
      category: 'Deep Learning',
      answerSeconds: 60,
      rubric:
      'CNN for images and spatial data; RNN or LSTM for sequences; Transformers for language and long-range dependencies with attention; trade-offs.'),
  MiQuestion('How would you handle a highly imbalanced dataset?',
      category: 'Data',
      answerSeconds: 60,
      rubric:
      'Resampling with oversampling, undersampling or SMOTE; class weights; suitable metrics such as PR-AUC and F1; threshold tuning; collect more minority data.'),
  MiQuestion(
      'How would you deploy a machine learning model and keep it healthy in production?',
      category: 'MLOps',
      answerSeconds: 75,
      rubric:
      'Serving via API or batch; containers; versioning; monitor latency and data or concept drift; retraining pipeline; rollback; testing.'),
  MiQuestion(
      'Describe a challenging project you worked on and your role in it.',
      category: 'Behavioural',
      answerSeconds: 90,
      rubric:
      'STAR structure of situation, task, action and result; personal contribution; measurable outcome; lessons learned.'),
  MiQuestion(
      'Tell me about a time you disagreed with a teammate and how you resolved it.',
      category: 'Behavioural',
      answerSeconds: 75,
      rubric:
      'Specific example; respectful communication; listening; compromise or data-driven decision; positive result.'),
  MiQuestion(
      'What are the main ethical risks in AI systems, and how can they be reduced?',
      category: 'Responsible AI',
      answerSeconds: 75,
      rubric:
      'Bias and fairness; privacy; transparency and explainability; accountability; misuse; mitigations such as diverse data, audits, human oversight, documentation.'),
  MiQuestion(
      'Where do you see yourself in three years, and why are you interested in this role?',
      category: 'Closing',
      answerSeconds: 60,
      rubric:
      'Realistic goals; learning plan; alignment with the role; motivation; enthusiasm.'),
];

// --------------------------------------------------------------------------
//  WIDGET
// --------------------------------------------------------------------------

class AiMockInterview extends StatefulWidget {
  final List<MiQuestion> questions;
  final String defaultRecipient;
  const AiMockInterview({
    super.key,
    this.questions = kMiQuestions,
    this.defaultRecipient = '',
  });

  @override
  State<AiMockInterview> createState() => _AiMockInterviewState();
}

class _AiMockInterviewState extends State<AiMockInterview> {
  CameraController? _cam;
  CameraDescription? _camDesc;
  final FlutterTts _tts = FlutterTts();
  final Stopwatch _clock = Stopwatch();

  // speech recognition (answers -> text)
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;
  bool _wantListen = false;
  bool _listening = false;
  bool _restarting = false;
  String _base = '';
  final TextEditingController _liveCtl = TextEditingController();

  late final TextEditingController _nameCtl = TextEditingController();
  late final TextEditingController _emailCtl =
  TextEditingController(text: widget.defaultRecipient);

  final Queue<MiQuestion> _queue = Queue();
  MiQuestion? _current;
  final List<MiAnswer> _records = [];

  MiPhase _phase = MiPhase.setup;
  bool _recordVideo = true;
  bool _isRecording = false;
  bool _speaking = false;
  int _remaining = 0;
  int _token = 0;
  int? _answerStartMs;
  Timer? _timer;
  String? _cameraError;
  DateTime? _startedAt;

  bool _busy = false;
  String _busyMsg = '';

  XFile? _video;
  int _videoBytes = 0;
  String? _videoError;
  VideoPlayerController? _player;

  MiStep _markStep = MiStep.idle;
  String? _markMsg;
  bool _aiMarked = false;
  String _overallFeedback = '';
  MiStep _uploadStep = MiStep.idle;
  String? _uploadMsg;

  @override
  void initState() {
    super.initState();
    _initCamera(withAudio: true);
    _initTts();
    _initStt();
  }

  Future<void> _initStt() async {
    try {
      _sttReady = await _stt.initialize(
        onStatus: _onSttStatus,
        onError: (e) {
          if (_wantListen) _scheduleRestart();
        },
      );
    } catch (_) {
      _sttReady = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _initCamera({required bool withAudio}) async {
    try {
      if (_miCameras.isEmpty) _miCameras = await availableCameras();
      if (_miCameras.isEmpty) {
        if (mounted)
          setState(() => _cameraError = 'No camera found on this device.');
        return;
      }
      _camDesc ??= _miCameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _miCameras.first,
      );
      await _cam?.dispose();
      final ctl =
      CameraController(_camDesc!, kMiVideoPreset, enableAudio: withAudio);
      await ctl.initialize();
      if (!mounted) {
        await ctl.dispose();
        return;
      }
      setState(() {
        _cam = ctl;
        _cameraError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera unavailable: $e');
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wantListen = false;
    _stt.stop();
    _tts.stop();
    _player?.dispose();
    _cam?.dispose();
    _nameCtl.dispose();
    _emailCtl.dispose();
    _liveCtl.dispose();
    super.dispose();
  }

  // ───────────── Speech-to-text for answers ─────────────

  void _onSttStatus(String st) {
    if (!mounted) return;
    setState(() => _listening = st == 'listening');
    if (_wantListen && (st == 'done' || st == 'notListening')) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (_restarting) return;
    _restarting = true;
    Future.delayed(const Duration(milliseconds: 450), () async {
      _restarting = false;
      if (mounted && _wantListen) {
        _base = _liveCtl.text.trim();
        await _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (!_sttReady || !_wantListen) return;
    try {
      await _stt.listen(
        onResult: (r) {
          if (!mounted || !_wantListen) return;
          final w = r.recognizedWords;
          final t = _base.isEmpty ? w : (w.isEmpty ? _base : '$_base $w');
          setState(() {
            _liveCtl.value = TextEditingValue(
                text: t, selection: TextSelection.collapsed(offset: t.length));
          });
          if (r.finalResult) _base = t;
        },
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (_) {}
  }

  Future<void> _stopListening() async {
    _wantListen = false;
    try {
      await _stt.stop();
    } catch (_) {}
    if (mounted) setState(() => _listening = false);
  }

  // ───────────── Recording ─────────────

  Future<bool> _startRecording() async {
    Future<void> attempt() async {
      if (_cam == null || !_cam!.value.isInitialized) {
        throw 'Camera is not ready';
      }
      try {
        await _cam!.prepareForVideoRecording();
      } catch (_) {}
      await _cam!.startVideoRecording();
    }

    try {
      await attempt();
      return true;
    } catch (e1) {
      try {
        await _initCamera(withAudio: false);
        await attempt();
        _snack(
            'Recording without audio (microphone unavailable). Speech capture may not work; type your answers instead.');
        return true;
      } catch (e2) {
        _videoError = 'Could not start recording: $e1';
        return false;
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_cam == null || !_cam!.value.isRecordingVideo) {
      _videoError ??= 'Recording was not active when the interview ended.';
      return;
    }
    try {
      final x = await _cam!.stopVideoRecording();
      if (kIsWeb) {
        _video = x;
      } else {
        // The camera plugin has already written the recording to its temporary
        // file. Keep that XFile path; the IO adapter handles local playback.
        _video = x;
      }
      _videoBytes = await _video!.length();
      if (_videoBytes == 0) {
        _videoError = 'The recorded file is empty.';
        _video = null;
      }
    } catch (e) {
      _videoError = 'Could not save the recording: $e';
      _video = null;
    }
    _isRecording = false;
  }

  String get _videoExt {
    final mime = (_video?.mimeType ?? '').toLowerCase();
    final name = (_video?.name ?? '').toLowerCase();
    if (mime.contains('mp4') || name.endsWith('.mp4')) return 'mp4';
    if (mime.contains('webm') || name.endsWith('.webm')) return 'webm';
    return kIsWeb ? 'webm' : 'mp4';
  }

  Future<void> _initPlayer() async {
    final v = _video;
    await _player?.dispose();
    _player = null;
    if (v == null) return;
    try {
      final c = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(v.path))
          : platform_io.localVideoController(v.path);
      await c.initialize();
      if (!mounted) return;
      setState(() => _player = c);
    } catch (_) {}
  }

  // ───────────── Interview flow ─────────────

  Future<void> _start() async {
    if (_cam == null || !_cam!.value.isInitialized) {
      _snack('Camera is not ready yet.');
      return;
    }
    if (_nameCtl.text.trim().isEmpty) {
      _snack('Enter the candidate name first.');
      return;
    }
    _queue
      ..clear()
      ..addAll(widget.questions);
    _records.clear();
    _video = null;
    _videoError = null;
    _videoBytes = 0;
    _markStep = MiStep.idle;
    _markMsg = null;
    _aiMarked = false;
    _overallFeedback = '';
    _uploadStep = MiStep.idle;
    _uploadMsg = null;
    _liveCtl.clear();
    _base = '';
    await _player?.dispose();
    _player = null;
    _startedAt = DateTime.now();

    if (_recordVideo) {
      _clock
        ..reset()
        ..start();
      final ok = await _startRecording();
      if (!ok) {
        _clock.stop();
        if (!mounted) return;
        final cont = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Video recording failed'),
            content:
            Text('$_videoError\n\nContinue the interview without video?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Continue')),
            ],
          ),
        );
        if (cont != true) return;
        _clock
          ..reset()
          ..start();
      } else {
        _isRecording = true;
      }
    } else {
      _clock
        ..reset()
        ..start();
    }

    setState(() => _phase = MiPhase.running);
    await _askNext();
  }

  Future<void> _askNext() async {
    if (_queue.isEmpty) {
      await _finish();
      return;
    }
    final token = ++_token;
    final q = _queue.removeFirst();
    _liveCtl.clear();
    _base = '';
    setState(() {
      _current = q;
      _speaking = true;
      _remaining = q.answerSeconds;
    });
    _answerStartMs = null;

    try {
      await _tts
          .speak(q.text)
          .timeout(const Duration(seconds: 40), onTimeout: () => null);
    } catch (_) {}
    _beginAnswer(token);
  }

  void _beginAnswer(int token) {
    if (!mounted || token != _token || !_speaking) return;
    _answerStartMs = _clock.elapsedMilliseconds;
    setState(() => _speaking = false);
    _wantListen = true;
    _base = '';
    _startListening();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || token != _token) {
        t.cancel();
        return;
      }
      if (_remaining <= 1) {
        t.cancel();
        _endAnswer(token);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _endAnswer(int token) {
    if (token != _token || _current == null) return;
    _timer?.cancel();
    _token++;
    _stopListening();
    final startMs = _answerStartMs ?? _clock.elapsedMilliseconds;
    _records.add(MiAnswer(
      question: _current!,
      startSec: startMs / 1000,
      durationSec: (_clock.elapsedMilliseconds - startMs) / 1000,
      transcript: _liveCtl.text.trim(),
    ));
    _askNext();
  }

  void _skip() {
    if (_speaking) {
      _tts.stop();
      _beginAnswer(_token);
    } else {
      _endAnswer(_token);
    }
  }

  Future<void> _repeatQuestion() async {
    if (_current == null || _speaking) return;
    try {
      await _tts.speak(_current!.text);
    } catch (_) {}
  }

  Future<void> _finish() async {
    if (_phase != MiPhase.running) return;
    _timer?.cancel();
    _token++;
    await _stopListening();
    try {
      await _tts.stop();
    } catch (_) {}
    if (_current != null &&
        !_speaking &&
        _answerStartMs != null &&
        _records.length < widget.questions.length - _queue.length) {
      _records.add(MiAnswer(
        question: _current!,
        startSec: _answerStartMs! / 1000,
        durationSec: (_clock.elapsedMilliseconds - _answerStartMs!) / 1000,
        transcript: _liveCtl.text.trim(),
      ));
    }
    setState(() => _phase = MiPhase.finishing);
    _clock.stop();
    if (_recordVideo) await _stopRecording();
    await _initPlayer();
    if (!mounted) return;
    setState(() => _phase = MiPhase.review);
    // ignore: unawaited_futures
    _runPostInterview();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _setBusy(String? msg) {
    if (!mounted) return;
    setState(() {
      _busy = msg != null;
      _busyMsg = msg ?? '';
    });
  }

  // ───────────── On-device marking ─────────────

  Future<void> _runPostInterview() async {
    await _autoMark();
    if (mounted) _showSubmitDialog();
  }

  Future<void> _autoMark() async {
    setState(() {
      _markStep = MiStep.running;
      _markMsg = null;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      for (final r in _records) {
        final s = MiScorer.score(r.question, r.transcript, r.durationSec);
        r.score = s.score;
        r.notes = s.feedback;
      }
      final overall = MiScorer.overall(_records);
      if (!mounted) return;
      setState(() {
        _aiMarked = true;
        _overallFeedback = overall;
        _markStep = MiStep.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _markStep = MiStep.failed;
        _markMsg = '$e';
      });
    }
  }

  Future<void> _saveAll() async {
    setState(() {
      _uploadStep = MiStep.running;
      _uploadMsg = null;
    });
    try {
      final names = await _downloadCore();
      if (!mounted) return;
      setState(() {
        _uploadStep = MiStep.done;
        _uploadMsg = 'Saved ${names.length} files: ${names.join(", ")}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadStep = MiStep.failed;
        _uploadMsg = '$e';
      });
    }
  }

  // ───────────── Report building ─────────────

  double get _total => _records.fold(0.0, (a, r) => a + r.score);
  double get _maxTotal => _records.length * 10.0;
  double get _percent => _maxTotal == 0 ? 0 : _total / _maxTotal * 100;

  String get _grade {
    final p = _percent;
    if (p >= 85) return 'A';
    if (p >= 70) return 'B';
    if (p >= 55) return 'C';
    if (p >= 40) return 'D';
    return 'F';
  }

  String _fmt(double s) {
    final m = s ~/ 60;
    final sec = (s % 60).round().toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String get _safeName {
    final n = _nameCtl.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return n.isEmpty ? 'candidate' : n;
  }

  Future<Uint8List> _pdfBytes() async {
    final doc = pw.Document();
    final date = (_startedAt ?? DateTime.now()).toString().substring(0, 16);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
              color: gen_pdf_blue, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Text('Mock Interview Marksheet',
              style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Candidate: ${_nameCtl.text.trim()}'),
        pw.Text('Date: $date'),
        pw.Text(
            'Marking: ${_aiMarked ? "On-device smart marking (reviewable)" : "Manual"}'),
        pw.Text(
            'Video recorded: ${_video != null ? "Yes (.$_videoExt)" : "No"}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: [
            '#',
            'Category',
            'Question',
            'Time',
            'Score /10',
            'Feedback'
          ],
          data: [
            for (var i = 0; i < _records.length; i++)
              [
                '${i + 1}',
                _records[i].question.category,
                _records[i].question.text,
                _fmt(_records[i].durationSec),
                _records[i].score.toStringAsFixed(1),
                _records[i].notes,
              ],
          ],
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: gen_pdf_pink),
          columnWidths: {
            0: const pw.FixedColumnWidth(18),
            1: const pw.FixedColumnWidth(60),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FixedColumnWidth(32),
            4: const pw.FixedColumnWidth(42),
            5: const pw.FlexColumnWidth(3),
          },
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Total: ${_total.toStringAsFixed(1)} / ${_maxTotal.toStringAsFixed(0)}   '
              '(${_percent.toStringAsFixed(1)}%)   Grade: $_grade',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        if (_overallFeedback.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('Overall feedback',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(_overallFeedback),
        ],
      ],
    ));
    return Uint8List.fromList(await doc.save());
  }

  String _csvEscape(String s) => '"${s.replaceAll('"', '""')}"';

  Uint8List _csvBytes() {
    final b = StringBuffer()
      ..writeln('Candidate,${_csvEscape(_nameCtl.text.trim())}')
      ..writeln('Date,${_startedAt ?? DateTime.now()}')
      ..writeln('Marking,${_aiMarked ? "On-device smart marking" : "Manual"}')
      ..writeln()
      ..writeln(
          'No,Category,Question,Start (s),Duration (s),Score /10,Feedback,Transcript');
    for (var i = 0; i < _records.length; i++) {
      final r = _records[i];
      b.writeln([
        i + 1,
        _csvEscape(r.question.category),
        _csvEscape(r.question.text),
        r.startSec.toStringAsFixed(1),
        r.durationSec.toStringAsFixed(1),
        r.score.toStringAsFixed(1),
        _csvEscape(r.notes),
        _csvEscape(r.transcript),
      ].join(','));
    }
    b
      ..writeln()
      ..writeln(
          'Total,${_total.toStringAsFixed(1)},Max,${_maxTotal.toStringAsFixed(0)},'
              'Percent,${_percent.toStringAsFixed(1)},Grade,$_grade')
      ..writeln('Overall feedback,${_csvEscape(_overallFeedback)}');
    return Uint8List.fromList(utf8.encode(b.toString()));
  }

  Future<_MiAtt> _pdfAtt() async =>
      _MiAtt('marksheet_$_safeName.pdf', 'application/pdf', await _pdfBytes());

  _MiAtt _csvAtt() =>
      _MiAtt('assessment_$_safeName.csv', 'text/csv', _csvBytes());

  Future<_MiAtt?> _videoAtt() async {
    if (_video == null) return null;
    final ext = _videoExt;
    return _MiAtt('interview_$_safeName.$ext',
        ext == 'mp4' ? 'video/mp4' : 'video/webm', await _video!.readAsBytes());
  }

  // ───────────── Download ─────────────

  Future<void> _saveAtt(_MiAtt a) async {
    // Safely find the extension index
    final dot = a.name.lastIndexOf('.');

    // Separate the base name and the extension
    final nameOnly = dot != -1 ? a.name.substring(0, dot) : a.name;
    final extensionOnly = dot != -1 ? a.name.substring(dot + 1) : '';

    await FileSaver.instance.saveFile(
      name: nameOnly,
      bytes: a.bytes,
      ext: extensionOnly,
      mimeType: MimeType.custom,
      customMimeType: a.mime,
    );
  }


  Future<List<String>> _downloadCore() async {
    final atts = <_MiAtt>[await _pdfAtt(), _csvAtt()];
    final v = await _videoAtt();
    if (v != null) atts.add(v);
    for (final a in atts) {
      await _saveAtt(a);
      await Future.delayed(const Duration(milliseconds: 350));
    }
    return atts.map((a) => a.name).toList();
  }

  Future<void> _downloadAll() async {
    if (_busy) return;
    _setBusy('Preparing downloads…');
    try {
      final names = await _downloadCore();
      _snack('Saved ${names.length} files: ${names.join(", ")}');
    } catch (e) {
      _snack('Download failed: $e');
    } finally {
      _setBusy(null);
    }
  }

  /// Downloads a single file: 'pdf', 'csv' or 'video'.
  Future<void> _downloadOne(String kind) async {
    if (_busy) return;
    _setBusy('Preparing $kind…');
    try {
      final _MiAtt? a = kind == 'pdf'
          ? await _pdfAtt()
          : kind == 'csv'
          ? _csvAtt()
          : await _videoAtt();
      if (a == null) {
        _snack('No video was recorded.');
      } else {
        await _saveAtt(a);
        _snack('Saved ${a.name}');
      }
    } catch (e) {
      _snack('Download failed: $e');
    } finally {
      _setBusy(null);
    }
  }

  // ───────────── Email ─────────────

  bool _validEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  Future<String?> _askEmail() async {
    final current = _emailCtl.text.trim();
    if (_validEmail(current)) return current;
    final c = TextEditingController(text: current);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send results to which email?'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'name@example.com'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Send')),
        ],
      ),
    );
    if (r == null) return null;
    if (!_validEmail(r)) {
      _snack('That email address looks invalid.');
      return null;
    }
    setState(() => _emailCtl.text = r);
    return r;
  }

  String get _mailSubject =>
      'Mock interview submission - ${_nameCtl.text.trim()}';

  String get _mailBody => 'Candidate: ${_nameCtl.text.trim()}\n'
      'Score: ${_total.toStringAsFixed(1)} / ${_maxTotal.toStringAsFixed(0)} '
      '(${_percent.toStringAsFixed(1)}%), Grade $_grade\n\n'
      '$_overallFeedback\n\n'
      '${_video != null ? "Attached: interview video (.$_videoExt), marksheet (PDF) and assessment record (CSV)." : "Attached: marksheet (PDF) and assessment record (CSV). No video was recorded."}';

  Future<void> _emailAll() async {
    if (_busy) return;
    final to = await _askEmail();
    if (to == null) return;
    _setBusy('Preparing email…');
    try {
      if (!kIsWeb) {
        await _sendViaMailApp(to);
      } else {
        await _fallbackMailto(to);
      }
    } catch (e) {
      _snack('Direct email failed ($e). Opening fallback…');
      try {
        await _fallbackMailto(to);
      } catch (e2) {
        _snack(
            'Email could not be started: $e2. Use Download and attach the files manually.');
      }
    } finally {
      _setBusy(null);
    }
  }

  /// Mobile: opens the phone's mail app with recipient, subject, body and the
  /// PDF + CSV + video already attached. Press Send there.
  Future<void> _sendViaMailApp(String to) async {
    final paths = <String>[];
    for (final a in [await _pdfAtt(), _csvAtt()]) {
      final String? savedPath = await platform_io.writeLocalBytes(
        a.bytes,
        a.name,
      );
      if (savedPath != null && savedPath.isNotEmpty) {
        paths.add(savedPath);
      }
    }
    if (_video != null) paths.add(_video!.path);
    if (paths.isEmpty) {
      throw StateError('No attachment files could be prepared.');
    }
    await FlutterEmailSender.send(Email(
      recipients: [to],
      subject: _mailSubject,
      body: _mailBody,
      attachmentPaths: paths,
      isHTML: false,
    ));
  }

  /// Web / fallback: saves the files, then opens a mailto draft.
  Future<void> _fallbackMailto(String to) async {
    _setBusy('Saving files…');
    final names = await _downloadCore();
    final body =
        '$_mailBody\n\n(Please attach the downloaded files: ${names.join(", ")})';
    final uri = Uri.parse(
        'mailto:$to?subject=${Uri.encodeComponent(_mailSubject)}&body=${Uri.encodeComponent(body)}');
    final ok = await launchUrl(uri);
    if (!ok) throw 'no email handler found on this device';
    _snack('Files saved. Attach them to the email draft that just opened.');
  }

  // ───────────── Dialog + UI ─────────────

  void _showSubmitDialog() {
    final uploaded = _uploadStep == MiStep.done;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Interview complete'),
        content: SingleChildScrollView(
          child: Text(
            '${_aiMarked ? "Marking finished: ${_total.toStringAsFixed(1)} / ${_maxTotal.toStringAsFixed(0)} "
                "(${_percent.toStringAsFixed(1)}%, Grade $_grade)." : "Marking did not run${_markMsg != null ? ": $_markMsg" : "."}"}\n\n'
                '${uploaded ? "Assessment CSV, PDF and recording were saved to this device.\n\n" : ""}'
                '${_video == null ? "No video was saved. ${_videoError ?? ""}\n\n" : ""}'
                'Download or email the report${_video != null ? " and video" : ""}?',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Review first')),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(c);
              _downloadAll();
            },
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(c);
              _emailAll();
            },
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.blue, AppColors.pink]),
          ),
          child: Row(
            children: [
              const Icon(Icons.videocam, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('AI Mock Interview',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
              ),
              if (_phase == MiPhase.running)
                TextButton.icon(
                  onPressed: _finish,
                  style: TextButton.styleFrom(foregroundColor: AppColors.background),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End'),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (_phase) {
            MiPhase.setup => _setupView(),
            MiPhase.running => _runningView(),
            MiPhase.finishing => const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Saving video…'),
              ]),
            ),
            MiPhase.review => _reviewView(),
          },
        ),
      ],
    );
  }

  Widget _cameraView() {
    if (_cameraError != null) {
      return Container(
        color: AppColors.blueSoft,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_cameraError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () => _initCamera(withAudio: true),
                  child: const Text('Retry camera')),
            ]),
          ),
        ),
      );
    }
    if (_cam == null || !_cam!.value.isInitialized) {
      return Container(
          color: AppColors.blueSoft,
          child: const Center(child: CircularProgressIndicator()));
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cam!.value.previewSize!.height,
          height: _cam!.value.previewSize!.width,
          child: CameraPreview(_cam!),
        ),
      ),
    );
  }

  Widget _setupView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
              height: 280, width: double.infinity, child: _cameraView()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameCtl,
          decoration: const InputDecoration(labelText: 'Candidate name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailCtl,
          keyboardType: TextInputType.emailAddress,
          decoration:
          const InputDecoration(labelText: 'Submit results to (email)'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _recordVideo,
          onChanged: (v) => setState(() => _recordVideo = v),
          title: const Text('Record video'),
          subtitle: const Text(
              'Adds the video to the download and email attachments'),
          secondary: const Icon(Icons.videocam),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            _sttReady
                ? 'Voice answers are turned into text on this device and marked automatically. No internet keys needed.'
                : 'Speech recognition is unavailable here. You can still type each answer in the answer box and it will be marked.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.fiber_manual_record),
            label:
            Text('Start interview (${widget.questions.length} questions)'),
          ),
        ),
      ],
    );
  }

  Widget _runningView() {
    final total = widget.questions.length;
    final index = total - _queue.length;
    final q = _current;
    return Stack(children: [
      Positioned.fill(child: _cameraView()),
      Positioned(
        left: 12,
        right: 12,
        top: 12,
        child: Card(
          color: AppColors.card.withOpacity(0.96),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Chip(label: Text('Q$index / $total')),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(q?.category ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted)),
                ),
                const Spacer(),
                Icon(_speaking ? Icons.volume_up : Icons.mic,
                    color: _speaking ? AppColors.pink : AppColors.blue),
                const SizedBox(width: 4),
                Text(_speaking ? 'Listen…' : 'Answer: ${_remaining}s',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Text(q?.text ?? '', style: const TextStyle(fontSize: 17)),
              if (!_speaking && q != null) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                    value: _remaining / q.answerSeconds, color: AppColors.pink),
              ],
            ]),
          ),
        ),
      ),
      // live answer text (speech result or typed)
      Positioned(
        left: 12,
        right: 12,
        bottom: 88,
        child: Card(
          color: AppColors.card.withOpacity(0.96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Icon(_listening ? Icons.hearing : Icons.edit_note,
                    size: 16,
                    color: _listening ? AppColors.pink : AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _speaking
                        ? 'Wait for the question to finish'
                        : (_listening
                        ? 'Listening. Your words appear below'
                        : (_sttReady
                        ? 'Mic paused. You can type your answer'
                        : 'Type your answer below')),
                    style:
                    const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: TextField(
                  controller: _liveCtl,
                  enabled: !_speaking,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: (v) => _base = v.trim(),
                  decoration: const InputDecoration(
                      hintText: 'Your answer', isDense: true),
                ),
              ),
            ]),
          ),
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 16,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            if (_isRecording) ...[
              const _MiRecDot(),
              const SizedBox(width: 6),
              const Text('REC', style: TextStyle(fontWeight: FontWeight.bold)),
            ] else
              const Text('Video off', style: TextStyle(color: AppColors.muted)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _speaking ? null : _repeatQuestion,
              icon: const Icon(Icons.replay),
              label: const Text('Repeat'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _skip,
              icon: const Icon(Icons.skip_next),
              label: Text(_speaking ? 'Skip' : 'Next'),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _videoCard() {
    if (_video == null) {
      return Card(
        color: AppColors.pinkSoft,
        child: ListTile(
          leading: const Icon(Icons.videocam_off, color: AppColors.pink),
          title: const Text('No video recorded'),
          subtitle: Text(_videoError ?? 'Video recording was switched off.'),
        ),
      );
    }
    final p = _player;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              'Recorded video (.$_videoExt) • ${(_videoBytes / 1048576).toStringAsFixed(1)} MB',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (p != null && p.value.isInitialized) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: AspectRatio(
                  aspectRatio: p.value.aspectRatio, child: VideoPlayer(p)),
            ),
            Align(
              child: IconButton(
                iconSize: 36,
                icon: Icon(
                    p.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                onPressed: () => setState(() {
                  p.value.isPlaying ? p.pause() : p.play();
                }),
              ),
            ),
          ] else
            const Text('Saved. (Preview unavailable on this device.)',
                style: TextStyle(color: AppColors.muted)),
        ]),
      ),
    );
  }

  Widget _stepTile({
    required MiStep step,
    required String title,
    required String doneText,
    String? message,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    final (IconData icon, Color color) = switch (step) {
      MiStep.done => (Icons.check_circle, AppColors.blue),
      MiStep.failed => (Icons.error, AppColors.pink),
      MiStep.skipped => (Icons.info_outline, AppColors.rose),
      _ => (Icons.hourglass_empty, AppColors.faint),
    };
    return ListTile(
      leading: step == MiStep.running
          ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5))
          : Icon(icon, color: color),
      title: Text(step == MiStep.done ? doneText : title),
      subtitle: message == null || message.isEmpty
          ? (step == MiStep.running
          ? const Text('Marking your answers…')
          : null)
          : Text(message, maxLines: 4, overflow: TextOverflow.ellipsis),
      trailing: (onRetry != null && step != MiStep.running)
          ? TextButton(onPressed: onRetry, child: Text(retryLabel))
          : null,
    );
  }

  Widget _statusCard() {
    return Card(
      child: Column(children: [
        _stepTile(
          step: _markStep,
          title: 'Smart marking (on-device)',
          doneText: 'Marking complete',
          message: _markStep == MiStep.done ? _overallFeedback : _markMsg,
          onRetry: _autoMark,
          retryLabel: _markStep == MiStep.done ? 'Re-mark' : 'Retry',
        ),
        const Divider(height: 1),
        _stepTile(
          step: _uploadStep,
          title: 'Save CSV + PDF + recording',
          doneText: 'Saved to device',
          message: _uploadMsg,
          onRetry: _saveAll,
          retryLabel: _uploadStep == MiStep.done ? 'Save again' : 'Save now',
        ),
      ]),
    );
  }

  Widget _resultHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.blue, AppColors.pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration:
          const BoxDecoration(color: AppColors.cardAlt, shape: BoxShape.circle),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_percent.toStringAsFixed(0),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue)),
            const Text('%',
                style: TextStyle(color: AppColors.pink, height: 0.6)),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_nameCtl.text.trim(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                'Total ${_total.toStringAsFixed(1)} / ${_maxTotal.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            Text('Grade $_grade',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            if (_aiMarked)
              const Text('Auto-marked • adjust with sliders',
                  style: TextStyle(color: Colors.white, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _reviewView() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _resultHeader(),
      const SizedBox(height: 8),
      _statusCard(),
      _videoCard(),
      const SizedBox(height: 4),
      for (var i = 0; i < _records.length; i++) _recordCard(i, _records[i]),
      const SizedBox(height: 12),
      TextField(
        controller: _emailCtl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Submit to (email)'),
      ),
      const SizedBox(height: 12),
      if (_busy) ...[
        const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(_busyMsg, textAlign: TextAlign.center),
        ),
      ],
      FilledButton.icon(
        onPressed: _busy ? null : _emailAll,
        icon: const Icon(Icons.email_outlined),
        label: const Text('Email video + PDF + CSV'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _downloadAll,
        icon: const Icon(Icons.download),
        label: const Text('Download all (PDF + CSV + video)'),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          ActionChip(
            avatar: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('PDF'),
            onPressed: _busy ? null : () => _downloadOne('pdf'),
          ),
          ActionChip(
            avatar: const Icon(Icons.table_chart, size: 18),
            label: const Text('CSV'),
            onPressed: _busy ? null : () => _downloadOne('csv'),
          ),
          ActionChip(
            avatar: const Icon(Icons.movie, size: 18),
            label: Text('Video (.${_video != null ? _videoExt : "mp4"})'),
            onPressed: _busy ? null : () => _downloadOne('video'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: (_busy ||
            _markStep == MiStep.running ||
            _uploadStep == MiStep.running)
            ? null
            : () async {
          await _player?.dispose();
          setState(() {
            _player = null;
            _phase = MiPhase.setup;
          });
        },
        child: const Text('New interview'),
      ),
    ]);
  }

  Widget _recordCard(int i, MiAnswer r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              'Q${i + 1} • ${r.question.category} • ${_fmt(r.durationSec)} answered',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(r.question.text),
          Row(children: [
            Expanded(
              child: Slider(
                value: r.score.clamp(0, 10).toDouble(),
                min: 0,
                max: 10,
                divisions: 20,
                label: r.score.toStringAsFixed(1),
                onChanged: (v) => setState(() => r.score = v),
              ),
            ),
            SizedBox(width: 36, child: Text(r.score.toStringAsFixed(1))),
          ]),
          if (r.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(r.notes,
                  style:
                  const TextStyle(color: AppColors.blueDark, fontSize: 13)),
            ),
          // editable transcript: fix any speech errors, then tap "Re-mark"
          TextFormField(
            key: ValueKey('tr_${i}_${r.transcript.hashCode}'),
            initialValue: r.transcript,
            maxLines: null,
            decoration: const InputDecoration(
                labelText: 'Your answer (editable, then tap Re-mark)',
                isDense: true),
            onChanged: (v) => r.transcript = v,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('note_${i}_${r.notes.hashCode}'),
            initialValue: r.notes,
            maxLines: null,
            decoration: const InputDecoration(
                hintText: 'Evaluator notes (optional)', isDense: true),
            onChanged: (v) => r.notes = v,
          ),
        ]),
      ),
    );
  }
}

class _MiRecDot extends StatefulWidget {
  const _MiRecDot();
  @override
  State<_MiRecDot> createState() => _MiRecDotState();
}

class _MiRecDotState extends State<_MiRecDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: const Icon(Icons.fiber_manual_record,
        color: AppColors.pink, size: 16),
  );
}

// ==========================================================================
//  MODULE: Shruthi Box
// ==========================================================================

// ==========================================================================
//  SHRUTHI BOX  (Tanpura / shruti drone, runs as a self-contained sub-app)
//  Entry point:  const ShruthiBox()
// ==========================================================================

const int _tpSr = 22050;

const List<String> _tpShrutiNames = [
  'Safed 1 (C)',
  'Kali 1 (C♯)',
  'Safed 2 (D)',
  'Kali 2 (D♯)',
  'Safed 3 (E)',
  'Safed 4 (F)',
  'Kali 3 (F♯)',
  'Safed 5 (G)',
  'Kali 4 (G♯)',
  'Safed 6 (A)',
  'Kali 5 (A♯)',
  'Safed 7 (B)',
];
const List<String> _tpFirstNames = [
  'Pa',
  'Ma',
  'Ni (shuddha)',
  'Ni (komal)',
  'Sa'
];
// Just-intonation ratios relative to the lower Sa (the 4th string).
const List<double> _tpFirstRatio = [3 / 2, 4 / 3, 15 / 8, 9 / 5, 1.0];

/// Renders one seamless tanpura cycle (strings: first, Sa, Sa, lower Sa) as a WAV.
Uint8List _renderTanpura(Map<String, dynamic> p) {
  final double sa = p['sa'];
  final double ratio = p['ratio'];
  final double cycle = p['cycle'];
  final double jv = p['jivari'];
  final int n = (cycle * _tpSr).round();
  final freqs = [sa / 2 * ratio, sa, sa * 1.0007, sa / 2];
  final offsets = [0.0, 0.22, 0.44, 0.66].map((f) => (f * n).round()).toList();
  final mix = Float64List(n);
  final tau = cycle / 3.2;
  final rng = Random(7);

  final swell = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / _tpSr;
    swell[i] = (t / 0.6) * exp(1 - t / 0.6);
  }

  for (var s = 0; s < 4; s++) {
    final f0 = freqs[s];
    final maxK = min(36, (9500 / f0).floor());
    for (var k = 1; k <= maxK; k++) {
      final w = 2 * pi * f0 * k * (1 + 0.00005 * k * k) / _tpSr;
      final amp0 = 1.0 / pow(k, 1.05);
      final bump = exp(-pow((k - 9) / 5.0, 2));
      final decay = exp(-(1 + 0.07 * k) / (tau * _tpSr));
      final ph = rng.nextDouble() * 2 * pi;
      var env = 1.0;
      for (var i = 0; i < n; i++) {
        final a = amp0 * env * (1 + jv * 4 * swell[i] * bump);
        final ramp = i < 66 ? i / 66.0 : 1.0;
        mix[(offsets[s] + i) % n] += a * ramp * sin(w * i + ph);
        env *= decay;
      }
    }
  }

  var peak = 0.0;
  for (final v in mix) {
    if (v.abs() > peak) peak = v.abs();
  }
  final double scale = peak == 0 ? 0.0 : 0.85 * 32767 / peak;

  final b = ByteData(44 + n * 2);
  void tag(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      b.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, _tpSr, Endian.little);
  b.setUint32(28, _tpSr * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    b.setInt16(44 + i * 2, (mix[i] * scale).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

class ShruthiBox extends StatefulWidget {
  const ShruthiBox({super.key});
  @override
  State<ShruthiBox> createState() => _ShruthiBoxState();
}

class _ShruthiBoxState extends State<ShruthiBox>
    with SingleTickerProviderStateMixin {
  final player = AudioPlayer();
  late final AnimationController anim;
  SharedPreferences? prefs;
  int shruti = 0, first = 0, oct = 0, gen = 0;
  double cents = 0, cycle = 6, jivari = 0.6, volume = 0.8, refA = 440;
  bool playing = false, rendering = false;
  Timer? debounce;

  double get _sa => (261.6256 *
      (refA / 440) *
      pow(2, shruti / 12) *
      pow(2, oct - 1) *
      pow(2, cents / 1200))
      .toDouble();

  @override
  void initState() {
    super.initState();
    anim = AnimationController(
        vsync: this, duration: Duration(milliseconds: (cycle * 1000).round()));
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      prefs = p;
      if (!mounted) return;
      setState(() {
        shruti = p.getInt('tp_shruti') ?? 0;
        first = p.getInt('tp_first') ?? 0;
        oct = p.getInt('tp_oct') ?? 0;
        cents = p.getDouble('tp_cents') ?? 0;
        cycle = p.getDouble('tp_cycle') ?? 6;
        jivari = p.getDouble('tp_jivari') ?? 0.6;
        volume = p.getDouble('tp_volume') ?? 0.8;
        refA = p.getDouble('tp_refA') ?? 440;
      });
    } catch (_) {}
  }

  void _save() {
    final p = prefs;
    if (p == null) return;
    p.setInt('tp_shruti', shruti);
    p.setInt('tp_first', first);
    p.setInt('tp_oct', oct);
    p.setDouble('tp_cents', cents);
    p.setDouble('tp_cycle', cycle);
    p.setDouble('tp_jivari', jivari);
    p.setDouble('tp_volume', volume);
    p.setDouble('tp_refA', refA);
  }

  void _changed() {
    _save();
    if (playing) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 350), _render);
    }
  }

  Future<void> _render() async {
    final my = ++gen;
    setState(() => rendering = true);
    try {
      final bytes = await compute(_renderTanpura, {
        'sa': _sa,
        'ratio': _tpFirstRatio[first],
        'cycle': cycle,
        'jivari': jivari,
      });
      if (!mounted || my != gen) return;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(volume);
      await player.play(BytesSource(bytes));
      anim.duration = Duration(milliseconds: (cycle * 1000).round());
      anim.repeat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play the drone: $e')));
        setState(() => playing = false);
      }
    }
    if (mounted) setState(() => rendering = false);
  }

  Future<void> _toggle() async {
    if (playing) {
      gen++;
      debounce?.cancel();
      await player.stop();
      anim.stop();
      setState(() {
        playing = false;
        rendering = false;
      });
    } else {
      setState(() => playing = true);
      await _render();
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    player.dispose();
    anim.dispose();
    super.dispose();
  }

  Widget _slider(String label, double v, double min, double max, int? div,
      ValueChanged<double> on,
      {bool rerender = true}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label),
        Slider(
          value: v,
          min: min,
          max: max,
          divisions: div,
          onChanged: on,
          onChangeEnd: (_) {
            if (rerender) _changed();
          },
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final sa = _sa;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient:
          const LinearGradient(colors: [AppColors.blue, AppColors.pink]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          const Icon(Icons.music_note, color: Colors.white, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Shruthi Box',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(
                  'Strings: ${_tpFirstNames[first]} · Sa · Sa · Sa(low)\n'
                      'Sa = ${sa.toStringAsFixed(1)} Hz, lower Sa = ${(sa / 2).toStringAsFixed(1)} Hz',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) => SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                  painter: _TpStringsPainter(
                      anim.value, cycle, playing && !rendering)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: FilledButton.icon(
          icon: rendering
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Icon(playing ? Icons.stop : Icons.play_arrow),
          label: Text(rendering
              ? 'Tuning...'
              : (playing ? 'Stop shruthi' : 'Start shruthi')),
          onPressed: _toggle,
        ),
      ),
      const SizedBox(height: 16),
      Text('Shruti (Sa)', style: Theme.of(context).textTheme.titleMedium),
      Wrap(spacing: 6, children: [
        for (var i = 0; i < 12; i++)
          ChoiceChip(
            label: Text(_tpShrutiNames[i]),
            selected: shruti == i,
            onSelected: (_) {
              setState(() => shruti = i);
              _changed();
            },
          ),
      ]),
      const SizedBox(height: 12),
      Text('First string', style: Theme.of(context).textTheme.titleMedium),
      Wrap(spacing: 6, children: [
        for (var i = 0; i < _tpFirstNames.length; i++)
          ChoiceChip(
            label: Text(_tpFirstNames[i]),
            selected: first == i,
            onSelected: (_) {
              setState(() => first = i);
              _changed();
            },
          ),
      ]),
      const SizedBox(height: 12),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Gents pitch')),
          ButtonSegment(value: 1, label: Text('Ladies pitch')),
        ],
        selected: {oct},
        onSelectionChanged: (s) {
          setState(() => oct = s.first);
          _changed();
        },
      ),
      const SizedBox(height: 8),
      _slider('Pluck cycle: ${cycle.toStringAsFixed(1)} s', cycle, 4, 9, 50,
              (v) => setState(() => cycle = v)),
      _slider('Jivari (buzz): ${(jivari * 100).round()}%', jivari, 0, 1, 20,
              (v) => setState(() => jivari = v)),
      _slider('Fine tune: ${cents.round()} cents', cents, -50, 50, 100,
              (v) => setState(() => cents = v)),
      _slider('Reference A4: ${refA.round()} Hz', refA, 430, 450, 20,
              (v) => setState(() => refA = v)),
      _slider('Volume: ${(volume * 100).round()}%', volume, 0, 1, null, (v) {
        setState(() => volume = v);
        player.setVolume(v);
      }, rerender: false),
      const SizedBox(height: 24),
    ]);
  }
}

class _TpStringsPainter extends CustomPainter {
  final double t, cycle;
  final bool active;
  _TpStringsPainter(this.t, this.cycle, this.active);
  static const plucks = [0.0, 0.22, 0.44, 0.66];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.stroke;
    for (var s = 0; s < 4; s++) {
      final y = size.height * (s + 1) / 5;
      final dt = (t - plucks[s]) % 1.0;
      final amp = active ? 16 * exp(-dt * 4.5) : 0.0;
      p.color = s.isEven ? AppColors.blue : AppColors.pink;
      p.strokeWidth = s == 3 ? 3.2 : (s == 0 ? 2.2 : 1.6);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 4) {
        final dy = amp * sin(pi * x / size.width) * sin(t * cycle * 2 * pi * 9);
        path.lineTo(x, y + dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _TpStringsPainter old) => true;
}

// ============================================================================
//  main.dart  -  AI Visa Clearance Protocol  +  Precheck Gatekeeper
//  Two bottom-bar tabs, blue & pink theme, pure Flutter (no API keys).
//  Only extra package: shared_preferences (already used in your app).
//
//  HOW TO MERGE INTO YOUR SUPER-APP
//  1. Copy everything from "// ===== PALETTE" down to the end of the file
//     into your main.dart (skip main() / VisaDemoApp / VisaHome).
//  2. Add two destinations to your bottom NavigationBar:
//        NavigationDestination(icon: Icon(Icons.verified_user_outlined),
//            selectedIcon: Icon(Icons.verified_user), label: 'Visa Clearance'),
//        NavigationDestination(icon: Icon(Icons.fact_check_outlined),
//            selectedIcon: Icon(Icons.fact_check), label: 'Gatekeeper'),
//  3. Add  const VisaClearanceTab()  and  const PrecheckGatekeeperTab()
//     to the page list at the same indexes.
//
//  NOTE: everything here is an on-device READINESS and CONSISTENCY checker.
//  It does not forensically authenticate documents and is not an official
//  embassy decision. Only genuine, unaltered documents should ever be used.
// ============================================================================

class VisaDemoApp extends StatelessWidget {
  const VisaDemoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Visa Clearance',
      theme: AppTheme.dark(),
      home: const VisaHome(),
    );
  }
}

class VisaHome extends StatefulWidget {
  const VisaHome({super.key});
  @override
  State<VisaHome> createState() => _VisaHomeState();
}

class _VisaHomeState extends State<VisaHome> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _i, children: const [
          VisaClearanceTab(),
          PrecheckGatekeeperTab(),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        indicatorColor: VP.palePink,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.verified_user_outlined),
              selectedIcon: Icon(Icons.verified_user, color: VP.pink),
              label: 'Visa Clearance'),
          NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check, color: VP.pink),
              label: 'Gatekeeper'),
        ],
      ),
    );
  }
}

// ===== PALETTE ==============================================================
class VP {
  static const blue = AppColors.blue;
  static const deepBlue = AppColors.blueDark;
  static const paleBlue = AppColors.blueSoft;
  static const pink = AppColors.pink;
  static const deepPink = AppColors.pinkDark;
  static const palePink = AppColors.pinkSoft;
  static const ink = AppColors.text;
  static const ok = AppColors.green;
  static const warn = AppColors.amber;
  static const bad = AppColors.red;
  static const gradient = LinearGradient(
    colors: [AppColors.blueDark, AppColors.pinkDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ===== SHARED CASE STATE (links the two tabs) ===============================
class VisaCase {
  VisaCase._();
  static final VisaCase I = VisaCase._();
  final ValueNotifier<String> country = ValueNotifier('USA');
  final ValueNotifier<String> visaType = ValueNotifier('Student');
  final ValueNotifier<int> docReadiness = ValueNotifier(0); // 0-100
  final ValueNotifier<int> docFailures = ValueNotifier(0);
  final ValueNotifier<int> interviewScore = ValueNotifier(0); // 0-100
  final ValueNotifier<int> answered = ValueNotifier(0);
}

const List<String> kCountries = [
  'USA',
  'UK',
  'Canada',
  'Australia',
  'Germany',
  'Schengen'
];
const List<String> kVisaTypes = ['Student', 'Tourist', 'Work', 'Business'];

// Indicative figures only - always confirm on the official embassy website.
const Map<String, double> kStudentFundsUsd = {
  'USA': 30000,
  'UK': 20000,
  'Canada': 15000,
  'Australia': 24000,
  'Germany': 11500,
  'Schengen': 8000,
};
const Map<String, double> kTypeFactor = {
  'Student': 1.0,
  'Tourist': 0.2,
  'Work': 0.4,
  'Business': 0.3,
};

List<String> docsFor(String type) {
  switch (type) {
    case 'Tourist':
      return [
        'Passport (valid)',
        'Application confirmation page',
        'Itinerary & bookings',
        'Financial proof',
        'Employment / ITR proof',
        'Photograph (as per spec)',
        'Travel insurance',
      ];
    case 'Work':
      return [
        'Passport (valid)',
        'Application confirmation page',
        'Job offer / contract',
        'Employer sponsorship / petition',
        'Degree & experience letters',
        'Financial proof',
        'Photograph (as per spec)',
      ];
    case 'Business':
      return [
        'Passport (valid)',
        'Application confirmation page',
        'Invitation letter',
        'Company registration proof',
        'Financial proof',
        'Meeting itinerary',
        'Photograph (as per spec)',
      ];
    default:
      return [
        'Passport (valid)',
        'Application confirmation page',
        'Admission / offer letter',
        'Financial proof',
        'Academic transcripts',
        'Test scores (IELTS/TOEFL/GRE)',
        'Photograph (as per spec)',
        'Fee payment receipt',
      ];
  }
}

// ===== SMALL SHARED WIDGETS =================================================
class GradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const GradientHeader(
      {super.key,
        required this.title,
        required this.subtitle,
        required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        gradient: VP.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(.2), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  const SectionCard({super.key, this.title, this.icon, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: VP.blue.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            if (icon != null) Icon(icon, size: 20, color: VP.pink),
            if (icon != null) const SizedBox(width: 8),
            Expanded(
              child: Text(title!,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: VP.deepBlue)),
            ),
          ]),
          const SizedBox(height: 10),
        ],
        child,
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

InputDecoration _dec(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  isDense: true,
  filled: true,
  fillColor: VP.paleBlue.withOpacity(.45),
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: VP.pink, width: 1.6)),
);

ButtonStyle _primaryBtn() => ElevatedButton.styleFrom(
  backgroundColor: VP.pink,
  foregroundColor: AppColors.background,
  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontWeight: FontWeight.w800),
);

String _fmtDate(DateTime? d) => d == null
    ? 'Select date'
    : '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

Color _scoreColor(num s) => s >= 75 ? VP.ok : (s >= 50 ? VP.warn : VP.bad);

// ============================================================================
//  TAB 1  -  AI VISA CLEARANCE PROTOCOL
//  (consular compliance verification + document checks + mock consular interview)
// ============================================================================
class VisaClearanceTab extends StatelessWidget {
  const VisaClearanceTab({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const GradientHeader(
          title: 'AI Visa Clearance Protocol',
          subtitle:
          'Consular compliance verification, document checks & mock visa interview',
          icon: Icons.verified_user,
        ),
        const SizedBox(height: 6),
        const TabBar(
          labelColor: VP.deepPink,
          unselectedLabelColor: VP.deepBlue,
          indicatorColor: VP.pink,
          indicatorWeight: 3,
          labelStyle: TextStyle(fontWeight: FontWeight.w800),
          tabs: [
            Tab(icon: Icon(Icons.rule_folder_outlined), text: 'Compliance'),
            Tab(
                icon: Icon(Icons.record_voice_over_outlined),
                text: 'Interview'),
          ],
        ),
        const Expanded(
          child: TabBarView(children: [_CompliancePane(), _InterviewPane()]),
        ),
      ]),
    );
  }
}

enum Lvl { pass, warn, fail }

class Check {
  final String title;
  final String detail;
  final Lvl level;
  const Check(this.title, this.detail, this.level);
}

class _CasePicker extends StatelessWidget {
  final VoidCallback onChanged;
  const _CasePicker({required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: ValueListenableBuilder<String>(
          valueListenable: VisaCase.I.country,
          builder: (_, v, __) => DropdownButtonFormField<String>(
            value: v,
            decoration: _dec('Destination'),
            items: kCountries
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (x) {
              VisaCase.I.country.value = x ?? v;
              onChanged();
            },
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ValueListenableBuilder<String>(
          valueListenable: VisaCase.I.visaType,
          builder: (_, v, __) => DropdownButtonFormField<String>(
            value: v,
            decoration: _dec('Visa type'),
            items: kVisaTypes
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (x) {
              VisaCase.I.visaType.value = x ?? v;
              onChanged();
            },
          ),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- COMPLIANCE
class _CompliancePane extends StatefulWidget {
  const _CompliancePane();
  @override
  State<_CompliancePane> createState() => _CompliancePaneState();
}

class _CompliancePaneState extends State<_CompliancePane> {
  final _passNo = TextEditingController();
  final _nameP = TextEditingController();
  final _nameA = TextEditingController();
  final _nameB = TextEditingController();
  final _funds = TextEditingController();
  DateTime? _expiry;
  DateTime? _travel;
  double _stmtMonths = 6;
  final Map<String, bool> _ready = {};
  final Map<String, bool> _hygiene = {
    'All documents are originals / true copies': false,
    'Bank statement carries bank seal / stamp': false,
    'No page has been edited or altered': false,
    'Non-English documents have certified translations': false,
  };
  List<Check> _checks = [];
  int? _score;

  @override
  void dispose() {
    _passNo.dispose();
    _nameP.dispose();
    _nameA.dispose();
    _nameB.dispose();
    _funds.dispose();
    super.dispose();
  }

  double get _required {
    final c = VisaCase.I.country.value;
    final t = VisaCase.I.visaType.value;
    return (kStudentFundsUsd[c] ?? 10000) * (kTypeFactor[t] ?? 1);
  }

  double _nameSim(String a, String b) {
    Set<String> t(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toSet();
    final x = t(a), y = t(b);
    if (x.isEmpty || y.isEmpty) return 0;
    return x.intersection(y).length / x.union(y).length;
  }

  Future<void> _pick(bool expiry) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: expiry
          ? now.add(const Duration(days: 365 * 2))
          : now.add(const Duration(days: 60)),
      firstDate: expiry ? now.subtract(const Duration(days: 365)) : now,
      lastDate: now.add(const Duration(days: 365 * 12)),
    );
    if (d != null) setState(() => expiry ? _expiry = d : _travel = d);
  }

  void _run() {
    final out = <Check>[];

    // 1. passport number format
    final pn = _passNo.text.trim().toUpperCase();
    if (pn.isEmpty) {
      out.add(const Check('Passport number', 'Not entered.', Lvl.fail));
    } else if (RegExp(r'^[A-Z][0-9]{7}$').hasMatch(pn)) {
      out.add(const Check('Passport number',
          'Format matches Indian passport pattern.', Lvl.pass));
    } else if (RegExp(r'^[A-Z0-9]{6,9}$').hasMatch(pn)) {
      out.add(const Check('Passport number',
          'Plausible format, re-check against the data page.', Lvl.warn));
    } else {
      out.add(const Check(
          'Passport number', 'Invalid format - recheck digits.', Lvl.fail));
    }

    // 2. passport validity vs travel date
    if (_expiry == null || _travel == null) {
      out.add(const Check('Passport validity',
          'Select both passport expiry and planned travel date.', Lvl.fail));
    } else {
      final months = _expiry!.difference(_travel!).inDays / 30.4;
      if (months >= 6) {
        out.add(Check(
            'Passport validity',
            '${months.toStringAsFixed(1)} months beyond travel date (6+ needed).',
            Lvl.pass));
      } else if (months >= 0) {
        out.add(Check(
            'Passport validity',
            'Only ${months.toStringAsFixed(1)} months beyond travel - renew first.',
            Lvl.warn));
      } else {
        out.add(const Check(
            'Passport validity', 'Passport expires before travel.', Lvl.fail));
      }
      final lead = _travel!.difference(DateTime.now()).inDays;
      if (lead < 15) {
        out.add(Check(
            'Processing lead time',
            'Only $lead days to travel - slots and processing may not fit.',
            Lvl.warn));
      } else {
        out.add(
            Check('Processing lead time', '$lead days to travel.', Lvl.pass));
      }
    }

    // 3. name consistency
    if (_nameP.text.trim().isEmpty) {
      out.add(const Check('Name consistency',
          'Enter the name exactly as on passport.', Lvl.fail));
    } else {
      for (final pair in [
        ['application form', _nameA.text],
        ['bank / sponsor document', _nameB.text],
      ]) {
        final s = _nameSim(_nameP.text, pair[1]);
        if (pair[1].trim().isEmpty) {
          out.add(Check('Name vs ${pair[0]}', 'Not entered.', Lvl.warn));
        } else if (s >= .99) {
          out.add(Check('Name vs ${pair[0]}', 'Exact match.', Lvl.pass));
        } else if (s >= .6) {
          out.add(Check('Name vs ${pair[0]}',
              'Partial match - fix spelling / initials mismatch.', Lvl.warn));
        } else {
          out.add(Check('Name vs ${pair[0]}', 'Names do not match.', Lvl.fail));
        }
      }
    }

    // 4. funds
    final funds = double.tryParse(_funds.text.trim()) ?? 0;
    final need = _required;
    if (funds <= 0) {
      out.add(Check(
          'Financial proof',
          'Enter funds in USD (indicative need ~\$${need.toStringAsFixed(0)}).',
          Lvl.fail));
    } else if (funds >= need) {
      out.add(Check(
          'Financial proof',
          '\$${funds.toStringAsFixed(0)} covers indicative \$${need.toStringAsFixed(0)}.',
          Lvl.pass));
    } else if (funds >= need * .75) {
      out.add(Check(
          'Financial proof',
          'Covers ${(funds / need * 100).toStringAsFixed(0)}% of indicative need.',
          Lvl.warn));
    } else {
      out.add(Check(
          'Financial proof',
          'Only ${(funds / need * 100).toStringAsFixed(0)}% of indicative need.',
          Lvl.fail));
    }

    // 5. statement history
    if (_stmtMonths >= 6) {
      out.add(Check('Statement history',
          '${_stmtMonths.round()} months of statements.', Lvl.pass));
    } else if (_stmtMonths >= 3) {
      out.add(Check(
          'Statement history',
          '${_stmtMonths.round()} months - 6 is the usual expectation.',
          Lvl.warn));
    } else {
      out.add(
          Check('Statement history', 'Too short to show stability.', Lvl.fail));
    }

    // 6. authenticity hygiene (self-attested)
    final unmet = _hygiene.entries.where((e) => !e.value).map((e) => e.key);
    if (unmet.isEmpty) {
      out.add(const Check(
          'Document hygiene', 'All integrity declarations ticked.', Lvl.pass));
    } else {
      out.add(Check('Document hygiene', 'Not confirmed: ${unmet.join('; ')}.',
          unmet.length > 1 ? Lvl.fail : Lvl.warn));
    }

    // scoring
    final docs = docsFor(VisaCase.I.visaType.value);
    final readyCount = docs.where((d) => _ready[d] == true).length;
    final readyRatio = readyCount / docs.length;
    final pts = out.fold<double>(
        0,
            (p, c) =>
        p + (c.level == Lvl.pass ? 1 : (c.level == Lvl.warn ? .5 : 0)));
    final checkRatio = pts / out.length;
    final score = ((checkRatio * .6 + readyRatio * .4) * 100).round();

    VisaCase.I.docReadiness.value = score;
    VisaCase.I.docFailures.value = out.where((c) => c.level == Lvl.fail).length;

    setState(() {
      _checks = out;
      _score = score;
    });
  }

  @override
  Widget build(BuildContext context) {
    final docs = docsFor(VisaCase.I.visaType.value);
    return ListView(padding: const EdgeInsets.all(16), children: [
      SectionCard(
        title: 'Case setup',
        icon: Icons.public,
        child: _CasePicker(onChanged: () => setState(() {})),
      ),
      SectionCard(
        title: 'Document checklist',
        icon: Icons.checklist,
        child: Column(
          children: docs
              .map((d) => CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: VP.pink,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(d, style: const TextStyle(fontSize: 13.5)),
            value: _ready[d] ?? false,
            onChanged: (v) => setState(() => _ready[d] = v ?? false),
          ))
              .toList(),
        ),
      ),
      SectionCard(
        title: 'Passport & dates',
        icon: Icons.badge_outlined,
        child: Column(children: [
          TextField(
              controller: _passNo,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('Passport number', hint: 'e.g. K1234567')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(true),
                icon: const Icon(Icons.event, size: 18),
                label: Text('Expiry: ${_fmtDate(_expiry)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(false),
                icon: const Icon(Icons.flight_takeoff, size: 18),
                label: Text('Travel: ${_fmtDate(_travel)}'),
              ),
            ),
          ]),
        ]),
      ),
      SectionCard(
        title: 'Name consistency',
        icon: Icons.compare_arrows,
        child: Column(children: [
          TextField(controller: _nameP, decoration: _dec('Name on passport')),
          const SizedBox(height: 10),
          TextField(
              controller: _nameA, decoration: _dec('Name on application form')),
          const SizedBox(height: 10),
          TextField(
              controller: _nameB,
              decoration: _dec('Name on bank / sponsor document')),
        ]),
      ),
      SectionCard(
        title: 'Financial proof',
        icon: Icons.account_balance_wallet_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _funds,
            keyboardType: TextInputType.number,
            decoration: _dec('Available funds (USD equivalent)'),
          ),
          const SizedBox(height: 6),
          Text(
              'Indicative requirement: \$${_required.toStringAsFixed(0)} (verify on the official site)',
              style: const TextStyle(fontSize: 12, color: VP.deepBlue)),
          const SizedBox(height: 8),
          Text('Statement history: ${_stmtMonths.round()} months',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _stmtMonths,
            min: 0,
            max: 12,
            divisions: 12,
            activeColor: VP.pink,
            inactiveColor: VP.paleBlue,
            onChanged: (v) => setState(() => _stmtMonths = v),
          ),
        ]),
      ),
      SectionCard(
        title: 'Document integrity declarations',
        icon: Icons.gpp_good_outlined,
        child: Column(
          children: _hygiene.keys
              .map((k) => SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: VP.pink,
            title: Text(k, style: const TextStyle(fontSize: 13)),
            value: _hygiene[k]!,
            onChanged: (v) => setState(() => _hygiene[k] = v),
          ))
              .toList(),
        ),
      ),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: _primaryBtn(),
          onPressed: _run,
          icon: const Icon(Icons.shield_outlined),
          label: const Text('RUN COMPLIANCE VERIFICATION'),
        ),
      ),
      const SizedBox(height: 14),
      if (_score != null) _result(),
      const SizedBox(height: 24),
    ]);
  }

  Widget _result() {
    final s = _score!;
    return SectionCard(
      title: 'Verification report',
      icon: Icons.assignment_turned_in_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 84,
                height: 84,
                child: CircularProgressIndicator(
                    value: s / 100,
                    strokeWidth: 9,
                    backgroundColor: VP.paleBlue,
                    color: _scoreColor(s)),
              ),
              Text('$s%',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: VP.deepBlue)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  s >= 75
                      ? 'Compliance-ready'
                      : (s >= 50 ? 'Needs corrections' : 'Not ready yet'),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _scoreColor(s))),
              const SizedBox(height: 4),
              const Text(
                  'Score is shared with the Gatekeeper tab automatically.',
                  style: TextStyle(fontSize: 12, color: VP.ink)),
            ]),
          ),
        ]),
        const Divider(height: 24),
        ..._checks.map((c) {
          final col = c.level == Lvl.pass
              ? VP.ok
              : (c.level == Lvl.warn ? VP.warn : VP.bad);
          final ic = c.level == Lvl.pass
              ? Icons.check_circle
              : (c.level == Lvl.warn
              ? Icons.warning_amber_rounded
              : Icons.cancel);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(ic, color: col, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text(c.detail,
                          style:
                          const TextStyle(fontSize: 12.5, color: VP.ink)),
                    ]),
              ),
            ]),
          );
        }),
        const SizedBox(height: 6),
        const Text(
            'This is a consistency and readiness check on what you entered. It cannot authenticate documents; embassies verify originals themselves.',
            style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- INTERVIEW
class Q {
  final String q;
  final List<String> keys;
  final String tip;
  const Q(this.q, this.keys, this.tip);
}

class AnswerScore {
  final int total;
  final List<String> notes;
  const AnswerScore(this.total, this.notes);
}

List<Q> questionsFor(String type, String country) {
  const funding = Q(
      'Who is sponsoring your trip and how will it be funded?',
      [
        'sponsor',
        'father',
        'mother',
        'parents',
        'savings',
        'loan',
        'scholarship',
        'salary',
        'bank',
        'funds',
        'income'
      ],
      'Name the sponsor, the amount and the document that proves it.');
  const ties = Q(
      'What ties do you have to your home country?',
      [
        'family',
        'job',
        'property',
        'business',
        'return',
        'parents',
        'career',
        'studies',
        'home',
        'employer'
      ],
      'Give concrete ties: family, job, property, ongoing commitments.');
  switch (type) {
    case 'Tourist':
      return [
        Q(
            'What is the purpose of your visit to $country?',
            [
              'tour',
              'visit',
              'holiday',
              'sightseeing',
              'travel',
              'friends',
              'trip'
            ],
            'State one clear purpose and the places you will see.'),
        const Q(
            'How long will you stay and where?',
            ['days', 'week', 'itinerary', 'hotel', 'city', 'cities', 'return'],
            'Mention exact dates, cities and bookings.'),
        const Q(
            'Have you travelled abroad before?',
            [
              'visited',
              'travelled',
              'traveled',
              'countries',
              'previous',
              'before',
              'visa'
            ],
            'List countries and years; honesty matters.'),
        funding,
        ties,
        const Q(
            'What do you do for a living?',
            ['work', 'company', 'role', 'employed', 'business', 'job', 'years'],
            'Employer, role, tenure - keep it consistent with your papers.'),
      ];
    case 'Work':
      return [
        Q(
            'Why do you want to work in $country?',
            [
              'career',
              'role',
              'skills',
              'opportunity',
              'project',
              'experience',
              'growth'
            ],
            'Link the role to your skills and career plan.'),
        const Q(
            'Describe your job role and employer.',
            [
              'role',
              'team',
              'skills',
              'employer',
              'company',
              'project',
              'responsibilities'
            ],
            'Role, team, tools, reporting line.'),
        const Q(
            'How did you get this offer?',
            [
              'interview',
              'recruiter',
              'applied',
              'offer',
              'contract',
              'rounds',
              'referral'
            ],
            'Explain the real hiring process in order.'),
        const Q(
            'What is your salary and contract length?',
            [
              'salary',
              'package',
              'year',
              'years',
              'contract',
              'months',
              'annual'
            ],
            'State numbers that match the offer letter.'),
        ties,
        const Q(
            'What are your plans after the contract ends?',
            ['return', 'extend', 'career', 'home', 'plan', 'india', 'future'],
            'Show a credible, honest plan.'),
      ];
    case 'Business':
      return [
        Q(
            'What is the purpose of your business trip to $country?',
            [
              'meeting',
              'client',
              'conference',
              'company',
              'contract',
              'partner',
              'business'
            ],
            'Name the event / counterpart and the agenda.'),
        const Q(
            'Who invited you and what is your relationship?',
            [
              'invited',
              'invitation',
              'partner',
              'client',
              'vendor',
              'company',
              'contract'
            ],
            'Name the host company and the history.'),
        const Q(
            'Who bears the cost of the trip?',
            ['company', 'sponsor', 'self', 'funds', 'bank', 'expenses', 'paid'],
            'Be exact about who pays what.'),
        const Q(
            'How long will you stay and what is your schedule?',
            [
              'days',
              'week',
              'schedule',
              'meetings',
              'hotel',
              'return',
              'itinerary'
            ],
            'Dates and meetings should match your invitation.'),
        ties,
        const Q(
            'What does your company do?',
            [
              'products',
              'services',
              'turnover',
              'employees',
              'founded',
              'industry',
              'customers'
            ],
            'Short, factual company summary.'),
      ];
    default:
      return [
        Q(
            'Why do you want to study in $country?',
            [
              'course',
              'program',
              'university',
              'career',
              'research',
              'quality',
              'curriculum',
              'faculty'
            ],
            'Tie the country to your course and goals.'),
        const Q(
            'Why this university and this course?',
            [
              'ranking',
              'faculty',
              'curriculum',
              'research',
              'program',
              'lab',
              'scholarship',
              'modules'
            ],
            'Mention specific modules, labs or professors.'),
        const Q(
            'What did you study before and what scores did you get?',
            [
              'bachelor',
              'degree',
              'cgpa',
              'gpa',
              'percent',
              'ielts',
              'toefl',
              'gre',
              'score'
            ],
            'Quote your real marks and test scores.'),
        funding,
        ties,
        const Q(
            'What will you do after graduation?',
            [
              'return',
              'india',
              'career',
              'job',
              'company',
              'plan',
              'industry',
              'startup'
            ],
            'Show intent and a concrete plan back home.'),
      ];
  }
}

AnswerScore scoreAnswer(Q q, String raw) {
  final text = raw.trim().toLowerCase();
  if (text.isEmpty) return const AnswerScore(0, ['Not answered.']);
  final words =
  RegExp(r"[a-z0-9']+").allMatches(text).map((m) => m.group(0)!).toList();
  final n = words.length;
  final notes = <String>[];

  // relevance (40)
  final hits = q.keys.where((k) => text.contains(k)).length;
  final rel = (hits / 3).clamp(0.0, 1.0) * 40;
  if (hits < 2) notes.add('Cover the question more directly. ${q.tip}');

  // length (25)
  double len;
  if (n < 8) {
    len = 3;
    notes.add('Too short - officers expect 2-4 clear sentences.');
  } else if (n < 20) {
    len = 3 + (n - 8) / 12 * 17;
    notes.add('Add one more concrete detail.');
  } else if (n <= 90) {
    len = 25;
  } else {
    len = 25 - ((n - 90) / 10).clamp(0.0, 15.0);
    notes.add('Too long - keep answers crisp.');
  }

  // specificity (20)
  double spec = 0;
  if (RegExp(r'\d').hasMatch(text)) spec += 10;
  final proper = RegExp(r'\b[A-Z][a-z]{2,}').allMatches(raw).length;
  spec += (proper / 2).clamp(0.0, 1.0) * 10;
  if (spec < 10) notes.add('Use specifics: numbers, names, dates.');

  // confidence (15)
  const hedges = [
    'maybe',
    'i think',
    'not sure',
    'probably',
    'um ',
    'i guess',
    'kind of',
    'sort of',
    'i hope',
    'might'
  ];
  final hedgeHits = hedges.where((h) => text.contains(h)).length;
  final conf = (15 - hedgeHits * 5).clamp(0, 15).toDouble();
  if (hedgeHits > 0)
    notes.add('Avoid hedging words; sound certain and honest.');

  final total = (rel + len + spec + conf).round().clamp(0, 100);
  if (notes.isEmpty) notes.add('Clear, specific and confident.');
  return AnswerScore(total, notes);
}

class _InterviewPane extends StatefulWidget {
  const _InterviewPane();
  @override
  State<_InterviewPane> createState() => _InterviewPaneState();
}

class _InterviewPaneState extends State<_InterviewPane> {
  final Map<String, TextEditingController> _c = {};
  final Map<String, AnswerScore> _s = {};
  int? _overall;

  TextEditingController _ctl(String key) =>
      _c.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _score(List<Q> qs) {
    int sum = 0, count = 0;
    final m = <String, AnswerScore>{};
    for (final q in qs) {
      final sc = scoreAnswer(q, _ctl(q.q).text);
      m[q.q] = sc;
      if (_ctl(q.q).text.trim().isNotEmpty) {
        sum += sc.total;
        count++;
      }
    }
    final avg = count == 0 ? 0 : (sum / count).round();
    // unanswered questions pull the readiness figure down
    final overall = count == 0 ? 0 : (sum / qs.length).round();
    VisaCase.I.interviewScore.value = overall;
    VisaCase.I.answered.value = count;
    setState(() {
      _s
        ..clear()
        ..addAll(m);
      _overall = overall;
    });
    if (count < qs.length && avg > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${qs.length - count} question(s) unanswered - they count as zero.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final qs =
    questionsFor(VisaCase.I.visaType.value, VisaCase.I.country.value);
    return ListView(padding: const EdgeInsets.all(16), children: [
      SectionCard(
        title: 'Interview setup',
        icon: Icons.tune,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CasePicker(
              onChanged: () => setState(() {
                _s.clear();
                _overall = null;
              })),
          const SizedBox(height: 10),
          const Text(
              'Answer in your own words as you would to the officer. Scoring runs fully on-device: relevance, length, specificity and confidence.',
              style: TextStyle(fontSize: 12, color: VP.ink)),
        ]),
      ),
      ...List.generate(qs.length, (i) {
        final q = qs[i];
        final sc = _s[q.q];
        return SectionCard(
          title: 'Q${i + 1}. ${q.q}',
          icon: Icons.help_outline,
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _ctl(q.q),
              minLines: 3,
              maxLines: 6,
              decoration: _dec('Your answer', hint: q.tip),
            ),
            if (sc != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Pill('${sc.total}/100', _scoreColor(sc.total)),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: sc.total / 100,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(6),
                    backgroundColor: VP.paleBlue,
                    color: _scoreColor(sc.total),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              ...sc.notes.map((n) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: VP.pink)),
                      Expanded(
                          child: Text(n,
                              style: const TextStyle(fontSize: 12.5))),
                    ]),
              )),
            ],
          ]),
        );
      }),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: _primaryBtn(),
          onPressed: () => _score(qs),
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('SCORE MY INTERVIEW'),
        ),
      ),
      const SizedBox(height: 14),
      if (_overall != null)
        SectionCard(
          title: 'Interview readiness',
          icon: Icons.emoji_events_outlined,
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$_overall',
                  style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: _scoreColor(_overall!))),
              const Text(' / 100',
                  style: TextStyle(fontSize: 16, color: VP.deepBlue)),
              const Spacer(),
              Pill(
                  _overall! >= 75
                      ? 'INTERVIEW READY'
                      : (_overall! >= 55 ? 'NEEDS POLISH' : 'PRACTISE MORE'),
                  _scoreColor(_overall!)),
            ]),
            const SizedBox(height: 8),
            const Text(
                'Be truthful, consistent with your documents, and never memorise scripts - officers notice rehearsed answers.',
                style: TextStyle(fontSize: 12.5)),
          ]),
        ),
      const SizedBox(height: 24),
    ]);
  }
}

// ============================================================================
//  TAB 2  -  PRECHECK GATEKEEPER ASSESSMENT
//  (interview-initial pre-screening clearance pipeline)
// ============================================================================
class StageRes {
  final String name;
  final IconData icon;
  final double weight;
  final double score;
  final String note;
  const StageRes(this.name, this.icon, this.weight, this.score, this.note);
}

class PrecheckGatekeeperTab extends StatefulWidget {
  const PrecheckGatekeeperTab({super.key});
  @override
  State<PrecheckGatekeeperTab> createState() => _PrecheckGatekeeperTabState();
}

class _PrecheckGatekeeperTabState extends State<PrecheckGatekeeperTab> {
  double _passMonths = 12;
  bool _nameOk = true;
  String _refusal = 'None';
  bool _attested = false;
  double _fundsPct = 80;
  bool _sponsor = false;
  bool _source = false;
  double _ties = 5;
  double _plan = 5;
  int _trips = 0;

  bool _ran = false;
  List<StageRes> _stages = [];
  List<String> _hard = [];
  double _total = 0;
  String _outcome = '';
  String? _last;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('visa_gate_last');
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        if (mounted) {
          setState(() =>
          _last = '${m['outcome']} - ${m['score']}/100 on ${m['date']}');
        }
      }
    } catch (_) {}
  }

  Future<void> _saveLast() async {
    try {
      final p = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await p.setString(
          'visa_gate_last',
          jsonEncode({
            'outcome': _outcome,
            'score': _total.round(),
            'date': _fmtDate(now),
          }));
    } catch (_) {}
  }

  void _run() {
    final docs = VisaCase.I.docReadiness.value.toDouble();
    final docFails = VisaCase.I.docFailures.value;
    final iv = VisaCase.I.interviewScore.value.toDouble();
    final ivN = VisaCase.I.answered.value;
    final hard = <String>[];

    // Stage 1 - identity & eligibility (20)
    final passScore =
    _passMonths >= 12 ? 100.0 : (_passMonths >= 6 ? 80.0 : 20.0);
    final refusalScore =
    _refusal == 'None' ? 100.0 : (_refusal == 'Disclosed' ? 70.0 : 0.0);
    final s1 = passScore * .5 + (_nameOk ? 25 : 0) + refusalScore * .25;
    if (_passMonths < 6) hard.add('Passport validity is under 6 months.');
    if (_refusal == 'Undisclosed') {
      hard.add(
          'A previous refusal is not being disclosed - this risks a misrepresentation ban.');
    }
    if (!_nameOk) hard.add('Names differ across identity documents.');

    // Stage 2 - documents (20)
    final s2 = (docs * .8 + (_attested ? 20 : 0)).clamp(0.0, 100.0);
    if (docFails >= 3) {
      hard.add('Compliance tab shows $docFails failed checks.');
    }

    // Stage 3 - financial (25)
    final s3 = (_fundsPct.clamp(0, 100) * .7 +
        (_sponsor ? 15 : 0) +
        (_source ? 15 : 0))
        .toDouble();
    if (_fundsPct < 60)
      hard.add('Funds cover less than 60% of the requirement.');

    // Stage 4 - ties & intent (20)
    final s4 = _ties * 10 * .5 +
        _plan * 10 * .35 +
        (_trips.clamp(0, 3) / 3 * 100) * .15;

    // Stage 5 - interview readiness (15)
    final s5 = iv;

    final stages = [
      StageRes('Identity', Icons.badge, .20, s1.clamp(0, 100),
          'Passport validity, name integrity, refusal history'),
      StageRes('Documents', Icons.folder_copy, .20, s2,
          'Checklist completion and compliance report'),
      StageRes('Finance', Icons.payments, .25, s3,
          'Funds coverage, sponsor proof, source of funds'),
      StageRes('Ties', Icons.home_work, .20, s4.clamp(0, 100),
          'Home ties, return plan, travel history'),
      StageRes('Interview', Icons.record_voice_over, .15, s5,
          ivN == 0 ? 'No mock interview taken yet' : '$ivN answers scored'),
    ];
    final total = stages.fold<double>(0, (p, s) => p + s.score * s.weight);
    final outcome = hard.isNotEmpty
        ? 'HOLD'
        : (total >= 78 ? 'CLEARED' : (total >= 60 ? 'CONDITIONAL' : 'HOLD'));

    setState(() {
      _stages = stages;
      _hard = hard;
      _total = total;
      _outcome = outcome;
      _ran = true;
    });
    _saveLast();
    _loadLast();
  }

  Color get _outColor => _outcome == 'CLEARED'
      ? VP.ok
      : (_outcome == 'CONDITIONAL' ? VP.warn : VP.bad);

  String _advice(StageRes s) {
    switch (s.name) {
      case 'Identity':
        return 'Renew the passport if under 12 months, align name spellings and declare any past refusal honestly.';
      case 'Documents':
        return 'Finish the checklist and rerun the Compliance verification in the first tab.';
      case 'Finance':
        return 'Build funds to the full requirement, add sponsor affidavits and explain the source of funds.';
      case 'Ties':
        return 'Prepare evidence of family, employment or property ties and a clear return plan.';
      default:
        return 'Take the mock interview in the first tab and aim for 75+.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const GradientHeader(
        title: 'Precheck Gatekeeper',
        subtitle: 'Interview-initial pre-screening clearance pipeline',
        icon: Icons.fact_check,
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _pipeline(),
          if (_last != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                const Icon(Icons.history, size: 16, color: VP.deepBlue),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('Last run: $_last',
                        style:
                        const TextStyle(fontSize: 12, color: VP.deepBlue))),
              ]),
            ),
          _linked(),
          _stage1(),
          _stage2(),
          _stage3(),
          _stage4(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: _primaryBtn(),
              onPressed: _run,
              icon: const Icon(Icons.lock_open),
              label: const Text('RUN GATEKEEPER'),
            ),
          ),
          const SizedBox(height: 14),
          if (_ran) _verdict(),
          const SizedBox(height: 24),
        ]),
      ),
    ]);
  }

  Widget _pipeline() {
    const names = ['Identity', 'Documents', 'Finance', 'Ties', 'Interview'];
    const icons = [
      Icons.badge,
      Icons.folder_copy,
      Icons.payments,
      Icons.home_work,
      Icons.record_voice_over
    ];
    final children = <Widget>[];
    for (int i = 0; i < names.length; i++) {
      final Color col =
      !_ran ? AppColors.faint : _scoreColor(_stages[i].score);
      children.add(Column(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: col.withOpacity(.15),
            border: Border.all(color: col, width: 2),
          ),
          child: Icon(icons[i], color: col, size: 21),
        ),
        const SizedBox(height: 4),
        Text(names[i],
            style:
            const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
      ]));
      if (i < names.length - 1) {
        children.add(Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                gradient: VP.gradient, borderRadius: BorderRadius.circular(3)),
          ),
        ));
      }
    }
    return SectionCard(
      title: 'Clearance pipeline',
      icon: Icons.account_tree_outlined,
      child:
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: children),
    );
  }

  Widget _linked() {
    return SectionCard(
      title: 'Linked from Visa Clearance tab',
      icon: Icons.link,
      child: Row(children: [
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: VisaCase.I.docReadiness,
            builder: (_, v, __) => _stat('Documents', '$v%', _scoreColor(v)),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: VisaCase.I.interviewScore,
            builder: (_, v, __) => _stat('Interview', '$v/100', _scoreColor(v)),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: VisaCase.I.docFailures,
            builder: (_, v, __) =>
                _stat('Failed checks', '$v', v == 0 ? VP.ok : VP.bad),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(children: [
    Text(v,
        style:
        TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
    Text(l, style: const TextStyle(fontSize: 11.5, color: VP.ink)),
  ]);

  Widget _slider(String label, double v, double min, double max, int div,
      String suffix, ValueChanged<double> cb) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: ${v.round()}$suffix',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      Slider(
        value: v,
        min: min,
        max: max,
        divisions: div,
        activeColor: VP.pink,
        inactiveColor: VP.paleBlue,
        onChanged: cb,
      ),
    ]);
  }

  Widget _stage1() => SectionCard(
    title: '1 - Identity & eligibility',
    icon: Icons.badge_outlined,
    child: Column(children: [
      _slider('Passport validity left', _passMonths, 0, 60, 60, ' months',
              (v) => setState(() => _passMonths = v)),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeColor: VP.pink,
        title: const Text('Name identical on all documents',
            style: TextStyle(fontSize: 13)),
        value: _nameOk,
        onChanged: (v) => setState(() => _nameOk = v),
      ),
      DropdownButtonFormField<String>(
        value: _refusal,
        decoration: _dec('Previous visa refusal'),
        items: const ['None', 'Disclosed', 'Undisclosed']
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => _refusal = v ?? 'None'),
      ),
    ]),
  );

  Widget _stage2() => SectionCard(
    title: '2 - Documents',
    icon: Icons.folder_open,
    child: SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: VP.pink,
      title: const Text('Copies attested / translations certified',
          style: TextStyle(fontSize: 13)),
      subtitle: const Text('Readiness score comes from the Compliance tab.',
          style: TextStyle(fontSize: 11.5)),
      value: _attested,
      onChanged: (v) => setState(() => _attested = v),
    ),
  );

  Widget _stage3() => SectionCard(
    title: '3 - Financial capacity',
    icon: Icons.account_balance,
    child: Column(children: [
      _slider('Funds vs requirement', _fundsPct, 0, 150, 30, '%',
              (v) => setState(() => _fundsPct = v)),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeColor: VP.pink,
        title: const Text('Sponsor affidavit & proof ready',
            style: TextStyle(fontSize: 13)),
        value: _sponsor,
        onChanged: (v) => setState(() => _sponsor = v),
      ),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeColor: VP.pink,
        title: const Text('Source of funds can be explained',
            style: TextStyle(fontSize: 13)),
        value: _source,
        onChanged: (v) => setState(() => _source = v),
      ),
    ]),
  );

  Widget _stage4() => SectionCard(
    title: '4 - Ties & intent',
    icon: Icons.home_outlined,
    child: Column(children: [
      _slider('Strength of home ties', _ties, 0, 10, 10, '/10',
              (v) => setState(() => _ties = v)),
      _slider('Clarity of return / career plan', _plan, 0, 10, 10, '/10',
              (v) => setState(() => _plan = v)),
      Row(children: [
        const Expanded(
            child: Text('Countries travelled before',
                style:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        IconButton(
            onPressed: () =>
                setState(() => _trips = (_trips - 1).clamp(0, 20)),
            icon: const Icon(Icons.remove_circle_outline, color: VP.blue)),
        Text('$_trips',
            style:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        IconButton(
            onPressed: () =>
                setState(() => _trips = (_trips + 1).clamp(0, 20)),
            icon: const Icon(Icons.add_circle_outline, color: VP.pink)),
      ]),
    ]),
  );

  Widget _verdict() {
    final weak = _stages.where((s) => s.score < 75).toList();
    return SectionCard(
      title: 'Gatekeeper decision',
      icon: Icons.gavel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: _total / 100,
                  strokeWidth: 10,
                  backgroundColor: VP.paleBlue,
                  color: _outColor,
                ),
              ),
              Text(_total.round().toString(),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: VP.deepBlue)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Pill(_outcome, _outColor),
              const SizedBox(height: 8),
              Text(
                _outcome == 'CLEARED'
                    ? 'Proceed to the visa interview with confidence.'
                    : (_outcome == 'CONDITIONAL'
                    ? 'Close the gaps below before booking your slot.'
                    : 'Pause: resolve blockers before applying.'),
                style: const TextStyle(fontSize: 13),
              ),
            ]),
          ),
        ]),
        if (_hard.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: VP.bad.withOpacity(.08),
                borderRadius: BorderRadius.circular(12)),
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Hard stops',
                  style: TextStyle(fontWeight: FontWeight.w800, color: VP.bad)),
              ..._hard.map((h) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block, size: 16, color: VP.bad),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(h,
                              style: const TextStyle(fontSize: 12.5))),
                    ]),
              )),
            ]),
          ),
        ],
        const Divider(height: 26),
        ..._stages.map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(s.icon, size: 18, color: VP.blue),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                          '${s.name}  (${(s.weight * 100).round()}%)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13))),
                  Text('${s.score.round()}',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _scoreColor(s.score))),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (s.score / 100).clamp(0.0, 1.0),
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: VP.paleBlue,
                  color: _scoreColor(s.score),
                ),
                const SizedBox(height: 3),
                Text(s.note,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.muted)),
              ]),
        )),
        if (weak.isNotEmpty) ...[
          const Divider(height: 26),
          const Text('Next actions',
              style:
              TextStyle(fontWeight: FontWeight.w800, color: VP.deepPink)),
          ...weak.map((s) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right, color: VP.pink),
                  Expanded(
                      child: Text('${s.name}: ${_advice(s)}',
                          style: const TextStyle(fontSize: 12.5))),
                ]),
          )),
        ],
        const SizedBox(height: 10),
        const Text(
            'Indicative pre-screen only. Final decisions rest with the consular officer.',
            style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}

// ============================================================================
// MERGED MODULES: Peer Resolution Board + NLP Doubt Buster
// Original Tuition AI ML Super-App source above is preserved.
// ============================================================================


void peerResolutionStandaloneMain() {
  runApp(const PeerResolutionApp());
}

// ============================================================
// APP COLORS AND THEME
// ============================================================

class PeerBoardColors {
  static const Color pink = AppColors.pink;
  static const Color lightPink = AppColors.pinkSoft;
  static const Color blue = AppColors.blue;
  static const Color lightBlue = AppColors.blueSoft;
  static const Color background = AppColors.background;
  static const Color text = AppColors.text;
  static const Color muted = AppColors.muted;
  static const Color border = AppColors.line;
  static const Color green = AppColors.green;
}

class PeerResolutionApp extends StatelessWidget {
  const PeerResolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peer Resolution & Doubt Buster',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const MainNavigationPage(),
    );
  }
}

// ============================================================
// DATA MODEL FOR PEER RESOLUTION BOARD
// ============================================================

class ResolutionPost {
  ResolutionPost({
    required this.title,
    required this.description,
    required this.author,
    required this.email,
    required this.category,
    required this.createdAt,
    List<String>? solutions,
  }) : solutions = solutions ?? [];

  final String title;
  final String description;
  final String author;
  final String email;
  final String category;
  final DateTime createdAt;
  final List<String> solutions;
}

// ============================================================
// MAIN NAVIGATION
// ============================================================

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() =>
      _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int selectedIndex = 0;

  late final List<ResolutionPost> posts;

  @override
  void initState() {
    super.initState();

    posts = [
      ResolutionPost(
        title: 'How can I improve my study schedule?',
        description:
        'I have several subjects to prepare for. '
            'How can I manage my time effectively?',
        author: 'Ananya',
        email: 'ananya.peer@gmail.com',
        category: 'Study Skills',
        createdAt: DateTime.now().subtract(
          const Duration(hours: 2),
        ),
        solutions: [
          'Try the Pomodoro technique: 25 minutes of study '
              'followed by a 5-minute break.',
        ],
      ),
      ResolutionPost(
        title: 'Understanding a difficult programming concept',
        description:
        'I find it difficult to understand how functions '
            'and parameters work in programming.',
        author: 'Rahul',
        email: 'rahul.peer@gmail.com',
        category: 'Programming',
        createdAt: DateTime.now().subtract(
          const Duration(hours: 5),
        ),
        solutions: [
          'Start with a simple function and experiment '
              'with different input values.',
        ],
      ),
      ResolutionPost(
        title: 'Tips for group discussion preparation',
        description:
        'How can I communicate my ideas clearly in a '
            'group discussion?',
        author: 'Priya',
        email: 'priya.peer@gmail.com',
        category: 'Communication',
        createdAt: DateTime.now().subtract(
          const Duration(days: 1),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: [
            PeerResolutionBoard(
              posts: posts,
              onPostsChanged: () {
                setState(() {});
              },
            ),
            const DoubtBusterTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: AppColors.surface,
        indicatorColor: PeerBoardColors.lightBlue,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(
              Icons.people,
              color: PeerBoardColors.blue,
            ),
            label: 'Peer Board',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(
              Icons.smart_toy,
              color: PeerBoardColors.pink,
            ),
            label: 'Doubt Buster',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1: PEER-TO-PEER RESOLUTION BOARD
// ============================================================

class PeerResolutionBoard extends StatefulWidget {
  const PeerResolutionBoard({
    super.key,
    required this.posts,
    required this.onPostsChanged,
  });

  final List<ResolutionPost> posts;
  final VoidCallback onPostsChanged;

  @override
  State<PeerResolutionBoard> createState() =>
      _PeerResolutionBoardState();
}

class _PeerResolutionBoardState
    extends State<PeerResolutionBoard> {
  String selectedCategory = 'All';

  final List<String> categories = const [
    'All',
    'Study Skills',
    'Programming',
    'Communication',
    'Career',
    'Other',
  ];

  List<ResolutionPost> get filteredPosts {
    if (selectedCategory == 'All') {
      return widget.posts;
    }

    return widget.posts
        .where((post) => post.category == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = filteredPosts;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Peer Resolution',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add a problem',
            onPressed: _showAddPostDialog,
            icon: const Icon(
              Icons.add_circle_outline,
              color: PeerBoardColors.pink,
              size: 28,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHero(),
          _buildCategorySelector(),
          Expanded(
            child: visiblePosts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                24,
              ),
              itemCount: visiblePosts.length,
              itemBuilder: (context, index) {
                return _buildPostCard(
                  visiblePosts[index],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: PeerBoardColors.pink,
        foregroundColor: AppColors.background,
        onPressed: _showAddPostDialog,
        icon: const Icon(Icons.add),
        label: const Text('Post a Problem'),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            PeerBoardColors.lightBlue,
            PeerBoardColors.lightPink,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.handshake_outlined,
            size: 36,
            color: PeerBoardColors.blue,
          ),
          SizedBox(height: 12),
          Text(
            'Solve it together.',
            style: TextStyle(
              color: PeerBoardColors.text,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Share a challenge, exchange ideas, '
                'and learn from your peers.',
            style: TextStyle(
              color: PeerBoardColors.muted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            selectedColor: PeerBoardColors.lightBlue,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected
                  ? PeerBoardColors.blue
                  : PeerBoardColors.border,
            ),
            labelStyle: TextStyle(
              color: selected
                  ? PeerBoardColors.blue
                  : PeerBoardColors.muted,
              fontWeight: selected
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            onSelected: (_) {
              setState(() {
                selectedCategory = category;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildPostCard(ResolutionPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PeerBoardColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: PeerBoardColors.lightPink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: PeerBoardColors.pink,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: PeerBoardColors.text,
                        ),
                      ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(
                          color: PeerBoardColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _categoryBadge(post.category),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: PeerBoardColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.description,
              style: const TextStyle(
                color: PeerBoardColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: PeerBoardColors.blue,
                  size: 19,
                ),
                const SizedBox(width: 6),
                Text(
                  '${post.solutions.length} solution(s)',
                  style: const TextStyle(
                    color: PeerBoardColors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (post.solutions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: PeerBoardColors.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: post.solutions.map((solution) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 6,
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: PeerBoardColors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              solution,
                              style: const TextStyle(
                                color: PeerBoardColors.text,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSolutionDialog(post),
                  icon: const Icon(
                    Icons.tips_and_updates_outlined,
                  ),
                  label: const Text('Add Solution'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: PeerBoardColors.blue,
                    foregroundColor: AppColors.background,
                  ),
                  onPressed: () => _showPeerEmailDialog(post),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Email Peer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: PeerBoardColors.lightPink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: PeerBoardColors.pink,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              color: PeerBoardColors.blue,
              size: 55,
            ),
            SizedBox(height: 12),
            Text(
              'No problems in this category',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Post a problem and start a conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PeerBoardColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // ADD NEW PROBLEM
  // ----------------------------------------------------------

  Future<void> _showAddPostDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final authorController = TextEditingController();
    final emailController = TextEditingController();

    String category = 'Study Skills';

    final result = await showDialog<ResolutionPost>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Post a Problem'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Problem title',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Describe the problem',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: authorController,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Your Gmail address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: const [
                        'Study Skills',
                        'Programming',
                        'Communication',
                        'Career',
                        'Other',
                      ].map((item) {
                        return DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            category = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final title =
                    titleController.text.trim();
                    final description =
                    descriptionController.text.trim();
                    final author =
                    authorController.text.trim();
                    final email =
                    emailController.text.trim();

                    if (title.isEmpty ||
                        description.isEmpty ||
                        author.isEmpty ||
                        !_validEmail(email)) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter all details and a valid email.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      ResolutionPost(
                        title: title,
                        description: description,
                        author: author,
                        email: email,
                        category: category,
                        createdAt: DateTime.now(),
                      ),
                    );
                  },
                  child: const Text('Publish'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    authorController.dispose();
    emailController.dispose();

    if (result != null && mounted) {
      setState(() {
        widget.posts.insert(0, result);
      });

      widget.onPostsChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your problem has been published.'),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // ADD A SOLUTION
  // ----------------------------------------------------------

  Future<void> _showSolutionDialog(
      ResolutionPost post,
      ) async {
    final controller = TextEditingController();

    final solution = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Share a Solution'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write a helpful suggestion...',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();

                if (text.isNotEmpty) {
                  Navigator.pop(dialogContext, text);
                }
              },
              child: const Text('Submit Solution'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (solution != null && mounted) {
      setState(() {
        post.solutions.add(solution);
      });

      widget.onPostsChanged();
    }
  }

  // ----------------------------------------------------------
  // EMAIL A PEER
  // ----------------------------------------------------------

  Future<void> _showPeerEmailDialog(
      ResolutionPost post,
      ) async {
    final controller = TextEditingController(
      text: post.email,
    );

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Email Your Peer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm the recipient address. '
                    'Gmail will open with a prepared message.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Recipient email',
                  prefixIcon: Icon(
                    Icons.alternate_email,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (_validEmail(
                  controller.text.trim(),
                )) {
                  Navigator.pop(dialogContext, true);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Gmail'),
            ),
          ],
        );
      },
    );

    final recipient = controller.text.trim();
    controller.dispose();

    if (shouldContinue == true && mounted) {
      await openGmailCompose(
        recipient: recipient,
        subject: 'Peer Resolution: ${post.title}',
        body: 'Hello ${post.author},\n\n'
            'I would like to discuss your problem:\n'
            '${post.title}\n\n'
            '${post.description}\n\n'
            'My response:\n\n'
            'Regards',
      );
    }
  }
}

// ============================================================
// TAB 2: NLP DOUBT BUSTER CHATBOT
// ============================================================

class DoubtBusterChatMessage {
  DoubtBusterChatMessage({
    required this.text,
    required this.isBot,
    this.isEmailAction = false,
  });

  final String text;
  final bool isBot;
  final bool isEmailAction;
}

class StandardQuestion {
  const StandardQuestion({
    required this.question,
    required this.answer,
    required this.keywords,
  });

  final String question;
  final String answer;
  final List<String> keywords;
}

class DoubtBusterTab extends StatefulWidget {
  const DoubtBusterTab({super.key});

  @override
  State<DoubtBusterTab> createState() =>
      _DoubtBusterTabState();
}

class _DoubtBusterTabState extends State<DoubtBusterTab> {
  final TextEditingController messageController =
  TextEditingController();

  final ScrollController scrollController =
  ScrollController();

  // ----------------------------------------------------------
  // 10 STANDARD QUESTIONS AND ANSWERS
  // ----------------------------------------------------------

  final List<StandardQuestion> standardQuestions = const [
    StandardQuestion(
      question: 'How can I create an effective study plan?',
      answer:
      'Start by listing your subjects and deadlines. '
          'Set realistic daily goals, study difficult topics '
          'when you feel most alert, and review your progress '
          'at the end of each week.',
      keywords: [
        'study plan',
        'study schedule',
        'timetable',
        'study effectively',
      ],
    ),
    StandardQuestion(
      question: 'What is the Pomodoro technique?',
      answer:
      'The Pomodoro technique divides study time into '
          'focused intervals. A common method is 25 minutes '
          'of focused work followed by a 5-minute break. '
          'After four sessions, take a longer break.',
      keywords: [
        'pomodoro',
        'focus technique',
        'study break',
      ],
    ),
    StandardQuestion(
      question: 'How can I improve my concentration?',
      answer:
      'Keep your phone away, choose a quiet study space, '
          'set one clear goal, take regular breaks, and '
          'get sufficient sleep. Short, focused sessions '
          'can help you build concentration.',
      keywords: [
        'concentration',
        'focus',
        'distracted',
        'distraction',
      ],
    ),
    StandardQuestion(
      question: 'How do I prepare for an examination?',
      answer:
      'Review the syllabus, identify important topics, '
          'practise past questions, test yourself without '
          'looking at notes, and leave time for revision. '
          'Prioritise sleep before the examination.',
      keywords: [
        'exam preparation',
        'prepare for exam',
        'examination',
        'revision',
      ],
    ),
    StandardQuestion(
      question: 'How can I improve my communication skills?',
      answer:
      'Practise speaking clearly, listen actively, '
          'organise your thoughts before responding, '
          'read regularly, and ask for constructive feedback. '
          'Small daily practice sessions can build confidence.',
      keywords: [
        'communication skills',
        'speak confidently',
        'communication',
      ],
    ),
    StandardQuestion(
      question: 'How do I participate in a group discussion?',
      answer:
      'Understand the topic, make concise and relevant '
          'points, listen to others, support your arguments '
          'with examples, and disagree respectfully. '
          'Give others a chance to contribute.',
      keywords: [
        'group discussion',
        'gd',
        'discussion',
      ],
    ),
    StandardQuestion(
      question: 'How can I manage stress as a student?',
      answer:
      'Break large tasks into smaller steps, plan your '
          'week, exercise regularly, sleep adequately, and '
          'talk to someone you trust when overwhelmed. '
          'Seek professional support if stress persists.',
      keywords: [
        'stress',
        'anxiety',
        'overwhelmed',
        'student stress',
      ],
    ),
    StandardQuestion(
      question: 'How do I learn programming?',
      answer:
      'Choose one programming language, learn its '
          'fundamentals, write small programs, practise '
          'problem-solving, and build projects. Read error '
          'messages carefully and learn to debug your code.',
      keywords: [
        'learn programming',
        'coding',
        'programming language',
        'debug',
      ],
    ),
    StandardQuestion(
      question: 'How can I improve my vocabulary?',
      answer:
      'Learn a few new words daily. Record each word '
          'with its meaning, synonyms, and an example sentence. '
          'Use the words in your own writing and revisit them '
          'regularly using spaced repetition.',
      keywords: [
        'vocabulary',
        'new words',
        'learn words',
        'improve english',
      ],
    ),
    StandardQuestion(
      question: 'How can I prepare for an interview?',
      answer:
      'Research the organisation, understand the role, '
          'practise common questions, and prepare examples '
          'of your skills and achievements. Use the STAR '
          'method for experience-based questions and prepare '
          'thoughtful questions for the interviewer.',
      keywords: [
        'interview',
        'job interview',
        'interview preparation',
      ],
    ),
  ];

  late List<DoubtBusterChatMessage> messages;

  @override
  void initState() {
    super.initState();

    messages = [
      DoubtBusterChatMessage(
        text:
        'Hello! Welcome to the 24/7 Doubt Buster. 👋\n\n'
            'Choose one of the 10 standard questions below, '
            'or type your own question.\n\n'
            'If I cannot answer your question, I can help '
            'you prepare an email to a peer using Gmail.',
        isBot: true,
      ),
    ];
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '24/7 NLP Doubt Buster',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: PeerBoardColors.green,
                ),
                SizedBox(width: 6),
                Text(
                  'Ready',
                  style: TextStyle(
                    color: PeerBoardColors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildChatHeader(),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12,
              ),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(messages[index]);
              },
            ),
          ),
          _buildStandardQuestions(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            PeerBoardColors.lightBlue,
            PeerBoardColors.lightPink,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surface,
            child: Icon(
              Icons.smart_toy,
              color: PeerBoardColors.pink,
              size: 28,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doubt Buster Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: PeerBoardColors.text,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Standard answers • Peer email support',
                  style: TextStyle(
                    fontSize: 12,
                    color: PeerBoardColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(DoubtBusterChatMessage message) {
    final isBot = message.isBot;

    return Align(
      alignment: isBot
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.83,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isBot
              ? AppColors.background
              : PeerBoardColors.lightBlue,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(isBot ? 4 : 17),
            bottomRight: Radius.circular(isBot ? 17 : 4),
          ),
          border: Border.all(
            color: isBot
                ? PeerBoardColors.border
                : AppColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBot)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'DOUBT BUSTER',
                  style: TextStyle(
                    color: PeerBoardColors.pink,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            Text(
              message.text,
              style: const TextStyle(
                color: PeerBoardColors.text,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            if (message.isEmailAction) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _showEmailDialog,
                icon: const Icon(Icons.email_outlined),
                label: const Text('Email a Peer'),
                style: FilledButton.styleFrom(
                  backgroundColor: PeerBoardColors.pink,
                  foregroundColor: AppColors.background,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // THE 10 STANDARD QUESTION CHIPS
  // ----------------------------------------------------------

  Widget _buildStandardQuestions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: PeerBoardColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STANDARD QUESTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: PeerBoardColors.muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: standardQuestions.length,
              separatorBuilder: (_, __) =>
              const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final question =
                    standardQuestions[index].question;

                return ActionChip(
                  avatar: const Icon(
                    Icons.help_outline,
                    size: 17,
                    color: PeerBoardColors.blue,
                  ),
                  label: Text(
                    '${index + 1}. $question',
                    maxLines: 1,
                  ),
                  backgroundColor: PeerBoardColors.lightBlue,
                  side: BorderSide.none,
                  onPressed: () {
                    _askQuestion(question);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // CHAT INPUT
  // ----------------------------------------------------------

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: PeerBoardColors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTypedMessage(),
              decoration: InputDecoration(
                hintText: 'Type your doubt here...',
                prefixIcon: const Icon(
                  Icons.chat_bubble_outline,
                  color: PeerBoardColors.blue,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: PeerBoardColors.pink,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendTypedMessage,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
              ),
              tooltip: 'Send question',
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // SIMPLE KEYWORD-BASED NLP MATCHING
  // ----------------------------------------------------------

  void _sendTypedMessage() {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    messageController.clear();
    _askQuestion(text);
  }

  void _askQuestion(String question) {
    if (!mounted) return;

    final answer = _findAnswer(question);

    setState(() {
      messages.add(
        DoubtBusterChatMessage(
          text: question,
          isBot: false,
        ),
      );

      messages.add(
        DoubtBusterChatMessage(
          text: answer ??
              'I could not find a matching answer among my '
                  '10 standard questions.\n\n'
                  'You can email your question to a peer. '
                  'I will prepare a Gmail message with your '
                  'question so you can send it for help.',
          isBot: true,
          isEmailAction: answer == null,
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String? _findAnswer(String input) {
    final normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // First, match the complete standard question.
    for (final item in standardQuestions) {
      final standard = item.question
          .toLowerCase()
          .replaceAll('?', '')
          .trim();

      if (normalized == standard) {
        return item.answer;
      }
    }

    // Next, match phrases and keywords.
    StandardQuestion? bestMatch;
    int bestScore = 0;

    for (final item in standardQuestions) {
      int score = 0;

      for (final keyword in item.keywords) {
        final normalizedKeyword = keyword.toLowerCase();

        if (normalized.contains(normalizedKeyword)) {
          score += normalizedKeyword.contains(' ')
              ? 3
              : 1;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    if (bestScore > 0 && bestMatch != null) {
      return bestMatch.answer;
    }

    return null;
  }

  // ----------------------------------------------------------
  // FURTHER QUESTION: GMAIL COMPOSE DIALOG
  // ----------------------------------------------------------

  Future<void> _showEmailDialog() async {
    final recipientController = TextEditingController();
    final subjectController = TextEditingController(
      text: 'Help with my question',
    );

    final latestQuestion = _latestUnansweredQuestion();

    final bodyController = TextEditingController(
      text: 'Hello,\n\n'
          'I need help with the following question:\n\n'
          '${latestQuestion ?? "Please describe your question here."}'
          '\n\nCould you please help me understand this topic?\n\n'
          'Thank you.',
    );

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                color: PeerBoardColors.pink,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Email Your Question'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your peer’s email address. '
                      'Gmail will open with your question '
                      'and message ready to review.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: recipientController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Gmail address',
                    hintText: 'peer@gmail.com',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Email subject',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: PeerBoardColors.pink,
                foregroundColor: AppColors.background,
              ),
              onPressed: () {
                if (_validEmail(
                  recipientController.text.trim(),
                )) {
                  Navigator.pop(dialogContext, true);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Gmail'),
            ),
          ],
        );
      },
    );

    final recipient = recipientController.text.trim();
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();

    recipientController.dispose();
    subjectController.dispose();
    bodyController.dispose();

    if (shouldContinue == true && mounted) {
      await openGmailCompose(
        recipient: recipient,
        subject: subject,
        body: body,
      );
    }
  }

  String? _latestUnansweredQuestion() {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].isBot) {
        final answer = _findAnswer(messages[i].text);

        if (answer == null) {
          return messages[i].text;
        }
      }
    }

    return null;
  }
}

// ============================================================
// GMAIL COMPOSE HELPER
// ============================================================

Future<void> openGmailCompose({
  required String recipient,
  required String subject,
  required String body,
}) async {
  final Uri gmailUri = Uri.https(
    'mail.google.com',
    '/mail/',
    {
      'view': 'cm',
      'fs': '1',
      'to': recipient,
      'su': subject,
      'body': body,
    },
  );

  try {
    final opened = await launchUrl(
      gmailUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw Exception('Could not open Gmail.');
    }
  } catch (error) {
    debugPrint('Gmail launch error: $error');

    // Fallback: open the device's default email application.
    final Uri mailUri = Uri(
      scheme: 'mailto',
      path: recipient,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      final opened = await launchUrl(
        mailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        debugPrint('No email application could be opened.');
      }
    } catch (fallbackError) {
      debugPrint('Email fallback error: $fallbackError');
    }
  }
}

// ============================================================
// SHARED VALIDATION AND DATE HELPERS
// ============================================================

bool _validEmail(String email) {
  return RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  ).hasMatch(email);
}

String _timeAgo(DateTime time) {
  final difference = DateTime.now().difference(time);

  if (difference.inMinutes < 1) {
    return 'Just now';
  }

  if (difference.inHours < 1) {
    return '${difference.inMinutes} min ago';
  }

  if (difference.inDays < 1) {
    return '${difference.inHours} hr ago';
  }

  return '${difference.inDays} day(s) ago';
}


// ============================================================================
// NAVIGATION ADAPTER: Peer Resolution Board
// Keeps the existing Tuition AI ML Super-App navigation API unchanged.
// ============================================================================
class PeerResolutionBoardTab extends StatefulWidget {
  const PeerResolutionBoardTab({super.key});

  @override
  State<PeerResolutionBoardTab> createState() => _PeerResolutionBoardTabState();
}

class _PeerResolutionBoardTabState extends State<PeerResolutionBoardTab> {
  late final List<ResolutionPost> _posts;

  @override
  void initState() {
    super.initState();
    _posts = [
      ResolutionPost(
        title: 'How can I improve my study schedule?',
        description:
        'I have several subjects to prepare for. '
            'How can I manage my time effectively?',
        author: 'Ananya',
        email: 'ananya.peer@gmail.com',
        category: 'Study Skills',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        solutions: [
          'Try the Pomodoro technique: 25 minutes of study '
              'followed by a 5-minute break.',
        ],
      ),
      ResolutionPost(
        title: 'Understanding a difficult programming concept',
        description:
        'I find it difficult to understand how functions '
            'and parameters work in programming.',
        author: 'Rahul',
        email: 'rahul.peer@gmail.com',
        category: 'Programming',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        solutions: [
          'Start with a simple function and experiment '
              'with different input values.',
        ],
      ),
      ResolutionPost(
        title: 'Tips for group discussion preparation',
        description:
        'How can I communicate my ideas clearly in a '
            'group discussion?',
        author: 'Priya',
        email: 'priya.peer@gmail.com',
        category: 'Communication',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PeerResolutionBoard(
      posts: _posts,
      onPostsChanged: () {
        if (mounted) setState(() {});
      },
    );
  }
}

// ============================================================================
//  APPENDED INTEGRATED MODULES
//  BluePink Interactive PDF Reader + Granular Marks Grader + ScriptGrade OCR
//  These modules are opened from the "Combined Academic Suite" drawer group.
//  Shared state is provided by SuiteState and cached with SharedPreferences.
// ============================================================================

const suiteNavy = AppColors.text;
const suiteBlue = AppColors.blue;
const suitePink = AppColors.pink;
const suitePaleBlue = AppColors.blueSoft;
const suitePalePink = AppColors.pinkSoft;
const suitePageBg = AppColors.background;
const suiteInk = AppColors.inkSoft;
const suiteBorder = AppColors.line;

String suiteGradeOf(double p) => p >= 90 ? 'A+' : p >= 80 ? 'A' : p >= 70 ? 'B' : p >= 60 ? 'C' : p >= 50 ? 'D' : 'F';

class AppApi {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static Future<Map<String, dynamic>> get(String path) async {
    final r = await http.get(uri(path)).timeout(const Duration(seconds: 20));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('GET $path: ${r.statusCode} ${r.body}');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  static Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final r = await http.post(uri(path), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 40));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('POST $path: ${r.statusCode} ${r.body}');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  static Future<Map<String, dynamic>> upload(String path, String field, Uint8List bytes, String filename, {Map<String, String> fields = const {}}) async {
    final request = http.MultipartRequest('POST', uri(path));
    request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Upload failed (${response.statusCode}): ${response.body}');
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }
}

class SuiteState extends ChangeNotifier {
  List<Map<String, dynamic>> marks = [];
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> submissions = [];
  List<Map<String, dynamic>> pdfs = [];
  bool loading = false;
  bool backendOnline = false;
  String backendMessage = 'Connecting to Python backend…';
  String? lastError;

  Future<void> initialize() async {
    await loadCache();
    await refresh();
  }

  Future<void> loadCache() async {
    final p = await SharedPreferences.getInstance();
    marks = _decodeList(p.getString('suite_marks_cache'));
    questions = _decodeList(p.getString('suite_questions_cache'));
    submissions = _decodeList(p.getString('suite_submissions_cache'));
    pdfs = _decodeList(p.getString('suite_pdfs_cache'));
    notifyListeners();
  }

  List<Map<String, dynamic>> _decodeList(String? value) {
    if (value == null) return [];
    try { return (jsonDecode(value) as List).map((e) => Map<String, dynamic>.from(e)).toList(); }
    catch (_) { return []; }
  }

  Future<void> _cache() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('suite_marks_cache', jsonEncode(marks));
    await p.setString('suite_questions_cache', jsonEncode(questions));
    await p.setString('suite_submissions_cache', jsonEncode(submissions));
    await p.setString('suite_pdfs_cache', jsonEncode(pdfs));
  }

  Future<void> refresh() async {
    loading = true; notifyListeners();
    try {
      final data = await AppApi.get('/bootstrap');
      marks = _mapList(data['marks']);
      questions = _mapList(data['questions']);
      submissions = _mapList(data['submissions']);
      pdfs = _mapList(data['pdfs']);
      backendOnline = true;
      backendMessage = 'Python backend connected';
      lastError = null;
      await _cache();
    } catch (e) {
      backendOnline = false;
      backendMessage = 'Offline cache mode';
      lastError = e.toString();
    } finally {
      loading = false; notifyListeners();
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic value) =>
      value is List ? value.map((e) => Map<String, dynamic>.from(e)).toList() : [];

  Future<void> importMarks(Uint8List bytes, String name) async {
    final result = await AppApi.upload('/marks/import', 'file', bytes, name);
    marks = _mapList(result['records']);
    await _cache(); notifyListeners();
  }

  Future<void> addQuestion(Map<String, dynamic> q) async {
    await AppApi.postJson('/questions', q);
    await refresh();
  }

  Future<Map<String, dynamic>> evaluateImage(Uint8List bytes, String filename, String student, String questionId) async {
    return AppApi.upload('/ocr', 'file', bytes, filename, fields: {'student': student, 'question_id': questionId});
  }

  Future<void> saveSubmission(Map<String, dynamic> submission) async {
    await AppApi.postJson('/submissions', submission);
    await refresh();
  }

  Future<void> reviewSubmission(String id, double awarded, String feedback) async {
    await AppApi.postJson('/submissions/$id/review', {'awarded': awarded, 'feedback': feedback});
    await refresh();
  }

  Future<void> uploadPdf(Uint8List bytes, String filename) async {
    final result = await AppApi.upload('/pdfs/upload', 'file', bytes, filename);
    pdfs = [Map<String, dynamic>.from(result['pdf']), ...pdfs];
    await _cache(); notifyListeners();
  }

  int get studentCount => marks.map((e) => '${e['studentId']}').toSet().length;
  double get averageMarks => marks.isEmpty ? 0 : marks.map((e) => _percentage(e)).reduce((a,b) => a+b) / marks.length;
  double get passRate => marks.isEmpty ? 0 : marks.where((e) => _percentage(e) >= 50).length * 100 / marks.length;
  static double _percentage(Map<String, dynamic> e) {
    final m = (e['marks'] as num?)?.toDouble() ?? 0;
    final max = (e['maxMarks'] as num?)?.toDouble() ?? 100;
    return max <= 0 ? 0 : m * 100 / max;
  }
}

Widget pageFrame(String title, String subtitle, Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(20),
  child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: suiteNavy)),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 18),
      child,
    ]))),
);

Widget sectionTitle(String value) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 10),
  child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: suiteNavy)),
);

Widget metricCard(String title, String value, IconData icon, Color color) => Card(
  child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: suiteNavy)),
      Text(title, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
    ])),
  ])),
);

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});
  @override Widget build(BuildContext context) {
    final s = context.watch<SuiteState>();
    return pageFrame('Academic workspace', 'One connected workspace for textbooks, student marks and answer-sheet evaluation.',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF102540), Color(0xFF214D82), Color(0xFF74365F)]), borderRadius: BorderRadius.circular(24)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('READ • ASSESS • IMPROVE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            SizedBox(height: 12),
            Text('Your complete academic\\nreading & grading suite', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.12)),
            SizedBox(height: 10),
            Text('Open learning resources, analyse grade distributions and review OCR-assisted assessments.', style: TextStyle(color: Colors.white, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (_,c) {
          final count = c.maxWidth > 800 ? 4 : 2;
          return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: count, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.7,
            children: [
              metricCard('Unique students', '${s.studentCount}', Icons.people_alt_outlined, suiteBlue),
              metricCard('Mark records', '${s.marks.length}', Icons.assessment_outlined, suitePink),
              metricCard('Average marks', '${s.averageMarks.toStringAsFixed(1)}%', Icons.analytics_outlined, suiteBlue),
              metricCard('Pass rate', '${s.passRate.toStringAsFixed(1)}%', Icons.check_circle_outline, suitePink),
            ]);
        }),
        sectionTitle('Modules'),
        const Wrap(spacing: 10, runSpacing: 10, children: [
          ModuleChip(icon: Icons.menu_book, title: 'Interactive PDF reader', tint: suiteBlue),
          ModuleChip(icon: Icons.table_chart, title: 'Historical grade matrix', tint: suitePink),
          ModuleChip(icon: Icons.document_scanner, title: 'OCR answer capture', tint: suiteBlue),
          ModuleChip(icon: Icons.fact_check, title: 'Teacher review workflow', tint: suitePink),
        ]),
        sectionTitle('Backend status'),
        Card(child: ListTile(leading: Icon(s.backendOnline ? Icons.cloud_done : Icons.cloud_off, color: s.backendOnline ? Colors.green : suitePink),
          title: Text(s.backendMessage, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(s.backendOnline ? 'Changes are synchronised with backend/app_state.json.' : 'Start the Python backend to synchronise changes. Cached data remains visible.'),
          trailing: IconButton(onPressed: () => s.refresh(), icon: const Icon(Icons.refresh)))),
        if (s.lastError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.lastError!, style: const TextStyle(fontSize: 11, color: AppColors.muted))),
      ]),
    );
  }
}

class ModuleChip extends StatelessWidget {
  final IconData icon; final String title; final Color tint;
  const ModuleChip({super.key, required this.icon, required this.title, required this.tint});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: suiteBorder), borderRadius: BorderRadius.circular(14)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: tint, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))]),
  );
}

class PdfLibraryPage extends StatefulWidget {
  const PdfLibraryPage({super.key});
  @override State<PdfLibraryPage> createState() => _PdfLibraryPageState();
}
class _PdfLibraryPageState extends State<PdfLibraryPage> {
  Uint8List? bytes;
  String? url;
  String title = '';
  final controller = PdfViewerController();
  final search = TextEditingController();
  PdfTextSearchResult? searchResult;
  int page = 1, pages = 0;
  final pageInput = TextEditingController(text: '1');
  bool dark = false;
  List<int> bookmarks = [];
  static const sampleBooks = [
    ['Biology 2e — OpenStax', 'Open textbook • Biology', 'https://d3bxy9euw4e147.cloudfront.net/oscms-prodcms/media/documents/Biology2e-OP_aHSFm3Y.pdf'],
    ['Flutter Succinctly', 'Programming • Flutter', 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf'],
  ];
  @override void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => bookmarks = (prefs.getStringList('suite_pdf_bookmarks') ?? [])
        .map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList());
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('suite_pdf_bookmarks', bookmarks.map((e) => '$e').toList());
  }

  void _toggleBookmark() {
    if (page < 1) return;
    setState(() {
      if (bookmarks.contains(page)) { bookmarks.remove(page); }
      else { bookmarks.add(page); bookmarks.sort(); }
    });
    _saveBookmarks();
  }

  Future<void> _openBundledSample() async {
    try {
      final data = await rootBundle.load('assets/sample_study_guide.pdf');
      setState(() { bytes = data.buffer.asUint8List(); url = null; title = 'BluePink Sample Study Guide'; page = 1; pages = 0; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open sample PDF: $e')));
    }
  }

  void _showBookmarks() {
    showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        const ListTile(title: Text('Saved PDF pages', style: TextStyle(fontWeight: FontWeight.w800))),
        if (bookmarks.isEmpty) const ListTile(title: Text('No bookmarked pages yet.')),
        ...bookmarks.map((p) => ListTile(leading: const Icon(Icons.bookmark, color: suitePink), title: Text('Page $p'), onTap: () { Navigator.pop(sheetContext); controller.jumpToPage(p); })),
      ]),
    ));
  }

  @override void dispose() { controller.dispose(); search.dispose(); pageInput.dispose(); searchResult?.clear(); super.dispose(); }

  Future<void> pickPdf() async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );

    if (!mounted || files.isEmpty) return;

    final f = files.single;
final Uint8List fileBytes = await f.readAsBytes();
    if (fileBytes.isEmpty) {
      throw Exception(
        'The selected PDF could not be read. Please select it again.',
      );
    }

    if (fileBytes.length < 5 ||
        String.fromCharCodes(fileBytes.take(5)) != '%PDF-') {
      throw Exception('The selected file is not a valid PDF.');
    }

    searchResult?.clear();

    if (!mounted) return;

    setState(() {
      bytes = Uint8List.fromList(fileBytes);
      url = null;
      title = f.name;
      page = 1;
      pages = 0;
      pageInput.text = '1';
    });

  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open PDF: $e')),
    );
  }
}

  void openWeb(String name, String link) {
    final parsed = Uri.tryParse(link);
    if (parsed == null ||
        !(parsed.scheme == 'https' || parsed.scheme == 'http') ||
        parsed.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This PDF link is invalid.')),
      );
      return;
    }
    searchResult?.clear();
    setState(() {
      bytes = null;
      url = parsed.toString();
      title = name;
      page = 1;
      pages = 0;
      pageInput.text = '1';
    });
  }

  void doSearch() {
    if (search.text.trim().isEmpty) return;
    setState(() => searchResult = controller.searchText(search.text.trim()));
  }

  Widget viewer() {
    if (bytes == null && url == null) return const Center(child: Text('Choose a PDF to begin reading.'));
    final child = bytes != null
      ? SfPdfViewer.memory(bytes!, key: ValueKey(title), controller: controller,
          onDocumentLoaded: (d) {
            if (!mounted) return;
            setState(() {
              pages = d.document.pages.count;
              page = 1;
              pageInput.text = '1';
            });
          },
          onPageChanged: (d) {
            if (!mounted) return;
            setState(() {
              page = d.newPageNumber;
              pageInput.text = '$page';
            });
          },
          onDocumentLoadFailed: (d) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('PDF error: ${d.error}')),
            );
          })
      : SfPdfViewer.network(url!, key: ValueKey(title), controller: controller,
          onDocumentLoaded: (d) {
            if (!mounted) return;
            setState(() {
              pages = d.document.pages.count;
              page = 1;
              pageInput.text = '1';
            });
          },
          onPageChanged: (d) {
            if (!mounted) return;
            setState(() {
              page = d.newPageNumber;
              pageInput.text = '$page';
            });
          },
          onDocumentLoadFailed: (d) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'This host may block embedded PDF access (CORS) or require a direct PDF response: ${d.description}',
                ),
                action: SnackBarAction(
                  label: 'Open in browser',
                  onPressed: () {
                    final target = url;
                    if (target != null) {
                      launchUrl(
                        Uri.parse(target),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
            );
          });
    return Column(children: [
      Card(child: Padding(padding: const EdgeInsets.all(8), child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 4, children: [
        IconButton(onPressed: () => setState(() { bytes = null; url = null; }), icon: const Icon(Icons.arrow_back)),
        SizedBox(width: 150, child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
        IconButton(onPressed: page > 1 ? () => controller.previousPage() : null, icon: const Icon(Icons.chevron_left)),
        SizedBox(width: 55, child: TextField(controller: pageInput, keyboardType: TextInputType.number, onSubmitted: (_) { final p = int.tryParse(pageInput.text); if (p != null && p > 0 && p <= pages) controller.jumpToPage(p); }, decoration: const InputDecoration(isDense: true, hintText: 'Page'))),
        Text('/ $pages'),
        IconButton(onPressed: pages == 0 || page < pages ? () => controller.nextPage() : null, icon: const Icon(Icons.chevron_right)),
        IconButton(tooltip: 'Bookmark this page', onPressed: _toggleBookmark, icon: Icon(bookmarks.contains(page) ? Icons.bookmark : Icons.bookmark_add, color: suitePink)),
        IconButton(tooltip: 'Saved pages', onPressed: _showBookmarks, icon: const Icon(Icons.bookmarks_outlined, color: suiteBlue)),
        SizedBox(width: 150, child: TextField(controller: search, onSubmitted: (_) => doSearch(), decoration: InputDecoration(isDense: true, hintText: 'Search PDF', suffixIcon: IconButton(onPressed: doSearch, icon: const Icon(Icons.search))))),
        IconButton(onPressed: searchResult == null ? null : () => searchResult!.previousInstance(), icon: const Icon(Icons.keyboard_arrow_up)),
        IconButton(onPressed: searchResult == null ? null : () => searchResult!.nextInstance(), icon: const Icon(Icons.keyboard_arrow_down)),
        if (url != null) IconButton(tooltip: 'Open online PDF in browser', onPressed: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_browser, color: suitePink)),
        IconButton(onPressed: () => setState(() => dark = !dark), icon: Icon(dark ? Icons.light_mode : Icons.dark_mode)),
      ]))),
      const SizedBox(height: 8),
      Expanded(child: Container(color: dark ? const Color(0xFF202634) : AppColors.cardAlt, child: child)),
    ]);
  }

  @override Widget build(BuildContext context) {
    final state = context.watch<SuiteState>();
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
        const Text('PDF Library', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: suiteNavy)),
        FilledButton.tonalIcon(onPressed: _openBundledSample, icon: const Icon(Icons.menu_book), label: const Text('Sample PDF')),
        FilledButton.icon(onPressed: pickPdf, icon: const Icon(Icons.upload_file), label: const Text('Upload PDF')),
      ]),
      const SizedBox(height: 8),
      if (bytes != null || url != null) Expanded(child: viewer())
      else Expanded(child: ListView(children: [
        const Text('Read your own books or open free sample textbooks hosted by their publishers.'),
        const SizedBox(height: 14),
        ...sampleBooks.map((b) => Card(child: ListTile(
          leading: const CircleAvatar(backgroundColor: suitePaleBlue, child: Icon(Icons.menu_book, color: suiteBlue)),
          title: Text(b[0], style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(b[1]),
          trailing: const Icon(Icons.open_in_new, color: suitePink),
          onTap: () => openWeb(b[0], b[2]),
        ))),
        sectionTitle('Uploaded library records'),
        if (state.pdfs.isEmpty) const Text('No PDFs archived in the backend yet.')
        else ...state.pdfs.map((p) => Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf, color: suitePink), title: Text('${p['filename']}'), subtitle: Text('${p['size']} bytes • ${p['uploadedAt']}'), trailing: const Icon(Icons.open_in_new, color: suiteBlue), onTap: () => openWeb('${p['filename']}', '${AppApi.baseUrl}${p['url']}')))),
      ])),
    ]));
  }
}

class MarksPage extends StatefulWidget {
  const MarksPage({super.key});
  @override State<MarksPage> createState() => _MarksPageState();
}
class _MarksPageState extends State<MarksPage> {
  String year = 'All', subject = 'All', className = 'All';
  Future<void> importJson() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return;
    final file = files.single;
    final fileBytes = await file.readAsBytes();
    try {
      await context.read<SuiteState>().importMarks(fileBytes, file.name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marks imported and saved to backend.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'))); }
  }
  Future<void> loadSampleMarks() async {
    try {
      final data = await rootBundle.load('assets/academic_marks.json');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await context.read<SuiteState>().importMarks(bytes, 'academic_marks.json');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bundled sample academic marks loaded.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load sample marks: $e')));
    }
  }
  @override Widget build(BuildContext context) {
    final s = context.watch<SuiteState>();
    final years = ['All', ...s.marks.map((e) => '${e['academicYear']}').toSet().toList()..sort()];
    final subjects = ['All', ...s.marks.map((e) => '${e['subject']}').toSet().toList()..sort()];
    final classes = ['All', ...s.marks.map((e) => '${e['className']}').toSet().toList()..sort()];
    final filtered = s.marks.where((m) => (year == 'All' || '${m['academicYear']}' == year) && (subject == 'All' || '${m['subject']}' == subject) && (className == 'All' || '${m['className']}' == className)).toList();
    final counts = {for (final g in ['A+','A','B','C','D','F']) g: filtered.where((m) => suiteGradeOf(_pct(m)) == g).length};
    final byYear = <String, Map<String,int>>{};
    for (final m in s.marks) { final y = '${m['academicYear']}'; byYear.putIfAbsent(y, () => {for (final g in ['A+','A','B','C','D','F']) g:0}); byYear[y]![suiteGradeOf(_pct(m))] = byYear[y]![suiteGradeOf(_pct(m))]! + 1; }
    return pageFrame('Marks & Gradebook', 'Import academic marks JSON, filter results and inspect the historical grade matrix.',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [OutlinedButton.icon(onPressed: loadSampleMarks, icon: const Icon(Icons.auto_stories), label: const Text('Load bundled sample marks')), FilledButton.icon(onPressed: importJson, icon: const Icon(Icons.upload_file), label: const Text('Import marks JSON'))]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _filter('Year', year, years, (v) => setState(() => year = v)),
          _filter('Class', className, classes, (v) => setState(() => className = v)),
          _filter('Subject', subject, subjects, (v) => setState(() => subject = v)),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_,c) => GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: c.maxWidth > 700 ? 4 : 2, childAspectRatio: 1.8, crossAxisSpacing: 8, mainAxisSpacing: 8, children: [
          metricCard('Students', '${filtered.map((e) => e['studentId']).toSet().length}', Icons.people, suiteBlue),
          metricCard('Results', '${filtered.length}', Icons.assignment, suitePink),
          metricCard('Average', '${_avg(filtered).toStringAsFixed(1)}%', Icons.analytics, suiteBlue),
          metricCard('Pass rate', '${_pass(filtered).toStringAsFixed(1)}%', Icons.check_circle, suitePink),
        ])),
        sectionTitle('Grade distribution'),
        ...counts.entries.map((e) => _gradeBar(e.key, e.value, filtered.length)),
        sectionTitle('Historical grade matrix (all imported records)'),
        if (byYear.isEmpty) const Text('Import a JSON file to view historical distribution.')
        else SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          headingRowColor: WidgetStateProperty.all(suitePaleBlue),
          columns: [DataColumn(label: const Text('Academic year')), ...['A+','A','B','C','D','F'].map((g) => DataColumn(label: Text(g)))],
          rows: (byYear.keys.toList()..sort()).map((y) => DataRow(cells: [DataCell(Text(y)), ...['A+','A','B','C','D','F'].map((g) => DataCell(Text('${byYear[y]![g]}')))])).toList(),
        )),
        sectionTitle('Student results'),
        if (filtered.isEmpty) const Text('No records yet. Import your academic_marks.json file.')
        else ...filtered.map((m) => Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: suitePaleBlue, child: Text('${m['studentName'] ?? '?'}'.characters.first.toUpperCase())),
          title: Text('${m['studentName']} • ${m['subject']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${m['studentId']} • ${m['academicYear']} • ${m['className']}'),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(suiteGradeOf(_pct(m)), style: const TextStyle(color: suitePink, fontWeight: FontWeight.w900, fontSize: 17)), Text('${_pct(m).toStringAsFixed(1)}%')]),
        ))),
      ]),
    );
  }
  Widget _filter(String label, String value, List<String> items, ValueChanged<String> changed) => SizedBox(width: 170, child: DropdownButtonFormField<String>(
    value: items.contains(value) ? value : 'All', decoration: InputDecoration(labelText: label, isDense: true),
    items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if (v != null) changed(v); }));
  Widget _gradeBar(String grade, int count, int total) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
    SizedBox(width: 38, child: Text(grade, style: const TextStyle(fontWeight: FontWeight.w800))),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: total == 0 ? 0 : count/total, minHeight: 10, color: grade == 'F' ? suitePink : suiteBlue, backgroundColor: suitePaleBlue))),
    const SizedBox(width: 8), SizedBox(width: 34, child: Text('$count')),
  ]));
}
double _pct(Map<String,dynamic> m) { final max=(m['maxMarks'] as num?)?.toDouble() ?? 100; final marks=(m['marks'] as num?)?.toDouble() ?? 0; return max<=0?0:marks*100/max; }
double _avg(List<Map<String,dynamic>> m) => m.isEmpty ? 0 : m.map(_pct).reduce((a,b)=>a+b)/m.length;
double _pass(List<Map<String,dynamic>> m) => m.isEmpty ? 0 : m.where((e)=>_pct(e)>=50).length*100/m.length;

class OcrPage extends StatefulWidget {
  const OcrPage({super.key});
  @override State<OcrPage> createState() => _OcrPageState();
}
class _OcrPageState extends State<OcrPage> {
  final student = TextEditingController();
  final answer = TextEditingController();
  String? questionId, imageName;
  bool busy = false;
  double suggested = 0;
  final Set<String> _locallyAddedQuestionIds = <String>{};
  bool _localScoringActive = false;
  String _scoreFeedback = 'Suggested by keyword coverage. Teacher approval required.';
  String status = 'Upload a photographed or scanned answer sheet. OCR runs through the Python backend.';
  @override void dispose() { student.dispose(); answer.dispose(); super.dispose(); }

  String _normaliseForMarking(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _recalculateLocalScore(Map<String, dynamic> question) {
    final maxMarks = (question['maxMarks'] as num?)?.toDouble() ?? 0;
    final response = _normaliseForMarking(answer.text);
    final modelAnswer = _normaliseForMarking('${question['modelAnswer'] ?? ''}');
    final rawKeywords = question['keywords'];
    final keywords = rawKeywords is List
        ? rawKeywords.map((e) => _normaliseForMarking('$e')).where((e) => e.isNotEmpty).toSet().toList()
        : <String>[];
    if (response.isEmpty || maxMarks <= 0) {
      suggested = 0;
      _scoreFeedback = 'Enter or scan an answer to calculate a suggested score.';
      return;
    }
    if (modelAnswer.isNotEmpty && response == modelAnswer) {
      suggested = maxMarks;
      _scoreFeedback = 'Exact model-answer match. Teacher approval required.';
      return;
    }
    if (keywords.isEmpty && modelAnswer.isNotEmpty) {
      const stopWords = <String>{'the','and','for','with','that','this','from','are','was','were','has','have','had','into','its','their','they','them','then','than','when','where','which','what','who','how','why','can','could','should','would','will','shall','a','an','of','to','in','on','at','by','is','be','as','or','it'};
      keywords.addAll(modelAnswer.split(' ').where((w) => w.length > 2 && !stopWords.contains(w)).toSet());
    }
    if (keywords.isEmpty) {
      suggested = 0;
      _scoreFeedback = 'This rubric has no usable keywords. Add keywords to enable automatic suggestions.';
      return;
    }
    final matched = keywords.where((word) => response.contains(word)).length;
    final coverage = matched / keywords.length;
    suggested = (maxMarks * coverage).clamp(0.0, maxMarks).toDouble();
    _scoreFeedback = 'Local rubric: $matched of ${keywords.length} key concepts matched (${(coverage * 100).round()}%). Teacher approval required.';
  }

  Future<void> scan() async {
    final pickedFiles = await FilePicker.pickFiles(type: FileType.image);
    if (pickedFiles.isEmpty) return;
    final pickedFile = pickedFiles.single;
    final imageBytes = await pickedFile.readAsBytes();
    final qid = questionId;
    if (student.text.trim().isEmpty || qid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter student name and choose a question first.')));
      return;
    }
    setState(() { busy = true; status = 'Uploading image and running OCR…'; imageName = pickedFile.name; });
    try {
      final result = await context.read<SuiteState>().evaluateImage(imageBytes, pickedFile.name, student.text.trim(), qid);
      answer.text = '${result['extractedText'] ?? ''}';
      final selectedQuestion = context.read<SuiteState>().questions.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item != null && '${item['id']}' == qid,
        orElse: () => null,
      );
      setState(() {
        final backendScore = (result['suggestedMarks'] as num?)?.toDouble() ?? 0;
        if (selectedQuestion != null && (_locallyAddedQuestionIds.contains(qid) || backendScore <= 0)) {
          _localScoringActive = true;
          _recalculateLocalScore(selectedQuestion);
        } else {
          suggested = backendScore;
          _localScoringActive = false;
          _scoreFeedback = 'Suggested by the backend evaluator. Teacher approval required.';
        }
        status = result['ocrAvailable'] == true ? 'OCR complete. Correct the extracted text before saving.' : 'OCR engine unavailable on backend. Type/paste the answer manually, then save.';
        busy = false;
      });
    } catch (e) { setState(() { busy = false; status = 'OCR request failed: $e'; }); }
  }

  Future<void> _addQuestion() async {
    final title = TextEditingController();
    final prompt = TextEditingController();
    final model = TextEditingController();
    final maximum = TextEditingController(text: '10');
    final keywords = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Add marking rubric'),
      content: SingleChildScrollView(child: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Question title')),
        const SizedBox(height: 8), TextField(controller: prompt, maxLines: 2, decoration: const InputDecoration(labelText: 'Question prompt')),
        const SizedBox(height: 8), TextField(controller: model, maxLines: 3, decoration: const InputDecoration(labelText: 'Model answer')),
        const SizedBox(height: 8), TextField(controller: maximum, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum marks')),
        const SizedBox(height: 8), TextField(controller: keywords, maxLines: 2, decoration: const InputDecoration(labelText: 'Keywords, separated by commas')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save rubric'))],
    ));
    if (ok == true) {
      final max = double.tryParse(maximum.text.trim()) ?? 0;
      if (title.text.trim().isEmpty || prompt.text.trim().isEmpty || model.text.trim().isEmpty || max <= 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete all fields and enter a positive maximum mark.')));
      } else {
        try {
          await context.read<SuiteState>().addQuestion({'title': title.text.trim(), 'prompt': prompt.text.trim(), 'modelAnswer': model.text.trim(), 'maxMarks': max, 'keywords': keywords.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()});
          if (mounted) setState(() {
            final addedId = context.read<SuiteState>().questions.last['id']?.toString();
            questionId = addedId;
            if (addedId != null) _locallyAddedQuestionIds.add(addedId);
            _localScoringActive = true;
            suggested = 0;
            answer.clear();
            _scoreFeedback = 'New rubric added. Upload or enter an answer to calculate its score locally.';
          });
        } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save rubric: $e'))); }
      }
    }
    title.dispose(); prompt.dispose(); model.dispose(); maximum.dispose(); keywords.dispose();
  }

  Future<void> save() async {
    final qid = questionId;
    if (qid == null || student.text.trim().isEmpty || answer.text.trim().isEmpty) return;
    final q = context.read<SuiteState>().questions.firstWhere((e) => '${e['id']}' == qid);
    final max = (q['maxMarks'] as num?)?.toDouble() ?? 0;
    if (_locallyAddedQuestionIds.contains(qid) || _localScoringActive) _recalculateLocalScore(q);
    final score = suggested.clamp(0.0, max).toDouble();
    try {
      await context.read<SuiteState>().saveSubmission({
        'student': student.text.trim(), 'questionId': qid, 'answer': answer.text.trim(),
        'imageName': imageName ?? 'Manual entry', 'suggested': score, 'awarded': score,
        'reviewed': false, 'feedback': _scoreFeedback
      });
      if (!mounted) return;
      setState(() { status = 'Submission saved for teacher review.'; answer.clear(); student.clear(); suggested = 0; imageName = null; });
    } catch (e) { setState(() => status = 'Save failed: $e'); }
  }

  @override Widget build(BuildContext context) {
    final s = context.watch<SuiteState>();
    questionId ??= s.questions.isNotEmpty ? '${s.questions.first['id']}' : null;
    Map<String, dynamic>? q;
    for (final item in s.questions) { if ('${item['id']}' == questionId) { q = item; break; } }
    return pageFrame('OCR answer evaluation', 'Capture or upload an answer image, edit OCR text, and generate a transparent suggested score.',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          TextField(controller: student, decoration: const InputDecoration(labelText: 'Student name', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: questionId, decoration: const InputDecoration(labelText: 'Question / rubric'),
            items: s.questions.map((q) => DropdownMenuItem(value: '${q['id']}', child: Text('${q['title']}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => questionId = v)),
          if (q != null) Container(width: double.infinity, margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: suitePaleBlue, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${q['title']} • ${q['maxMarks']} marks', style: const TextStyle(fontWeight: FontWeight.w800, color: suiteNavy)),
              Text('${q['prompt']}'),
              const SizedBox(height: 5), Text('Model answer: ${q['modelAnswer']}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ])),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(onPressed: busy ? null : scan, icon: const Icon(Icons.document_scanner), label: const Text('Upload answer image & OCR')),
            OutlinedButton.icon(onPressed: _addQuestion, icon: const Icon(Icons.add), label: const Text('Add question / rubric')),
          ])),
          if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(status, style: const TextStyle(fontSize: 12, color: AppColors.muted)))),
          if (imageName != null) Align(alignment: Alignment.centerLeft, child: Text('File: $imageName', style: const TextStyle(color: suiteBlue, fontSize: 12))),
        ]))),
        sectionTitle('Extracted answer — editable'),
        TextField(controller: answer, minLines: 8, maxLines: 16, onChanged: (_) {
          final selectedId = questionId;
          if (selectedId != null && (_locallyAddedQuestionIds.contains(selectedId) || _localScoringActive) && q != null) {
            setState(() => _recalculateLocalScore(q!));
          }
        }, decoration: const InputDecoration(hintText: 'OCR text appears here. You can correct it or type the answer manually.', alignLabelWithHint: true)),
        const SizedBox(height: 12),
        Text(_scoreFeedback, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Card(child: ListTile(title: const Text('Suggested marks'), subtitle: Text('${suggested.toStringAsFixed(1)} / ${(q?['maxMarks'] ?? 0)}'), leading: const Icon(Icons.auto_awesome, color: suitePink)))),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: busy ? null : save, icon: const Icon(Icons.save), label: const Text('Save for review')),
        ]),
      ]),
    );
  }
}

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});
  @override Widget build(BuildContext context) {
    final s = context.watch<SuiteState>();
    final pending = s.submissions.where((e) => e['reviewed'] != true).length;
    return pageFrame('Grading review & analytics', 'Teacher-controlled final marks and submission history.',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (_,c) => GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: c.maxWidth > 700 ? 3 : 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.8, children: [
          metricCard('Submissions', '${s.submissions.length}', Icons.description, suiteBlue),
          metricCard('Awaiting review', '$pending', Icons.pending_actions, suitePink),
          metricCard('Reviewed', '${s.submissions.length-pending}', Icons.verified, suiteBlue),
        ])),
        sectionTitle('Answer submissions'),
        if (s.submissions.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No submissions yet. Use OCR Evaluation to create one.')))
        else ...s.submissions.map((sub) => SubmissionReviewCard(submission: sub)),
      ]),
    );
  }
}

class SubmissionReviewCard extends StatefulWidget {
  final Map<String,dynamic> submission;
  const SubmissionReviewCard({super.key, required this.submission});
  @override State<SubmissionReviewCard> createState() => _SubmissionReviewCardState();
}
class _SubmissionReviewCardState extends State<SubmissionReviewCard> {
  late TextEditingController marks;
  late TextEditingController feedback;
  @override void initState() {
    super.initState();
    marks = TextEditingController(text: '${widget.submission['awarded']}');
    feedback = TextEditingController(text: '${widget.submission['feedback'] ?? ''}');
  }
  @override void dispose() { marks.dispose(); feedback.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final sub = widget.submission;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('${sub['student']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), Chip(label: Text(sub['reviewed'] == true ? 'Reviewed' : 'Pending'), backgroundColor: sub['reviewed'] == true ? suitePaleBlue : suitePalePink)]),
      Text('Suggested: ${sub['suggested']} • Awarded: ${sub['awarded']} • ${sub['createdAt'] ?? ''}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 8),
      Text('${sub['answer']}', maxLines: 5, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(controller: marks, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Final marks'))),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: TextField(controller: feedback, decoration: const InputDecoration(labelText: 'Teacher feedback'))),
      ]),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () async {
        final value = double.tryParse(marks.text.trim());
        if (value == null || value < 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid final marks.'))); return; }
        try {
          await context.read<SuiteState>().reviewSubmission('${sub['id']}', value, feedback.text.trim());
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher review saved.')));
        } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review failed: $e'))); }
      }, icon: const Icon(Icons.verified), label: const Text('Approve / update marks'))),
    ])));
  }
}

// ============================================================================
// APPENDED ORIGINAL MODULE IMPLEMENTATIONS
// PDF Reader, Granular Marks Gradebook and ScriptGrade Pro
// ============================================================================
const navy = AppColors.text;
const blue = AppColors.blue;
const pink = AppColors.pink;
const paleBlue = AppColors.blueSoft;
const palePink = AppColors.pinkSoft;
const ink = AppColors.text;

class ReaderApp extends StatelessWidget {
  const ReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BluePink PDF Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const ReaderHome(),
    );
  }
}

class OnlineBook {
  final String title;
  final String subtitle;
  final String url;
  final String tag;
  const OnlineBook(this.title, this.subtitle, this.url, this.tag);
}

const onlineBooks = <OnlineBook>[
  OnlineBook(
    'Biology 2e — OpenStax',
    'Openly licensed college biology textbook PDF',
    'https://d3bxy9euw4e147.cloudfront.net/oscms-prodcms/media/documents/Biology2e-OP_aHSFm3Y.pdf',
    'SCIENCE',
  ),
  OnlineBook(
    'Flutter Succinctly',
    'A technical learning book from Syncfusion',
    'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
    'TECHNOLOGY',
  ),
];

class ReaderHome extends StatefulWidget {
  const ReaderHome({super.key});

  @override
  State<ReaderHome> createState() => _ReaderHomeState();
}

class _ReaderHomeState extends State<ReaderHome> {
  Uint8List? _pdfBytes;
  String? _documentUrl;
  String _documentName = 'Welcome to your library';
  String _documentId = '';
  bool _isLoading = false;
  bool _showLibrary = true;
  int _currentPage = 1;
  int _pageCount = 0;
  double _zoom = 1.0;
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _pageController = TextEditingController(text: '1');
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;
  List<int> _bookmarks = [];
  Map<String, int> _savedPages = {};

  bool get _hasDocument => _pdfBytes != null || _documentUrl != null;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('pdf_reader_bookmarks') ?? [];
    final pages = prefs.getStringList('pdf_reader_pages') ?? [];
    final map = <String, int>{};
    for (final item in pages) {
      final parts = item.split('|');
      if (parts.length == 2) {
        final page = int.tryParse(parts[1]);
        if (page != null) map[parts[0]] = page;
      }
    }
    if (!mounted) return;
    setState(() {
      _bookmarks = raw.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
      _savedPages = map;
    });
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdf_reader_bookmarks', _bookmarks.map((e) => e.toString()).toList());
    final pages = _savedPages.entries.map((e) => '${e.key}|${e.value}').toList();
    await prefs.setStringList('pdf_reader_pages', pages);
  }

  Future<void> _pickPdf() async {
    try {
      setState(() => _isLoading = true);
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (files.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final file = files.single;
      final fileBytes = await file.readAsBytes();
      _openBytes(fileBytes, file.name);
    } catch (e) {
      _showMessage('Could not open PDF: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openBytes(Uint8List bytes, String name) {
    _searchResult?.clear();
    setState(() {
      _pdfBytes = bytes;
      _documentUrl = null;
      _documentName = name;
      _documentId = name;
      _currentPage = 1;
      _pageCount = 0;
      _pageController.text = '1';
      _searchResult = null;
      _showLibrary = false;
      _isLoading = false;
    });
  }

  Future<void> _openOfflineSample() async {
    try {
      final data = await rootBundle.load('assets/sample_study_guide.pdf');
      _openBytes(data.buffer.asUint8List(), 'Sample_Study_Guide.pdf');
    } catch (e) {
      _showMessage('Could not open the bundled sample: $e');
    }
  }

  void _openOnline(OnlineBook book) {
    _searchResult?.clear();
    setState(() {
      _pdfBytes = null;
      _documentUrl = book.url;
      _documentName = book.title;
      _documentId = book.title;
      _currentPage = _savedPages[book.title] ?? 1;
      _pageController.text = '$_currentPage';
      _pageCount = 0;
      _searchResult = null;
      _showLibrary = false;
      _isLoading = false;
    });
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
      _pageController.text = '${details.newPageNumber}';
      if (_documentId.isNotEmpty) _savedPages[_documentId] = details.newPageNumber;
    });
    _persistState();
  }

  void _jumpToPage() {
    final page = int.tryParse(_pageController.text.trim());
    if (page == null || page < 1 || (_pageCount > 0 && page > _pageCount)) {
      _showMessage('Enter a page between 1 and ${_pageCount == 0 ? 'the total page count' : _pageCount}.');
      return;
    }
    _pdfController.jumpToPage(page);
    FocusScope.of(context).unfocus();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showMessage('Enter a word or phrase to search.');
      return;
    }
    setState(() => _searchResult = _pdfController.searchText(query));
  }

  void _toggleBookmark() {
    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
      } else {
        _bookmarks.add(_currentPage);
        _bookmarks.sort();
      }
    });
    _persistState();
    _showMessage(_bookmarks.contains(_currentPage) ? 'Page bookmarked.' : 'Bookmark removed.');
  }

  void _showBookmarks() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bookmarks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
              const SizedBox(height: 12),
              if (_bookmarks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Text('No bookmarks yet. Tap the bookmark icon while reading.'),
                )
              else
                ..._bookmarks.map((page) => ListTile(
                  leading: const Icon(Icons.bookmark, color: pink),
                  title: Text('Page $page'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _pdfController.jumpToPage(page);
                  },
                )),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _searchResult?.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [blue, pink]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ReadSpace', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
                Text('INTERACTIVE PDF READER', style: TextStyle(fontSize: 9, letterSpacing: 1.4, color: blue, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Library',
            onPressed: () => setState(() => _showLibrary = true),
            icon: const Icon(Icons.library_books_outlined),
          ),
          IconButton(
            tooltip: 'Open PDF',
            onPressed: _pickPdf,
            icon: const Icon(Icons.upload_file_rounded, color: pink),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return Row(
            children: [
              if (wide) _sideRail(),
              Expanded(
                child: _showLibrary || !_hasDocument
                    ? _libraryView()
                    : _readerView(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sideRail() {
    return Container(
      width: 76,
      margin: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          _railButton(Icons.home_rounded, 'Home', true, () => setState(() => _showLibrary = true)),
          _railButton(Icons.menu_book_rounded, 'Reader', false, () {
            if (_hasDocument) setState(() => _showLibrary = false);
          }),
          _railButton(Icons.bookmarks_outlined, 'Saved', false, _showBookmarks),
          const Spacer(),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _railButton(IconData icon, String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? paleBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? blue : AppColors.muted),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, color: selected ? blue : AppColors.muted, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _libraryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF172554), Color(0xFF2563EB), Color(0xFFDB2777)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: LayoutBuilder(
                  builder: (context, c) => Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(30)),
                              child: const Text('YOUR DIGITAL STUDY DESK', style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 18),
                            Text('A better way to\\nread, learn & focus.', style: TextStyle(color: Colors.white, fontSize: c.maxWidth < 500 ? 28 : 38, height: 1.12, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            const Text('Open your own PDF or explore free sample learning books.', style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              onPressed: _pickPdf,
                              style: FilledButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: navy, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15)),
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Upload a PDF', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                      if (c.maxWidth > 520) const SizedBox(width: 24),
                      if (c.maxWidth > 520)
                        Container(
                          width: 150, height: 170,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(26)),
                          child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 100),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Text('Explore sample books', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: palePink, borderRadius: BorderRadius.circular(30)), child: const Text('FREE RESOURCES', style: TextStyle(color: pink, fontSize: 10, fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Open sample PDFs directly from the web. An internet connection is required.', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, c) {
                  final count = c.maxWidth > 850 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: onlineBooks.length + 1,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count, mainAxisSpacing: 14, crossAxisSpacing: 14, mainAxisExtent: 164,
                    ),
                    itemBuilder: (context, index) => index == 0
                        ? _offlineBookCard()
                        : _bookCard(onlineBooks[index - 1], index - 1),
                  );
                },
              ),
              const SizedBox(height: 26),
              const Text('Your reading workspace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: const [
                  _FeatureChip(icon: Icons.search_rounded, title: 'Text search'),
                  _FeatureChip(icon: Icons.zoom_in_rounded, title: 'Zoom controls'),
                  _FeatureChip(icon: Icons.bookmark_add_outlined, title: 'Bookmarks'),
                  _FeatureChip(icon: Icons.history_rounded, title: 'Reading progress'),
                  _FeatureChip(icon: Icons.dark_mode_outlined, title: 'Night reading'),
                  _FeatureChip(icon: Icons.touch_app_outlined, title: 'Text selection'),
                ],
              ),
              const SizedBox(height: 22),
              const Text('Note: Online sample textbooks are hosted by their publishers. Availability and download permissions are controlled by those websites.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }


  Widget _offlineBookCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 82, height: 112,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF172554), Color(0xFFEC4899)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('OFFLINE SAMPLE', style: TextStyle(color: pink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  const Text('Sample Study Guide', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                  const SizedBox(height: 5),
                  const Text('Included in this project for instant testing', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _openOfflineSample,
                      icon: const Icon(Icons.menu_book_rounded, size: 17),
                      label: const Text('Read sample'),
                      style: FilledButton.styleFrom(foregroundColor: blue, backgroundColor: paleBlue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookCard(OnlineBook book, int index) {
    final isPink = index.isOdd;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 82, height: 112,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPink ? [AppColors.pinkSoft, const Color(0xFFEC4899)] : [AppColors.blueSoft, const Color(0xFF2563EB)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(index == 0 ? Icons.biotech_rounded : Icons.code_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(book.tag, style: TextStyle(color: isPink ? pink : blue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                  const SizedBox(height: 5),
                  Text(book.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openOnline(book),
                      icon: const Icon(Icons.menu_book_rounded, size: 17),
                      label: const Text('Read online'),
                      style: FilledButton.styleFrom(foregroundColor: blue, backgroundColor: paleBlue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readerView() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8, runSpacing: 8,
            children: [
              IconButton(tooltip: 'Back to library', onPressed: () => setState(() => _showLibrary = true), icon: const Icon(Icons.arrow_back_rounded)),
              SizedBox(
                width: 220,
                child: Text(_documentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
              ),
              const SizedBox(width: 4),
              IconButton(tooltip: 'Previous page', onPressed: _currentPage > 1 ? () => _pdfController.previousPage() : null, icon: const Icon(Icons.chevron_left)),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: _pageController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 5), border: OutlineInputBorder()),
                  onSubmitted: (_) => _jumpToPage(),
                ),
              ),
              Text('/ ${_pageCount == 0 ? '—' : _pageCount}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
              IconButton(tooltip: 'Go to page', onPressed: _jumpToPage, icon: const Icon(Icons.keyboard_return_rounded, color: blue)),
              IconButton(tooltip: 'Next page', onPressed: _pageCount == 0 || _currentPage < _pageCount ? () => _pdfController.nextPage() : null, icon: const Icon(Icons.chevron_right)),
              const SizedBox(width: 8),
              SizedBox(
                width: 190,
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Find in document',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 19),
                    suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward, size: 18)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              IconButton(tooltip: 'Previous match', onPressed: _searchResult == null ? null : () => _searchResult!.previousInstance(), icon: const Icon(Icons.keyboard_arrow_up)),
              IconButton(tooltip: 'Next match', onPressed: _searchResult == null ? null : () => _searchResult!.nextInstance(), icon: const Icon(Icons.keyboard_arrow_down)),
              IconButton(tooltip: 'Bookmark page', onPressed: _toggleBookmark, icon: Icon(_bookmarks.contains(_currentPage) ? Icons.bookmark : Icons.bookmark_border, color: pink)),
              IconButton(tooltip: 'Bookmarks', onPressed: _showBookmarks, icon: const Icon(Icons.bookmarks_outlined)),
              IconButton(tooltip: 'Zoom out', onPressed: () => setState(() => _zoom = (_zoom - .1).clamp(.6, 2.5)), icon: const Icon(Icons.zoom_out)),
              Text('${(_zoom * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              IconButton(tooltip: 'Zoom in', onPressed: () => setState(() => _zoom = (_zoom + .1).clamp(.6, 2.5)), icon: const Icon(Icons.zoom_in)),
              if (_documentUrl != null) IconButton(tooltip: 'Open online PDF in browser', onPressed: () => launchUrl(Uri.parse(_documentUrl!), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_browser, color: pink)),
            ],
          ),
        ),
        if (_searchResult != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: palePink, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(child: Text(_searchResult!.hasResult ? 'Match ${_searchResult!.currentInstanceIndex} of ${_searchResult!.totalInstanceCount}' : 'Searching document…', style: const TextStyle(color: navy, fontWeight: FontWeight.w700, fontSize: 12))),
                IconButton(onPressed: () { _searchResult?.clear(); setState(() => _searchResult = null); }, icon: const Icon(Icons.close, size: 18)),
              ],
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: _pdfBytes != null
                ? SfPdfViewer.memory(
                    _pdfBytes!,
                    key: ValueKey(_documentId),
                    controller: _pdfController,
                    initialPageNumber: _savedPages[_documentId] ?? 1,
                    initialZoomLevel: _zoom,
                    onDocumentLoaded: (details) => setState(() {
                      _pageCount = details.document.pages.count;
                      _isLoading = false;
                    }),
                    onPageChanged: _onPageChanged,
                    onDocumentLoadFailed: (details) => _showMessage('PDF could not be loaded: ${details.error}'),
                  )
                : SfPdfViewer.network(
                    _documentUrl!,
                    key: ValueKey(_documentId),
                    controller: _pdfController,
                    initialPageNumber: _savedPages[_documentId] ?? 1,
                    initialZoomLevel: _zoom,
                    onDocumentLoaded: (details) => setState(() {
                      _pageCount = details.document.pages.count;
                      _isLoading = false;
                    }),
                    onPageChanged: _onPageChanged,
                    onDocumentLoadFailed: (details) { _showMessage('Online PDF could not be embedded. Use the browser button to open it directly. ${details.description}'); },
                  ),
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String title;
  const _FeatureChip({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: pink, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

const Color pageBackground = AppColors.background;
const List<String> grades = ['A+', 'A', 'B', 'C', 'D', 'F'];

String gradeOf(double percentage) {
  if (percentage >= 90) return 'A+';
  if (percentage >= 80) return 'A';
  if (percentage >= 70) return 'B';
  if (percentage >= 60) return 'C';
  if (percentage >= 50) return 'D';
  return 'F';
}

Color gradeColor(String grade) {
  switch (grade) {
    case 'A+': return Colors.green;
    case 'A': return Colors.teal;
    case 'B': return Colors.blue;
    case 'C': return Colors.orange;
    case 'D': return Colors.deepOrange;
    default: return Colors.red;
  }
}

class MarkRecord {
  final String studentId;
  final String studentName;
  final String year;
  final String className;
  final String subject;
  final double marks;
  final double maxMarks;

  const MarkRecord({
    required this.studentId,
    required this.studentName,
    required this.year,
    required this.className,
    required this.subject,
    required this.marks,
    required this.maxMarks,
  });

  double get percentage => maxMarks > 0 ? marks * 100 / maxMarks : 0;
  String get grade => gradeOf(percentage);

  factory MarkRecord.fromJson(Map<String, dynamic> json) {
    double number(dynamic value, String field) {
      if (value is num) return value.toDouble();
      final parsed = double.tryParse('$value');
      if (parsed == null) {
        throw FormatException('Invalid or missing "$field".');
      }
      return parsed;
    }

    final studentId = '${json['studentId'] ?? ''}'.trim();
    final studentName = '${json['studentName'] ?? 'Unknown'}'.trim();
    final year = '${json['academicYear'] ?? ''}'.trim();
    final className = '${json['className'] ?? 'Unspecified'}'.trim();
    final subject = '${json['subject'] ?? ''}'.trim();
    final marks = number(json['marks'], 'marks');
    final maxMarks = number(json['maxMarks'] ?? 100, 'maxMarks');

    if (studentId.isEmpty || year.isEmpty || subject.isEmpty) {
      throw const FormatException(
        'Each record needs studentId, academicYear and subject.',
      );
    }
    if (maxMarks <= 0 || marks < 0 || marks > maxMarks) {
      throw FormatException(
        'Marks must be between 0 and maxMarks for student $studentId.',
      );
    }

    return MarkRecord(
      studentId: studentId,
      studentName: studentName.isEmpty ? 'Unknown' : studentName,
      year: year,
      className: className,
      subject: subject,
      marks: marks,
      maxMarks: maxMarks,
    );
  }
}

class MarksGraderApp extends StatelessWidget {
  const MarksGraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Granular Marks Grader',
      theme: AppTheme.dark(),
      home: const GranularDashboardPage(),
    );
  }
}

class GranularDashboardPage extends StatefulWidget {
  const GranularDashboardPage({super.key});

  @override
  State<GranularDashboardPage> createState() => _GranularDashboardPageState();
}

class _GranularDashboardPageState extends State<GranularDashboardPage> {
  List<MarkRecord> records = [];
  String selectedYear = 'All';
  String selectedClass = 'All';
  String selectedSubject = 'All';
  String fileName = '';
  int selectedTab = 0;
  bool loading = false;

  List<MarkRecord> get filtered => records.where((r) {
    return (selectedYear == 'All' || r.year == selectedYear) &&
        (selectedClass == 'All' || r.className == selectedClass) &&
        (selectedSubject == 'All' || r.subject == selectedSubject);
  }).toList();

  List<String> get years => _options((r) => r.year);
  List<String> get classes => _options((r) => r.className);
  List<String> get subjects => _options((r) => r.subject);

  List<String> _options(String Function(MarkRecord) field) {
    final values = records.map(field).toSet().toList()..sort();
    return ['All', ...values];
  }

  int get studentCount => filtered.map((r) => r.studentId).toSet().length;

  double get average => filtered.isEmpty
      ? 0
      : filtered.fold<double>(0, (sum, r) => sum + r.percentage) /
          filtered.length;

  double get passRate => filtered.isEmpty
      ? 0
      : filtered.where((r) => r.percentage >= 50).length *
          100 / filtered.length;

  Future<void> uploadJson() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isEmpty) return;

      final bytes = await files.single.readAsBytes();

      final decoded = jsonDecode(utf8.decode(bytes));
      dynamic raw;
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map) {
        raw = decoded['records'] ?? decoded['marks'] ?? decoded['results'];
      }

      if (raw is! List || raw.isEmpty) {
        throw const FormatException(
          'JSON must be an array or contain a non-empty records, marks or results array.',
        );
      }

      final parsed = raw.map((item) {
        if (item is! Map) {
          throw const FormatException('Every record must be a JSON object.');
        }
        return MarkRecord.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      if (!mounted) return;
      setState(() {
        records = parsed;
fileName = files.single.name; 
        selectedYear = 'All';
        selectedClass = 'All';
        selectedSubject = 'All';
        selectedTab = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${parsed.length} records imported successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<String, int> gradeDistribution(List<MarkRecord> data) {
    final counts = {for (final grade in grades) grade: 0};
    for (final record in data) {
      counts[record.grade] = counts[record.grade]! + 1;
    }
    return counts;
  }

  Widget metric(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 9),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: navy,
              )),
            ),
            Text(title, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(title, style: const TextStyle(
      fontSize: 18, fontWeight: FontWeight.bold, color: navy,
    )),
  );

  Widget filter(String title, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: title,
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: options.map((e) => DropdownMenuItem(
        value: e, child: Text(e, overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget gradeBar(String grade, int count, int total) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 36, child: Text(grade,
          style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction, minHeight: 13,
            backgroundColor: AppColors.line,
            color: gradeColor(grade),
          ),
        )),
        const SizedBox(width: 9),
        SizedBox(width: 88, child: Text(
          '$count (${(fraction * 100).toStringAsFixed(1)}%)',
          textAlign: TextAlign.right, style: const TextStyle(fontSize: 12),
        )),
      ]),
    );
  }

  Widget statRow(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label), Text('$value',
        style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  Widget buildDashboard() {
    final counts = gradeDistribution(filtered);
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Academic Performance', style: TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, color: navy,
      )),
      const SizedBox(height: 5),
      Text(fileName.isEmpty
          ? 'Upload historical marks in JSON format.'
          : 'Loaded dataset: $fileName'),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: loading ? null : uploadJson,
        icon: loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file),
        label: Text(loading ? 'Importing...' : 'Upload Academic Marks JSON'),
        style: FilledButton.styleFrom(
          backgroundColor: blue, padding: const EdgeInsets.all(16),
        ),
      )),
      sectionTitle('Filters'),
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth > 650
            ? (constraints.maxWidth - 20) / 3
            : (constraints.maxWidth - 10) / 2;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(width: width, child: filter('Academic Year', selectedYear,
            years, (v) => setState(() => selectedYear = v ?? 'All'))),
          SizedBox(width: width, child: filter('Class', selectedClass,
            classes, (v) => setState(() => selectedClass = v ?? 'All'))),
          SizedBox(width: width, child: filter('Subject', selectedSubject,
            subjects, (v) => setState(() => selectedSubject = v ?? 'All'))),
        ]);
      }),
      sectionTitle('Performance Overview'),
      GridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 650 ? 4 : 2,
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.55, crossAxisSpacing: 10, mainAxisSpacing: 10,
        children: [
          metric('Unique Students', '$studentCount', Icons.people, blue),
          metric('Subject Results', '${filtered.length}', Icons.assignment, pink),
          metric('Average Marks', '${average.toStringAsFixed(1)}%',
              Icons.analytics, Colors.purple),
          metric('Pass Rate', '${passRate.toStringAsFixed(1)}%',
              Icons.check_circle, Colors.green),
        ],
      ),
      sectionTitle('Grade Distribution'),
      ...grades.map((g) => gradeBar(g, counts[g] ?? 0, filtered.length)),
      sectionTitle('Quick Statistics'),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        children: [
          statRow('Distinction (90%+)',
              filtered.where((r) => r.percentage >= 90).length),
          statRow('First class (60%+)',
              filtered.where((r) => r.percentage >= 60).length),
          statRow('Passed (50%+)',
              filtered.where((r) => r.percentage >= 50).length),
          statRow('Failed (below 50%)',
              filtered.where((r) => r.percentage < 50).length),
        ],
      ))),
    ]);
  }

  Widget buildMarks() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      sectionTitle('Granular Student Marks'),
      Text('${filtered.length} subject results in current filter'),
      const SizedBox(height: 10),
      if (filtered.isEmpty)
        const Padding(padding: EdgeInsets.all(24),
          child: Center(child: Text('Upload a JSON dataset to view marks.'))),
      ...filtered.map((r) => Card(child: ListTile(
        leading: CircleAvatar(
          backgroundColor: blue.withOpacity(0.10),
          child: Text(r.studentName.isEmpty ? '?' : r.studentName[0].toUpperCase()),
        ),
        title: Text(r.studentName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${r.studentId} • ${r.year} • ${r.className}\n'
          '${r.subject} • ${r.marks}/${r.maxMarks}',
        ),
        isThreeLine: true,
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(r.grade, style: TextStyle(
            color: gradeColor(r.grade), fontWeight: FontWeight.bold, fontSize: 18,
          )),
          Text('${r.percentage.toStringAsFixed(1)}%'),
        ]),
      ))),
    ]);
  }

  Widget buildMatrix() {
    final allYears = records.map((r) => r.year).toSet().toList()..sort();
    final matrix = <String, Map<String, int>>{};
    for (final year in allYears) {
      matrix[year] = {for (final g in grades) g: 0};
      for (final r in records.where((x) => x.year == year)) {
        matrix[year]![r.grade] = matrix[year]![r.grade]! + 1;
      }
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      sectionTitle('Historical Grade Distribution Matrix'),
      const Text('Rows are academic years; columns are grade counts.'),
      const SizedBox(height: 12),
      if (records.isEmpty)
        const Text('Upload JSON to generate the historical matrix.')
      else
        Card(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(navy),
            headingTextStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold,
            ),
            columns: [
              const DataColumn(label: Text('Year')),
              ...grades.map((g) => DataColumn(label: Text(g))),
              const DataColumn(label: Text('Total')),
            ],
            rows: allYears.map((year) {
              final counts = matrix[year]!;
              final total = counts.values.fold<int>(0, (a, b) => a + b);
              return DataRow(cells: [
                DataCell(Text(year)),
                ...grades.map((g) => DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: gradeColor(g).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${counts[g]}'),
                ))),
                DataCell(Text('$total',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              ]);
            }).toList(),
          ),
        )),
      sectionTitle('Historical Distribution Percentages'),
      ...allYears.map((year) {
        final counts = matrix[year]!;
        final total = counts.values.fold<int>(0, (a, b) => a + b);
        return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(year, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 9),
            ...grades.map((g) => gradeBar(g, counts[g]!, total)),
          ],
        )));
      }),
    ]);
  }

  Widget buildSubjects() {
    final names = records.map((r) => r.subject).toSet().toList()..sort();
    return ListView(padding: const EdgeInsets.all(16), children: [
      sectionTitle('Subject-wise Academic Analytics'),
      if (records.isEmpty)
        const Text('Upload JSON to view subject analytics.'),
      ...names.map((subject) {
        final data = records.where((r) => r.subject == subject).toList();
        final avg = data.fold<double>(0, (sum, r) => sum + r.percentage) /
            data.length;
        final passed = data.where((r) => r.percentage >= 50).length;
        return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18,
            )),
            const SizedBox(height: 9),
            Text('Results: ${data.length}'),
            Text('Average: ${avg.toStringAsFixed(1)}%'),
            Text('Pass rate: ${(passed * 100 / data.length).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (avg / 100).clamp(0.0, 1.0),
              minHeight: 9, color: pink,
              backgroundColor: AppColors.line,
            ),
          ],
        )));
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [buildDashboard(), buildMarks(), buildMatrix(), buildSubjects()];
    const titles = [
      'Academic Dashboard', 'Marks Grader', 'Historical Matrix', 'Subject Analytics',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedTab]),
        actions: [
          IconButton(
            tooltip: 'Upload JSON',
            onPressed: loading ? null : uploadJson,
            icon: const Icon(Icons.upload_file),
          ),
        ],
      ),
      body: pages[selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.grading), label: 'Marks'),
          NavigationDestination(icon: Icon(Icons.grid_on), label: 'Matrix'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Subjects'),
        ],
      ),
    );
  }
}

// ============================================================================
// SCRIPTGRADE PRO - FLUTTER CLIENT
// Architecture: UI -> ChangeNotifier store -> REST API -> FastAPI/SQLite/OCR
// ============================================================================

const Color sgNavy = AppColors.text;
const Color sgBlue = AppColors.blue;
const Color sgPink = AppColors.pink;
const Color sgCanvas = AppColors.background;
const Color sgBorder = AppColors.line;
const Color sgMuted = AppColors.muted;
const String defaultApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');



// ============================================================================
// DATA MODELS
// ============================================================================

class QuestionModel {
  final int id;
  final String code;
  final String title;
  final String subject;
  final String prompt;
  final String modelAnswer;
  final double maxMarks;
  final List<String> keywords;
  final List<Map<String, dynamic>> rubric;
  final bool isActive;
  final DateTime? createdAt;

  const QuestionModel({
    required this.id,
    required this.code,
    required this.title,
    required this.subject,
    required this.prompt,
    required this.modelAnswer,
    required this.maxMarks,
    required this.keywords,
    required this.rubric,
    required this.isActive,
    this.createdAt,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: _asInt(json['id']),
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled question',
      subject: json['subject']?.toString() ?? 'General',
      prompt: json['prompt']?.toString() ?? '',
      modelAnswer: json['model_answer']?.toString() ?? '',
      maxMarks: _asDouble(json['max_marks']),
      keywords: _asStringList(json['keywords']),
      rubric: _asMapList(json['rubric']),
      isActive: json['is_active'] != false,
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class SubmissionModel {
  final int id;
  final String publicId;
  final String studentName;
  final String studentId;
  final String examName;
  final int questionId;
  final String originalFilename;
  final String extractedText;
  final String correctedText;
  final double suggestedMarks;
  final double finalMarks;
  final double maxMarks;
  final Map<String, dynamic> gradingDetails;
  final String feedback;
  final String status;
  final double ocrConfidence;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const SubmissionModel({
    required this.id,
    required this.publicId,
    required this.studentName,
    required this.studentId,
    required this.examName,
    required this.questionId,
    required this.originalFilename,
    required this.extractedText,
    required this.correctedText,
    required this.suggestedMarks,
    required this.finalMarks,
    required this.maxMarks,
    required this.gradingDetails,
    required this.feedback,
    required this.status,
    required this.ocrConfidence,
    this.createdAt,
    this.reviewedAt,
  });

  bool get isReviewed => status == 'reviewed';

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    return SubmissionModel(
      id: _asInt(json['id']),
      publicId: json['public_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      examName: json['exam_name']?.toString() ?? '',
      questionId: _asInt(json['question_id']),
      originalFilename: json['original_filename']?.toString() ?? '',
      extractedText: json['extracted_text']?.toString() ?? '',
      correctedText: json['corrected_text']?.toString() ?? '',
      suggestedMarks: _asDouble(json['suggested_marks']),
      finalMarks: _asDouble(json['final_marks']),
      maxMarks: _asDouble(json['max_marks_snapshot']),
      gradingDetails: _asMap(json['grading_details']),
      feedback: json['teacher_feedback']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      ocrConfidence: _asDouble(json['ocr_confidence']),
      createdAt: _parseDate(json['created_at']),
      reviewedAt: _parseDate(json['reviewed_at']),
    );
  }
}

class DashboardModel {
  final int questionCount;
  final int submissionCount;
  final int pendingCount;
  final int reviewedCount;
  final double averagePercentage;
  final double marksAwarded;
  final double marksAvailable;

  const DashboardModel({
    required this.questionCount,
    required this.submissionCount,
    required this.pendingCount,
    required this.reviewedCount,
    required this.averagePercentage,
    required this.marksAwarded,
    required this.marksAvailable,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      questionCount: _asInt(json['question_count']),
      submissionCount: _asInt(json['submission_count']),
      pendingCount: _asInt(json['pending_count']),
      reviewedCount: _asInt(json['reviewed_count']),
      averagePercentage: _asDouble(json['average_percentage']),
      marksAwarded: _asDouble(json['marks_awarded']),
      marksAvailable: _asDouble(json['marks_available']),
    );
  }
}

class OcrPreview {
  final String text;
  final double confidence;
  final List<String> warnings;
  final String filename;

  const OcrPreview({
    required this.text,
    required this.confidence,
    required this.warnings,
    required this.filename,
  });

  factory OcrPreview.fromJson(Map<String, dynamic> json) {
    return OcrPreview(
      text: json['text']?.toString() ?? '',
      confidence: _asDouble(json['confidence']),
      warnings: _asStringList(json['warnings']),
      filename: json['filename']?.toString() ?? '',
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return <String>[];
  return value.map((e) => e.toString()).toList();
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

// ============================================================================
// REST API SERVICE
// ============================================================================

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ScriptGradeApi {
  String baseUrl;
  final http.Client _client;

  ScriptGradeApi({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$normalized$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => const {
        'Accept': 'application/json',
      };

  Future<dynamic> _decode(http.Response response) async {
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      data = response.body;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Server error (${response.statusCode})';
      if (data is Map && data['detail'] != null) {
        message = data['detail'].toString();
      }
      throw ApiException(message, statusCode: response.statusCode);
    }
    return data;
  }

  Future<Map<String, dynamic>> getHealth() async {
    final response = await _client
        .get(_uri('/api/health'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    return Map<String, dynamic>.from(await _decode(response) as Map);
  }

  Future<DashboardModel> getDashboard() async {
    final response = await _client
        .get(_uri('/api/dashboard'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    return DashboardModel.fromJson(
      Map<String, dynamic>.from(await _decode(response) as Map),
    );
  }

  Future<List<QuestionModel>> getQuestions({bool activeOnly = true}) async {
    final response = await _client.get(
      _uri('/api/questions', {'active_only': '$activeOnly'}),
      headers: _headers,
    );
    final data = await _decode(response) as List;
    return data
        .map((item) => QuestionModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<QuestionModel> createQuestion(Map<String, dynamic> payload) async {
    final response = await _client.post(
      _uri('/api/questions'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return QuestionModel.fromJson(
      Map<String, dynamic>.from(await _decode(response) as Map),
    );
  }

  Future<QuestionModel> updateQuestion(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.patch(
      _uri('/api/questions/$id'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return QuestionModel.fromJson(
      Map<String, dynamic>.from(await _decode(response) as Map),
    );
  }

  Future<void> deleteQuestion(int id) async {
    final response = await _client.delete(
      _uri('/api/questions/$id'),
      headers: _headers,
    );
    await _decode(response);
  }

  Future<OcrPreview> previewOcr(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest('POST', _uri('/api/ocr'));
    request.headers.addAll(_headers);
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename,
    ));
    final streamed = await request.send().timeout(
          const Duration(minutes: 2),
        );
    final response = await http.Response.fromStream(streamed);
    return OcrPreview.fromJson(
      Map<String, dynamic>.from(await _decode(response) as Map),
    );
  }

  Future<SubmissionModel> createSubmission({
    required String studentName,
    required String studentId,
    required String examName,
    required int questionId,
    required String correctedText,
    Uint8List? imageBytes,
    String? filename,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/submissions'));
    request.headers.addAll(_headers);
    request.fields.addAll({
      'student_name': studentName,
      'student_id': studentId,
      'exam_name': examName,
      'question_id': '$questionId',
      'corrected_text': correctedText,
    });
    if (imageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename ?? 'answer.jpg',
      ));
    }
    final streamed = await request.send().timeout(
          const Duration(minutes: 3),
        );
    final response = await http.Response.fromStream(streamed);
    return SubmissionModel.fromJson(
      Map<String, dynamic>.from(await _decode(response) as Map),
    );
  }

  Future<List<SubmissionModel>> getSubmissions({
    String? status,
    String? student,
    int? questionId,
  }) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status_filter'] = status;
    if (student != null && student.isNotEmpty) query['student'] = student;
    if (questionId != null) query['question_id'] = '$questionId';
    final response = await _client.get(
      _uri('/api/submissions', query),
      headers: _headers,
    );
    final data = await _decode(response) as List;
    return data
        .map((item) => SubmissionModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<SubmissionModel> getSubmission(String publicId) async {
    final response = await _client.get(
      _uri('/api/submissions/$publicId'),
      headers: _headers,
    );
    return SubmissionModel.fromJson(
      Map<String, dynamic>.from(await _decode(response) as Map),
    );
  }

  Future<SubmissionModel> regrade(
    String publicId,
    String answerText,
  ) async {
    final response = await _client.post(
      _uri('/api/submissions/$publicId/regrade'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'answer_text': answerText}),
    );
    return SubmissionModel.fromJson(
      Map<String, dynamic>.from(await _decode(response) as Map),
    );
  }

  Future<SubmissionModel> reviewSubmission({
    required String publicId,
    required String correctedText,
    required double finalMarks,
    required String feedback,
  }) async {
    final response = await _client.patch(
      _uri('/api/submissions/$publicId/review'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'corrected_text': correctedText,
        'final_marks': finalMarks,
        'teacher_feedback': feedback,
      }),
    );
    return SubmissionModel.fromJson(
      Map<String, dynamic>.from(await _decode(response) as Map),
    );
  }

  Future<List<Map<String, dynamic>>> getQuestionAnalytics() async {
    final response = await _client.get(_uri('/api/analytics/questions'));
    final data = await _decode(response) as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getStudentAnalytics() async {
    final response = await _client.get(_uri('/api/analytics/students'));
    final data = await _decode(response) as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void close() => _client.close();
}

// ============================================================================
// APPLICATION STATE / PROVIDER
// ============================================================================

class ScriptGradeStore extends ChangeNotifier {
  late SharedPreferences _preferences;
  late ScriptGradeApi api;
  String apiUrl = defaultApiUrl;
  String teacherName = 'Teacher';
  bool isLoading = false;
  bool isConnected = false;
  String? lastError;
  Map<String, dynamic> health = {};
  DashboardModel? dashboard;
  List<QuestionModel> questions = [];
  List<SubmissionModel> submissions = [];
  List<Map<String, dynamic>> questionAnalytics = [];
  List<Map<String, dynamic>> studentAnalytics = [];

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    apiUrl = _preferences.getString('sg_api_url') ?? defaultApiUrl;
    teacherName = _preferences.getString('sg_teacher_name') ?? 'Teacher';
    api = ScriptGradeApi(baseUrl: apiUrl);
    await refreshAll(silent: true);
  }

  Future<void> setConnection(String url) async {
    apiUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    await _preferences.setString('sg_api_url', apiUrl);
    api = ScriptGradeApi(baseUrl: apiUrl);
    await refreshAll();
  }

  Future<void> setTeacherName(String name) async {
    teacherName = name.trim().isEmpty ? 'Teacher' : name.trim();
    await _preferences.setString('sg_teacher_name', teacherName);
    notifyListeners();
  }

  Future<void> refreshAll({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      lastError = null;
      notifyListeners();
    }
    try {
      health = await api.getHealth();
      isConnected = health['status'] == 'ok';
      final results = await Future.wait([
        api.getDashboard(),
        api.getQuestions(activeOnly: false),
        api.getSubmissions(),
        api.getQuestionAnalytics(),
        api.getStudentAnalytics(),
      ]);
      dashboard = results[0] as DashboardModel;
      questions = results[1] as List<QuestionModel>;
      submissions = results[2] as List<SubmissionModel>;
      questionAnalytics = results[3] as List<Map<String, dynamic>>;
      studentAnalytics = results[4] as List<Map<String, dynamic>>;
    } catch (error) {
      isConnected = false;
      lastError = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createQuestion(Map<String, dynamic> payload) async {
    await api.createQuestion(payload);
    await refreshAll();
  }

  Future<void> updateQuestion(
    int id,
    Map<String, dynamic> payload,
  ) async {
    await api.updateQuestion(id, payload);
    await refreshAll();
  }

  Future<void> deleteQuestion(int id) async {
    await api.deleteQuestion(id);
    await refreshAll();
  }

  Future<OcrPreview> previewOcr(Uint8List bytes, String filename) {
    return api.previewOcr(bytes, filename);
  }

  Future<SubmissionModel> createSubmission({
    required String studentName,
    required String studentId,
    required String examName,
    required int questionId,
    required String correctedText,
    Uint8List? imageBytes,
    String? filename,
  }) async {
    final result = await api.createSubmission(
      studentName: studentName,
      studentId: studentId,
      examName: examName,
      questionId: questionId,
      correctedText: correctedText,
      imageBytes: imageBytes,
      filename: filename,
    );
    await refreshAll(silent: true);
    return result;
  }

  Future<SubmissionModel> regrade(
    String publicId,
    String answer,
  ) async {
    final result = await api.regrade(publicId, answer);
    await refreshAll(silent: true);
    return result;
  }

  Future<SubmissionModel> review({
    required String publicId,
    required String correctedText,
    required double finalMarks,
    required String feedback,
  }) async {
    final result = await api.reviewSubmission(
      publicId: publicId,
      correctedText: correctedText,
      finalMarks: finalMarks,
      feedback: feedback,
    );
    await refreshAll();
    return result;
  }

  QuestionModel? questionById(int id) {
    for (final question in questions) {
      if (question.id == id) return question;
    }
    return null;
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }
}

// ============================================================================
// APP ROOT AND NAVIGATION
// ============================================================================

class ScriptGradeApp extends StatelessWidget {
  const ScriptGradeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScriptGrade Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    QuestionBankScreen(),
    ScanAnswerScreen(),
    SubmissionListScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    'Overview',
    'Question bank',
    'Scan answer',
    'Grading review',
    'Analytics',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;
    final store = context.watch<ScriptGradeStore>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sgBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'ScriptGrade Pro',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            if (wide)
              Text(
                _titles[selectedIndex],
                style: const TextStyle(
                  color: sgMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: 14),
            ConnectionPill(connected: store.isConnected),
          ],
        ),
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                setState(() => selectedIndex = value);
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Overview'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books),
                  label: Text('Questions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.document_scanner_outlined),
                  selectedIcon: Icon(Icons.document_scanner),
                  label: Text('Scan'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.rate_review_outlined),
                  selectedIcon: Icon(Icons.rate_review),
                  label: Text('Review'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: Text('Analytics'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                setState(() => selectedIndex = value);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_books_outlined),
                  label: 'Questions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.document_scanner_outlined),
                  label: 'Scan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.rate_review_outlined),
                  label: 'Review',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  label: 'Stats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

// ============================================================================
// REUSABLE UI COMPONENTS
// ============================================================================

class ConnectionPill extends StatelessWidget {
  final bool connected;

  const ConnectionPill({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 6),
          Text(
            connected ? 'Backend online' : 'Backend offline',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  const ScreenBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: sgNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(color: sgMuted),
                          ),
                        ],
                      ),
                      ...actions,
                    ],
                  ),
                  const SizedBox(height: 22),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionHeading(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: sgNavy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(color: sgMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: sgNavy,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: sgMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    helper,
                    style: const TextStyle(fontSize: 10, color: sgMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 38, color: sgMuted),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: sgNavy,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: sgMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.amberSoft,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFF9A3412)),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DASHBOARD SCREEN
// ============================================================================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScriptGradeStore>();
    final dashboard = store.dashboard;

    return ScreenBody(
      title: 'Welcome back, ${store.teacherName}',
      subtitle: 'Monitor answer-sheet processing, grading and student outcomes.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => store.refreshAll(),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(context),
          const SizedBox(height: 18),
          if (store.lastError != null)
            ErrorBanner(
              message: store.lastError!,
              onRetry: () => store.refreshAll(),
            ),
          if (store.isLoading && dashboard == null)
            const LinearProgressIndicator(),
          if (dashboard != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth > 760 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: count,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.1,
                  children: [
                    MetricCard(
                      label: 'Question bank',
                      value: '${dashboard.questionCount}',
                      helper: 'Active questions',
                      icon: Icons.menu_book_rounded,
                      color: sgBlue,
                    ),
                    MetricCard(
                      label: 'Submissions',
                      value: '${dashboard.submissionCount}',
                      helper: 'All uploaded answers',
                      icon: Icons.assignment_turned_in_outlined,
                      color: sgPink,
                    ),
                    MetricCard(
                      label: 'Pending review',
                      value: '${dashboard.pendingCount}',
                      helper: 'Need teacher approval',
                      icon: Icons.pending_actions,
                      color: Colors.orange,
                    ),
                    MetricCard(
                      label: 'Average percentage',
                      value: '${dashboard.averagePercentage.toStringAsFixed(1)}%',
                      helper: 'Final awarded / available',
                      icon: Icons.insights,
                      color: Colors.green,
                    ),
                  ],
                );
              },
            ),
          ],
          const SectionHeading('Recent submissions'),
          if (store.submissions.isEmpty)
            const EmptyState(
              title: 'No submissions yet',
              detail: 'Create a question and scan a handwritten answer sheet.',
            )
          else
            ...store.submissions.take(6).map(
                  (item) => SubmissionListTile(item: item),
                ),
          const SectionHeading('Assessment workflow'),
          const WorkflowStep(
            number: '01',
            title: 'Set up the question',
            detail: 'Define the model answer, maximum marks, keywords and rubric.',
            icon: Icons.library_books_outlined,
          ),
          const WorkflowStep(
            number: '02',
            title: 'Scan handwritten responses',
            detail: 'Upload a clear answer image. The local OCR service extracts text.',
            icon: Icons.document_scanner_outlined,
          ),
          const WorkflowStep(
            number: '03',
            title: 'Review and finalize',
            detail: 'Correct recognition errors and approve the suggested marks.',
            icon: Icons.verified_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [sgNavy, Color(0xFF3346A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'HANDWRITTEN ASSESSMENT WORKSPACE',
                      style: TextStyle(
                        color: Color(0xFFB9C8FF),
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Scan. Understand. Review. Grade.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Offline OCR with explainable marking suggestions and teacher-controlled final results.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (constraints.maxWidth > 460) ...[
                const SizedBox(width: 18),
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFB9C8FF),
                  size: 72,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class WorkflowStep extends StatelessWidget {
  final String number;
  final String title;
  final String detail;
  final IconData icon;

  const WorkflowStep({
    super.key,
    required this.number,
    required this.title,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.blueSoft,
          child: Text(
            number,
            style: const TextStyle(
              color: sgBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(detail),
        trailing: Icon(icon, color: sgBlue),
      ),
    );
  }
}

// ============================================================================
// QUESTION BANK SCREEN AND FORM
// ============================================================================

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  String search = '';
  String subject = 'All';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScriptGradeStore>();
    final subjects = <String>{
      'All',
      ...store.questions.map((q) => q.subject),
    }.toList();
    final visible = store.questions.where((q) {
      final matchesText =
          '${q.title} ${q.code} ${q.prompt}'.toLowerCase().contains(search.toLowerCase());
      final matchesSubject = subject == 'All' || q.subject == subject;
      return matchesText && matchesSubject;
    }).toList();

    return ScreenBody(
      title: 'Question bank',
      subtitle: 'Manage model answers, marking criteria and maximum marks.',
      actions: [
        FilledButton.icon(
          onPressed: () => _openQuestionEditor(context),
          icon: const Icon(Icons.add),
          label: const Text('New question'),
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search questions...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => search = value),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: subjects.contains(subject) ? subject : 'All',
                items: subjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) => setState(() => subject = value ?? 'All'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const EmptyState(
              icon: Icons.library_books_outlined,
              title: 'No matching questions',
              detail: 'Create a new question or change your search.',
            )
          else
            ...visible.map(
              (question) => QuestionCard(
                question: question,
                onEdit: () => _openQuestionEditor(context, question: question),
                onDelete: () => _confirmDelete(context, question),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openQuestionEditor(
    BuildContext context, {
    QuestionModel? question,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => QuestionEditorDialog(question: question),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    QuestionModel question,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete question?'),
        content: Text(
          'Delete "${question.title}" and all submissions linked to it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<ScriptGradeStore>().deleteQuestion(question.id);
      } catch (error) {
        if (context.mounted) _showMessage(context, error.toString());
      }
    }
  }
}

class QuestionCard extends StatelessWidget {
  final QuestionModel question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const QuestionCard({
    super.key,
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question.title,
                    style: const TextStyle(
                      color: sgNavy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(label: Text('${question.maxMarks} marks')),
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit question',
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete question',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            Text(
              '${question.code}  •  ${question.subject}',
              style: const TextStyle(color: sgMuted, fontSize: 12),
            ),
            const SizedBox(height: 9),
            Text(question.prompt),
            const SizedBox(height: 10),
            const Text(
              'Model answer',
              style: TextStyle(
                color: sgBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(question.modelAnswer),
            const SizedBox(height: 10),
            const Text(
              'Marking keywords',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: question.keywords
                  .map(
                    (keyword) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(keyword),
                    ),
                  )
                  .toList(),
            ),
            if (question.rubric.isNotEmpty) ...[
              const Divider(height: 22),
              Text(
                '${question.rubric.length} rubric criteria configured',
                style: const TextStyle(color: sgMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class QuestionEditorDialog extends StatefulWidget {
  final QuestionModel? question;

  const QuestionEditorDialog({super.key, this.question});

  @override
  State<QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<QuestionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController code;
  late final TextEditingController title;
  late final TextEditingController subject;
  late final TextEditingController prompt;
  late final TextEditingController modelAnswer;
  late final TextEditingController maxMarks;
  late final TextEditingController keywords;
  late final TextEditingController rubricText;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    code = TextEditingController(text: q?.code ?? '');
    title = TextEditingController(text: q?.title ?? '');
    subject = TextEditingController(text: q?.subject ?? 'General');
    prompt = TextEditingController(text: q?.prompt ?? '');
    modelAnswer = TextEditingController(text: q?.modelAnswer ?? '');
    maxMarks = TextEditingController(text: q?.maxMarks.toString() ?? '10');
    keywords = TextEditingController(text: q?.keywords.join(', ') ?? '');
    rubricText = TextEditingController(
      text: q?.rubric.map((r) => '${r['name']}|${r['marks']}|${(r['keywords'] as List? ?? []).join(',')}').join('\n') ?? '',
    );
  }

  @override
  void dispose() {
    code.dispose();
    title.dispose();
    subject.dispose();
    prompt.dispose();
    modelAnswer.dispose();
    maxMarks.dispose();
    keywords.dispose();
    rubricText.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseRubric() {
    final result = <Map<String, dynamic>>[];
    for (final line in rubricText.text.split('\n')) {
      final parts = line.split('|');
      if (parts.length < 3) continue;
      final marks = double.tryParse(parts[1].trim());
      if (marks == null || marks <= 0) continue;
      result.add({
        'name': parts[0].trim(),
        'description': '',
        'marks': marks,
        'keywords': parts[2]
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      });
    }
    return result;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final payload = <String, dynamic>{
      'code': code.text.trim(),
      'title': title.text.trim(),
      'subject': subject.text.trim(),
      'prompt': prompt.text.trim(),
      'model_answer': modelAnswer.text.trim(),
      'max_marks': double.parse(maxMarks.text.trim()),
      'keywords': keywords.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'rubric': _parseRubric(),
    };
    try {
      final store = context.read<ScriptGradeStore>();
      if (widget.question == null) {
        await store.createQuestion(payload);
      } else {
        payload.remove('code');
        await store.updateQuestion(widget.question!.id, payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? 'Create question' : 'Edit question'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(code, 'Question code', required: true),
                _field(title, 'Question title', required: true),
                _field(subject, 'Subject'),
                _field(prompt, 'Question prompt', required: true, lines: 2),
                _field(modelAnswer, 'Model answer', required: true, lines: 4),
                _field(
                  maxMarks,
                  'Maximum marks',
                  required: true,
                  keyboard: TextInputType.number,
                ),
                _field(
                  keywords,
                  'Keywords separated by commas',
                  lines: 2,
                  hint: 'e.g. force, mass, acceleration',
                ),
                _field(
                  rubricText,
                  'Optional rubric: criterion|marks|keyword1,keyword2',
                  lines: 4,
                  hint: 'Definition|2|meaning,process\nFormula|3|f=ma,mass',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save question'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        minLines: lines,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? 'This field is required'
                : null
            : null,
      ),
    );
  }
}

// ============================================================================
// SCAN ANSWER SCREEN
// ============================================================================

class ScanAnswerScreen extends StatefulWidget {
  const ScanAnswerScreen({super.key});

  @override
  State<ScanAnswerScreen> createState() => _ScanAnswerScreenState();
}

class _ScanAnswerScreenState extends State<ScanAnswerScreen> {
  final _studentName = TextEditingController();
  final _studentId = TextEditingController();
  final _examName = TextEditingController(text: 'Practice assessment');
  final _answer = TextEditingController();
  final _picker = ImagePicker();

  int? selectedQuestionId;
  Uint8List? imageBytes;
  String? imageFilename;
  OcrPreview? ocrPreview;
  bool processing = false;
  bool saving = false;
  String? errorText;

  @override
  void dispose() {
    _studentName.dispose();
    _studentId.dispose();
    _examName.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _chooseImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2400,
      );
      if (file == null) return;
      setState(() {
        processing = true;
        errorText = null;
        imageFilename = file.name;
      });
      final bytes = await file.readAsBytes();
      final preview = await context
          .read<ScriptGradeStore>()
          .previewOcr(bytes, file.name);
      if (!mounted) return;
      setState(() {
        imageBytes = bytes;
        ocrPreview = preview;
        _answer.text = preview.text;
        processing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        processing = false;
        errorText = error.toString();
      });
    }
  }

  Future<void> _saveSubmission() async {
    final questionId = selectedQuestionId;
    if (_studentName.text.trim().isEmpty) {
      _showMessage(context, 'Enter the student name.');
      return;
    }
    if (questionId == null) {
      _showMessage(context, 'Select a question.');
      return;
    }
    if (_answer.text.trim().isEmpty && imageBytes == null) {
      _showMessage(context, 'Upload an answer image or enter answer text.');
      return;
    }
    setState(() => saving = true);
    try {
      final result = await context.read<ScriptGradeStore>().createSubmission(
            studentName: _studentName.text.trim(),
            studentId: _studentId.text.trim(),
            examName: _examName.text.trim(),
            questionId: questionId,
            correctedText: _answer.text.trim(),
            imageBytes: imageBytes,
            filename: imageFilename,
          );
      if (!mounted) return;
      _showMessage(
        context,
        'Saved. Suggested marks: ${result.suggestedMarks.toStringAsFixed(1)} / ${result.maxMarks}',
      );
      setState(() {
        _studentName.clear();
        _studentId.clear();
        _answer.clear();
        imageBytes = null;
        imageFilename = null;
        ocrPreview = null;
      });
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScriptGradeStore>();
    final activeQuestions = store.questions.where((q) => q.isActive).toList();
    selectedQuestionId ??=
        activeQuestions.isNotEmpty ? activeQuestions.first.id : null;
    final selected = store.questionById(selectedQuestionId ?? -1);

    return ScreenBody(
      title: 'Scan handwritten answer',
      subtitle: 'Capture or upload a page, extract text and correct it before grading.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (store.lastError != null)
            ErrorBanner(
              message: store.lastError!,
              onRetry: () => store.refreshAll(),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: _studentName,
                    decoration: const InputDecoration(
                      labelText: 'Student full name *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _studentId,
                    decoration: const InputDecoration(
                      labelText: 'Student / roll number',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _examName,
                    decoration: const InputDecoration(
                      labelText: 'Exam or assessment name',
                      prefixIcon: Icon(Icons.assignment_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedQuestionId,
                    decoration: const InputDecoration(
                      labelText: 'Select question *',
                      prefixIcon: Icon(Icons.quiz_outlined),
                    ),
                    items: activeQuestions
                        .map(
                          (q) => DropdownMenuItem(
                            value: q.id,
                            child: Text(
                              '${q.code} — ${q.title}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedQuestionId = value),
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    _QuestionPromptCard(question: selected),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: processing
                            ? null
                            : () => _chooseImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Take photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: processing
                            ? null
                            : () => _chooseImage(ImageSource.gallery),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Upload image'),
                      ),
                      if (imageBytes != null)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              imageBytes = null;
                              imageFilename = null;
                              ocrPreview = null;
                              _answer.clear();
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove image'),
                        ),
                    ],
                  ),
                  if (processing) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Running local OCR on the Python backend...'),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (ocrPreview != null) ...[
                    const SizedBox(height: 12),
                    OcrConfidencePanel(preview: ocrPreview!),
                  ],
                ],
              ),
            ),
          ),
          const SectionHeading('Extracted answer – editable text'),
          TextField(
            controller: _answer,
            minLines: 9,
            maxLines: 18,
            decoration: const InputDecoration(
              hintText: 'OCR text will appear here. Correct any recognition mistakes before saving.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving || processing || activeQuestions.isEmpty
                  ? null
                  : _saveSubmission,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Save answer and suggest marks'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionPromptCard extends StatelessWidget {
  final QuestionModel question;

  const _QuestionPromptCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question • ${question.maxMarks} marks',
            style: const TextStyle(
              color: sgNavy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(question.prompt),
        ],
      ),
    );
  }
}

class OcrConfidencePanel extends StatelessWidget {
  final OcrPreview preview;

  const OcrConfidencePanel({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final color = preview.confidence >= 65
        ? Colors.green
        : preview.confidence >= 35
            ? Colors.orange
            : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.document_scanner_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OCR confidence: ${preview.confidence.toStringAsFixed(1)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                preview.filename,
                style: const TextStyle(fontSize: 11, color: sgMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          if (preview.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...preview.warnings.map(
              (warning) => Text(
                '• $warning',
                style: const TextStyle(fontSize: 12, color: sgMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// SUBMISSIONS / TEACHER REVIEW
// ============================================================================

class SubmissionListScreen extends StatefulWidget {
  const SubmissionListScreen({super.key});

  @override
  State<SubmissionListScreen> createState() => _SubmissionListScreenState();
}

class _SubmissionListScreenState extends State<SubmissionListScreen> {
  String filter = 'all';
  String search = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScriptGradeStore>();
    final items = store.submissions.where((item) {
      final statusMatches = filter == 'all' ||
          (filter == 'pending' && !item.isReviewed) ||
          (filter == 'reviewed' && item.isReviewed);
      final text = '${item.studentName} ${item.studentId} ${item.examName}'.toLowerCase();
      return statusMatches && text.contains(search.toLowerCase());
    }).toList();

    return ScreenBody(
      title: 'Grading review',
      subtitle: 'Review extracted responses and approve final teacher-awarded marks.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => store.refreshAll(),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by student, roll number or exam...',
            ),
            onChanged: (value) => setState(() => search = value),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'reviewed', label: Text('Reviewed')),
            ],
            selected: {filter},
            onSelectionChanged: (values) =>
                setState(() => filter = values.first),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.rate_review_outlined,
              title: 'No submissions found',
              detail: 'Upload handwritten answer sheets to start reviewing.',
            )
          else
            ...items.map((item) => SubmissionListTile(item: item)),
        ],
      ),
    );
  }
}

class SubmissionListTile extends StatelessWidget {
  final SubmissionModel item;

  const SubmissionListTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScriptGradeStore>();
    final question = store.questionById(item.questionId);
    final color = item.isReviewed ? Colors.green : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.10),
          child: Icon(
            item.isReviewed ? Icons.verified_outlined : Icons.pending_actions,
            color: color,
          ),
        ),
        title: Text(
          item.studentName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${question?.title ?? 'Question #${item.questionId}'} • ${item.status.toUpperCase()}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.finalMarks.toStringAsFixed(1)} / ${item.maxMarks.toStringAsFixed(1)}',
              style: const TextStyle(
                color: sgNavy,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Suggested ${item.suggestedMarks.toStringAsFixed(1)}',
              style: const TextStyle(color: sgMuted, fontSize: 10),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewDetailScreen(publicId: item.publicId),
          ),
        ),
      ),
    );
  }
}

class ReviewDetailScreen extends StatefulWidget {
  final String publicId;

  const ReviewDetailScreen({super.key, required this.publicId});

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  final answerController = TextEditingController();
  final marksController = TextEditingController();
  final feedbackController = TextEditingController();
  SubmissionModel? item;
  bool loading = true;
  bool saving = false;
  bool regrading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    answerController.dispose();
    marksController.dispose();
    feedbackController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await context
          .read<ScriptGradeStore>()
          .api
          .getSubmission(widget.publicId);
      if (!mounted) return;
      setState(() {
        item = result;
        answerController.text = result.correctedText;
        marksController.text = result.finalMarks.toStringAsFixed(1);
        feedbackController.text = result.feedback;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }

  Future<void> _regrade() async {
    if (item == null || answerController.text.trim().isEmpty) return;
    setState(() => regrading = true);
    try {
      final updated = await context
          .read<ScriptGradeStore>()
          .regrade(item!.publicId, answerController.text.trim());
      if (!mounted) return;
      setState(() {
        item = updated;
        marksController.text = updated.suggestedMarks.toStringAsFixed(1);
      });
      _showMessage(context, 'Suggested marks recalculated.');
    } catch (exception) {
      if (mounted) _showMessage(context, exception.toString());
    } finally {
      if (mounted) setState(() => regrading = false);
    }
  }

  Future<void> _approve() async {
    final current = item;
    if (current == null) return;
    final marks = double.tryParse(marksController.text.trim());
    if (marks == null || marks < 0 || marks > current.maxMarks) {
      _showMessage(
        context,
        'Enter a valid mark between 0 and ${current.maxMarks}.',
      );
      return;
    }
    setState(() => saving = true);
    try {
      await context.read<ScriptGradeStore>().review(
            publicId: current.publicId,
            correctedText: answerController.text.trim(),
            finalMarks: marks,
            feedback: feedbackController.text.trim(),
          );
      if (!mounted) return;
      _showMessage(context, 'Teacher grade saved and approved.');
      Navigator.pop(context);
    } catch (exception) {
      if (mounted) _showMessage(context, exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null || item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review submission')),
        body: Center(child: Text(error ?? 'Submission not found')),
      );
    }
    final current = item!;
    final question = context
        .read<ScriptGradeStore>()
        .questionById(current.questionId);

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher review')),
      body: ScreenBody(
        title: current.studentName,
        subtitle: '${current.examName} • ${question?.title ?? 'Answer sheet'}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewSummaryCard(item: current),
            const SectionHeading('Question and marking guide'),
            if (question != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.prompt,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text('Model answer: ${question.modelAnswer}'),
                      const SizedBox(height: 8),
                      Text(
                        'Keywords: ${question.keywords.join(', ')}',
                        style: const TextStyle(color: sgMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            const SectionHeading('Correct OCR text'),
            TextField(
              controller: answerController,
              minLines: 9,
              maxLines: 18,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                hintText: 'Edit OCR transcription here...',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: regrading ? null : _regrade,
              icon: regrading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Recalculate suggested marks'),
            ),
            const SectionHeading('Final teacher grade'),
            TextField(
              controller: marksController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Final marks',
                helperText:
                    'Suggested: ${current.suggestedMarks} / ${current.maxMarks}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Teacher feedback',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : _approve,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified),
                label: const Text('Confirm and save final grade'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  final SubmissionModel item;

  const _ReviewSummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Wrap(
          spacing: 26,
          runSpacing: 12,
          children: [
            _summary('Suggested marks', '${item.suggestedMarks}', sgBlue),
            _summary('Final marks', '${item.finalMarks}', sgNavy),
            _summary(
              'OCR confidence',
              '${item.ocrConfidence.toStringAsFixed(1)}%',
              item.ocrConfidence >= 60 ? Colors.green : Colors.orange,
            ),
            _summary(
              'Status',
              item.status.toUpperCase(),
              item.isReviewed ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: sgMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ANALYTICS SCREEN
// ============================================================================

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScriptGradeStore>();
    final dashboard = store.dashboard;

    return ScreenBody(
      title: 'Performance analytics',
      subtitle: 'Understand grading workload and student performance.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => store.refreshAll(),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dashboard != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall awarded marks',
                      style: TextStyle(
                        color: sgNavy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${dashboard.averagePercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: sgBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value:
                          (dashboard.averagePercentage / 100).clamp(0.0, 1.0),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${dashboard.marksAwarded.toStringAsFixed(1)} awarded out of ${dashboard.marksAvailable.toStringAsFixed(1)} available marks',
                      style: const TextStyle(color: sgMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SectionHeading('Question-wise performance'),
          if (store.questionAnalytics.isEmpty)
            const EmptyState(
              title: 'No analytics yet',
              detail: 'Teacher-reviewed submissions will appear here.',
            )
          else
            ...store.questionAnalytics.map(
              (item) => _QuestionAnalyticsCard(data: item),
            ),
          const SectionHeading('Student performance'),
          if (store.studentAnalytics.isEmpty)
            const EmptyState(
              title: 'No reviewed student records',
              detail: 'Approve grades to build student performance summaries.',
            )
          else
            ...store.studentAnalytics.map(
              (item) => _StudentAnalyticsTile(data: item),
            ),
          const SectionHeading('Interpretation'),
          const InfoPanel(
            icon: Icons.info_outline,
            text:
                'Analytics use teacher-confirmed marks only for student-level performance. Pending OCR suggestions are not treated as final grades.',
          ),
        ],
      ),
    );
  }
}

class _QuestionAnalyticsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _QuestionAnalyticsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final percent = _asDouble(data['average_percentage']);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['title']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: sgNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 7),
            Text(
              '${data['reviewed_count'] ?? 0} reviewed of ${data['submission_count'] ?? 0} submissions',
              style: const TextStyle(color: sgMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAnalyticsTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _StudentAnalyticsTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final percent = _asDouble(data['percentage']);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.blueSoft,
          child: Text(
            (data['student_name']?.toString().isNotEmpty ?? false)
                ? data['student_name'].toString()[0].toUpperCase()
                : '?',
            style: const TextStyle(color: sgBlue, fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          data['student_name']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${data['submissions'] ?? 0} reviewed submissions'),
        trailing: Text(
          '${percent.toStringAsFixed(1)}%',
          style: const TextStyle(
            color: sgNavy,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoPanel({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: sgBlue),
        title: Text(text, style: const TextStyle(color: sgMuted)),
      ),
    );
  }
}

// ============================================================================
// SETTINGS SCREEN
// ============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController urlController;
  late TextEditingController teacherController;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<ScriptGradeStore>();
    urlController = TextEditingController(text: store.apiUrl);
    teacherController = TextEditingController(text: store.teacherName);
  }

  @override
  void dispose() {
    urlController.dispose();
    teacherController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final store = context.read<ScriptGradeStore>();
      await store.setTeacherName(teacherController.text);
      await store.setConnection(urlController.text);
      if (mounted) _showMessage(context, 'Settings saved.');
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScriptGradeStore>();
    return ScreenBody(
      title: 'Settings',
      subtitle: 'Configure the local Python backend and teacher workspace.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backend connection',
                    style: TextStyle(
                      color: sgNavy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      hintText: 'http://192.168.1.10:8000',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chrome on the same computer: http://127.0.0.1:8000\nAndroid emulator: http://10.0.2.2:8000\nPhysical Android device: use your computer LAN IP, e.g. http://192.168.1.10:8000',
                    style: TextStyle(color: sgMuted, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: teacherController,
                    decoration: const InputDecoration(
                      labelText: 'Teacher display name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(saving ? 'Saving...' : 'Save and test connection'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeading('Backend status'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConnectionPill(connected: store.isConnected),
                  const SizedBox(height: 12),
                  _statusLine('API URL', store.apiUrl),
                  _statusLine(
                    'Database',
                    store.health['database']?.toString() ?? 'Not connected',
                  ),
                  _statusLine(
                    'OCR engine',
                    store.health['ocr_engine']?.toString() ?? 'Unknown',
                  ),
                  _statusLine(
                    'OCR language',
                    store.health['ocr_language']?.toString() ?? 'Unknown',
                  ),
                  _statusLine(
                    'Tesseract available',
                    '${store.health['tesseract_available'] ?? false}',
                  ),
                ],
              ),
            ),
          ),
          const SectionHeading('Deployment notes'),
          const InfoPanel(
            icon: Icons.wifi,
            text:
                'Android and Chrome both call the Python backend. For a phone, the backend computer and phone must be on the same trusted Wi-Fi network.',
          ),
          const InfoPanel(
            icon: Icons.lock_outline,
            text:
                'This starter is intended for a trusted classroom LAN. Add teacher authentication, HTTPS and access controls before exposing it outside your network.',
          ),
        ],
      ),
    );
  }

  Widget _statusLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: sgMuted)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: sgNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SHARED HELPERS
// ============================================================================

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ============================================================================
// UNIFIED MODULE HOST: ScriptGrade uses the shared Flask backend and its own
// ChangeNotifier provider, while remaining inside this single Flutter app.
// ============================================================================
class ScriptGradeHost extends StatefulWidget {
  const ScriptGradeHost({super.key});
  @override
  State<ScriptGradeHost> createState() => _ScriptGradeHostState();
}

class _ScriptGradeHostState extends State<ScriptGradeHost> {
  late final ScriptGradeStore _store;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _store = ScriptGradeStore();
    _ready = _store.initialize();
  }

  @override
  void dispose() {
    try { _store.api.close(); } catch (_) {}
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: sgCanvas,
            body: Center(child: CircularProgressIndicator(color: sgPink)),
          );
        }
        return ChangeNotifierProvider<ScriptGradeStore>.value(
          value: _store,
          child: const ScriptGradeApp(),
        );
      },
    );
  }
}



// ============================================================================
// UTILITIES & BUILDERS — shared helpers for the expanded builder modules
// ============================================================================
Widget _builderScaffold(BuildContext context,String title,String subtitle,IconData icon,Widget content){
  return Scaffold(backgroundColor:AppColors.background,appBar:AppBar(title:Text(title),backgroundColor:AppColors.surface,foregroundColor:AppColors.text,elevation:0),body:Column(children:[Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(18,12,18,18),decoration:const BoxDecoration(gradient:LinearGradient(colors:[AppColors.blueSoft,AppColors.pinkSoft])),child:Row(children:[CircleAvatar(backgroundColor:AppColors.cardAlt,child:Icon(icon,color:AppColors.blue)),const SizedBox(width:12),Expanded(child:Text(subtitle,style:const TextStyle(color:AppColors.inkSoft)))]),),Expanded(child:content)]));
}
Widget _appField(TextEditingController c,String label,{int max=1,bool obscure=false})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:c,maxLines:obscure?1:max,obscureText:obscure,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),filled:true,fillColor:AppColors.field)));
Widget _resultPanel(String title,String text)=>Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.card,borderRadius:BorderRadius.circular(14),border:Border.all(color:AppColors.line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.bold,color:AppColors.blue)),const SizedBox(height:8),SelectableText(text)]));
Future<void> _copyText(BuildContext context,String value)async{await Clipboard.setData(ClipboardData(text:value));if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Copied to clipboard')));}
String _html(String s)=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#39;');



// ============================================================================
// TUITION BLUEPINK — ENTERPRISE MANAGEMENT WORKSPACE (9 functional UI modules)
// Appended module pack. These screens are client-side prototype workflows:
// connect authenticated backend endpoints before using them for live decisions.
// No camera-based proctoring, geolocation collection, firewall, DB routing, or
// tenant isolation is claimed by this local UI implementation.
// ============================================================================

const Color _entBlue = AppColors.blue;
const Color _entPink = AppColors.pink;
const Color _entInk = AppColors.text;
const Color _entCanvas = AppColors.background;
const Color _entLine = AppColors.line;

class _EnterpriseModulePage extends StatefulWidget {
  final int module;
  const _EnterpriseModulePage({required this.module});
  @override
  State<_EnterpriseModulePage> createState() => _EnterpriseModulePageState();
}

class _EnterpriseModulePageState extends State<_EnterpriseModulePage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _detail = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final List<String> _items = <String>[];
  final Map<String, bool> _switches = <String, bool>{};
  final Map<String, String> _attendance = <String, String>{
    'Aarav Sharma': 'Present',
    'Diya Iyer': 'Present',
    'Kabir Rao': 'Absent',
    'Meera Nair': 'Present',
    'Vihaan Das': 'Late',
  };
  int _selectedPeriod = 0;
  int _selectedTenant = 0;
  double _cpu = 42;
  double _storage = 61;
  bool _monitoring = false;
  bool _verified = false;

  static const List<Color> _moduleAccents = <Color>[
    AppColors.blue,
    AppColors.sky,
    AppColors.teal,
    AppColors.green,
    AppColors.amber,
    AppColors.orange,
    AppColors.pink,
    AppColors.purple,
    AppColors.red,
  ];
  Color get _accent => _moduleAccents[widget.module % _moduleAccents.length];
  Color get _accentAlt => _moduleAccents[(widget.module + 4) % _moduleAccents.length];

  static const List<String> _titles = <String>[
    'Educator Command Deck',
    'Real-Time Proctor & Attendance Monitor',
    'Live Class Institutional Scheduler',
    'Geospatial Centre & Teacher Evaluator',
    'Statistical Exam Multi-Graph Analytics',
    'Infrastructure Resource Usage Analytics',
    'Parent Supervision Gateway',
    'Global Enterprise Administration',
    'Super Admin Panel',
  ];
  static const List<String> _subtitles = <String>[
    'Assignment engine • grading pipelines • educator workload',
    'Attendance register • verification protocol • session oversight',
    'Institution calendar • live class planning • tenant schedules',
    'Centre directory • teacher allocation • location matrix',
    'Score distributions • subject comparisons • performance trends',
    'Compute telemetry • storage consumption • capacity planning',
    'Parent access • progress audit • permission gateway',
    'Platform settings • query routing policy • user authorization',
    'Tenant allocation • platform governance • API policy controls',
  ];
  static const List<IconData> _icons = <IconData>[
    Icons.assignment_turned_in, Icons.fact_check, Icons.calendar_month,
    Icons.location_on, Icons.query_stats, Icons.memory,
    Icons.family_restroom, Icons.admin_panel_settings, Icons.security,
  ];

  @override
  void dispose() {
    _name.dispose();
    _detail.dispose();
    _search.dispose();
    super.dispose();
  }

  void _addItem(String label) {
    final String value = _name.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name or title first.')),
      );
      return;
    }
    setState(() {
      _items.insert(0, '$value${label.isEmpty ? '' : ' • $label'}');
      _name.clear();
      _detail.clear();
    });
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _metric(String label, String value, IconData icon, {String? foot}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _entLine),
      ),
      child: Row(children: <Widget>[
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: _accent.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: _accent)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: _entInk, fontSize: 21, fontWeight: FontWeight.w800)),
          if (foot != null) Text(foot, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        ])),
      ]),
    );
  }

  Widget _section(String title, {String? subtitle, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 9),
      child: Row(children: <Widget>[
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _entInk)),
          if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ])),
        if (trailing != null) trailing,
      ]),
    );
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _entLine)),
    child: child,
  );

  Widget _field(String label, TextEditingController controller, {String? hint, int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller, maxLines: lines,
      decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: _entCanvas,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _entLine)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _entLine)))),
  );

  Widget _primaryButton(String label, VoidCallback action, {IconData icon = Icons.add}) => FilledButton.icon(
    onPressed: action, icon: Icon(icon), label: Text(label),
    style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: AppColors.background, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13)),
  );

  Widget _records(String emptyLabel) {
    final String q = _search.text.trim().toLowerCase();
    final List<String> visible = _items.where((e) => e.toLowerCase().contains(q)).toList();
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search records', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      if (visible.isEmpty) Padding(padding: const EdgeInsets.all(14), child: Center(child: Text(emptyLabel, style: const TextStyle(color: AppColors.muted))))
      else ...visible.map((e) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.description_outlined, color: _accent), title: Text(e), trailing: IconButton(icon: Icon(Icons.delete_outline, color: _accentAlt), onPressed: () => setState(() => _items.remove(e))))),
    ]));
  }

 Widget _barChart(
  String title,
  List<double> values,
  List<String> labels,
) {
  final double maxValue = values.isEmpty
      ? 1.0
      : values.reduce((a, b) => a > b ? a : b);

  return _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _entInk,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 176,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${values[i].round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 112,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              height: maxValue <= 0
                                  ? 0
                                  : 104 *
                                      values[i].clamp(0.0, 100.0) /
                                      100.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    _accentAlt,
                                    _accent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          i < labels.length ? labels[i] : '',
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _assignment() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: _metric('Assignments created', '${12 + _items.length}', Icons.assignment)), const SizedBox(width: 10), Expanded(child: _metric('Pending grading', '${8 - (_items.length > 7 ? 7 : _items.length)}', Icons.pending_actions))]),
    _section('Create assignment', subtitle: 'Add a task to the local educator workspace'),
    _panel(Column(children: <Widget>[_field('Assignment title', _name, hint: 'e.g. Algebra — Unit 3'), _field('Instructions / grading rubric', _detail, lines: 3), Align(alignment: Alignment.centerRight, child: _primaryButton('Create assignment', () => _addItem('Assignment')))])),
    _section('Grading pipeline', subtitle: 'Illustrative workload stages'),
    _panel(Column(children: <Widget>[
      _PipelineRow(label: 'Submitted', value: 86, color: _accent),
      _PipelineRow(label: 'Under review', value: 54, color: _accentAlt),
      _PipelineRow(label: 'Graded', value: 72, color: Color(0xFF0F9D78)),
    ])),
    _section('Assignment register'), _records('No assignments added yet.'),
  ]);

  Widget _proctor() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: _metric('Present', '${_attendance.values.where((e) => e == 'Present').length}', Icons.how_to_reg)), const SizedBox(width: 8), Expanded(child: _metric('Absent', '${_attendance.values.where((e) => e == 'Absent').length}', Icons.person_off))]),
    _section('Session verification panel', subtitle: 'Local controls only — no camera capture or identity verification is active'),
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Session monitoring mode'), subtitle: const Text('Enable a local session status indicator'), value: _monitoring, activeColor: _accent, onChanged: (v) => setState(() => _monitoring = v)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Manual identity checklist complete'), value: _verified, activeColor: _accentAlt, onChanged: (v) => setState(() => _verified = v)),
      Text(_monitoring ? 'Session status: monitoring enabled' : 'Session status: paused', style: const TextStyle(fontWeight: FontWeight.w700, color: _entInk)),
      Text(_verified ? 'Manual verification checklist marked complete.' : 'Manual verification is still pending.', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ])),
    _section('Attendance register', subtitle: 'Select a status for each demo learner'),
    _panel(Column(children: _attendance.keys.map((name) => Row(children: <Widget>[
      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
      DropdownButton<String>(value: _attendance[name], items: const <String>['Present', 'Absent', 'Late', 'Excused'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { if (v != null) setState(() => _attendance[name] = v); }),
    ])).toList())),
  ]);

  Widget _scheduler() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: _metric('Scheduled classes', '${6 + _items.length}', Icons.video_camera_front)), const SizedBox(width: 8), Expanded(child: _metric('Institutions', '04', Icons.apartment))]),
    _section('Create institutional class event'),
    _panel(Column(children: <Widget>[
      _field('Class / event title', _name, hint: 'e.g. Grade 10 Physics'),
      _field('Date, time, tenant and meeting details', _detail, hint: '2026-11-10 • 10:00 AM • Campus A', lines: 2),
      Align(alignment: Alignment.centerRight, child: _primaryButton('Add to calendar', () => _addItem('Class event'), icon: Icons.event_available)),
    ])),
    _section('Calendar overview'),
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      SegmentedButton<int>(segments: const <ButtonSegment<int>>[ButtonSegment(value: 0, label: Text('Day')), ButtonSegment(value: 1, label: Text('Week')), ButtonSegment(value: 2, label: Text('Month'))], selected: <int>{_selectedPeriod}, onSelectionChanged: (v) => setState(() => _selectedPeriod = v.first)),
      const SizedBox(height: 14),
      ...<String>['09:00  •  Mathematics — Room 204', '10:30  •  Science — Lab 1', '12:00  •  English — Online', '14:00  •  Assessment review — Hall B'].map((e) => ListTile(dense: true, leading: Icon(Icons.schedule, color: _accent), title: Text(e))),
      Text('View: ${<String>['Day', 'Week', 'Month'][_selectedPeriod]} (sample schedule)', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
    ])),
    _section('Added events'), _records('No calendar events created yet.'),
  ]);

  Widget _geospatial() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: _metric('Learning centres', '12', Icons.location_city)), const SizedBox(width: 8), Expanded(child: _metric('Teachers allocated', '48', Icons.co_present))]),
    _section('Institution location matrix', subtitle: 'Illustrative centre directory; no device location is collected'),
    _panel(Column(children: const <Widget>[
      _LocationRow(name: 'North Campus', detail: 'Teachers 12 • Rooms 18 • Capacity 420'),
      _LocationRow(name: 'Central Learning Hub', detail: 'Teachers 16 • Rooms 22 • Capacity 560'),
      _LocationRow(name: 'South Campus', detail: 'Teachers 10 • Rooms 14 • Capacity 300'),
      _LocationRow(name: 'West Assessment Centre', detail: 'Teachers 10 • Rooms 12 • Capacity 260'),
    ])),
    _section('Allocate teacher to centre'),
    _panel(Column(children: <Widget>[_field('Teacher / evaluator name', _name), _field('Centre, subject and capacity notes', _detail), Align(alignment: Alignment.centerRight, child: _primaryButton('Save allocation', () => _addItem('Centre allocation'), icon: Icons.add_location_alt))])),
    _section('Saved allocations'), _records('No teacher allocations saved.'),
  ]);

  Widget _examAnalytics() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: _metric('Average score', '76.4%', Icons.speed)), const SizedBox(width: 8), Expanded(child: _metric('Pass rate', '84%', Icons.verified))]),
    _section('Performance distributions', subtitle: 'Sample analytics data — replace with exam API results'),
    _barChart('Score bands', const <double>[18, 32, 64, 88, 53], const <String>['0–20', '21–40', '41–60', '61–80', '81–100']),
    _section('Subject performance'),
    _barChart('Average by subject', const <double>[78, 69, 86, 73, 91], const <String>['Maths', 'Sci', 'Eng', 'Hist', 'Comp']),
    _section('Report configuration'),
    _panel(Column(children: <Widget>[
      DropdownButtonFormField<String>(value: 'Term 1', decoration: const InputDecoration(labelText: 'Assessment period'), items: const <String>['Term 1', 'Term 2', 'Final examination'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => _notice('Selected ${v ?? 'period'}')),
      const SizedBox(height: 10), _field('Report label', _name, hint: 'e.g. Grade 8 — Term 1'), Align(alignment: Alignment.centerRight, child: _primaryButton('Save report label', () => _addItem('Analytics report'), icon: Icons.save)),
    ])),
    _section('Saved report labels'), _records('No report labels saved.'),
  ]);

  Widget _usageAnalytics() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: _metric('CPU utilization', '${_cpu.round()}%', Icons.memory)), const SizedBox(width: 8), Expanded(child: _metric('Storage used', '${_storage.round()}%', Icons.storage))]),
    _section('Infrastructure telemetry', subtitle: 'Interactive sample sliders, not live server telemetry'),
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('Compute / CPU capacity  ${_cpu.round()}%'), Slider(value: _cpu, min: 0, max: 100, divisions: 20, activeColor: _accent, onChanged: (v) => setState(() => _cpu = v)),
      Text('Storage capacity  ${_storage.round()}%'), Slider(value: _storage, min: 0, max: 100, divisions: 20, activeColor: _accentAlt, onChanged: (v) => setState(() => _storage = v)),
      const SizedBox(height: 8), _PipelineRow(label: 'CPU headroom', value: 100 - _cpu, color: _accent), _PipelineRow(label: 'Storage headroom', value: 100 - _storage, color: _accentAlt),
    ])),
    _section('Resource thresholds'),
    ...<String>['Notify at 75% CPU', 'Notify at 80% storage', 'Daily telemetry summary'].map((s) => SwitchListTile(title: Text(s), value: _switches[s] ?? true, activeColor: _accent, onChanged: (v) => setState(() => _switches[s] = v))),
  ]);

  Widget _parentGateway() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: _metric('Linked learners', '02', Icons.school)), const SizedBox(width: 8), Expanded(child: _metric('Reports available', '08', Icons.assessment))]),
    _section('Learner progress audit'),
    _panel(Column(children: <Widget>[
      _PipelineRow(label: 'Assignments completed', value: 82, color: _accent),
      _PipelineRow(label: 'Attendance', value: 94, color: _accentAlt),
      _PipelineRow(label: 'Learning goals', value: 68, color: Color(0xFF0F9D78)),
    ])),
    _section('Parent gateway permissions', subtitle: 'Local preference controls; enforce authorization on the backend'),
    ...<String>['View grades', 'View attendance', 'View assignment feedback', 'Receive class notifications', 'Download progress reports'].map((s) => SwitchListTile(title: Text(s), value: _switches[s] ?? true, activeColor: _accent, onChanged: (v) => setState(() => _switches[s] = v))),
    _section('Parent notes'),
    _panel(Column(children: <Widget>[_field('Note title', _name), _field('Observation / follow-up', _detail, lines: 2), Align(alignment: Alignment.centerRight, child: _primaryButton('Save parent note', () => _addItem('Parent note'), icon: Icons.note_add))])),
    _section('Saved notes'), _records('No parent notes saved.'),
  ]);

  Widget _admin() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    _section('Enterprise platform configuration', subtitle: 'UI policy switches; production enforcement belongs in backend services'),
    _panel(Column(children: <Widget>[
      ...<String>['Require verified email', 'Enable audit logging', 'Allow educator exports', 'Require multi-factor authentication', 'Enable maintenance banner'].map((s) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(s), value: _switches[s] ?? (s != 'Enable maintenance banner'), activeColor: _accent, onChanged: (v) => setState(() => _switches[s] = v))),
    ])),
    _section('User authorization registry'),
    _panel(Column(children: <Widget>[
      _field('User email / identifier', _name),
      DropdownButtonFormField<String>(value: 'Educator', decoration: const InputDecoration(labelText: 'Role'), items: const <String>['Student', 'Parent', 'Educator', 'Institution Admin', 'Auditor'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => _detail.text = v ?? 'Educator'),
      const SizedBox(height: 10), Align(alignment: Alignment.centerRight, child: _primaryButton('Add authorization record', () => _addItem(_detail.text.isEmpty ? 'Educator role' : _detail.text), icon: Icons.person_add_alt_1)),
    ])),
    _section('Authorization records'), _records('No local authorization records.'),
    _section('Query routing policy'),
    _panel(const Text('Configure database query routing, tenant scoping, input validation, rate limits and audit trails in the authenticated backend. This screen does not execute database queries.', style: TextStyle(color: AppColors.muted, height: 1.4))),
  ]);

  Widget _superAdmin() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: _metric('Tenant instances', '${3 + _items.length}', Icons.apartment)), const SizedBox(width: 8), Expanded(child: _metric('Policy status', 'Draft', Icons.policy))]),
    _section('Tenant allocation control'),
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      DropdownButtonFormField<int>(value: _selectedTenant, decoration: const InputDecoration(labelText: 'Tenant instance'), items: const <String>['BluePink Academy', 'North Campus', 'South Campus', 'Partner Institution'].asMap().entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => setState(() => _selectedTenant = v ?? 0)),
      const SizedBox(height: 10), _field('Allocation / instance note', _name), _field('Quota, modules and owner', _detail, lines: 2),
      Align(alignment: Alignment.centerRight, child: _primaryButton('Save tenant allocation', () => _addItem('Tenant ${_selectedTenant + 1} allocation'), icon: Icons.add_business)),
    ])),
    _section('Tenant allocations'), _records('No tenant allocation changes saved.'),
    _section('Platform security policy', subtitle: 'Display-only controls; no firewall or kernel configuration is changed here'),
    ...<String>['API gateway rate limiting required', 'Tenant isolation policy required', 'Admin actions require audit trail', 'Block unknown API origins'].map((s) => SwitchListTile(title: Text(s), value: _switches[s] ?? true, activeColor: _accentAlt, onChanged: (v) => setState(() => _switches[s] = v))),
    _panel(Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Icon(Icons.shield_outlined, color: _accentAlt), SizedBox(width: 10), Expanded(child: Text('Security boundary: real tenant allocation, API firewall rules, kernel-level controls and authorization must be implemented and verified server-side. This Flutter panel only captures configuration intent.', style: TextStyle(color: AppColors.muted, height: 1.4)))])),
  ]);

  Widget _bodyForModule() {
    switch (widget.module) {
      case 0: return _assignment();
      case 1: return _proctor();
      case 2: return _scheduler();
      case 3: return _geospatial();
      case 4: return _examAnalytics();
      case 5: return _usageAnalytics();
      case 6: return _parentGateway();
      case 7: return _admin();
      default: return _superAdmin();
    }
  }


@override
Widget build(BuildContext context) {
  final int i = widget.module;

  return Scaffold(
    backgroundColor: _entCanvas,
    appBar: AppBar(
      title: Text(
        _titles[i],
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _entInk,
        ),
      ),
      backgroundColor: AppColors.surface,
      foregroundColor: _entInk,
      elevation: 0,
      actions: <Widget>[
        IconButton(
          tooltip: 'Module information',
          onPressed: () {
            showAboutDialog(
              context: context,
              applicationName: _titles[i],
              children: <Widget>[
                Text(_subtitles[i]),
                const Text(
                  'Local prototype UI. Connect your authenticated API for live data.',
                ),
              ],
            );
          },
          icon: const Icon(Icons.info_outline),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                AppColors.blueSoft,
                AppColors.pinkSoft,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.surface,
                child: Icon(
                  _icons[i],
                  color: _accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _titles[i],
                      style: const TextStyle(
                        color: _entInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitles[i],
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.amberSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Color(0xFF7A5624),
            ),
          ),
          child: const Row(
            children: <Widget>[
              Icon(
                Icons.info_outline,
                color: AppColors.amber,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prototype workspace: sample values and local controls. Live integrations require backend APIs.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF805B16),
                  ),
                ),
              ),
            ],
          ),
        ),
        _bodyForModule(),
      ],
    ),
  );
}

}

class _PipelineRow extends StatelessWidget {
  final String label; final double value; final Color color;
  const _PipelineRow({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: Text(label)), Text('${value.round()}%', style: const TextStyle(fontWeight: FontWeight.w700))]),
    const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (value / 100).clamp(0, 1), minHeight: 9, color: color, backgroundColor: AppColors.line)),
  ]));
}

class _LocationRow extends StatelessWidget {
  final String name; final String detail;
  const _LocationRow({required this.name, required this.detail});
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(backgroundColor: AppColors.blueSoft, child: Icon(Icons.location_on, color: AppColors.sky)), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(detail));
}

class EducatorCommandDeckPage extends StatelessWidget { const EducatorCommandDeckPage({super.key}); @override Widget build(BuildContext context) => const _EnterpriseModulePage(module: 0); }
class ProctorAttendancePage extends StatelessWidget { const ProctorAttendancePage({super.key}); @override Widget build(BuildContext context) => const _EnterpriseModulePage(module: 1); }
class InstitutionalSchedulerPage extends StatelessWidget { const InstitutionalSchedulerPage({super.key}); @override Widget build(BuildContext context) => const _EnterpriseModulePage(module: 2); }
class GeospatialCentrePage extends StatelessWidget { const GeospatialCentrePage({super.key}); @override Widget build(BuildContext context) => const _EnterpriseModulePage(module: 3); }
class StatisticalExamAnalyticsPage extends StatelessWidget { const StatisticalExamAnalyticsPage({super.key}); @override Widget build(BuildContext context) => const _EnterpriseModulePage(module: 4); }
class InfrastructureUsagePage extends StatelessWidget { const InfrastructureUsagePage({super.key}); @override Widget build(BuildContext context) => const _EnterpriseModulePage(module: 5); }
class ParentSupervisionGatewayPage extends StatelessWidget { const ParentSupervisionGatewayPage({super.key}); @override Widget build(BuildContext context) => const _EnterpriseModulePage(module: 6); }
class GlobalEnterpriseAdminPage extends StatelessWidget { const GlobalEnterpriseAdminPage({super.key}); @override Widget build(BuildContext context) => const _EnterpriseModulePage(module: 7); }
class SuperAdminKernelPage extends StatelessWidget { const SuperAdminKernelPage({super.key}); @override Widget build(BuildContext context) => const _EnterpriseModulePage(module: 8); }


// ============================================================================
// ENTERPRISE MODULE INTEGRATION NOTES
// ============================================================================
// The nine management routes above now point to the detailed enterprise
// workspace pages instead of the previous placeholder-only pages. The module
// workspace includes local interactive workflows for assignment creation,
// grading pipeline visualization, attendance status changes, session setup,
// calendar event creation, centre/teacher allocation records, exam analytics,
// resource telemetry controls, parent permissions, administrator settings,
// and tenant policy drafts.
//
// Production requirements that remain server-side: authenticated role checks,
// persistent tenant-scoped records, real-time event transport, camera consent
// and proctoring review, device/location permission handling, geospatial APIs,
// metrics collection, database query routing, API gateway/firewall policies,
// tenant isolation, audit logging, and privileged kernel operations. The UI
// intentionally does not claim to enforce these security boundaries locally.
// ============================================================================



// ============================================================================
// FIREBASE AUTHENTICATION + PUSH NOTIFICATIONS
// ============================================================================

class FirebaseAuthGate extends StatelessWidget {
  final Widget child;
  const FirebaseAuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null ? const FirebaseLoginPage() : child;
      },
    );
  }
}

class FirebaseLoginPage extends StatefulWidget {
  const FirebaseLoginPage({super.key});

  @override
  State<FirebaseLoginPage> createState() => _FirebaseLoginPageState();
}

class _FirebaseLoginPageState extends State<FirebaseLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final email = _email.text.trim();
      if (_register) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
        await credential.user?.sendEmailVerification();
      } else {
        await auth.signInWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _authMessage(e.code));
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email already has an account.';
      case 'weak-password':
        return 'Choose a stronger password (at least 8 characters).';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      default:
        return 'Authentication error: $code';
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!_validEmail(email)) {
      setState(() => _error = 'Enter your valid email address first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent if the account exists.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _authMessage(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school, size: 58, color: AppColors.pink),
                        const SizedBox(height: 12),
                        const Text('TUITION AI ML',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_register ? 'Create your account' : 'Sign in to continue',
                            style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) => _validEmail(v ?? '') ? null : 'Enter a valid email',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _hidePassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _hidePassword = !_hidePassword),
                              icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                            ),
                          ),
                          validator: (v) {
                            final value = v ?? '';
                            if (value.length < 8) return 'Use at least 8 characters';
                            if (_register &&
                                (!RegExp(r'[A-Za-z]').hasMatch(value) ||
                                 !RegExp(r'\d').hasMatch(value))) {
                              return 'Use letters and numbers';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: AppColors.red)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(_register ? 'CREATE ACCOUNT' : 'SIGN IN'),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                          child: Text(_register
                              ? 'Already registered? Sign in'
                              : 'New user? Create an account'),
                        ),
                        if (!_register)
                          TextButton(
                            onPressed: _busy ? null : _resetPassword,
                            child: const Text('Forgot password?'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('FCM background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static String? fcmToken;
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<User?>? _authSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'tuition_ai_updates',
    'Tuition AI updates',
    description: 'Learning, assessment and account notifications',
    importance: Importance.high,
  );

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
                   defaultTargetPlatform == TargetPlatform.iOS);

 static Future<void> initialize() async {
  if (!_supported || _ready) return;

  await _messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  const InitializationSettings initializationSettings =
      InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await _local.initialize(initializationSettings);

  final android = _local.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await android?.createNotificationChannel(_channel);
  await android?.requestNotificationsPermission();

  await _messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  try {
    fcmToken = await _messaging.getToken();
    await _saveToken();
  } catch (e) {
    debugPrint('FCM token retrieval failed: $e');
  }

  _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
    fcmToken = token;
    await _saveToken();
  });

  _authSubscription =
      FirebaseAuth.instance.authStateChanges().listen((_) {
    _saveToken();
  });

  _foregroundSubscription =
      FirebaseMessaging.onMessage.listen((message) async {
    final notification = message.notification;

    if (notification != null) {
      await showLocal(
        notification.title ?? 'Tuition AI update',
        notification.body ?? '',
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    debugPrint('Notification opened: ${message.data}');
  });

  final initial = await _messaging.getInitialMessage();

  if (initial != null) {
    debugPrint('App opened from notification: ${initial.data}');
  }

  _ready = true;
}

  static Future<void> _saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = fcmToken;
    if (user == null || token == null || token.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not save FCM token to Firestore: $e');
    }
  }

  static Future<void> showLocal(String title, String body) async {
  if (!_supported || !_ready) return;

  await _local.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );
}

  static Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    await _foregroundSubscription?.cancel();
  }
}



// ============================================================================
// INTEGRATED LEARNING MODULES
// These pages are part of main.dart; no learning_modules.dart import required.
// ============================================================================

class _IntegratedLearningPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget content;

  const _IntegratedLearningPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2962FF), Color(0xFF7C4DFF), Color(0xFFFF4081)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(
                        color: Colors.white, fontSize: 21,
                        fontWeight: FontWeight.bold,
                      )),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          content,
        ],
      ),
    );
  }
}

class _IntegratedLearningTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IntegratedLearningTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.13),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// 1. Learning Hub
class LearningHubPage extends StatelessWidget {
  const LearningHubPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return _IntegratedLearningPage(
      title: 'Learning Hub',
      subtitle: 'Your digital classroom and study centre',
      icon: Icons.school,
      content: Column(children: [
        _IntegratedLearningTile(
          title: 'Ebook and PDF Reader',
          subtitle: 'Read and organise study material',
          icon: Icons.picture_as_pdf,
          color: Colors.blue,
          onTap: () => _open(context, const LearningEbookPage()),
        ),
        _IntegratedLearningTile(
          title: 'Questions from Books',
          subtitle: 'Find relevant passages in supplied text',
          icon: Icons.question_answer,
          color: Colors.pink,
          onTap: () => _open(context, const LearningRagPage()),
        ),
        _IntegratedLearningTile(
          title: 'Video Classes',
          subtitle: 'Browse lesson resources',
          icon: Icons.video_library,
          color: Colors.deepPurple,
          onTap: () => _open(context, const LearningVideoPage()),
        ),
        _IntegratedLearningTile(
          title: 'Class Recording Archive',
          subtitle: 'Organise recorded classroom sessions',
          icon: Icons.video_collection,
          color: Colors.orange,
          onTap: () => _open(context, const LearningArchivePage()),
        ),
        _IntegratedLearningTile(
          title: 'Virtual Science Lab',
          subtitle: 'Explore interactive physics simulations',
          icon: Icons.science,
          color: Colors.teal,
          onTap: () => _open(context, const LearningLabPage()),
        ),
        _IntegratedLearningTile(
          title: 'Typewriting Practice',
          subtitle: 'Improve typing accuracy',
          icon: Icons.keyboard,
          color: Colors.deepOrange,
          onTap: () => _open(context, const LearningTypingPage()),
        ),
      ]),
    );
  }
}

// 2. Ebook / reading module
class LearningEbookPage extends StatefulWidget {
  const LearningEbookPage({super.key});

  @override
  State<LearningEbookPage> createState() => _LearningEbookPageState();
}

class _LearningEbookPageState extends State<LearningEbookPage> {
  final TextEditingController _notes = TextEditingController();
  String _chapter = 'Introduction';

  final Map<String, String> _content = const {
    'Introduction': 'Welcome to your digital learning notebook. Use this section to read, revise and organise your study material.',
    'Science': 'Science is the systematic study of the natural world through observation, experimentation and evidence.',
    'Mathematics': 'Mathematics is the study of numbers, quantities, structures, patterns and logical relationships.',
    'English': 'English learning includes reading, writing, listening, speaking, vocabulary and grammar.',
  };

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _IntegratedLearningPage(
      title: 'Ebook Reader',
      subtitle: 'Digital reading and study notes',
      icon: Icons.menu_book,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<String>(
          value: _chapter,
          decoration: const InputDecoration(
            labelText: 'Select chapter',
            border: OutlineInputBorder(),
          ),
          items: _content.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) { if (v != null) setState(() => _chapter = v); },
        ),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: SelectableText(
            _content[_chapter]!,
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
        )),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'My study notes',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notes are currently kept in this session only.')),
          ),
          icon: const Icon(Icons.save),
          label: const Text('Save Notes'),
        ),
        const Text(
          'Sample chapter content is included. A file picker and full PDF viewer can be connected to this page.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ]),
    );
  }
}

// 3. Local text retrieval / book question module
class LearningRagPage extends StatefulWidget {
  const LearningRagPage({super.key});

  @override
  State<LearningRagPage> createState() => _LearningRagPageState();
}

class _LearningRagPageState extends State<LearningRagPage> {
  final TextEditingController _source = TextEditingController();
  final TextEditingController _question = TextEditingController();
  String _answer = '';

  void _ask() {
    final source = _source.text.trim();
    final question = _question.text.trim();
    if (source.isEmpty || question.isEmpty) {
      setState(() => _answer = 'Enter study text and a question first.');
      return;
    }
    final words = question.toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > 2).toSet();
    final paragraphs = source.split(RegExp(r'[\n.!?]+'))
        .map((s) => s.trim()).where((s) => s.isNotEmpty);
    final scored = <MapEntry<String, int>>[];
    for (final p in paragraphs) {
      final lower = p.toLowerCase();
      final score = words.where(lower.contains).length;
      if (score > 0) scored.add(MapEntry(p, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    setState(() {
      _answer = scored.isEmpty
          ? 'No matching passage found. Try keywords used in your study text.'
          : 'Relevant passages:\n\n${scored.take(3).map((e) => '• ${e.key}').join('\n\n')}\n\nThis is local keyword retrieval, not an AI-generated answer.';
    });
  }

  @override
  void dispose() {
    _source.dispose();
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _IntegratedLearningPage(
      title: 'Questions from Books',
      subtitle: 'Search your supplied study material',
      icon: Icons.auto_awesome,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _source,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Paste book or lesson text',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _question,
          decoration: const InputDecoration(
            labelText: 'Ask a question',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _ask(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _ask,
            icon: const Icon(Icons.search),
            label: const Text('Find Answer in Text'),
          ),
        ),
        if (_answer.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(_answer),
          )),
        ],
        const Text(
          'This is offline keyword retrieval. It is not connected to your MongoDB or online RAG backend.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ]),
    );
  }
}

// 4. Video classes
class LearningVideoPage extends StatelessWidget {
  const LearningVideoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const lessons = [
      ('Mathematics', 'Numbers, algebra and problem solving', Icons.calculate, Colors.blue),
      ('Science', 'Physics, chemistry and biology', Icons.science, Colors.teal),
      ('English', 'Grammar, vocabulary and communication', Icons.language, Colors.pink),
      ('Computer Studies', 'Programming and computer fundamentals', Icons.computer, Colors.deepPurple),
    ];
    return _IntegratedLearningPage(
      title: 'Video Classes',
      subtitle: 'Your online lesson resources',
      icon: Icons.video_library,
      content: Column(children: lessons.map((lesson) =>
        _IntegratedLearningTile(
          title: lesson.$1,
          subtitle: lesson.$2,
          icon: lesson.$3,
          color: lesson.$4,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Add a video URL or connect your video library for ${lesson.$1}.')),
          ),
        ),
      ).toList()),
    );
  }
}

// 5. Class recording archive
class LearningArchivePage extends StatefulWidget {
  const LearningArchivePage({super.key});

  @override
  State<LearningArchivePage> createState() => _LearningArchivePageState();
}

class _LearningArchivePageState extends State<LearningArchivePage> {
  final List<String> _recordings = [
    'Mathematics - Algebra',
    'Physics - Motion',
    'English - Grammar',
  ];

  void _addRecording() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add recording entry'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Recording title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) setState(() => _recordings.add(value));
              Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return _IntegratedLearningPage(
      title: 'Class Archive',
      subtitle: 'Recorded lessons and classroom history',
      icon: Icons.video_collection,
      content: Column(children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _addRecording,
            icon: const Icon(Icons.add),
            label: const Text('Add Recording Entry'),
          ),
        ),
        const SizedBox(height: 12),
        ..._recordings.map((name) => Card(
          child: ListTile(
            leading: const Icon(Icons.video_file, color: Colors.deepPurple),
            title: Text(name),
            subtitle: const Text('Recording entry'),
          ),
        )),
        const Text(
          'Entries are currently session-only. Connect file storage and a video player for actual recordings.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ]),
    );
  }
}

// 6. Interactive physics simulations
class LearningLabPage extends StatefulWidget {
  const LearningLabPage({super.key});

  @override
  State<LearningLabPage> createState() => _LearningLabPageState();
}

class _LearningLabPageState extends State<LearningLabPage> {
  double _mass = 5;
  double _acceleration = 2;
  double _voltage = 6;
  double _resistance = 3;

  @override
  Widget build(BuildContext context) {
    final force = _mass * _acceleration;
    final current = _voltage / _resistance;
    return _IntegratedLearningPage(
      title: 'Virtual Science Lab',
      subtitle: 'Interactive physics simulations',
      icon: Icons.science,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Experiment 1: Newton’s Second Law',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('Force = Mass × Acceleration'),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text('Mass: ${_mass.toStringAsFixed(1)} kg'),
            Slider(value: _mass, min: 1, max: 20, divisions: 19,
              onChanged: (v) => setState(() => _mass = v)),
            Text('Acceleration: ${_acceleration.toStringAsFixed(1)} m/s²'),
            Slider(value: _acceleration, min: 1, max: 10, divisions: 18,
              onChanged: (v) => setState(() => _acceleration = v)),
            Text('Force = ${force.toStringAsFixed(2)} N',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
          ]),
        )),
        const SizedBox(height: 18),
        const Text('Experiment 2: Ohm’s Law',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('Current = Voltage ÷ Resistance'),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text('Voltage: ${_voltage.toStringAsFixed(1)} V'),
            Slider(value: _voltage, min: 1, max: 24, divisions: 23,
              onChanged: (v) => setState(() => _voltage = v)),
            Text('Resistance: ${_resistance.toStringAsFixed(1)} Ω'),
            Slider(value: _resistance, min: 1, max: 20, divisions: 19,
              onChanged: (v) => setState(() => _resistance = v)),
            Text('Current = ${current.toStringAsFixed(2)} A',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pink)),
          ]),
        )),
        const Text('Educational calculations only; this is not a physical lab or full 3D simulation.',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}

// 7. Typewriting practice
class LearningTypingPage extends StatefulWidget {
  const LearningTypingPage({super.key});

  @override
  State<LearningTypingPage> createState() => _LearningTypingPageState();
}

class _LearningTypingPageState extends State<LearningTypingPage> {
  static const String _passage =
      'Learning is a continuous process. Practice every day to improve your knowledge, confidence and communication skills.';
  final TextEditingController _typing = TextEditingController();

  int get _correct {
    int count = 0;
    final value = _typing.text;
    for (int i = 0; i < value.length && i < _passage.length; i++) {
      if (value[i] == _passage[i]) count++;
    }
    return count;
  }

  double get _accuracy =>
      _typing.text.isEmpty ? 0 : _correct * 100 / _typing.text.length;

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _IntegratedLearningPage(
      title: 'Typewriting Practice',
      subtitle: 'Improve your typing accuracy',
      icon: Icons.keyboard,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Practice passage',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(_passage, style: const TextStyle(fontSize: 16, height: 1.6)),
        )),
        const SizedBox(height: 12),
        TextField(
          controller: _typing,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Type the passage here',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _LearningTypingMetric(label: 'Characters', value: '${_typing.text.length}')),
          Expanded(child: _LearningTypingMetric(label: 'Correct', value: '$_correct')),
          Expanded(child: _LearningTypingMetric(label: 'Accuracy', value: '${_accuracy.toStringAsFixed(1)}%')),
        ]),
        if (_typing.text.length >= _passage.length)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Passage completed! Well done.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
        OutlinedButton.icon(
          onPressed: () { _typing.clear(); setState(() {}); },
          icon: const Icon(Icons.refresh),
          label: const Text('Restart Practice'),
        ),
      ]),
    );
  }
}

class _LearningTypingMetric extends StatelessWidget {
  final String label;
  final String value;

  const _LearningTypingMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]),
    ));
  }
}

  