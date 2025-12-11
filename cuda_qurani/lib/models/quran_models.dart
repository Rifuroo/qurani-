// lib\models\quran_models.dart

class Verse {
  final int number;
  final String text;
  final List<String> words;

  Verse({
    required this.number,
    required this.text,
    required this.words,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      number: json['number'],
      text: json['text'],
      words: List<String>.from(json['words']),
    );
  }
}

class Surah {
  final int number;
  final String name;
  final String nameArabic;
  final List<Verse> verses;

  Surah({
    required this.number,
    required this.name,
    required this.nameArabic,
    required this.verses,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: json['number'],
      name: json['name'],
      nameArabic: json['nameArabic'],
      verses: (json['verses'] as List)
          .map((v) => Verse.fromJson(v))
          .toList(),
    );
  }
}

enum WordStatus {
  pending,
  processing,   // 🔵 Biru/Kuning - sedang diproses (realtime indicator)
  matched,
  mismatched,
  skipped,
}

// Status untuk evaluasi tartib (urutan ayat)
enum TartibStatus {
  unread,     // ⬜ Abu-abu - belum dibaca
  correct,    // 🟩 Hijau - dibaca dengan benar dan urut  
  skipped,    // 🟥 Merah - dilewati atau dibaca setelah ayat berikutnya
}

class WordFeedback {
  final String text;
  final WordStatus status;
  final int wordIndex;
  final double similarity;
  final String? transcribedWord;

  WordFeedback({
    required this.text,
    required this.status,
    this.wordIndex = 0,
    this.similarity = 0.0,
    this.transcribedWord,
  });

  factory WordFeedback.fromJson(Map<String, dynamic> json) {
    WordStatus status;
    switch (json['status']) {
      case 'matched':
        status = WordStatus.matched;
        break;
      case 'mismatched':
        status = WordStatus.mismatched;
        break;
      case 'skipped':
        status = WordStatus.skipped;
        break;
      default:
        status = WordStatus.pending;
    }

    return WordFeedback(
      text: json['text'] ?? '',
      status: status,
      wordIndex: json['word_index'] ?? 0,
      similarity: (json['similarity'] ?? 0.0).toDouble(),
      transcribedWord: json['transcribed_word'],
    );
  }
}

class RecitationSummary {
  final double matched;
  final double errors;
  final double skipped;

  RecitationSummary({
    required this.matched,
    required this.errors,
    required this.skipped,
  });

  factory RecitationSummary.fromJson(Map<String, dynamic> json) {
    return RecitationSummary(
      matched: (json['matched'] as num).toDouble(),
      errors: (json['errors'] as num).toDouble(),
      skipped: (json['skipped'] as num).toDouble(),
    );
  }
}



