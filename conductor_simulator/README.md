# CrowdLess Bus — Conductor Simulator

This is YOUR part (backend + ML integration person) — the conductor-side
ticketing simulator. It writes live occupancy data to Firebase, which the
passenger app (built by your teammates) reads in real time.

## ⚠️ IMPORTANT — Before running

1. **Use the SAME Firebase project as your passenger app team.**
   Ask them for the Firebase project ID, or get added as a collaborator
   on the Firebase Console.

2. **Generate `firebase_options.dart` properly:**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This replaces the placeholder `lib/firebase_options.dart` with real
   credentials. Select the SAME project your teammates are using.

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run:**
   ```bash
   flutter run
   ```

## 📦 Firestore Structure (agreed with team)

```
buses (collection)
  └── 21G (document)
        ├── occupancy: 35        (int)
        ├── capacity: 90         (int)
        ├── ticketsIssued: 120   (int)
        ├── route: "..."         (string)
        └── lastUpdated: <server timestamp>
  └── S1  (document)  ... same fields
  └── 1C  (document)  ... same fields
```

**Share this exact structure with your passenger-app teammates** so their
`StreamBuilder` reads the same field names (`occupancy`, `capacity`,
`ticketsIssued`, `route`, `lastUpdated`).

## 🎮 How the simulator works

- Dropdown to pick which bus this phone represents (21G / S1 / 1C)
- **+ Ticket** button → `occupancy += 1`, `ticketsIssued += 1`
  (capped — won't exceed `capacity`, but ticket count still increases)
- **Exit** button → `occupancy -= 1` (won't go below 0)
- Live crowd status badge: 🟢 Low (0-40%) / 🟡 Moderate (41-70%) / 🔴 Full (71-100%)
- Reset button (top-right) → sets occupancy & ticketsIssued back to 0 for
  that bus — useful between demo runs

## 🧠 For your ML integration part (next step)

Once this is writing data correctly, your LSTM model can:
1. Read historical `occupancy` + `lastUpdated` snapshots over time
   (write a small Cloud Function or local script to log each update
   to a `history` subcollection if you need a time series)
2. Use `ticketsIssued` rate + time-of-day as input features
3. Push predicted next-stop occupancy to a `predictedOccupancy` field
   on each bus document for the passenger app to display

## Files

- `lib/main.dart` — app entry point, Firebase init
- `lib/firebase_options.dart` — 🔴 placeholder, regenerate via flutterfire CLI
- `lib/bus_data.dart` — BusData model + crowd status logic
- `lib/bus_firestore_service.dart` — all Firestore read/write logic
- `lib/conductor_home.dart` — main UI screen
