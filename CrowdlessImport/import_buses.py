import json
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

with open("buses.json", "r", encoding="utf-8") as file:
    buses = json.load(file)

for bus in buses:
    db.collection("buses").document(bus["busNumber"]).set(bus)

print(f"{len(buses)} buses imported successfully!")