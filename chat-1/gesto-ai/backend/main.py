"""Gesto AI backend — real-time Pakistan Sign Language -> Urdu speech.

WebSocket endpoint receives JPEG frames, extracts hand landmarks with
MediaPipe Tasks HandLandmarker (VIDEO mode), runs sliding-window gesture
classification with a Keras model, and returns the predicted Urdu gesture
label with confidence.

IMPORTANT: MediaPipe is used ONLY via the Tasks API. The legacy
mp.solutions.hands API does NOT exist in the installed package and must
never be used.
"""

import asyncio
import base64
import json
import os
import pickle
import time
from collections import Counter, deque

import cv2
import numpy as np
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

# MediaPipe — Tasks API ONLY (never mp.solutions.hands).
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision as mp_vision

# Urdu sentence generation for a stable, detected gesture (Qwen + fallback).
from sentence_gen import get_sentence

# ---------------------------------------------------------------------------
# Paths (must work regardless of launch directory)
# ---------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, "models")
KERAS_MODEL_PATH = os.path.join(MODELS_DIR, "gesture_model_unified_final.h5")
LABEL_ENCODER_PATH = os.path.join(MODELS_DIR, "label_encoder.pkl")
HAND_LANDMARKER_PATH = os.path.join(MODELS_DIR, "hand_landmarker.task")

# ---------------------------------------------------------------------------
# Prediction configuration
# ---------------------------------------------------------------------------
SEQUENCE_LENGTH = 30          # frames per input sequence
PREDICT_EVERY_N_FRAMES = 3    # run model every N frames after warm-up
CONFIDENCE_THRESHOLD = 0.75   # minimum confidence to report a gesture
SMOOTHING_WINDOW = 5          # majority vote over last N raw predictions
MAJORITY_MIN_COUNT = 3        # minimum occurrences for a stable majority

app = FastAPI(title="Gesto AI", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Model loading (synchronous, at startup). Missing files must NOT crash the
# server: flags stay False, /health reports model_loaded=false and the
# WebSocket responds with reason "not_ready".
# ---------------------------------------------------------------------------
model = None
label_encoder = None
hand_landmarker = None
MODEL_LOADED = False
GESTURE_LABELS: list = []  # always derived from label_encoder.classes_

# ---------------------------------------------------------------------------
# Shared-detector concurrency guard. VIDEO-mode detect_for_video requires
# strictly increasing timestamps ACROSS ALL callers and is not safe for
# concurrent invocation. The lock serializes every detect call (asyncio.to_
# thread still keeps the blocking call off the event loop) and the global
# counter guarantees monotonically increasing timestamps even when multiple
# WebSocket sessions interleave.
# ---------------------------------------------------------------------------
detector_lock = asyncio.Lock()
last_global_timestamp_ms = 0

try:
    with open(LABEL_ENCODER_PATH, "rb") as f:
        label_encoder = pickle.load(f)
    # Gesture class names come from the encoder at runtime — never hardcoded.
    GESTURE_LABELS = list(label_encoder.classes_)

    from keras.models import load_model as keras_load_model

    model = keras_load_model(KERAS_MODEL_PATH)

    base_options = mp_python.BaseOptions(model_asset_path=HAND_LANDMARKER_PATH)
    options = mp_vision.HandLandmarkerOptions(
        base_options=base_options,
        running_mode=mp_vision.RunningMode.VIDEO,
        num_hands=1,
        min_hand_detection_confidence=0.5,
        min_hand_presence_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    hand_landmarker = mp_vision.HandLandmarker.create_from_options(options)

    MODEL_LOADED = True
    print("[gesto-ai] All models loaded. Gesture classes:", GESTURE_LABELS)
except Exception as exc:  # noqa: BLE001 - startup must not crash
    MODEL_LOADED = False
    print(f"[gesto-ai] Models NOT loaded (server starts in not_ready mode): {exc}")


# ---------------------------------------------------------------------------
# Per-WebSocket-connection session state (instance per connection, NOT global)
# ---------------------------------------------------------------------------
class PredictionSession:
    """Sliding-window prediction state for one WebSocket connection."""

    def __init__(self) -> None:
        self.frame_buffer: deque = deque(maxlen=SEQUENCE_LENGTH)
        self.raw_predictions: deque = deque(maxlen=SMOOTHING_WINDOW)
        self.warmed_up = False
        self.frames_since_predict = 0
        # Strictly increasing per-session timestamp counter (int ms).
        self.last_timestamp_ms = 0
        # Cached last response, replayed on non-prediction frames.
        self.last_response = {
            "gesture": None,
            "confidence": 0.0,
            "reason": "warming_up",
        }

    def next_timestamp_ms(self) -> int:
        """Strictly increasing millisecond timestamp, fresh per connection."""
        wall_ms = int(time.time() * 1000)
        ts = wall_ms if wall_ms > self.last_timestamp_ms else self.last_timestamp_ms + 1
        self.last_timestamp_ms = ts
        return ts


async def detect_hand_landmarks(rgb_frame: np.ndarray, timestamp_hint_ms: int):
    """Run HandLandmarker in VIDEO mode (in a worker thread).

    Returns a (21, 3) float32 array of landmarks or None if no hand found.

    The per-session timestamp is only a hint: under the global lock the real
    timestamp is max(hint, last_global_ts + 1) so it is strictly increasing
    across every concurrent connection.
    """
    global last_global_timestamp_ms
    # NOTE: Image/ImageFormat are exposed on the top-level mediapipe package
    # (same classes; mp_python re-exports only BaseOptions/components/etc).
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
    async with detector_lock:
        last_global_timestamp_ms = max(
            timestamp_hint_ms, last_global_timestamp_ms + 1
        )
        timestamp_ms = last_global_timestamp_ms
        # detect_for_video must NEVER run directly in the async event loop.
        result = await asyncio.to_thread(
            hand_landmarker.detect_for_video, mp_image, timestamp_ms
        )
    if not result.hand_landmarks:
        return None
    landmarks = result.hand_landmarks[0]
    return np.array(
        [[lm.x, lm.y, lm.z] for lm in landmarks], dtype=np.float32
    )


def extract_features(landmarks: np.ndarray) -> np.ndarray:
    """Wrist-relative, scale-normalized 63-dim feature vector (matches training)."""
    centered = landmarks - landmarks[0]  # wrist-relative
    norm = np.linalg.norm(centered[9])
    scale = norm if norm >= 1e-6 else 1.0  # scale-normalize by middle-finger MCP
    return (centered / scale).astype(np.float32).flatten()  # (63,)


def decode_frame(b64_data: str):
    """base64 JPEG -> BGR frame, or None on failure."""
    raw = base64.b64decode(b64_data)
    buf = np.frombuffer(raw, dtype=np.uint8)
    return cv2.imdecode(buf, cv2.IMREAD_COLOR)


def smooth_prediction(session: PredictionSession, latest_probs: np.ndarray):
    """Majority vote over the last SMOOTHING_WINDOW raw predictions.

    Requires the majority class to appear >= MAJORITY_MIN_COUNT times and
    the confidence for that class to be >= CONFIDENCE_THRESHOLD.
    """
    counts = Counter(idx for idx, _ in session.raw_predictions)
    majority_idx, majority_count = counts.most_common(1)[0]
    confidence = float(latest_probs[majority_idx])

    if majority_count >= MAJORITY_MIN_COUNT and confidence >= CONFIDENCE_THRESHOLD:
        session.last_response = {
            "gesture": GESTURE_LABELS[majority_idx],
            "confidence": confidence,
            "reason": None,  # contract completeness: reason is always present
        }
    else:
        session.last_response = {
            "gesture": None,
            "confidence": confidence,
            "reason": "below_threshold",
        }


async def process_frame(session: PredictionSession, bgr_frame: np.ndarray) -> dict:
    """Full per-frame pipeline. Returns the JSON response dict."""
    # BGR -> RGB. NO flipping/mirroring anywhere — frame reaches MediaPipe
    # exactly as captured.
    rgb_frame = cv2.cvtColor(bgr_frame, cv2.COLOR_BGR2RGB)

    timestamp_hint_ms = session.next_timestamp_ms()
    landmarks = await detect_hand_landmarks(rgb_frame, timestamp_hint_ms)
    if landmarks is None:
        session.last_response = {
            "gesture": None,
            "confidence": 0.0,
            "reason": "no_hand",
        }
        return session.last_response

    features = extract_features(landmarks)
    session.frame_buffer.append(features)

    if len(session.frame_buffer) < SEQUENCE_LENGTH:
        session.last_response = {
            "gesture": None,
            "confidence": 0.0,
            "reason": "warming_up",
        }
        return session.last_response

    # Predict on the frame that completes the first window, then on every
    # PREDICT_EVERY_N_FRAMES-th frame afterwards (with N=3: two skipped
    # frames, predict on the third — trace: fs 0->1->2 -> predict, reset).
    should_predict = (
        not session.warmed_up
        or session.frames_since_predict >= PREDICT_EVERY_N_FRAMES - 1
    )
    if should_predict:
        session.warmed_up = True
        session.frames_since_predict = 0

        sequence = np.asarray(session.frame_buffer, dtype=np.float32).reshape(
            1, SEQUENCE_LENGTH, 63
        )
        # model.predict must NEVER run directly in the async event loop.
        probs = await asyncio.to_thread(model.predict, sequence, verbose=0)
        probs = probs[0]
        best_idx = int(np.argmax(probs))
        session.raw_predictions.append((best_idx, float(probs[best_idx])))
        smooth_prediction(session, probs)

        # Stable gesture detected -> attach an Urdu sentence (Qwen, cached
        # after first call per gesture; falls back internally on failure).
        if session.last_response.get("gesture"):
            sentence = await asyncio.to_thread(
                get_sentence, session.last_response["gesture"]
            )
            session.last_response["sentence"] = sentence
    else:
        session.frames_since_predict += 1
        # Non-prediction frame: replay the cached stable/below-threshold result.

    return session.last_response


# ---------------------------------------------------------------------------
# HTTP endpoints
# ---------------------------------------------------------------------------
@app.get("/health")
async def health():
    return {
        "status": "ok",
        "model_loaded": MODEL_LOADED,
        "gesture_labels": GESTURE_LABELS,
        "config": {
            "SEQUENCE_LENGTH": SEQUENCE_LENGTH,
            "PREDICT_EVERY_N_FRAMES": PREDICT_EVERY_N_FRAMES,
            "CONFIDENCE_THRESHOLD": CONFIDENCE_THRESHOLD,
            "SMOOTHING_WINDOW": SMOOTHING_WINDOW,
        },
    }


# ---------------------------------------------------------------------------
# WebSocket endpoint
# ---------------------------------------------------------------------------
@app.websocket("/ws/predict")
async def ws_predict(websocket: WebSocket):
    await websocket.accept()
    session = PredictionSession()  # fresh per-connection state
    while True:
        try:
            message = await websocket.receive_text()

            if not MODEL_LOADED:
                await websocket.send_json(
                    {"gesture": None, "confidence": 0.0, "reason": "not_ready"}
                )
                continue

            try:
                payload = json.loads(message)
                b64_frame = payload.get("frame")
                if not isinstance(b64_frame, str):
                    raise ValueError("missing frame")
                bgr_frame = decode_frame(b64_frame)
                if bgr_frame is None:
                    raise ValueError("imdecode returned None")
            except Exception:  # noqa: BLE001
                await websocket.send_json(
                    {"gesture": None, "confidence": 0.0, "reason": "decode_failed"}
                )
                continue

            response = await process_frame(session, bgr_frame)
            await websocket.send_json(response)
        except WebSocketDisconnect:
            # Clean disconnect — exit the loop normally.
            return
        except Exception as exc:  # noqa: BLE001
            # One bad frame must NOT kill the connection: report it for this
            # frame only and keep the receive loop running.
            try:
                await websocket.send_json(
                    {"gesture": None, "confidence": 0.0, "reason": "decode_failed"}
                )
            except Exception:  # noqa: BLE001
                pass
            print(f"[gesto-ai] Frame error (connection kept alive): {exc}")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000)