import os
from typing import Optional

from dotenv import load_dotenv

load_dotenv()

SYSTEM_PROMPT = """Tum sirf ek Urdu jumla generate karte ho, kuch aur nahi.
Neeche diye gaye exact mappings follow karo - ye correct hain, inhe mat badalo:
help -> مجھے مدد چاہیے
pain -> مجھے درد ہو رہا ہے
doctor -> مجھے ڈاکٹر چاہیے
sick -> میری طبیعت خراب ہے
ambulance -> ایمبولینس بلائیں
good -> ٹھیک ہے
home -> مجھے گھر جانا ہے
no -> نہیں
yes -> ہاں
sleep -> مجھے نیند آ رہی ہے
sorry -> معاف کیجیے
eat -> مجھے کھانا چاہیے
drink -> مجھے پانی چاہیے
thankyou -> شکریہ

Agar gesture upar list mein na ho, tab hi khud se ek chota, first-person, grammatically sahi jumla banao. Sirf jumla do, kuch explanation nahi."""

# Agar Qwen call fail ho jaye (internet/quota/cold start), ye fallback use hoga
FALLBACK_SENTENCES = {
    "help": "مجھے مدد چاہیے",
    "pain": "مجھے درد ہو رہا ہے",
    "doctor": "مجھے ڈاکٹر چاہیے",
    "sick": "میری طبیعت خراب ہے",
    "ambulance": "ایمبولینس بلائیں",
    "good": "ٹھیک ہے",
    "home": "مجھے گھر جانا ہے",
    "no": "نہیں",
    "yes": "ہاں",
    "sleep": "مجھے نیند آ رہی ہے",
    "sorry": "معاف کیجیے",
    "eat": "مجھے کھانا چاہیے",
    "drink": "مجھے پانی چاہیے",
    "thankyou": "شکریہ",
}

_cache: dict[str, str] = {}

# The Qwen client is built lazily and never at import time: instantiating
# OpenAI() without an API key raises, which used to crash the whole server
# before it could even bind a port (every deploy without DASHSCOPE_* env
# vars died in a restart loop).
_client = None
_client_ready = False
_client_error: Optional[str] = None


def _get_client():
    """Return a configured OpenAI client, or None when Qwen is unavailable."""
    global _client, _client_ready, _client_error
    if _client_ready:
        return _client
    _client_ready = True

    api_key = os.getenv("DASHSCOPE_API_KEY")
    base_url = os.getenv("DASHSCOPE_BASE_URL")
    if not api_key:
        _client_error = "DASHSCOPE_API_KEY is not set"
        print("[gesto-ai] Qwen disabled (no DASHSCOPE_API_KEY) — using fallback sentences")
        return None

    try:
        from openai import OpenAI

        _client = OpenAI(api_key=api_key, base_url=base_url or None)
    except Exception as exc:  # noqa: BLE001 - never break startup over TTS text
        _client_error = str(exc)
        _client = None
        print(f"[gesto-ai] Qwen client unavailable ({exc}) — using fallback sentences")
    return _client


def get_sentence(gesture: str) -> str:
    """Gesture label -> Urdu sentence. Cached per-process; falls back to a
    static dictionary if Qwen is not configured, fails, or times out."""
    gesture = gesture.lower()
    if gesture in _cache:
        return _cache[gesture]

    sentence = FALLBACK_SENTENCES.get(gesture, gesture)
    client = _get_client()
    if client is not None:
        try:
            response = client.chat.completions.create(
                model="qwen-flash-character",
                temperature=0.1,
                max_tokens=30,
                timeout=3,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": f"Gesture: {gesture}\nJumla:"},
                ],
            )
            text = (response.choices[0].message.content or "").strip()
            if text:
                sentence = text
        except Exception as exc:  # noqa: BLE001
            print(f"[gesto-ai] Qwen call failed, using fallback: {exc}")

    _cache[gesture] = sentence
    return sentence
