import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_ACCOUNT_KEY = r"C:\Users\sanch\.gemini\antigravity\brain\eac6f437-6acf-400a-94d5-a2a2e1a961da\scratch\serviceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred)

db = firestore.client()

doc_ref = db.collection("karaoke_songs").document("justgivemeareason")
doc_snapshot = doc_ref.get()

if doc_snapshot.exists:
    # Update the document to include the rich metadata fields the catalog needs
    doc_ref.update({
        "style_category": "Pop Ballad",
        "difficulty": "intermediate",
        "duration_sec": 242,
        "tempo_bpm": 95,
        "vocal_range": {"low": "G3", "high": "E5"},
        "objective": "Hit the pitches accurately!",
        "performance_tips": ["Stay on beat", "Match pitch accurately"]
    })
    print("Successfully patched 'justgivemeareason' with the missing catalog fields!")
else:
    print("Document 'justgivemeareason' not found in Firestore.")
