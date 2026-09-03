from dotenv import load_dotenv
import os
from openai import OpenAI

load_dotenv()

client = OpenAI(
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
)

SYSTEM_PROMPT = """Tum sirf ek Urdu jumla generate karte ho, kuch aur nahi.
Neeche diye gaye exact mappings follow karo — ye correct hain, inhe mat badalo:
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

def get_sentence(gesture: str) -> str:
    response = client.chat.completions.create(
        model="qwen-flash-character",
        temperature=0.1,
        max_tokens=30,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Gesture: {gesture}\nJumla:"}
        ]
    )
    return response.choices[0].message.content.strip()

if __name__ == "__main__":
    for word in ["pain", "help", "water"]:
        print(word, "->", get_sentence(word))