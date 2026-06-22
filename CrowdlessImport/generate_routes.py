import json

routes = {
    "1A": [
    "Gandhipuram",
    "Town Hall",
    "Oppanakara Street",
    "Ukkadam"
],

"1C": [
    "Gandhipuram",
    "Town Hall",
    "Oppanakara Street",
    "Ukkadam"
],

"1D": [
    "Ukkadam",
    "Oppanakara Street",
    "Town Hall",
    "Gandhipuram"
],

"2A": [
    "Gandhipuram",
    "Cross Cut Road",
    "Lakshmi Mills",
    "Peelamedu"
],

"2B": [
    "Peelamedu",
    "Lakshmi Mills",
    "Cross Cut Road",
    "Gandhipuram"
],

"3A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College",
    "Singanallur"
],

"3B": [
    "Singanallur",
    "Hope College",
    "Lakshmi Mills",
    "Gandhipuram"
],

"3C": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College",
    "Singanallur"
],

"3H": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College"
],

"4A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College"
],

"4B": [
    "Hope College",
    "Lakshmi Mills",
    "Gandhipuram"
],

"5A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College",
    "Codissia",
    "Airport"
],

"5E": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College",
    "Codissia",
    "Airport"
],

"6A": [
    "Airport",
    "Codissia",
    "Hope College",
    "Lakshmi Mills",
    "Gandhipuram"
],

"7A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Peelamedu",
    "Codissia",
    "Saravanampatti"
],

"7B": [
    "Saravanampatti",
    "Codissia",
    "Peelamedu",
    "Lakshmi Mills",
    "Gandhipuram"
],

"8A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Peelamedu",
    "Saravanampatti",
    "KCT"
],

"9A": [
    "KCT",
    "Saravanampatti",
    "Peelamedu",
    "Lakshmi Mills",
    "Gandhipuram"
],

"10A": [
    "Gandhipuram",
    "RS Puram",
    "Saibaba Colony",
    "Vadavalli"
],

"11A": [
    "Vadavalli",
    "Saibaba Colony",
    "RS Puram",
    "Gandhipuram"
],

"12D": [
    "Gandhipuram",
    "Cross Cut Road",
    "Lakshmi Mills",
    "Hope College",
    "PSG Tech",
    "PSG Hospital",
    "PSG College"
],

"13A": [
    "Gandhipuram",
    "Town Hall"
],

"14A": [
    "Town Hall",
    "Gandhipuram"
],

"15A": [
    "Gandhipuram",
    "Town Hall",
    "Sungam",
    "Ondipudur"
],

"16A": [
    "Ondipudur",
    "Sungam",
    "Town Hall",
    "Gandhipuram"
],

"17A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College",
    "PSG College"
],

"18A": [
    "PSG College",
    "Hope College",
    "Lakshmi Mills",
    "Gandhipuram"
],

"19C": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College",
    "Singanallur"
],

"20A": [
    "Singanallur",
    "Hope College",
    "Lakshmi Mills",
    "Gandhipuram"
],

"21G": [
    "Gandhipuram",
    "Cross Cut Road",
    "Lakshmi Mills",
    "Fun Mall",
    "Hope College",
    "Peelamedu",
    "PSG Tech",
    "PSG Hospital",
    "PSG College"
],

"22B": [
    "Gandhipuram",
    "Town Hall"
],

"23A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College",
    "Codissia",
    "Airport"
],

"24A": [
    "Airport",
    "Codissia",
    "Hope College",
    "Lakshmi Mills",
    "Gandhipuram"
],

"25A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College"
],

"26A": [
    "Hope College",
    "Lakshmi Mills",
    "Gandhipuram"
],

"27A": [
    "Gandhipuram",
    "Peelamedu",
    "Codissia",
    "Saravanampatti"
],

"28A": [
    "Saravanampatti",
    "Codissia",
    "Peelamedu",
    "Gandhipuram"
],

"29A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Peelamedu"
],

"30A": [
    "Peelamedu",
    "Lakshmi Mills",
    "Gandhipuram"
],

"31A": [
    "Gandhipuram",
    "Peelamedu",
    "Saravanampatti",
    "KCT"
],

"32A": [
    "KCT",
    "Saravanampatti",
    "Peelamedu",
    "Gandhipuram"
],

"33G": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Peelamedu",
    "Codissia",
    "CHIL SEZ",
    "Prozone Mall",
    "Saravanampatti"
],

"34D": [
    "Gandhipuram",
    "RS Puram",
    "Saibaba Colony",
    "Thadagam Road",
    "Vadavalli"
],

"35A": [
    "Gandhipuram",
    "RS Puram",
    "Saibaba Colony",
    "Vadavalli"
],

"45G": [
    "Hope College",
    "Lakshmi Mills",
    "Cross Cut Road",
    "Gandhipuram"
],

"50A": [
    "Vadavalli",
    "Saibaba Colony",
    "RS Puram",
    "Gandhipuram"
],

"66A": [
    "Singanallur",
    "Hope College",
    "Lakshmi Mills",
    "Gandhipuram"
],

"70B": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Hope College",
    "Codissia",
    "Airport"
],

"99A": [
    "Airport",
    "Codissia",
    "Hope College",
    "Lakshmi Mills",
    "Gandhipuram"
],

"101A": [
    "Gandhipuram",
    "Lakshmi Mills",
    "Peelamedu",
    "CHIL SEZ",
    "Saravanampatti"
],

"S1": [
    "Saravanampatti",
    "CHIL SEZ",
    "Peelamedu",
    "Lakshmi Mills",
    "Gandhipuram"
]
}

route_docs = []

for route, stops in routes.items():
    route_docs.append({
        "routeNumber": route,
        "source": stops[0],
        "destination": stops[-1],
        "stops": stops,

        # Bus(s) running on this route
        "buses": [
            route
        ],

        # Future use for Google Maps
        "stopCoordinates": {}
    })

with open("routes.json", "w", encoding="utf-8") as f:
    json.dump(route_docs, f, indent=4)

print(f"{len(route_docs)} routes generated successfully!")