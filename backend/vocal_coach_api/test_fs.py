from google.cloud import firestore
import sys

try:
    db = firestore.Client(project="cockatiel-enhanced")
    db.collection("users").document("test-write").set({"status": "working"})
    print("Firestore Write Success!")
except Exception as e:
    print(f"Firestore Error: {e}")
    sys.exit(1)
