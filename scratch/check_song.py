import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_ACCOUNT_KEY = r"C:\Users\sanch\.gemini\antigravity\brain\eac6f437-6acf-400a-94d5-a2a2e1a961da\scratch\serviceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred)

db = firestore.client()

doc_ref = db.collection('karaoke_songs').document('myheartwillgoon')
doc = doc_ref.get()

if doc.exists:
    print(doc.to_dict())
else:
    print("Document not found!")
