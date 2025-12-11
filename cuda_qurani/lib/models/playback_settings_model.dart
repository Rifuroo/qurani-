// lib/models/playback_settings_model.dart

class PlaybackSettings {
  final int startSurahId;
  final int startVerse;
  final int endSurahId;
  final int endVerse;
  final String reciter;
  final double speed; // 0.5x - 1.75x
  final int eachVerseRepeat; // 1, 2, 3, or -1 for loop
  final int rangeRepeat; // 1, 2, 3, or -1 for loop

  PlaybackSettings({
    required this.startSurahId,
    required this.startVerse,
    required this.endSurahId,
    required this.endVerse,
    required this.reciter,
    this.speed = 1.0,
    this.eachVerseRepeat = 1,
    this.rangeRepeat = 1,
  });

  // Helper untuk cek apakah verse dalam range
  bool isVerseInRange(int surahId, int verseNumber) {
    if (surahId < startSurahId || surahId > endSurahId) {
      return false;
    }
    
    if (surahId == startSurahId && verseNumber < startVerse) {
      return false;
    }
    
    if (surahId == endSurahId && verseNumber > endVerse) {
      return false;
    }
    
    return true;
  }

  // Generate list of verses dalam range
  List<VerseReference> getVerseList(Map<int, int> surahVerseCounts) {
    final List<VerseReference> verses = [];
    
    for (int surahId = startSurahId; surahId <= endSurahId; surahId++) {
      int startAyah = (surahId == startSurahId) ? startVerse : 1;
      int endAyah = (surahId == endSurahId) 
          ? endVerse 
          : (surahVerseCounts[surahId] ?? 1);
      
      for (int ayah = startAyah; ayah <= endAyah; ayah++) {
        verses.add(VerseReference(surahId: surahId, verseNumber: ayah));
      }
    }
    
    return verses;
  }

  @override
  String toString() {
    return 'PlaybackSettings(${startSurahId}:${startVerse} - ${endSurahId}:${endVerse}, speed: ${speed}x)';
  }
}

class VerseReference {
  final int surahId;
  final int verseNumber;

  VerseReference({
    required this.surahId,
    required this.verseNumber,
  });

  String get key => '$surahId:$verseNumber';

  @override
  String toString() => key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerseReference &&
          surahId == other.surahId &&
          verseNumber == other.verseNumber;

  @override
  int get hashCode => surahId.hashCode ^ verseNumber.hashCode;
}


