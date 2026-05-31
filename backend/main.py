import os
import json
import random
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from openai import OpenAI
from dotenv import load_dotenv
from prompts import SYSTEM_PROMPT, CONTEXT_MAP

load_dotenv()

app = FastAPI(title="Shadow Chase Chatbot")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST"],
    allow_headers=["*"],
)

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Frases de fallback (sem API)
FALLBACK_MESSAGES = {
    "chase_start": [
        ("Ele está logo atrás de você.", "normal"),
        ("Não olhe para trás.", "normal"),
        ("Corra. Corra mais rápido.", "whisper"),
    ],
    "player_died": [
        ("Você sempre soube que ia falhar.", "normal"),
        ("Descanse. Por um momento.", "whisper"),
    ],
    "level_start": [
        ("Bem-vindo. Ele já sabe que você chegou.", "normal"),
        ("Esta fase... ela muda as pessoas.", "whisper"),
    ],
    "level_complete": [
        ("Você sobreviveu. Por enquanto.", "normal"),
        ("Ele só deixou você passar.", "whisper"),
    ],
    "default": [
        ("Ele ainda está lá.", "whisper"),
        ("Não se sinta seguro.", "normal"),
        ("Ouço seus passos.", "whisper"),
        ("Continue. Se conseguir.", "normal"),
    ],
}


class GameState(BaseModel):
    player_state: str = "running"
    creature_distance: float = 500.0
    game_time: float = 0.0
    current_level: int = 1
    is_being_chased: bool = False
    last_error: str = ""
    event: Optional[str] = None


def build_user_prompt(state: GameState) -> str:
    context = ""
    if state.event and state.event in CONTEXT_MAP:
        context = CONTEXT_MAP[state.event]
    else:
        if state.is_being_chased:
            context = "A criatura está perseguindo o jogador ativamente."
        elif state.creature_distance < 300:
            context = "A criatura está relativamente próxima. Crie tensão."
        elif state.player_state == "idle":
            context = "O jogador parou de se mover. Isso é perigoso."
        else:
            context = "Situação normal. Mantenha a tensão psicológica."

    msg_type = "whisper" if random.random() < 0.35 else "normal"

    return f"""{context}

Estado atual:
- Jogador: {state.player_state}
- Distância da criatura: {state.creature_distance:.0f}px
- Tempo de jogo: {state.game_time:.0f}s
- Nível: {state.current_level}
- Em perseguição: {state.is_being_chased}

Responda APENAS com JSON neste formato exato:
{{"message": "<sua mensagem aqui>", "type": "{msg_type}"}}
"""


def get_fallback_response(event: Optional[str]) -> dict:
    key = event if event in FALLBACK_MESSAGES else "default"
    msg, msg_type = random.choice(FALLBACK_MESSAGES[key])
    return {"message": msg, "type": msg_type}


@app.post("/chat")
async def chat_endpoint(state: GameState):
    try:
        user_prompt = build_user_prompt(state)
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            max_tokens=60,
            temperature=0.9,
        )
        raw = response.choices[0].message.content.strip()
        data = json.loads(raw)
        return {
            "message": data.get("message", ""),
            "type": data.get("type", "normal"),
        }
    except Exception as e:
        print(f"Erro na API: {e}. Usando fallback.")
        return get_fallback_response(state.event)


@app.get("/health")
async def health_check():
    return {"status": "running", "game": "Shadow Chase"}
