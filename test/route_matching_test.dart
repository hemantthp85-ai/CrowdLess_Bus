import 'package:flutter_test/flutter_test.dart';

// Helper to normalize stop names for comparison
String _normalizeStopName(String name) {
  String text = name.trim().toLowerCase();
  text = text.replaceAll(RegExp(r'\btech\b'), 'technology');
  text = text.replaceAll(RegExp(r'\bcol\b'), 'college');
  text = text.replaceAll(RegExp(r'\bcoll\b'), 'college');
  text = text.replaceAll(RegExp(r'\brly\b'), 'railway');
  text = text.replaceAll(RegExp(r'\bstn\b'), 'station');
  text = text.replaceAll(RegExp(r'\bjn\b'), 'junction');
  text = text.replaceAll(RegExp(r'\bjunc\b'), 'junction');
  text = text.replaceAll(RegExp(r'\bstd\b'), 'stand');
  text = text.replaceAll(RegExp(r'[^\w\s]'), '');
  return text;
}

// Helper to determine if a route stop matches the user's selected stop
bool _matchesStop(String routeStop, String queryStop) {
  final cleanRoute = _normalizeStopName(routeStop);
  final cleanQuery = _normalizeStopName(queryStop);
  
  if (cleanRoute == cleanQuery) return true;
  if (cleanRoute.contains(cleanQuery) || cleanQuery.contains(cleanRoute)) return true;
  
  const Map<String, List<String>> stopAliases = {
    'psg': ['psg college of technology', 'psg college', 'psg tech', 'psg'],
    'railway': ['railway station', 'coimbatore railway station', 'junction railway station', 'railway'],
    'airport': ['airport', 'coimbatore airport', 'airport stop'],
    'hope': ['hope college', 'hope'],
  };
  
  for (final entry in stopAliases.entries) {
    final list = entry.value;
    bool routeMatches = list.any((alias) => cleanRoute.contains(alias) || alias.contains(cleanRoute));
    bool queryMatches = list.any((alias) => cleanQuery.contains(alias) || alias.contains(cleanQuery));
    if (routeMatches && queryMatches) {
      return true;
    }
  }

  final wordsRoute = cleanRoute.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
  final wordsQuery = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
  
  if (wordsRoute.isEmpty || wordsQuery.isEmpty) return false;
  
  if (wordsQuery.every((w) => wordsRoute.contains(w))) return true;
  if (wordsRoute.every((w) => wordsQuery.contains(w))) return true;
  
  return false;
}

void main() {
  group('Stop Matching Tests', () {
    test('Airport vs Coimbatore Airport', () {
      expect(_matchesStop('Coimbatore Airport', 'Airport'), isTrue);
      expect(_matchesStop('Airport Stop', 'Airport'), isTrue);
    });

    test('PSG Tech vs PSG College of Technology', () {
      expect(_matchesStop('PSG College of Technology', 'PSG Tech'), isTrue);
      expect(_matchesStop('PSG College', 'PSG Tech'), isTrue);
    });

    test('Railway Station vs Coimbatore Railway Station', () {
      expect(_matchesStop('Coimbatore Railway Station', 'Railway Station'), isTrue);
      expect(_matchesStop('Railway Station', 'Coimbatore Railway Station'), isTrue);
    });

    test('Hope College vs Hope College with spaces', () {
      expect(_matchesStop('Hope College ', 'Hope College'), isTrue);
    });

    test('Case insensitivity and spacing', () {
      expect(_matchesStop('singanallur', 'Singanallur'), isTrue);
      expect(_matchesStop('  Ukkadam  ', 'ukkadam'), isTrue);
    });

    test('Non-matching stops', () {
      expect(_matchesStop('Hope College', 'PSG College'), isFalse);
      expect(_matchesStop('Ukkadam', 'Gandhipuram'), isFalse);
    });
  });
}
