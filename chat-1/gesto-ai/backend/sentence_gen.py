import os
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

client = OpenAI(
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
)

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

# Agar Qwen call fail ho jaye (internet/quota issue), ye fallback use hoga
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


def get_sentence(gesture: str) -> str:
    """Gesture label -> Urdu sentence. Cached per-process; falls back to a
    static dictionary if the Qwen call fails or times out."""
    gesture = gesture.lower()
    if gesture in _cache:
        return _cache[gesture]

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
        sentence = response.choices[0].message.content.strip()
    except Exception as exc:  # noqa: BLE001
        print(f"[gesto-ai] Qwen call failed, using fallback: {exc}")
        sentence = FALLBACK_SENTENCES.get(gesture, gesture)

    _cache[gesture] = sentence
    return sentence