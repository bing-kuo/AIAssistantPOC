from fastapi import FastAPI, UploadFile, File
from faster_whisper import WhisperModel
import shutil
import os

app = FastAPI()

print("Loading Whisper Model...")
model = WhisperModel("base", device="cpu", compute_type="int8") 
print("Whisper Model Loaded!")

@app.post("/api/v1/stt")
async def speech_to_text(file: UploadFile = File(...)):
    temp_file = f"temp_{file.filename}"
    with open(temp_file, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    segments, info = model.transcribe(temp_file, beam_size=5, language="zh")
    
    text = "".join([segment.text for segment in segments])
    
    os.remove(temp_file)
    return {"text": text, "language": info.language}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)