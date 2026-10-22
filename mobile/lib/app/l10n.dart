import 'package:flutter/widgets.dart';

import 'app_scope.dart';
import 'app_state.dart';

/// Which language the UI chrome is rendered in.
///
/// Gesture labels always stay in English (they are the model's class names),
/// while the Urdu translation of every gesture is shown alongside them.
enum AppLanguage { english, urdu }

extension AppLanguageX on AppLanguage {
  String get code => this == AppLanguage.urdu ? 'ur' : 'en';
  bool get isUrdu => this == AppLanguage.urdu;
  String get label => this == AppLanguage.urdu ? 'اردو' : 'English';
  String get englishLabel => this == AppLanguage.urdu ? 'Urdu' : 'English';
}

/// Tiny hand-written localisation layer — no codegen, no network, instant.
class L10n {
  const L10n(this.language);

  final AppLanguage language;

  bool get isUrdu => language.isUrdu;

  String _(String en, String ur) => isUrdu ? ur : en;

  static L10n of(BuildContext context) => L10n(AppScope.of(context).language);

  // ---------------------------------------------------------------- shell
  String get appName => 'Gesto AI';
  String get home => _('Home', 'ہوم');
  String get demo => _('Live Demo', 'لائیو ڈیمو');
  String get history => _('History', 'ریکارڈ');
  String get about => _('About', 'تعارف');
  String get settings => _('Settings', 'ترتیبات');

  // ----------------------------------------------------------------- home
  String get heroEyebrow => _('Real-time PSL → Urdu Speech', 'فوری پاکستانی اشاروں کی زبان → اردو آواز');
  String get heroTagline => _(
        'Turning Pakistan Sign Language into spoken Urdu — instantly — so deaf and mute voices are finally heard.',
        'پاکستانی اشاروں کی زبان کو فوراً اردو آواز میں بدل کر بہرے اور گونگے لوگوں کی آواز بنتے ہیں۔',
      );
  String get tryLiveDemo => _('Try Live Demo', 'لائیو ڈیمو آزمائیں');
  String get whyItMatters => _('Why it matters', 'یہ کیوں ضروری ہے');
  String get howItWorks => _('How it works', 'یہ کیسے کام کرتا ہے');
  String get signItSayIt => _('Sign it. We say it.', 'اشارہ کریں، ہم بول دیں گے۔');
  String get historySaved => _('saved gestures', 'محفوظ اشارے');
  String get stepCameraTitle => _('Camera', 'کیمرہ');
  String get stepCameraBody => _(
        'Captures the signer\'s hands through the phone camera.',
        'فون کے کیمرے سے اشارہ کرنے والے کے ہاتھ دیکھتا ہے۔',
      );
  String get stepModelTitle => _('AI Model', 'اے آئی ماڈل');
  String get stepModelBody => _(
        'MediaPipe tracks 21 hand landmarks and a TensorFlow classifier names the PSL gesture.',
        'میڈیا پائپ ہاتھ کے 21 پوائنٹس ٹریک کرتا ہے اور ٹینسر فلو ماڈل اشارے کا نام بتاتا ہے۔',
      );
  String get stepSpeechTitle => _('Urdu Speech', 'اردو آواز');
  String get stepSpeechBody => _(
        'The recognised gesture is spoken aloud in Urdu, closing the conversation gap.',
        'پہچانا گیا اشارہ اردو میں بول کر بات چیت کا فاصلہ ختم کرتا ہے۔',
      );
  String get statsPeople => _('9M+', '9 ملین+');
  String get statsPeopleLabel => _('Pakistanis sign', 'پاکستانی اشارے کرتے ہیں');
  String get statsGestures => _('14', '14');
  String get statsGesturesLabel => _('PSL gestures', 'اشارے');
  String get statsRealtime => _('~10 fps', '~10 fps');
  String get statsRealtimeLabel => _('Live inference', 'لائیو تجزیہ');
  String get serverStatus => _('Server status', 'سرور کی حالت');
  String get modelReady => _('Model ready', 'ماڈل تیار ہے');
  String get modelNotReady => _('Model not loaded', 'ماڈل لوڈ نہیں ہوا');
  String get serverOffline => _('Server unreachable', 'سرور تک رسائی نہیں');
  String get checking => _('Checking…', 'جانچ جاری ہے…');
  String get checkAgain => _('Check again', 'دوبارہ جانچیں');
  String gesturesAvailable(int n) => isUrdu ? '$n اشارے دستیاب' : '$n gestures available';
  String get footerNote => _('Hackathon build. Every sign deserves a voice.', 'ہیکاتھون پروجیکٹ۔ ہر اشارے کی ایک آواز ہونی چاہیے۔');

  // ----------------------------------------------------------------- demo
  String get cameraOff => _('Camera is off', 'کیمرہ بند ہے');
  String get cameraOffHint => _('Tap “Start Camera” to begin', 'شروع کرنے کے لیے ”کیمرہ شروع کریں“ دبائیں');
  String get startCamera => _('Start Camera', 'کیمرہ شروع کریں');
  String get stopCamera => _('Stop', 'بند کریں');
  String get flipCamera => _('Flip camera', 'کیمرہ بدلیں');
  String get connecting => _('Connecting…', 'منسلک ہو رہا ہے…');
  String get connected => _('Connected to server', 'سرور سے منسلک');
  String get disconnected => _('Server disconnected', 'سرور منقطع');
  String get reconnect => _('Reconnect', 'دوبارہ جوڑیں');
  String get recognizedGesture => _('Recognized Gesture', 'پہچانا گیا اشارہ');
  String get waitingForCamera => _('Waiting for camera…', 'کیمرے کا انتظار…');
  String get confidence => _('Confidence', 'اعتماد');
  String get recentGestures => _('Recent Gestures', 'حالیہ اشارے');
  String get noGesturesYet => _('Recognized gestures will appear here.', 'پہچانے گئے اشارے یہاں نظر آئیں گے۔');
  String get live => _('LIVE', 'لائیو');
  String get speakerOn => _('Urdu voice on', 'اردو آواز آن');
  String get speakerOff => _('Urdu voice off', 'اردو آواز آف');
  String get serverNotReadyBanner => _(
        'The server is up but the AI model is not loaded yet.',
        'سرور چل رہا ہے مگر اے آئی ماڈل ابھی لوڈ نہیں ہوا۔',
      );
  String get cameraDeniedTitle => _('Camera permission needed', 'کیمرہ کی اجازت درکار ہے');
  String get cameraDeniedBody => _(
        'Gesto AI needs the camera to read your signs. Nothing is uploaded except small frames sent for recognition.',
        'گسٹو اے آئی کو اشارے پڑھنے کے لیے کیمرے کی اجازت چاہیے۔ صرف چھوٹے فریمز پہچان کے لیے بھیجے جاتے ہیں۔',
      );
  String get openSettings => _('Open settings', 'ترتیبات کھولیں');
  String get cameraUnavailable => _('No camera found on this device.', 'اس ڈیوائس پر کوئی کیمرہ نہیں ملا۔');
  String get cameraFailed => _('Could not start the camera.', 'کیمرہ شروع نہیں ہو سکا۔');
  String get frameFormatUnsupported => _(
        'This device does not expose a JPEG camera stream. Try an Android phone.',
        'یہ ڈیوائس JPEG کیمرہ اسٹریم نہیں دیتی۔ اینڈرائیڈ فون آزمائیں۔',
      );
  String get signHere => _('Sign inside the frame', 'فریم کے اندر اشارہ کریں');
  String framesSent(int n) => isUrdu ? '$n فریم بھیجے گئے' : '$n frames sent';

  String reason(String? code) {
    switch (code) {
      case 'no_hand':
        return _('No hand detected', 'ہاتھ نظر نہیں آ رہا');
      case 'warming_up':
        return _('Reading gesture…', 'اشارہ پڑھا جا رہا ہے…');
      case 'not_ready':
        return _('Model not ready on server', 'سرور پر ماڈل تیار نہیں');
      case 'below_threshold':
        return _('Reading gesture…', 'اشارہ پڑھا جا رہا ہے…');
      case 'decode_failed':
        return _('Frame could not be read', 'فریم پڑھا نہیں جا سکا');
      default:
        return _('Show your hand to the camera', 'کیمرے کے سامنے ہاتھ دکھائیں');
    }
  }

  // -------------------------------------------------------------- history
  String get historyTitle => _('Gesture History', 'اشاروں کا ریکارڈ');
  String get historyEmpty => _(
        'No gestures yet. Run the live demo and your recognised signs will be saved here.',
        'ابھی کوئی اشارہ نہیں۔ لائیو ڈیمو چلائیں، پہچانے گئے اشارے یہاں محفوظ ہوں گے۔',
      );
  String get clearAll => _('Clear all', 'سب صاف کریں');
  String get clearAllConfirm => _(
        'Delete every saved gesture? This cannot be undone.',
        'تمام محفوظ اشارے حذف کریں؟ یہ واپس نہیں ہو سکتا۔',
      );
  String get cancel => _('Cancel', 'منسوخ');
  String get delete => _('Delete', 'حذف کریں');
  String get speak => _('Speak', 'بولیں');
  String get all => _('All', 'سب');
  String get today => _('Today', 'آج');
  String get yesterday => _('Yesterday', 'کل');
  String get savedGestures => _('saved', 'محفوظ');
  String get filter => _('Filter', 'فلٹر');
  String get startDemo => _('Start demo', 'ڈیمو شروع کریں');

  // ------------------------------------------------------------- settings
  String get language => _('App language', 'ایپ کی زبان');
  String get languageHelp => _('Ui language. Gesture names stay in English.', 'انٹرفیس کی زبان۔ اشاروں کے نام انگریزی میں رہیں گے۔');
  String get backend => _('Backend server', 'بیک اینڈ سرور');
  String get backendHelp => _(
        'The Railway FastAPI server that runs the PSL model. Point it at your own machine for offline demos.',
        'ریل وے پر چلنے والا FastAPI سرور جو ماڈل چلاتا ہے۔ لوکل ڈیمو کے لیے اپنے کمپیوٹر کا پتہ لکھیں۔',
      );
  String get resetDefault => _('Reset to default', 'ڈیفالٹ پر لائیں');
  String get testConnection => _('Test connection', 'کنکشن جانچیں');
  String get testing => _('Testing…', 'جانچ جاری…');
  String get connectionOk => _('Connection OK', 'کنکشن ٹھیک ہے');
  String get connectionFailed => _('Connection failed', 'کنکشن ناکام');
  String get save => _('Save', 'محفوظ کریں');
  String get saved => _('Saved', 'محفوظ ہو گیا');
  String get voice => _('Urdu voice', 'اردو آواز');
  String get voiceHelp => _(
        'Speaks every stable gesture out loud. Uses a Hindi voice when the phone has no Urdu voice — same spoken language, different script.',
        'ہر مستحکم اشارے کو بول کر سناتا ہے۔ اگر فون میں اردو آواز نہ ہو تو ہندی آواز استعمال ہوتی ہے — زبان ایک ہی ہے، رسم الخط مختلف۔',
      );
  String get speechRate => _('Speech speed', 'بولنے کی رفتار');
  String get normal => _('Normal', 'عام');
  String get slow => _('Slow', 'آہستہ');
  String get fast => _('Fast', 'تیز');
  String get testVoice => _('Test voice', 'آواز آزمائیں');
  String get data => _('Data', 'ڈیٹا');
  String get clearHistory => _('Clear gesture history', 'اشاروں کا ریکارڈ صاف کریں');
  String get version => _('Version', 'ورژن');
  String get modelStatus => _('Model status', 'ماڈل کی حالت');
  String get gesturesLoaded => _('Gesture classes', 'اشاروں کی کلاسیں');
  String get noVoiceWarning => _(
        'No Urdu/Hindi voice found on this device. Install a text-to-speech voice from Android settings.',
        'اس ڈیوائس پر اردو/ہندی آواز نہیں ملی۔ اینڈرائیڈ کی ترتیبات سے ٹیکسٹ ٹو اسپیچ آواز انسٹال کریں۔',
      );

  // ---------------------------------------------------------------- about
  String get problemTitle => _('9 million Pakistanis sign. Almost nobody hears them.', '90 لاکھ پاکستانی اشارے کرتے ہیں، مگر کوئی سنتا نہیں۔');
  String get problemBody1 => _(
        'Pakistan has one of the largest deaf populations in the world, yet sign-language interpreters are scarce and most hearing people cannot understand PSL. A doctor\'s visit, a market purchase, an emergency — everyday moments become walls of silence.',
        'پاکستان دنیا کی سب سے بڑی بہرے آبادیوں میں سے ایک ہے، مگر ترجمان بہت کم ہیں اور زیادہ تر لوگ اشاروں کی زبان نہیں سمجھتے۔ ڈاکٹر کے پاس جانا، بازار میں خریداری، ہنگامی صورتحال — معمول کے لمحے خاموشی کی دیواریں بن جاتے ہیں۔',
      );
  String get problemBody2 => _(
        'Gesto AI bridges that gap: the camera watches the signer\'s hands, the model reads the gesture, and the app speaks it aloud in Urdu — in real time, on an ordinary phone, with no special hardware.',
        'گسٹو اے آئی یہ فاصلہ مٹاتا ہے: کیمرہ ہاتھوں کو دیکھتا ہے، ماڈل اشارہ پڑھتا ہے اور ایپ اسے اردو میں بولتی ہے — فوراً، ایک عام فون پر، بغیر کسی خاص ہارڈویئر کے۔',
      );
  String get techTitle => _('Tech stack', 'ٹیک اسٹیک');
  String get teamTitle => _('The team', 'ٹیم');
  String get teamSub => _('The minds behind the magic.', 'جادو کے پیچھے موجود لوگ۔');
  String get links => _('Links', 'لنکس');
  String get liveDemo => _('Web live demo', 'ویب لائیو ڈیمو');
  String get backendApi => _('Backend API', 'بیک اینڈ API');
  String get sourceCode => _('Source code', 'سورس کوڈ');
  String get linkFailed => _('Could not open the link.', 'لنک نہیں کھل سکا۔');
  String get howItWorksBody => _(
        'Frames are captured on the phone and sent over a WebSocket to a FastAPI server, which extracts 21 hand landmarks with MediaPipe, classifies a 30-frame window with a Keras model and answers with the gesture name plus an Urdu sentence.',
        'فریمز فون سے WebSocket کے ذریعے FastAPI سرور کو جاتے ہیں، جو میڈیا پائپ سے ہاتھ کے 21 پوائنٹس نکالتا ہے، 30 فریموں کی ونڈو کو Keras ماڈل سے جانچتا ہے اور اشارے کا نام اور اردو جملہ واپس بھیجتا ہے۔',
      );

  // ------------------------------------------------------------ onboarding
  String get onboardTitle1 => _('Gesto AI', 'گسٹو اے آئی');
  String get onboardBody1 => _(
        'Pakistan Sign Language, understood and spoken in Urdu — in real time.',
        'پاکستانی اشاروں کی زبان، سمجھی اور اردو میں بولی گئی — فوراً۔',
      );
  String get onboardTitle2 => _('Sign. We say it.', 'اشارہ کریں، ہم بول دیں گے۔');
  String get onboardBody2 => _(
        'Point the camera at your hands. The AI model recognises the PSL gesture and the phone speaks the Urdu sentence out loud.',
        'کیمرہ اپنے ہاتھوں کی طرف رکھیں۔ اے آئی ماڈل اشارہ پہچانتا ہے اور فون اردو جملہ بول کر سناتا ہے۔',
      );
  String get onboardTitle3 => _('Camera & server', 'کیمرہ اور سرور');
  String get onboardBody3 => _(
        'Camera frames are sent to the Gesto AI server for recognition. You can change the server address any time in Settings.',
        'پہچان کے لیے کیمرے کے فریمز گسٹو اے آئی سرور کو بھیجے جاتے ہیں۔ سرور کا پتہ آپ ترتیبات میں کبھی بھی بدل سکتے ہیں۔',
      );
  String get getStarted => _('Get Started', 'شروع کریں');
  String get skip => _('Skip', 'چھوڑیں');
  String get next => _('Next', 'آگے');
  String get chooseLanguage => _('Choose your language', 'اپنی زبان منتخب کریں');
  String get continueLabel => _('Continue', 'جاری رکھیں');
}
