import os
import sys
import json
import subprocess
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, firestore

# Configure Firebase
SERVICE_ACCOUNT_KEY = r"C:\Users\sanch\.gemini\antigravity\brain\eac6f437-6acf-400a-94d5-a2a2e1a961da\scratch\serviceAccountKey.json"
if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred)

db = firestore.client()

FINAL_DIR = Path(r"G:\cockatiel\scratch\karaoke_out\final")
CLOUD_NAME = "dzddt8r3p"
UPLOAD_PRESET = "Unsigned"

def upload_via_curl(file_path, folder, resource_type):
    """Uploads a file to Cloudinary using curl and returns the secure_url."""
    url = f"https://api.cloudinary.com/v1_1/{CLOUD_NAME}/{resource_type}/upload"
    
    command = [
        "curl", "-s",
        "-X", "POST",
        url,
        "-F", f"file=@{file_path}",
        "-F", f"upload_preset={UPLOAD_PRESET}",
        "-F", f"folder={folder}"
    ]
    
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise Exception(f"Curl failed: {result.stderr}")
        
    response_data = json.loads(result.stdout)
    if "secure_url" not in response_data:
        raise Exception(f"Upload failed. API response: {response_data}")
        
    return response_data["secure_url"]

def process_uploads():
    if not FINAL_DIR.exists():
        print(f"Error: {FINAL_DIR} does not exist. Extraction might not have started yet.")
        return

    song_folders = [d for d in FINAL_DIR.iterdir() if d.is_dir()]
    print(f"Found {len(song_folders)} song folders to process.\n")

    for folder in song_folders:
        song_id = folder.name
        instrumental_file = folder / "instrumental.mp3"
        pitch_map_file = folder / "pitch_map.json"

        if not instrumental_file.exists() or not pitch_map_file.exists():
            print(f"[{song_id}] Skipped: Missing MP3 or JSON.")
            continue

        print(f"\n=================================")
        print(f"[*] Processing Uploads for: {song_id}")
        
        try:
            # 1. Upload Instrumental via cURL
            print(f"    - Uploading instrumental via cURL...")
            audio_url = upload_via_curl(
                str(instrumental_file), 
                folder=f"karaoke/{song_id}", 
                resource_type="video"
            )
            
            # 2. Upload Pitch Map via cURL
            print(f"    - Uploading pitch map via cURL...")
            json_url = upload_via_curl(
                str(pitch_map_file), 
                folder=f"karaoke/{song_id}", 
                resource_type="raw"
            )

            # 3. Update Firestore Document
            print(f"    - Linking to Firestore document '{song_id}'...")
            doc_ref = db.collection("karaoke_songs").document(song_id)
            doc_snapshot = doc_ref.get()
            
            if doc_snapshot.exists:
                doc_ref.update({
                    "instrumental_url": audio_url,
                    "pitch_map_url": json_url
                })
                print(f"    [SUCCESS] Linked to Firestore!")
            else:
                print(f"    [WARNING] Firestore document '{song_id}' not found! URLs not linked.")
                print(f"    Audio URL: {audio_url}")
                print(f"    Pitch Map URL: {json_url}")

        except Exception as e:
            print(f"    [ERROR] Failed to process {song_id}: {e}")

if __name__ == "__main__":
    process_uploads()
