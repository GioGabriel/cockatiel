import sys
sys.path.append(r"G:\cockatiel\scratch")

from build_karaoke_songs import process_one_song, setup_env

def main():
    setup_env()
    print(f"Starting extraction for Bad Romance alternative link...")
    
    try:
        res = process_one_song(
            "https://www.youtube.com/watch?v=TTOPBQhrvtQ", 
            "Bad Romance", 
            "Lady Gaga"
        )
        print(f"Result: {res['status']}")
    except Exception as e:
        print(f"FATAL ERROR: {e}")

if __name__ == "__main__":
    main()
