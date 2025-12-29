import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuda_qurani/services/local_database_service.dart';
import 'package:cuda_qurani/services/widget_service.dart';

class DailyAyahService {
  /// Expanded curated Ayah pool with English and Indonesian translations.
  /// These are hardcoded to ensure availability even if DB translation tables aren't accessible.
  static final List<Map<String, dynamic>> _ayahPool = [
    {
      'surah': 2, 'ayah': 255,
      'en': 'Allah! There is no god but He, the Living, the Self-subsisting, Eternal.',
      'id': 'Allah, tidak ada tuhan selain Dia. Yang Mahahidup, Yang terus-menerus mengurus (makhluk-Nya).'
    },
    {
      'surah': 2, 'ayah': 286,
      'en': 'Allah does not charge a soul except [with that within] its capacity.',
      'id': 'Allah tidak membebani seseorang melainkan sesuai dengan kesanggupannya.'
    },
    {
      'surah': 3, 'ayah': 103,
      'en': 'And hold firmly to the rope of Allah all together and do not become divided.',
      'id': 'Dan berpegangteguhlah kamu semuanya pada tali (agama) Allah, dan janganlah kamu bercerai-berai.'
    },
    {
      'surah': 13, 'ayah': 28,
      'en': 'Unquestionably, by the remembrance of Allah hearts are assured.',
      'id': 'Ingatlah, hanya dengan mengingati Allah hati menjadi tenteram.'
    },
    {
      'surah': 20, 'ayah': 25,
      'en': 'My Lord, expand for me my breast [with assurance].',
      'id': 'Ya Tuhanku, lapangkanlah dadaku.'
    },
    {
      'surah': 94, 'ayah': 5,
      'en': 'For indeed, with hardship [will be] ease.',
      'id': 'Maka sesungguhnya bersama kesulitan ada kemudahan.'
    },
    {
      'surah': 94, 'ayah': 6,
      'en': 'Indeed, with hardship [will be] ease.',
      'id': 'Sesungguhnya bersama kesulitan ada kemudahan.'
    },
    {
      'surah': 2, 'ayah': 153,
      'en': 'O you who have believed, seek help through patience and prayer.',
      'id': 'Wahai orang-orang yang beriman! Mohonlah pertolongan (kepada Allah) dengan sabar dan salat.'
    },
    {
      'surah': 16, 'ayah': 128,
      'en': 'Indeed, Allah is with those who fear Him and those who are doers of good.',
      'id': 'Sungguh, Allah beserta orang-orang yang bertakwa dan orang-orang yang berbuat kebaikan.'
    },
    {
      'surah': 40, 'ayah': 60,
      'en': 'And your Lord says, "Call upon Me; I will respond to you."',
      'id': 'Dan Tuhanmu berfirman, "Berdoalah kepada-Ku, niscaya akan Aku perkenankan bagimu."'
    },
    {
      'surah': 65, 'ayah': 3,
      'en': 'And He will provide for him from where he does not expect.',
      'id': 'Dan Dia memberinya rezeki dari arah yang tidak disangka-sangkanya.'
    },
    {
      'surah': 39, 'ayah': 53,
      'en': 'Do not despair of the mercy of Allah. Indeed, Allah forgives all sins.',
      'id': 'Janganlah kamu berputus asa dari rahmat Allah. Sesungguhnya Allah mengampuni dosa-dosa semuanya.'
    },
    {
      'surah': 2, 'ayah': 186,
      'en': 'I am near. I respond to the invocation of the supplicant when he calls upon Me.',
      'id': 'Aku dekat. Aku kabulkan permohonan orang yang berdoa apabila dia berdoa kepada-Ku.'
    },
    {
      'surah': 67, 'ayah': 2,
      'en': '[He] who created death and life to test you [as to] which of you is best in deed.',
      'id': 'Yang menciptakan mati dan hidup, untuk menguji kamu, siapa di antara kamu yang lebih baik amalnya.'
    },
    {
      'surah': 23, 'ayah': 118,
      'en': 'My Lord, forgive and have mercy, and You are the best of the merciful.',
      'id': 'Ya Tuhanku, berilah ampunan dan rahmat, Engkaulah sebaik-baik pemberi rahmat.'
    },
  ];

  /// Selects a random Ayah and updates the widget, respecting the user's language setting.
  static Future<void> refreshDailyAyah() async {
    try {
      // Ensure DB is initialized
      await LocalDatabaseService.preInitialize();

      // Get user language preference from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('app_language') ?? 'id'; // Default to ID if not set

      // Select a truly random Ayah from the pool
      final random = Random();
      final ayahData = _ayahPool[random.nextInt(_ayahPool.length)];
      
      final surahId = ayahData['surah'] as int;
      final ayahNum = ayahData['ayah'] as int;

      // Fetch Arabic text from LocalDatabaseService (Source of Truth for Arabic)
      final surah = await LocalDatabaseService.getSurah(surahId);
      final metadata = await LocalDatabaseService.getSurahMetadata(surahId);
      
      // Find specific verse text
      final verse = surah.verses.firstWhere((v) => v.number == ayahNum);
      final verseText = verse.text; // Arabic text
      
      final surahNameSimple = metadata?['name_simple'] ?? metadata?['name'] ?? 'Surah';
      final surahNameArabic = metadata?['name_arabic'] ?? surahNameSimple;
      
      String reference = "$surahNameSimple ($surahId:$ayahNum)";

      if (languageCode == 'ar') {
        final surahNumAr = toArabicDigits(surahId);
        final ayahNumAr = toArabicDigits(ayahNum);
        reference = "$surahNameArabic ($surahNumAr:$ayahNumAr)";
      }

      // Determine translation text based on language setting
      // Fallback to Indonesian if key not found (as user requested "sesuai sumber")
      String translationText = '';
      if (languageCode == 'ar') {
        translationText = ''; // No translation needed for Arabic
      } else {
        translationText = ayahData[languageCode] ?? ayahData['id'] ?? ayahData['en'];
      }
      
      // Determine widget title
      String widgetTitle = 'Ayah of the Day';
      if (languageCode == 'id') widgetTitle = 'Ayat Hari Ini';
      else if (languageCode == 'ar') widgetTitle = 'آية اليوم';

      await WidgetService.updateAyahWidget(
        arabicText: verseText,
        translationText: translationText,
        reference: reference,
        surahId: surahId,
        ayahNumber: ayahNum,
        titleText: widgetTitle,
      );
      
      print('Daily Ayah refreshed: $surahNameSimple $ayahNum');
    } catch (e) {
      print('DailyAyahService Error: $e');
    }
  }

  static String toArabicDigits(int number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    
    String str = number.toString();
    for (int i = 0; i < english.length; i++) {
      str = str.replaceAll(english[i], arabic[i]);
    }
    return str;
  }
}
