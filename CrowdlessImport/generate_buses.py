import json
import random

routes = {
    "1A": "Gandhipuram → Ukkadam",
    "1D": "Ukkadam → Gandhipuram",
    "2A": "Gandhipuram → Peelamedu",
    "2B": "Peelamedu → Gandhipuram",
    "3A": "Gandhipuram → Singanallur",
    "3B": "Singanallur → Gandhipuram",
    "4A": "Gandhipuram → Hope College",
    "4B": "Hope College → Gandhipuram",
    "5A": "Gandhipuram → Airport",
    "6A": "Airport → Gandhipuram",
    "7A": "Gandhipuram → Saravanampatti",
    "7B": "Saravanampatti → Gandhipuram",
    "8A": "Gandhipuram → KCT",
    "9A": "KCT → Gandhipuram",
    "10A": "Gandhipuram → Vadavalli",
    "11A": "Vadavalli → Gandhipuram",
    "13A": "Gandhipuram → Town Hall",
    "14A": "Town Hall → Gandhipuram",
    "15A": "Gandhipuram → Ondipudur",
    "16A": "Ondipudur → Gandhipuram",
    "17A": "Gandhipuram → PSG College",
    "18A": "PSG College → Gandhipuram",
    "19C": "Gandhipuram → Singanallur",
    "20A": "Singanallur → Gandhipuram",
    "23A": "Gandhipuram → Airport",
    "24A": "Airport → Gandhipuram",
    "25A": "Gandhipuram → Hope College",
    "26A": "Hope College → Gandhipuram",
    "27A": "Gandhipuram → Saravanampatti",
    "28A": "Saravanampatti → Gandhipuram",
    "29A": "Gandhipuram → Peelamedu",
    "30A": "Peelamedu → Gandhipuram",
    "31A": "Gandhipuram → KCT",
    "32A": "KCT → Gandhipuram",
    "35A": "Gandhipuram → Vadavalli",
    "50A": "Vadavalli → Gandhipuram",
    "70B": "Gandhipuram → Airport",
    "99A": "Airport → Gandhipuram",
    "101A": "Gandhipuram → Saravanampatti"
}

buses = []

for bus, route in routes.items():

    occupancy = random.randint(10, 90)

    predicted = occupancy + random.randint(1, 10)

    if occupancy < 30:
        status = "Low"
    elif occupancy <= 70:
        status = "Moderate"
    else:
        status = "High"

    bus_data = {
        "busNumber": bus,
        "capacity": 90,
        "comfortScore": 100 - occupancy,
        "confidenceScore": random.randint(85, 98),
        "eta": random.randint(2, 15),
        "expectedBoarding": random.randint(1, 15),
        "expectedExits": random.randint(1, 10),
        "lastUpdated": "2026-06-17T10:00:00",
        "latitude": round(random.uniform(10.99, 11.09), 6),
        "longitude": round(random.uniform(76.89, 77.05), 6),
        "occupancy": occupancy,
        "occupancyHistory": [],
        "predictedOccupancy": predicted,
        "route": route,
        "status": status,
        "ticketsIssued": random.randint(10, 80),
        "currentStop": "Gandhipuram",
        "nextStop": "Next Stop",
        "speed": random.randint(20, 50),
        "delayMinutes": random.randint(0, 5)
    }

    buses.append(bus_data)

with open("buses.json", "w", encoding="utf-8") as f:
    json.dump(buses, f, indent=4)

print(f"{len(buses)} buses generated successfully!")