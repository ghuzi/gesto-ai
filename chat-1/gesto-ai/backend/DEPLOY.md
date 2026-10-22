# Backend deploy — fix "Server unreachable"

The app and the web page both talk to the FastAPI backend. If they show
**Server unreachable**, the backend is not running — the app itself is fine.

## First: check what is wrong

Open this in a browser (or `curl`):

```
https://<your-backend-host>/health
```

| What you see | Meaning | Fix |
| --- | --- | --- |
| `{"status":"ok","model_loaded":true,...}` | Backend is healthy | nothing to do |
| `{"message":"Application not found"}` (HTTP 404, `x-railway-fallback: true`) | **The Railway service no longer exists** (deleted, trial ended, or the domain was released) | redeploy — see below |
| HTTP 502 / 503 / 504 | the container is asleep or booting | wait ~60 s, the app retries automatically |
| timeout / no answer | sleeping, or the host is down | wait, then redeploy if it never wakes |
| `{"model_loaded":false}` | server runs, model files missing | copy the 3 files from `models/` into the deploy |

> 2026-10-22: `gesto-ai-production.up.railway.app` returned
> `404 Application not found` — that service is gone. Everything below
> recreates it.

## Option A — Railway (same host as before)

### In the browser
1. <https://railway.app/new> → **Deploy from GitHub repo** → `ghuzi/gesto-ai`.
2. Open the service → **Settings**:
   * **Root Directory**: `chat-1/gesto-ai/backend`
   * **Builder**: `Dockerfile` (the repo has `backend/Dockerfile` + `railway.json`)
3. **Variables** (optional, only for the Qwen sentences):
   `DASHSCOPE_API_KEY`, `DASHSCOPE_BASE_URL`
4. **Networking → Generate Domain** → copy the URL, e.g.
   `https://gesto-ai-backend-production.up.railway.app`
   (the first deploy may take 5–10 min: TensorFlow + MediaPipe are heavy —
   `railway.json` gives the health check 300 s.)
5. Open `https://<that-domain>/health` until it says `"model_loaded": true`.

### With the CLI
```bash
npm i -g @railway/cli
railway login
cd chat-1/gesto-ai/backend
railway init          # or: railway link  (to an existing project)
railway up
railway domain        # prints the public URL
```

## Option B — Render (free-ish alternative)

1. <https://dashboard.render.com/blueprints> → **New Blueprint Instance**
2. Pick this repo — `backend/render.yaml` is detected automatically
   (Docker, health check `/health`).
3. Copy the service URL from the dashboard.

Free instances sleep after 15 min idle; the first request then takes ~60 s.
The app waits 45 s and keeps retrying by itself, so just leave it on screen.

## Option C — your own laptop (works offline, no account)

```bash
cd chat-1/gesto-ai/backend
python -m venv .venv && . .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Find the laptop IP (`ipconfig` / `ifconfig`), e.g. `192.168.1.10`, then in the
app: **Home → Server status → Change server** →
`http://192.168.1.10:8000` → **Test connection** → **Save**.
Phone and laptop must be on the same Wi-Fi. Plain `http://` already works —
the Android manifest allows cleartext traffic.

## Point the app (and the web page) at the new server

* **App:** Home → *Server status* → **Change server**, or **Settings → Backend server**.
  Saved permanently; no rebuild needed.
* **App (baked in at build time):**
  `flutter build apk --dart-define=GESTO_API_BASE=https://your-new-host`
* **Web frontend:** `chat-1/gesto-ai/frontend/script.js` → `WS_URL`, then redeploy Vercel.

## Why a fresh deploy used to crash

`sentence_gen.py` built the Qwen client at **import time**:

```python
client = OpenAI(api_key=os.getenv("DASHSCOPE_API_KEY"), ...)   # raises when the key is unset
```

Without `DASHSCOPE_*` variables the import threw, uvicorn exited before binding
a port, and the platform restarted the container forever (502/503 from outside,
"deployment failed" in the dashboard). The client is now created lazily and the
built-in Urdu sentences are used when Qwen is not configured, so **a deploy with
zero environment variables now works**. Verified with the
`.github/workflows/backend-docker-smoke.yml` job: image builds, container boots
with an injected `PORT`, `/health` reports `model_loaded: true` and 14 gestures.

## Notes

* The Dockerfile now honours the platform's `$PORT`
  (`uvicorn --port ${PORT}`) — hardcoding 8080 is what silently breaks some hosts.
* `railway.json` sets `healthcheckPath: /health` and a 300 s timeout so a slow
  TensorFlow boot is not killed mid-start.
* Model files must be present in the image: `models/gesture_model_unified_final.h5`,
  `label_encoder.pkl`, `hand_landmarker.task` (they are in the repo).
