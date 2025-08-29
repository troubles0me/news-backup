import random
from typing import List
import json
import os
from dotenv import load_dotenv

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from openai import OpenAI

# maekyung_scraper.py에서 함수 가져오기
from mk_news_reader import scrape_maekyung_article

# 환경 변수 로드
load_dotenv()

# --- 1. 기본 설정 ---
app = FastAPI()

# OpenAI API 키를 환경 변수에서 가져오기
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


# --- 2. CORS 설정 ---
origins = ["http://localhost:3000", "http://20.41.113.134", "http://20.41.113.134:80"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 3. 데이터 형식 정의 ---
class ScrapeRequest(BaseModel):
    url: str

class ChatRequest(BaseModel):
    word: str
    context: str

class LearnedEntry(BaseModel):
    word: str
    definition: str

class QuizRequest(BaseModel):
    entries: List[LearnedEntry]

# --- 4. API 엔드포인트 만들기 ---

@app.get("/")
def read_root():
    return {"status": "Backend server is running!"}

@app.post("/api/scrape")
def handle_scrape(request: ScrapeRequest):
    article = scrape_maekyung_article(request.url)
    if article:
        return article
    return {"error": "Failed to scrape article"}

# 테스트를 위해 추가했던 API 엔드포인트
@app.get("/api/")
def read_api_root():
    return {"message": "API server is working!"}


@app.post("/api/chat")
def handle_chat(request: ChatRequest):
    try:
        completion = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "너는 어려운 단어를 초등학생도 이해할 수 있게 설명해주는 친절한 AI 선생님이야."},
                {"role": "user", "content": f"'{request.word}'라는 단어가 무슨 뜻이야? 이 단어는 아래 뉴스 기사 내용에서 사용되었어.\\n---\\n{request.context[:1000]}\\n---"}
            ]
        )
        answer = completion.choices[0].message.content
        return {"answer": answer}
    except Exception as e:
        return {"error": f"OpenAI API Error: {e}"}

# 퀴즈 생성 API
@app.post("/api/quiz")
def handle_quiz(request: QuizRequest):
    if not request.entries:
        return {"error": "퀴즈를 만들려면 최소 1개 이상의 단어를 학습해야 합니다."}

    # 퀴즈 생성을 최대 3번까지 시도
    for attempt in range(3):
        try:
            # 출제할 단어와 '챗봇의 긴 설명'을 랜덤으로 선택
            correct_entry = random.choice(request.entries)
            answer_word = correct_entry.word
            long_definition = correct_entry.definition

            # --- 1. '챗봇의 긴 설명'을 '간결한 핵심 정의'로 요약 ---
            summarize_prompt = f"""
            다음은 '{answer_word}'라는 단어에 대한 설명이야. 이 설명에서 가장 핵심적인 정의만 한 문장으로 간결하게 요약해줘.
            다른 부가 설명이나 예시는 모두 제외하고, 오직 사전적인 정의만 남겨줘.

            원본 설명: "{long_definition}"
            """
            summary_completion = client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {"role": "system", "content": "너는 긴 문장에서 핵심 정의만 추출하여 한 문장으로 요약하는 AI야."},
                    {"role": "user", "content": summarize_prompt}
                ]
            )
            correct_definition = summary_completion.choices[0].message.content.strip()

            # --- 2. '간결한 정의'를 기반으로 오답 선택지 3개 생성 ---
            distractor_prompt = f"""
            '{answer_word}'라는 한국어 단어에 대한 퀴즈의 오답 선택지 3개를 만들어줘.
            정답은 이미 "{correct_definition}"으로 정해져 있어.
            이 정답과 비슷하지만 명백히 틀린, 그럴듯한 오답용 뜻 3개를 리스트 형태로 만들어줘.
            결과는 반드시 아래와 같은 JSON 형식으로만 응답하고, 다른 설명은 절대 추가하지 마.

            {{
              "distractors": ["오답 뜻 1", "오답 뜻 2", "오답 뜻 3"]
            }}
            """
            distractor_completion = client.chat.completions.create(
                model="gpt-4-turbo",
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": "너는 한국어 어휘 퀴즈의 오답 선택지를 JSON 형식으로 만드는 AI야."},
                    {"role": "user", "content": distractor_prompt}
                ]
            )

            quiz_data = json.loads(distractor_completion.choices[0].message.content)

            # --- 3. AI 응답 검증 및 퀴즈 조립 ---
            if "distractors" not in quiz_data or len(quiz_data["distractors"]) != 3:
                continue

            options = quiz_data["distractors"]
            if not correct_definition or not all(options):
                continue
            
            options.append(correct_definition)
            random.shuffle(options)

            return {
                "question": answer_word,
                "options": options,
                "answer": correct_definition
            }

        except Exception as e:
            continue
    
    return {"error": "AI가 퀴즈를 생성하는 데 실패했습니다. 잠시 후 다시 시도해주세요."}

