import argparse
import os
import subprocess
import json
import numpy as np
import librosa
from pathlib import Path

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
FFMPEG_PATH = r"C:\Users\sanch\Downloads\ffmpeg-master-latest-win64-gpl-shared\bin"
OUTPUT_DIR = r"G:\cockatiel\scratch\karaoke_out"
FINAL_DIR = r"G:\cockatiel\scratch\karaoke_out\final"
# ──────────────────────────────────────────────────────────────────────────────

def setup_env():
    """Add FFmpeg to PATH if not already there."""
    if FFMPEG_PATH and FFMPEG_PATH not in os.environ["PATH"]:
        os.environ["PATH"] += os.pathsep + FFMPEG_PATH

def download_audio(youtube_url: str, output_path: str) -> str:
    """Download audio from YouTube and convert to WAV."""
    print(f"  [*] Downloading: {youtube_url}", flush=True)
    command = [
        "yt-dlp",
        "-x",
        "--audio-format", "wav",
        "-o", output_path,
        youtube_url
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Download failed:\n{result.stderr}")
    return output_path

def separate_stems(input_wav: str, output_dir: str):
    """Run Demucs to split vocals and instrumental."""
    print(f"  [*] Splitting vocals with Demucs AI (This takes 2-3 mins)...", flush=True)
    command = [
        "demucs",
        "--two-stems", "vocals",
        "-n", "htdemucs",
        "-o", output_dir,
        input_wav
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Demucs failed:\n{result.stderr}")

    song_folder = Path(input_wav).stem
    demucs_out = Path(output_dir) / "htdemucs" / song_folder
    
    instrumental_path = demucs_out / "no_vocals.wav"
    vocals_path = demucs_out / "vocals.wav"
    
    if not instrumental_path.exists() or not vocals_path.exists():
        raise RuntimeError(f"Expected output stems not found in {demucs_out}")
        
    return str(instrumental_path), str(vocals_path)

def generate_pitch_map(vocals_path: str, output_json: str) -> int:
    """Extract pitch data using pYIN and save to JSON."""
    print(f"  [*] Analyzing vocal pitch with Librosa pYIN...", flush=True)
    
    y, sr = librosa.load(vocals_path, sr=None)
    f0, voiced_flag, voiced_probs = librosa.pyin(
        y, 
        fmin=librosa.note_to_hz('C2'), 
        fmax=librosa.note_to_hz('C7'),
        sr=sr,
        frame_length=2048,
        hop_length=512
    )
    
    hop_length = 512
    times = librosa.frames_to_time(np.arange(len(f0)), sr=sr, hop_length=hop_length)
    
    pitch_map = []
    for t, pitch, is_voiced in zip(times, f0, voiced_flag):
        if is_voiced and not np.isnan(pitch):
            pitch_map.append({
                "time": round(float(t), 3),
                "pitch": round(float(pitch), 2)
            })

    with open(output_json, "w") as f:
        json.dump(pitch_map, f, indent=2)
        
    return len(pitch_map)

def compress_to_mp3(input_wav: str, output_mp3: str) -> str:
    """Compress a WAV file to a 128kbps MP3 file using FFmpeg."""
    print(f"  [*] Compressing audio to MP3 to save space...", flush=True)
    command = [
        "ffmpeg",
        "-y",
        "-i", input_wav,
        "-codec:a", "libmp3lame",
        "-b:a", "128k",
        output_mp3
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"FFmpeg MP3 compression failed:\n{result.stderr}")
    return output_mp3


def process_one_song(youtube_url: str, name: str, artist: str):
    """Full pipeline: download -> split -> analyze -> compress -> save locally."""
    song_id = name.lower().replace(" ", "_")
    work_dir = Path(OUTPUT_DIR) / song_id
    work_dir.mkdir(parents=True, exist_ok=True)
    
    final_dir = Path(FINAL_DIR) / song_id
    final_dir.mkdir(parents=True, exist_ok=True)

    raw_wav = str(work_dir / f"{song_id}_raw.wav")
    final_mp3 = str(final_dir / "instrumental.mp3")
    final_json = str(final_dir / "pitch_map.json")

    print(f"\n{'='*60}", flush=True)
    print(f"  * Processing: {name} by {artist}", flush=True)
    print(f"{'='*60}", flush=True)

    try:
        # 1. Download
        download_audio(youtube_url, raw_wav)

        # 2. Split vocals/instrumental
        instrumental_path, vocals_path = separate_stems(raw_wav, str(work_dir))

        # 3. Analyze pitch
        point_count = generate_pitch_map(vocals_path, final_json)
        print(f"  [OK] Pitch map ready: {point_count} data points", flush=True)

        # 4. Compress to MP3
        compress_to_mp3(instrumental_path, final_mp3)
        print(f"  [OK] Audio compressed to {final_mp3}", flush=True)

        # 5. Clean up temporary huge WAVs
        if Path(raw_wav).exists(): os.remove(raw_wav)
        if Path(instrumental_path).exists(): os.remove(instrumental_path)
        if Path(vocals_path).exists(): os.remove(vocals_path)

        print(f"\n  [SUCCESS] '{name}' is ready in {final_dir}!", flush=True)
        return {"name": name, "status": "success"}

    except Exception as e:
        print(f"\n  [ERROR] Processing {name} failed: {e}", flush=True)
        return {"name": name, "status": "failed"}


def main():
    parser = argparse.ArgumentParser(description="Build Karaoke Assets Locally.")
    parser.add_argument("--songs", nargs="+", required=True, help="YouTube URLs")
    parser.add_argument("--names", nargs="+", required=True, help="Song Titles")
    parser.add_argument("--artists", nargs="+", required=False, help="Artist Names")
    args = parser.parse_args()

    if len(args.songs) != len(args.names):
        print("[ERROR] Mismatch between URLs and Names count.")
        return

    artists = args.artists or []
    if len(artists) < len(args.songs):
        artists += ["Unknown Artist"] * (len(args.songs) - len(artists))

    setup_env()
    tasks = list(zip(args.songs, args.names, artists))

    print(f"\n[*] Starting pipeline for {len(tasks)} song(s) sequentially...\n", flush=True)

    results = []
    for url, name, artist in tasks:
        try:
            result = process_one_song(url, name, artist)
            results.append(result)
        except Exception as e:
            print(f"  [ERROR] {name} failed: {e}", flush=True)
            results.append({"name": name, "status": "failed"})

    print("\n" + "="*60, flush=True)
    print("  [*] PIPELINE SUMMARY", flush=True)
    print("="*60, flush=True)
    for res in results:
        status = "[OK]" if res["status"] == "success" else "[X]"
        print(f"  {status} {res['name']}: {res['status']}", flush=True)
    print("="*60, flush=True)


if __name__ == "__main__":
    main()
