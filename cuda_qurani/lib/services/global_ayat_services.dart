// lib/services/global_ayat_service.dart

class GlobalAyatService {
  /// Total ayat dalam Al-Quran (Standar Kufi)
  static const int totalAyatCount = 6236;

  /// Mapping surah_id ke jumlah ayat kumulatif SEBELUM surah tersebut.
  // DATA YANG SUDAH DIKALIBRASI UNTUK TOTAL 6236 AYAT
  static const Map<int, int> surahStartIndices = {
    1: 0,        // Al-Fatihah (7 ayat)
    2: 7,        // Al-Baqarah
    3: 293,      // Ali 'Imran
    4: 493,      // An-Nisa'
    5: 669,      // Al-Ma'idah
    6: 789,      // Al-An'am
    7: 954,      // Al-A'raf
    8: 1160,     // Al-Anfal
    9: 1235,     // At-Taubah
    10: 1364,    // Yunus
    11: 1473,    // Hud
    12: 1596,    // Yusuf
    13: 1707,    // Ar-Ra'd
    14: 1750,    // Ibrahim
    15: 1802,    // Al-Hijr
    16: 1901,    // An-Nahl
    17: 2029,    // Al-Isra'
    18: 2140,    // Al-Kahf
    19: 2250,    // Maryam
    20: 2348,    // Ta-Ha
    21: 2483,    // Al-Anbiya'
    22: 2595,    // Al-Hajj
    23: 2673,    // Al-Mu'minun
    24: 2791,    // An-Nur
    25: 2855,    // Al-Furqan
    26: 2932,    // Asy-Syu'ara'
    27: 3159,    // An-Naml
    28: 3252,    // Al-Qasas
    29: 3340,    // Al-'Ankabut
    30: 3409,    // Ar-Rum
    31: 3469,    // Luqman
    32: 3503,    // As-Sajdah
    33: 3533,    // Al-Ahzab
    34: 3606,    // Saba'
    35: 3660,    // Fatir
    36: 3705,    // Ya-Sin. (Ayat 1 = 3705 + 1 = 3706). *Lihat note
    37: 3788,    // As-Saffat
    38: 3970,    // Sad
    39: 4058,    // Az-Zumar
    40: 4133,    // Ghafir
    41: 4218,    // Fussilat
    42: 4272,    // Asy-Syura
    43: 4325,    // Az-Zukhruf
    44: 4414,    // Ad-Dukhan
    45: 4473,    // Al-Jasiyah
    46: 4510,    // Al-Ahqaf
    47: 4545,    // Muhammad
    48: 4583,    // Al-Fath
    49: 4612,    // Al-Hujurat
    50: 4630,    // Qaf
    51: 4675,    // Az-Zariyat
    52: 4735,    // At-Tur
    53: 4784,    // An-Najm
    54: 4846,    // Al-Qamar
    55: 4901,    // Ar-Rahman
    56: 4979,    // Al-Waqi'ah
    57: 5075,    // Al-Hadid
    58: 5104,    // Al-Mujadilah
    59: 5126,    // Al-Hasyr
    60: 5150,    // Al-Mumtahanah
    61: 5163,    // As-Saff
    62: 5177,    // Al-Jumu'ah
    63: 5188,    // Al-Munafiqun
    64: 5199,    // At-Taghabun
    65: 5217,    // At-Talaq
    66: 5229,    // At-Tahrim
    67: 5241,    // Al-Mulk
    68: 5271,    // Al-Qalam
    69: 5323,    // Al-Haqqah
    70: 5375,    // Al-Ma'arij
    71: 5419,    // Nuh
    72: 5447,    // Al-Jinn
    73: 5475,    // Al-Muzzammil
    74: 5495,    // Al-Muddassir
    75: 5551,    // Al-Qiyamah
    76: 5591,    // Al-Insan
    77: 5622,    // Al-Mursalat
    78: 5672,    // An-Naba'
    79: 5712,    // An-Nazi'at
    80: 5758,    // 'Abasa
    81: 5800,    // At-Takwir
    82: 5829,    // Al-Infitar
    83: 5848,    // Al-Mutaffifin
    84: 5884,    // Al-Insyiqaq
    85: 5909,    // Al-Buruj
    86: 5931,    // At-Tariq
    87: 5948,    // Al-A'la
    88: 5967,    // Al-Ghasyiyah
    89: 5993,    // Al-Fajar
    90: 6023,    // Al-Balad
    91: 6043,    // Asy-Syams
    92: 6058,    // Al-Lail
    93: 6079,    // Ad-Duha
    94: 6090,    // Asy-Syarh
    95: 6098,    // At-Tin
    96: 6106,    // Al-'Alaq
    97: 6125,    // Al-Qadr
    98: 6130,    // Al-Bayyinah
    99: 6138,    // Az-Zalzalah
    100: 6146,   // Al-'Adiyat
    101: 6157,   // Al-Qari'ah
    102: 6168,   // At-Takatsur
    103: 6176,   // Al-'Asr
    104: 6179,   // Al-Humazah
    105: 6188,   // Al-Fil
    106: 6193,   // Quraisy
    107: 6197,   // Al-Ma'un
    108: 6204,   // Al-Kautsar
    109: 6207,   // Al-Kafirun
    110: 6213,   // An-Nasr
    111: 6216,   // Al-Lahab
    112: 6221,   // Al-Ikhlas
    113: 6225,   // Al-Falaq
    114: 6230,   // An-Nas
  };

  /// Convert (surah_id, ayah_number) ke global ayat number (1-6236)
  static int toGlobalAyat(int surahId, int ayahNumber) {
    final base = surahStartIndices[surahId] ?? 0;
    return base + ayahNumber;
  }

  /// Convert global ayat number ke (surah_id, ayah_number)
  static Map<String, int> fromGlobalAyat(int globalAyat) {
    if (!isValid(globalAyat)) {
      return {'surah_id': 1, 'ayah_number': 1}; // Default fallback
    }

    // Loop mundur dari 114 ke 1
    for (int surah = 114; surah >= 1; surah--) {
      final base = surahStartIndices[surah] ?? 0;
      if (globalAyat > base) {
        return {'surah_id': surah, 'ayah_number': globalAyat - base};
      }
    }
    return {'surah_id': 1, 'ayah_number': 1};
  }

  /// Validasi apakah global ayat valid (1 - 6236)
  static bool isValid(int globalAyat) {
    return globalAyat >= 1 && globalAyat <= totalAyatCount;
  }
}



