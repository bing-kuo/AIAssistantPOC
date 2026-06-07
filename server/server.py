from fastapi import FastAPI, UploadFile, File, Request, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from faster_whisper import WhisperModel
from collections import defaultdict, deque
from dotenv import load_dotenv
import shutil
import os
import json
import time

load_dotenv()

app = FastAPI()

print("Loading Whisper Model...")
WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "small")
model = WhisperModel(WHISPER_MODEL, device="cpu", compute_type="int8")
print(f"Whisper Model Loaded: {WHISPER_MODEL}")


@app.post("/api/v1/stt")
async def speech_to_text(file: UploadFile = File(...)):
    temp_file = f"temp_{file.filename}"
    with open(temp_file, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    segments, info = model.transcribe(temp_file, beam_size=5, vad_filter=True)

    text = "".join([segment.text for segment in segments])

    os.remove(temp_file)
    return {"text": text, "language": info.language}


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]


MAX_MESSAGES = int(os.environ.get("LLM_MAX_MESSAGES", "40"))
MAX_CHARS = int(os.environ.get("LLM_MAX_CHARS", "8000"))
RATE_LIMIT = int(os.environ.get("LLM_RATE_LIMIT", "30"))
RATE_WINDOW_SECONDS = 60

_request_times = defaultdict(deque)
_openai_client = None


def enforce_rate_limit(client_ip: str):
    now = time.time()
    history = _request_times[client_ip]
    while history and now - history[0] > RATE_WINDOW_SECONDS:
        history.popleft()
    if len(history) >= RATE_LIMIT:
        raise HTTPException(status_code=429, detail="rate limited")
    history.append(now)


def get_openai_client():
    global _openai_client
    if _openai_client is None:
        from openai import OpenAI

        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise RuntimeError("OPENAI_API_KEY is not set")
        _openai_client = OpenAI(api_key=api_key)
    return _openai_client


def stream_openai(messages):
    client = get_openai_client()
    model_name = os.environ.get("LLM_MODEL", "gpt-5.4-mini")
    max_tokens = int(os.environ.get("LLM_MAX_TOKENS", "512"))
    completion = client.chat.completions.create(
        model=model_name,
        messages=messages,
        max_tokens=max_tokens,
        stream=True,
    )
    for chunk in completion:
        delta = chunk.choices[0].delta.content
        if delta:
            yield delta


def stream_provider(messages):
    provider = os.environ.get("LLM_PROVIDER", "openai")
    if provider == "openai":
        return stream_openai(messages)
    raise HTTPException(status_code=400, detail=f"unsupported provider: {provider}")


def sse_events(deltas):
    try:
        for delta in deltas:
            yield f"data: {json.dumps({'delta': delta})}\n\n"
        yield "data: [DONE]\n\n"
    except Exception as error:
        print(f"Chat stream error: {error}")
        yield f"data: {json.dumps({'error': str(error)})}\n\n"


@app.post("/api/v1/chat")
async def chat(req: ChatRequest, request: Request):
    enforce_rate_limit(request.client.host if request.client else "unknown")

    if not req.messages:
        raise HTTPException(status_code=400, detail="empty conversation")
    if len(req.messages) > MAX_MESSAGES:
        raise HTTPException(status_code=413, detail="too many messages")
    if sum(len(m.content) for m in req.messages) > MAX_CHARS:
        raise HTTPException(status_code=413, detail="conversation too long")

    messages = [{"role": m.role, "content": m.content} for m in req.messages]
    return StreamingResponse(sse_events(stream_provider(messages)), media_type="text/event-stream")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
