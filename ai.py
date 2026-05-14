import requests
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

HF_TOKEN = os.getenv("HF_TOKEN")
API_URL = "https://router.huggingface.co/v1/chat/completions"
headers = {"Authorization": f"Bearer {HF_TOKEN}"}

def query_hf_api(messages, params):
    payload = {
        "model": "Qwen/Qwen2.5-7B-Instruct",
        "messages": messages,
        "max_tokens": params.get("max_new_tokens", 150),
        "temperature": params.get("temperature", 0.5),
    }
    response = requests.post(API_URL, headers=headers, json=payload)
    if not response.ok:
        raise HTTPException(status_code=502, detail=f"HF API error {response.status_code}: {response.text[:300]}")
    result = response.json()
    if "choices" not in result:
        raise HTTPException(status_code=502, detail=f"Unexpected HF response: {str(result)[:300]}")
    return result["choices"][0]["message"]["content"]

def get_summary(reviews: List[str], user_lang: str = "en"):
    params = {"max_new_tokens": 100, "temperature": 0.2}
    if user_lang == "ar":
        lang_instruction = "Always respond in Arabic. Start with 'بشكل عام، يرى العملاء...'"
        start_phrase = "بشكل عام، يرى العملاء"
    else:
        lang_instruction = "Always respond in English. Start with 'Overall, customers...'"
        start_phrase = "Overall, customers"
    messages = [
        {"role": "system", "content": f"You are a professional analyst. {lang_instruction} Summarize strictly in ONE sentence."},
        {"role": "user", "content": f"Summarize these reviews starting with '{start_phrase}':\n\n{' . '.join(reviews)}"},
    ]
    return query_hf_api(messages, params)

def enhance_description(raw_text: str):
    params = {"max_new_tokens": 250, "temperature": 0.5}
    messages = [
        {
            "role": "system",
            "content": (
                "You are a professional marketing writer. REFORMAT and ENHANCE the description."
                "\n1. Same language as input. 2. Warm tone. 3. Bullet points and emojis. 4. No new facts."
            ),
        },
        {"role": "user", "content": f"Enhance this product description:\n\n{raw_text}"},
    ]
    return query_hf_api(messages, params).replace("\\n", "\n")

class ReviewRequest(BaseModel):
    product_name: str
    product_description: str
    product_details: str
    customer_name: str
    review_text: str

def generate_reply(data: ReviewRequest):
    params = {"max_new_tokens": 150, "temperature": 0.3}
    messages = [
        {
            "role": "system",
            "content": (
                f"You are customer support for 'Usaruna'. INFO: Name: {data.product_name}, Desc: {data.product_description}, Details: {data.product_details}."
                f"\nGreet {data.customer_name}. Respond ONLY in the customer's language. Be short. No follow-up questions."
            ),
        },
        {"role": "user", "content": data.review_text},
    ]
    return query_hf_api(messages, params).strip()

class ProductDesc(BaseModel):
    description: str

class ReviewData(BaseModel):
    reviews: List[str]
    lang: str = "en"

@app.post("/smart-reply")
async def smart_reply_endpoint(data: ReviewRequest):
    return {"suggested_reply": generate_reply(data)}

@app.post("/enhance")
async def enhance_endpoint(data: ProductDesc):
    return {"enhanced_description": enhance_description(data.description)}

@app.post("/summarize")
async def summarize_endpoint(data: ReviewData):
    return {"summary": get_summary(data.reviews, data.lang)}
