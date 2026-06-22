
import json
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("serviceAccountKey.json")

try:
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

with open("routes.json", "r", encoding="utf-8") as f:
    routes = json.load(f)

for route in routes:
    db.collection("routes").document(
        route["routeNumber"]
    ).set(route)

print(f"{len(routes)} routes imported successfully!")