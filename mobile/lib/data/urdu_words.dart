/// The 14 PSL gesture classes the model was trained on.
///
/// The live list always comes from the backend (`/health` -> gesture_labels,
/// which is derived from label_encoder.pkl); this is the offline fallback so
/// the UI can still render history and labels when the server is unreachable.
const List<String> kDefaultGestures = <String>[
  'ambulance',
  'doctor',
  'drink',
  'eat',
  'good',
  'help',
  'home',
  'no',
  'pain',
  'sick',
  'sleep',
  'sorry',
  'thankyou',
  'yes',
];

/// Gesture label -> Urdu script, exactly as the web frontend shows it.
const Map<String, String> kUrduWords = <String, String>{
  'ambulance': 'ایمبولینس',
  'doctor': 'ڈاکٹر',
  'drink': 'پانی چاہیے',
  'eat': 'کھانا چاہیے',
  'good': 'اچھا',
  'help': 'مدد چاہیے',
  'home': 'گھر',
  'no': 'نہیں',
  'pain': 'درد ہو رہا ہے',
  'sick': 'طبیعت خراب ہے',
  'sleep': 'نیند آ رہی ہے',
  'sorry': 'معذرت',
  'thankyou': 'شکریہ',
  'yes': 'جی ہاں',
};

/// Same words in Devanagari — used only by the text-to-speech engine.
///
/// Most Android phones ship no Urdu ("ur") voice, but many ship a Hindi
/// ("hi-IN") voice. Urdu and Hindi are the same spoken language (Hindustani),
/// so a Hindi voice pronounces these words correctly; the on-screen text still
/// shows real Urdu script.
const Map<String, String> kSpokenWords = <String, String>{
  'ambulance': 'एम्बुलेंस',
  'doctor': 'डॉक्टर',
  'drink': 'पानी चाहिए',
  'eat': 'खाना चाहिए',
  'good': 'अच्छा',
  'help': 'मदद चाहिए',
  'home': 'घर',
  'no': 'नहीं',
  'pain': 'दर्द हो रहा है',
  'sick': 'तबीयत ख़राब है',
  'sleep': 'नींद आ रही है',
  'sorry': 'माफ़ करना',
  'thankyou': 'शुक्रिया',
  'yes': 'जी हाँ',
};

/// Full Urdu sentences, mirroring the backend's fallback dictionary.
const Map<String, String> kUrduSentences = <String, String>{
  'help': 'مجھے مدد چاہیے',
  'pain': 'مجھے درد ہو رہا ہے',
  'doctor': 'مجھے ڈاکٹر چاہیے',
  'sick': 'میری طبیعت خراب ہے',
  'ambulance': 'ایمبولینس بلائیں',
  'good': 'ٹھیک ہے',
  'home': 'مجھے گھر جانا ہے',
  'no': 'نہیں',
  'yes': 'ہاں',
  'sleep': 'مجھے نیند آ رہی ہے',
  'sorry': 'معاف کیجیے',
  'eat': 'مجھے کھانا چاہیے',
  'drink': 'مجھے پانی چاہیے',
  'thankyou': 'شکریہ',
};

String normalizedKey(String gesture) => gesture.trim().toLowerCase();

/// Urdu word shown on screen for a gesture (falls back to the raw label).
String urduFor(String gesture) =>
    kUrduWords[normalizedKey(gesture)] ?? gesture;

/// Full Urdu sentence for a gesture.
String urduSentenceFor(String gesture) =>
    kUrduSentences[normalizedKey(gesture)] ?? urduFor(gesture);

/// Devanagari text for the TTS engine.
String spokenFor(String gesture) =>
    kSpokenWords[normalizedKey(gesture)] ?? urduFor(gesture);

/// "thankyou" -> "Thank You"
String displayGesture(String gesture) {
  final String key = gesture.trim();
  if (key.isEmpty) return gesture;
  final String spaced = key.replaceAll('_', ' ');
  return spaced
      .split(' ')
      .where((String w) => w.isNotEmpty)
      .map((String w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
