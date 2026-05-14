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
        "model": "mistralai/Mistral-7B-Instruct-v0.2",
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

        {

            "role": "system",

            "content": (

                "You are a professional e-commerce marketplace for family businesses analyst. Your task is to summarize reviews with a focus on 'Consensus' and 'Overall meaning' of the reviews."

                f"\nCRITICAL RULE: {lang_instruction} ONLY"

                "\n1. Identify the majority opinion and lead with it."

                "\n2. If most reviews are positive, keep the tone encouraging and highlight the strengths."

                "\n3. Briefly mention any minority concerns (if any) at the end of the sentence as a minor note."

                "\n4. Ensure the output is a single, consistent, sophisticated, and professional sentence."

                "\n5. Avoid repetition and redundant phrases."



            )

        },

        {

            "role": "user",

            "content": f"Summarize these reviews starting with '{start_phrase}':\n\n{' . '.join(reviews)}"

        }

    ]
    return query_hf_api(messages, params)

def enhance_description(raw_text: str):
    params = {"max_new_tokens": 250, "temperature": 0.5}
    messages = [

        {

            "role": "system",

            "content": (

                "You are a professional marketing content writer specializing in the e-commerce market for home-based businesses."                

                "\nYour task is to only REFORMAT and ENHANCE descriptions to be attractive and professional."

                "\nCRITICAL RULES:"

                "\n1. Respond in the same language throughout the whole text (arabic or english)"

                "\n2. Do not add new information."

                "\nSTRICT RULES:"

                "\n1. Ensure the tone is warm and brief."

                "\n2. Ensure the output is sophisticated and professional sentence."

            )

        },

        {

            "role": "user",

            "content": f"enhance this product description:\n\n{raw_text}"

        }

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

                "You are a professional Customer Support Assistant specializing in the e-commerce market for home-based businesses."

                f"\nPRODUCT INFO:"

                f"\n- Name: {data.product_name}"

                f"\n- Description: {data.product_description}"

                f"\n- Specific Details: {data.product_details}"

                f"\n- Customer name:{data.customer_name}"

                "\nCRITICAL RULE: Always respond in the same review language throughout the whole text ONLY"

                "\nINSTRUCTIONS:"

                "\n1. Use the PRODUCT INFO above to answer questions."

                f"\n2. Greet customer usnig {data.customer_name} and keep it nice and short."

                "\n3. Understand then respond to the question/review without follow-up questions"

            )

        },

        {

            "role": "user",

            "content": f"Customer Review/Question: {data.review_text}"

        }

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
