# Gesto AI

Real-time Pakistan Sign Language (PSL) → Urdu speech. The backend captures
hand landmarks with MediaPipe (Tasks API, VIDEO mode), classifies gestures
with a Keras sliding-window model over a WebSocket, and the frontend
converts stable gestures into Urdu speech.

## Repository layout

```
gesto-ai/
├── backend/
│   ├── main.py              # FastAPI + WebSocket prediction server
│   ├── requirements.txt
│   └── models/              # ← copy model files here manually (see below)
└── frontend/
    └── index.html           # static frontend (camera + Urdu speech)
```

## Backend setup & run

Requires Python 3.10–3.12 (tensorflow 2.19 / numpy 1.26 have no wheels
for 3.13+).

```powershell
cd gesto-ai/backend

# Optional: create a virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### Copy the model files (manual step, required)

Copy these three files into `backend/models/` before the server can predict:

- `gesture_model_unified_final.h5` — Keras gesture classifier
- `label_encoder.pkl` — scikit-learn LabelEncoder (gesture class names)
- `hand_landmarker.task` — MediaPipe HandLandmarker model

The server starts even if these files are missing, but `GET /health` will
report `"model_loaded": false` and the WebSocket will respond with reason
`"not_ready"` until they are copied and the server is restarted.

After copying the three model files and restarting the server, verify
`GET http://localhost:8000/health` returns `"model_loaded": true` before
demo day.

### Start the server

```powershell
cd gesto-ai/backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

Health check: <http://localhost:8000/health> (reports load status, gesture
labels, and the prediction config: `SEQUENCE_LENGTH=30`,
`PREDICT_EVERY_N_FRAMES=3`, `CONFIDENCE_THRESHOLD=0.75`, `SMOOTHING_WINDOW=5`).

WebSocket endpoint: `ws://localhost:8000/ws/predict`
— send `{"frame": "<base64 JPEG, no data-url prefix>"}`, receive
`{"gesture": "<name or null>", "confidence": <float>, "reason": "<optional>"}`.

Note: the frontend hardcodes `ws://localhost:8000` (`WS_URL` in
`frontend/script.js`), so the backend must run on port 8000.

## Frontend setup & run

The frontend is static — no build step. Serve it locally (recommended):

```powershell
cd gesto-ai
python -m http.server 5500 --directory frontend
```

Then open <http://localhost:5500>.

Alternatively you can open the file directly
(`gesto-ai/frontend/index.html`), but if the camera won't start over
`file://`, use the HTTP server above instead — `getUserMedia` requires a
secure context (https or localhost).

## Troubleshooting

- **Port 8000 already in use** — find and kill the stale process:

  ```powershell
  netstat -ano | findstr :8000
  taskkill /PID <PID shown> /F
  ```

  Remember the frontend hardcodes `ws://localhost:8000` (`WS_URL` in
  `script.js`), so the backend must run on port 8000.
- **Camera won't start** — open the page via the local HTTP server
  (<http://localhost:5500>) instead of `file://`; `getUserMedia` needs a
  secure context.
