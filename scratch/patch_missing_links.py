import firebase_admin
from firebase_admin import credentials, firestore
import re

SERVICE_ACCOUNT_KEY = r"C:\Users\sanch\.gemini\antigravity\brain\eac6f437-6acf-400a-94d5-a2a2e1a961da\scratch\serviceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred)

db = firestore.client()

# Parse the log file
log_file = r"C:\Users\sanch\.gemini\antigravity\brain\eac6f437-6acf-400a-94d5-a2a2e1a961da\.system_generated\tasks\task-7891.log"

with open(log_file, 'r', encoding='utf-8') as f:
    content = f.read()

blocks = content.split("=================================")

for block in blocks:
    if "Firestore document" in block and "not found" in block:
        match = re.search(r"Processing Uploads for: (.*)", block)
        if not match: continue
        song_id_snake = match.group(1).strip()
        
        song_id_db = song_id_snake.replace("_", "")
        
        audio_match = re.search(r"Audio URL: (.*)", block)
        pitch_match = re.search(r"Pitch Map URL: (.*)", block)
        
        if audio_match and pitch_match:
            audio_url = audio_match.group(1).strip()
            pitch_url = pitch_match.group(1).strip()
            
            doc_ref = db.collection('karaoke_songs').document(song_id_db)
            if doc_ref.get().exists:
                doc_ref.update({
                    'instrumental_url': audio_url,
                    'pitch_map_url': pitch_url
                })
                print(f"Successfully linked {song_id_db}")
            else:
                print(f"Failed to find {song_id_db} in db")
