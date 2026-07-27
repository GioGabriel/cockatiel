import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_ACCOUNT_KEY = r"C:\Users\sanch\.gemini\antigravity\brain\eac6f437-6acf-400a-94d5-a2a2e1a961da\scratch\serviceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred)

db = firestore.client()

def fix_difficulties():
    print("Fixing difficulties in Firestore...")
    songs_ref = db.collection("karaoke_songs")
    docs = songs_ref.stream()
    
    updated_count = 0
    for doc in docs:
        data = doc.to_dict()
        current_diff = data.get("difficulty")
        
        new_diff = None
        if current_diff == "easy":
            new_diff = "beginner"
        elif current_diff == "hard":
            new_diff = "advanced"
            
        if new_diff:
            print(f"Updating {doc.id}: {current_diff} -> {new_diff}")
            doc.reference.update({"difficulty": new_diff})
            updated_count += 1
            
    print(f"Finished! Updated {updated_count} songs.")

if __name__ == "__main__":
    fix_difficulties()
