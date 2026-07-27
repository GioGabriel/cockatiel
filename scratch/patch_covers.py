import urllib.parse
import urllib.request
import json
import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_ACCOUNT_KEY = r"C:\Users\sanch\.gemini\antigravity\brain\eac6f437-6acf-400a-94d5-a2a2e1a961da\scratch\serviceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred)

db = firestore.client()

def fetch_cover_url(title, artist):
    query = f"{title} {artist}".strip()
    encoded_query = urllib.parse.quote(query)
    url = f"https://itunes.apple.com/search?term={encoded_query}&entity=song&limit=1"
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())
            if data.get('results'):
                artwork = data['results'][0].get('artworkUrl100', '')
                return artwork.replace('100x100bb', '600x600bb')
    except Exception as e:
        print(f"Error fetching {query}: {e}")
    return ""

def main():
    songs_ref = db.collection("karaoke_songs")
    docs = songs_ref.stream()
    
    updated = 0
    for doc in docs:
        data = doc.to_dict()
        title = data.get("title", "")
        artist = data.get("artist_name", "")
        
        print(f"Fetching cover for: {title} by {artist}")
        cover_url = fetch_cover_url(title, artist)
        
        if cover_url:
            print(f" -> Found: {cover_url}")
            doc.reference.update({"cover_url": cover_url})
            updated += 1
        else:
            print(f" -> Not found.")
            
    print(f"\nDone! Updated {updated} songs.")

if __name__ == "__main__":
    main()
