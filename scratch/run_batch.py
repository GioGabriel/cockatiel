import sys

from build_karaoke_songs import process_one_song, setup_env

songs = [
    # EASY
    {"title": "Baby", "artist": "Justin Bieber", "url": "http://www.youtube.com/watch?v=kffacxfA7G4"},
    {"title": "I Want It That Way", "artist": "Backstreet Boys", "url": "http://www.youtube.com/watch?v=4fndeDfaWCg"},
    {"title": "A Thousand Miles", "artist": "Vanessa Carlton", "url": "http://www.youtube.com/watch?v=Cwkej79U3ek"},
    {"title": "Shake It Off", "artist": "Taylor Swift", "url": "http://www.youtube.com/watch?v=nfWlot6h_JM"},
    {"title": "Just The Way You Are", "artist": "Bruno Mars", "url": "http://www.youtube.com/watch?v=LjhCEhWiKXk"},
    {"title": "Shape of You", "artist": "Ed Sheeran", "url": "http://www.youtube.com/watch?v=JGwWNGJdvx8"},
    {"title": "Uptown Funk", "artist": "Bruno Mars", "url": "http://www.youtube.com/watch?v=OPf0YbXqDm0"},
    
    # MEDIUM
    {"title": "Sk8er Boi", "artist": "Avril Lavigne", "url": "http://www.youtube.com/watch?v=TIy3n2b7V9k"},
    {"title": "Since U Been Gone", "artist": "Kelly Clarkson", "url": "http://www.youtube.com/watch?v=R7UrFYvl5TE"},
    {"title": "Someone Like You", "artist": "Adele", "url": "http://www.youtube.com/watch?v=hLQl3WQQoQ0"},
    {"title": "Oops I Did It Again", "artist": "Britney Spears", "url": "http://www.youtube.com/watch?v=MtcvYehs4MA"},
    {"title": "Blank Space", "artist": "Taylor Swift", "url": "http://www.youtube.com/watch?v=e-ORhEE9VVg"},
    {"title": "Bad Romance", "artist": "Lady Gaga", "url": "http://www.youtube.com/watch?v=BpjQro8BB_0"},
    
    # HARD
    {"title": "Chandelier", "artist": "Sia", "url": "http://www.youtube.com/watch?v=2vjPBrBU-TM"},
    {"title": "Wrecking Ball", "artist": "Miley Cyrus", "url": "http://www.youtube.com/watch?v=-YICuUtkjlg"},
    {"title": "Shallow", "artist": "Lady Gaga", "url": "http://www.youtube.com/watch?v=bo_efYhYU2A"},
    {"title": "Titanium", "artist": "David Guetta", "url": "http://www.youtube.com/watch?v=JRfuAukYTKg"},
    {"title": "Halo", "artist": "Beyonce", "url": "http://www.youtube.com/watch?v=bnVUHWCynig"},
    {"title": "My Heart Will Go On", "artist": "Celine Dion", "url": "http://www.youtube.com/watch?v=9bFHsd3o1w0"},
]

def main():
    setup_env()
    print(f"Starting batch extraction for {len(songs)} songs...")
    results = []
    
    for s in songs:
        try:
            res = process_one_song(s["url"], s["title"], s["artist"])
            results.append(res)
        except Exception as e:
            print(f"FATAL ERROR on {s['title']}: {e}")
            results.append({"name": s["title"], "status": "failed"})
            
    print("\n\nBATCH COMPLETED")
    for r in results:
        print(f"{r['name']}: {r['status']}")

if __name__ == "__main__":
    main()
