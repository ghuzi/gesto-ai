/* ==========================================================================
   Gesto AI — frontend logic (vanilla JS, no libraries)
   - Webcam capture: standard canvas.drawImage -> JPEG base64 (no data-url prefix)
   - Streams a frame over WebSocket every ~100ms
   - Protocol: client {"frame": "..."}  ->  server {"gesture", "confidence", "reason"}
   ========================================================================== */

'use strict';

/* ---------- Configuration ---------- */
// Live backend: Railway project "exciting-strength", service "gesto-backend".
const DEFAULT_BACKEND = 'https://gesto-backend-production.up.railway.app';
// Hosts that used to be the default and no longer exist — migrate away from
// them automatically instead of showing "Server unreachable".
const RETIRED_BACKENDS = [
  'https://gesto-ai-production.up.railway.app',
  'https://gesto-ai.up.railway.app',
  'https://gesto-ai-backend.up.railway.app',
  'https://gesto-ai-api.up.railway.app'
];
const BACKEND_STORAGE_KEY = 'gesto.backend';
const FRAME_INTERVAL_MS = 100;   // ~10 fps to the inference server
const HISTORY_CAP = 8;           // max entries in the recent-gestures list
const RECONNECT_DELAY_MS = 3000; // auto-retry backoff

/* --------------------------------------------------------------------------
   BACKEND ADDRESS — resolved at runtime, no rebuild required.
   Priority:  ?backend=<url>  >  localStorage  >  DEFAULT_BACKEND
   Accepted forms: https://host, http://host, wss://host, ws://host, host:port
   -------------------------------------------------------------------------- */

/** Local hosts are plain http (a laptop on the same Wi-Fi has no TLS). */
function looksLocal(value) {
  const host = value.split('/')[0].toLowerCase();
  const hostname = host.split(':')[0];
  if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '0.0.0.0') return true;
  if (/^10\./.test(hostname) || /^192\.168\./.test(hostname)) return true;
  if (/^172\.(1[6-9]|2\d|3[01])\./.test(hostname)) return true;
  // "192.168.1.10:8000" / "my-laptop:8000" — an explicit port means a dev server.
  return /:\d+$/.test(host) && !hostname.includes('.');
}

/** Turn whatever the user typed into a clean https?:// base URL (no trailing /). */
function normalizeBackend(raw) {
  let value = String(raw || '').trim();
  if (!value) return DEFAULT_BACKEND;
  // ws(s):// is the same host as http(s):// — accept both when configuring.
  value = value.replace(/^wss:\/\//i, 'https://').replace(/^ws:\/\//i, 'http://');
  if (!/^https?:\/\//i.test(value)) {
    value = (looksLocal(value) ? 'http://' : 'https://') + value;
  }
  try {
    const url = new URL(value);
    if (!url.hostname) return DEFAULT_BACKEND;
    return url.origin + url.pathname.replace(/\/+$/, '');
  } catch (err) {
    return DEFAULT_BACKEND;
  }
}

function resolveBackend() {
  try {
    const fromQuery = new URLSearchParams(window.location.search).get('backend');
    if (fromQuery) {
      const normalized = normalizeBackend(fromQuery);
      localStorage.setItem(BACKEND_STORAGE_KEY, normalized);
      return normalized;
    }
    const stored = localStorage.getItem(BACKEND_STORAGE_KEY);
    if (stored) {
      const normalized = normalizeBackend(stored);
      if (RETIRED_BACKENDS.indexOf(normalized) !== -1) {
        // Saved before the server moved — forget it, use the live one.
        localStorage.removeItem(BACKEND_STORAGE_KEY);
        return DEFAULT_BACKEND;
      }
      return normalized;
    }
  } catch (err) {
    // Private mode / storage disabled — fall through to the default.
  }
  return DEFAULT_BACKEND;
}

let BACKEND_URL = resolveBackend();
let WS_URL = BACKEND_URL.replace(/^http/i, 'ws') + '/ws/predict';

/** Ask for a new backend, persist it and reconnect. */
function promptForBackend() {
  const current = BACKEND_URL;
  const answer = window.prompt(
    'Backend server URL\n(e.g. https://my-gesto.up.railway.app or http://192.168.1.10:8000)',
    current
  );
  if (answer === null) return;
  const normalized = normalizeBackend(answer);
  try {
    localStorage.setItem(BACKEND_STORAGE_KEY, normalized);
  } catch (err) {
    // Storage unavailable — the URL still applies for this page view.
  }
  BACKEND_URL = normalized;
  WS_URL = BACKEND_URL.replace(/^http/i, 'ws') + '/ws/predict';
  setConnection('disconnected');
  connectWebSocket();
  checkBackendHealth();
}

/* ---------- DOM references ---------- */
const video = document.getElementById('webcam');
const startBtn = document.getElementById('start-camera');
const stopBtn = document.getElementById('stop-camera');
const speakerBtn = document.getElementById('speaker-btn');
const cameraPlaceholder = document.getElementById('camera-placeholder');
const scanline = document.getElementById('scanline');

const connDot = document.getElementById('conn-dot');
const connText = document.getElementById('conn-text');
const reconnectBtn = document.getElementById('reconnect-btn');
const changeServerBtn = document.getElementById('change-server-btn');

const gestureEl = document.getElementById('gesture-name');
const statusEl = document.getElementById('status-line');
const confidencePct = document.getElementById('confidence-pct');
const progressWrap = document.getElementById('progress-wrap');
const progressFill = document.getElementById('progress-fill');
const historyList = document.getElementById('history-list');
const historyEmpty = document.getElementById('history-empty');

/* ---------- State ---------- */
let ws = null;              // WebSocket instance
let cameraStream = null;    // MediaStream from getUserMedia
let captureTimer = null;    // setInterval handle for frame sending
let reconnectTimer = null;  // setTimeout handle for auto-retry
let demoActive = false;     // camera on AND streaming
let lastLoggedGesture = null;

/* Offscreen canvas used for frame capture (kept outside the capture loop). */
const canvas = document.createElement('canvas');
const ctx = canvas.getContext('2d');

/* --------------------------------------------------------------------------
   CAMERA CAPTURE — the one approved method. Do not change.
   -------------------------------------------------------------------------- */

/** Grab the current video frame and return it as a base64 JPEG string
 *  WITHOUT the "data:image/jpeg;base64," prefix. */
function captureFrameBase64() {
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;
  ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL('image/jpeg', 0.8).split(',')[1];
}

/* ---------- Camera controls ---------- */

function startCamera() {
  // Disable Start synchronously so a double-click cannot launch two streams
  // and leak the first one; re-enabled in the .catch() path below.
  startBtn.disabled = true;

  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    setStatusLine('Camera API unavailable in this browser.');
    startBtn.disabled = false;
    return;
  }

  setStatusLine('Starting camera…');

  navigator.mediaDevices.getUserMedia({ video: { width: 640, height: 480 } })
    .then(stream => {
      video.srcObject = stream;
      cameraStream = stream;
      cameraPlaceholder.classList.add('is-hidden');
      startBtn.disabled = true;
      stopBtn.disabled = false;
      connectWebSocket(); // ensure server link exists whenever camera runs
    })
    .catch(err => {
      console.error('Camera error:', err);
      setStatusLine('Camera access denied or unavailable.');
      startBtn.disabled = false; // allow retry after failure
    });
}

function stopCamera() {
  stopCaptureLoop();

  // Kill any pending auto-reconnect and detach onclose BEFORE closing the
  // socket, so a stop right after a disconnect cannot trigger a ghost
  // reconnect (and its leaked capture interval).
  clearTimeout(reconnectTimer);
  reconnectTimer = null;
  if (ws) {
    ws.onclose = null;
    ws.onerror = null;
    ws.onmessage = null;
    try {
      ws.close();
    } catch (err) {
      // Socket may already be closed — nothing to do.
    }
    ws = null;
  }

  if (cameraStream) {
    cameraStream.getTracks().forEach(t => t.stop());
    cameraStream = null;
  }
  video.srcObject = null;
  demoActive = false;

  cameraPlaceholder.classList.remove('is-hidden');
  scanline.classList.remove('is-scanning');
  startBtn.disabled = false;
  stopBtn.disabled = true;

  setStatusLine('Camera stopped.');
  resetResults();
}

video.addEventListener('playing', () => {
  demoActive = true;
  scanline.classList.add('is-scanning');
  setStatusLine('Camera live — waiting for server…');
});

/* --------------------------------------------------------------------------
   WEBSOCKET — connect, stream frames, handle responses.
   -------------------------------------------------------------------------- */

function connectWebSocket() {
  // Avoid duplicate sockets.
  if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
    return;
  }

  setConnection('connecting');
  clearTimeout(reconnectTimer);

  try {
    ws = new WebSocket(WS_URL);
  } catch (err) {
    // Invalid URL / immediate failure — fall through to disconnected path.
    setConnection('disconnected');
    return;
  }

  ws.onopen = () => {
    setConnection('connected');
    startCaptureLoop();
  };

  ws.onmessage = (event) => {
    let data;
    try {
      data = JSON.parse(event.data);
    } catch (err) {
      return; // ignore malformed payloads
    }
    handlePrediction(data);
  };

  ws.onerror = () => {
    // onclose always fires after onerror; cleanup happens there.
  };

  ws.onclose = () => {
    setConnection('disconnected');
    stopCaptureLoop();
    // Re-diagnose so the user sees *why* (404 / starting / offline) instead
    // of a generic "Server disconnected".
    checkBackendHealth();
    // Auto-retry only while the demo is actually running.
    if (demoActive) {
      reconnectTimer = setTimeout(connectWebSocket, RECONNECT_DELAY_MS);
    }
  };
}

/** Send a frame every ~100ms; skip silently when socket/video aren't ready. */
function startCaptureLoop() {
  stopCaptureLoop();
  captureTimer = setInterval(() => {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    if (!demoActive || video.readyState < 2 || !video.videoWidth) return;

    try {
      const frame = captureFrameBase64();
      if (frame) ws.send(JSON.stringify({ frame: frame }));
    } catch (err) {
      // Frame grab hiccup — skip this tick, never crash the loop.
    }
  }, FRAME_INTERVAL_MS);
}

function stopCaptureLoop() {
  if (captureTimer) {
    clearInterval(captureTimer);
    captureTimer = null;
  }
}

/* --------------------------------------------------------------------------
   SERVER RESPONSE HANDLING
   -------------------------------------------------------------------------- */

/** Map server "reason" codes to friendly status text. */
const REASON_TEXT = {
  no_hand: 'No hand detected',
  warming_up: 'Reading gesture…',
  not_ready: 'Model not ready on server',
  below_threshold: 'Reading gesture…',
  decode_failed: 'Reading gesture…'
};

function handlePrediction(data) {
  const { gesture, confidence, reason } = data;

  if (gesture && typeof confidence === 'number') {
    // A gesture was recognized.
    const pct = Math.round(confidence * 100);
    showGesture(gesture, pct);
    setStatusLine(URDU_MAP[gesture] || gesture, /* isUrdu */ true);
    addToHistory(gesture, pct);
    maybeSpeakGesture(gesture);
  } else if (reason && REASON_TEXT[reason]) {
    // No recognition yet — show the mapped reason, decay the bar.
    setStatusLine(REASON_TEXT[reason], /* isUrdu */ false);
    if (reason === 'no_hand' || reason === 'decode_failed') {
      gestureEl.textContent = '—';
      updateConfidence(0);
    }
  }
}

function showGesture(name, pct) {
  if (gestureEl.textContent !== name) {
    gestureEl.textContent = name;
    // Retrigger the pop animation.
    gestureEl.classList.remove('flash');
    void gestureEl.offsetWidth;
    gestureEl.classList.add('flash');
  }
  updateConfidence(pct);
}

function updateConfidence(pct) {
  const clamped = Math.max(0, Math.min(100, pct));
  confidencePct.textContent = clamped + '%';
  progressFill.style.width = clamped + '%';
  progressWrap.setAttribute('aria-valuenow', String(clamped));
}

function setStatusLine(text, isUrdu = false) {
  statusEl.textContent = text;
  statusEl.lang = isUrdu ? 'ur' : 'en';
  statusEl.dir = isUrdu ? 'rtl' : 'ltr';
}

function resetResults() {
  gestureEl.textContent = '—';
  setStatusLine('Waiting for camera…', false);
  updateConfidence(0);
}

/* ---------- Recent gestures history ---------- */

function addToHistory(name, pct) {
  // Skip consecutive duplicates to avoid spamming the list.
  if (name === lastLoggedGesture) return;
  lastLoggedGesture = name;

  if (historyEmpty && historyEmpty.parentNode === historyList) {
    historyList.removeChild(historyEmpty);
  }

  const li = document.createElement('li');

  const nameSpan = document.createElement('span');
  nameSpan.className = 'h-name';
  nameSpan.textContent = name;

  const timeSpan = document.createElement('span');
  timeSpan.className = 'h-time';
  timeSpan.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });

  const confSpan = document.createElement('span');
  confSpan.className = 'h-conf';
  confSpan.textContent = pct + '%';

  li.append(nameSpan, timeSpan, confSpan);
  historyList.prepend(li);

  // Cap the list length.
  while (historyList.children.length > HISTORY_CAP) {
    historyList.removeChild(historyList.lastChild);
  }
}

/* ---------- Connection status UI ---------- */

function setConnection(state) {
  connDot.className = 'conn-dot'; // reset modifier classes
  reconnectBtn.hidden = true;
  if (changeServerBtn) changeServerBtn.hidden = state !== 'disconnected';

  if (state === 'connected') {
    connDot.classList.add('is-connected');
    connText.textContent = 'Connected to server';
  } else if (state === 'connecting') {
    connDot.classList.add('is-connecting');
    connText.textContent = 'Connecting…';
  } else {
    connDot.classList.add('is-disconnected');
    connText.textContent = 'Server disconnected';
    reconnectBtn.hidden = false;
  }
}

reconnectBtn.addEventListener('click', () => {
  clearTimeout(reconnectTimer);
  connectWebSocket();
});

/* --------------------------------------------------------------------------
   URDU TEXT-TO-SPEECH — Web Speech API (SpeechSynthesis), no backend change.
   -------------------------------------------------------------------------- */

/** Gesture label (from label_encoder.classes_) -> Urdu script, shown on screen. */
const URDU_MAP = {
  ambulance: 'ایمبولینس',
  doctor: 'ڈاکٹر',
  drink: 'پانی چاہیے',
  eat: 'کھانا چاہیے',
  good: 'اچھا',
  help: 'مدد چاہیے',
  home: 'گھر',
  no: 'نہیں',
  pain: 'درد ہو رہا ہے',
  sick: 'طبیعت خراب ہے',
  sleep: 'نیند آ رہی ہے',
  sorry: 'معذرت',
  thankyou: 'شکریہ',
  yes: 'جی ہاں'
};

/**
 * Same words in Devanagari, for the TEXT-TO-SPEECH ENGINE only.
 * Most systems/browsers ship no Urdu ("ur") voice at all, so nothing plays
 * even though the browser accepts the request silently. Urdu and Hindi are
 * the same spoken language (Hindustani) — a Hindi ("hi-IN") voice reads
 * these words with the correct pronunciation, it's just written in a
 * different script. The on-screen text above still shows real Urdu script.
 */
const SPOKEN_MAP = {
  ambulance: 'एम्बुलेंस',
  doctor: 'डॉक्टर',
  drink: 'पानी चाहिए',
  eat: 'खाना चाहिए',
  good: 'अच्छा',
  help: 'मदद चाहिए',
  home: 'घर',
  no: 'नहीं',
  pain: 'दर्द हो रहा है',
  sick: 'तबीयत ख़राब है',
  sleep: 'नींद आ रही है',
  sorry: 'माफ़ करना',
  thankyou: 'शुक्रिया',
  yes: 'जी हाँ'
};

let speechEnabled = false;   // toggled by speakerBtn
let lastSpokenGesture = null;
let speechVoice = null;      // cached best-matching voice, once voices load
let speechLang = 'hi-IN';    // language tag paired with speechVoice

function pickSpeechVoice() {
  const voices = window.speechSynthesis ? window.speechSynthesis.getVoices() : [];
  // Prefer a real Urdu voice if this machine happens to have one.
  const ur = voices.find(v => v.lang === 'ur-PK') || voices.find(v => v.lang && v.lang.startsWith('ur'));
  if (ur) {
    speechVoice = ur;
    speechLang = ur.lang;
    return;
  }
  // Otherwise fall back to Hindi (Hindustani) — same spoken language as Urdu.
  const hi = voices.find(v => v.lang === 'hi-IN') || voices.find(v => v.lang && v.lang.startsWith('hi'));
  speechVoice = hi || null;
  speechLang = hi ? hi.lang : 'hi-IN';
}

if (window.speechSynthesis) {
  pickSpeechVoice();
  // Most browsers load voices asynchronously — refresh the cache once ready.
  window.speechSynthesis.onvoiceschanged = pickSpeechVoice;
}

/** Speak text aloud, interrupting whatever is currently speaking. */
function speakUrdu(text) {
  if (!window.speechSynthesis || !text) return;
  window.speechSynthesis.cancel(); // don't queue — always speak the latest gesture
  const utter = new SpeechSynthesisUtterance(text);
  utter.lang = speechLang;
  if (speechVoice) utter.voice = speechVoice;
  utter.rate = 1.05;
  utter.pitch = 1.35;  // higher pitch -> lighter, younger-sounding voice
  window.speechSynthesis.speak(utter);
}

/** Called from handlePrediction() whenever a recognized gesture changes. */
function maybeSpeakGesture(name) {
  if (!speechEnabled) return;
  if (name === lastSpokenGesture) return; // avoid repeating the same word every frame
  lastSpokenGesture = name;
  const spokenText = SPOKEN_MAP[name] || URDU_MAP[name] || name;
  speakUrdu(spokenText);
}

/* ---------- Speaker button (Urdu TTS on/off) ---------- */

speakerBtn.addEventListener('click', () => {
  speechEnabled = speakerBtn.classList.toggle('is-active');
  speakerBtn.setAttribute('aria-pressed', String(speechEnabled));
  speakerBtn.title = speechEnabled ? 'Urdu voice on' : 'Urdu voice off';

  if (!speechEnabled && window.speechSynthesis) {
    window.speechSynthesis.cancel(); // stop mid-sentence if turned off
  } else if (speechEnabled) {
    lastSpokenGesture = null; // let the next recognized gesture speak immediately
  }
});

/* --------------------------------------------------------------------------
   BACKEND HEALTH — tell the user *why* it is disconnected (404 = not deployed,
   502/503 = starting, no answer = offline) instead of a generic message.
   -------------------------------------------------------------------------- */

let healthTimer = null;

async function checkBackendHealth() {
  clearTimeout(healthTimer);
  let response;
  try {
    response = await fetch(BACKEND_URL + '/health', { cache: 'no-store' });
  } catch (err) {
    setConnText('Cannot reach the server — check internet or change the server', 'error');
    return;
  }

  if (response.status === 404) {
    setConnText('This address has no Gesto backend (404) — click "Change server"', 'error');
    if (changeServerBtn) changeServerBtn.hidden = false;
    return;
  }
  if (response.status >= 500) {
    setConnText('Server is starting up — retrying…', 'warn');
    healthTimer = setTimeout(checkBackendHealth, 15000);
    return;
  }
  if (!response.ok) {
    setConnText('Server error ' + response.status, 'error');
    return;
  }
  try {
    const data = await response.json();
    if (!data.model_loaded) {
      setConnText('Server is up but the model is not loaded', 'warn');
    }
  } catch (err) {
    // Health payload is optional; a 200 is already good news.
  }
}

/** Write a status line without disturbing the dot state. */
function setConnText(text, kind) {
  if (!connText) return;
  connText.textContent = text;
  connDot.className = 'conn-dot';
  connDot.classList.add(kind === 'warn' ? 'is-connecting' : 'is-disconnected');
}

if (changeServerBtn) {
  changeServerBtn.addEventListener('click', promptForBackend);
}

/* ---------- Start / Stop wiring ---------- */

startBtn.addEventListener('click', startCamera);
stopBtn.addEventListener('click', stopCamera);

// Attempt a background connection on load so status is honest before demo.
connectWebSocket();
checkBackendHealth();

/* ---------- Scroll reveal for sections ---------- */

const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('is-visible');
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.12 });

document.querySelectorAll('.panel, .step, .member, .badge, .about__text, .badges')
  .forEach(el => {
    el.classList.add('scroll-reveal');
    revealObserver.observe(el);
  });

/* ---------- Smooth-scroll focus management for in-page anchors ---------- */

document.querySelectorAll('a[href^="#"]').forEach(link => {
  link.addEventListener('click', (e) => {
    const target = document.querySelector(link.getAttribute('href'));
    if (!target) return;
    e.preventDefault();
    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    // Move keyboard focus to the section for accessibility.
    target.setAttribute('tabindex', '-1');
    target.focus({ preventScroll: true });
  });
});
