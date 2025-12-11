import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/quran_models.dart';

class QuranService {
  final String supabaseUrl;
  final String anonKey;

  QuranService()
      : supabaseUrl = AppConfig.supabaseUrl,
        anonKey = AppConfig.supabaseAnonKey;

  Map<String, String> get _headers {
    // ✅ FIX: Use user's access token for RLS to work
    final session = Supabase.instance.client.auth.currentSession;
    final accessToken = session?.accessToken ?? anonKey;
    
    return {
      'apikey': anonKey,
      'Authorization': 'Bearer $accessToken',  // ✅ Use JWT token, not anon key
      'Content-Type': 'application/json',
      'Prefer': 'count=exact',  // Get exact count
      'Range-Unit': 'items',     // Specify range unit
    };
  }

  /// Fetch Surah from words table (per word, grouped by ayah)
  Future<Surah> getSurah(int surahId) async {
    try {
      // Try different possible column names for word position
      final possibleQueries = [
        'location',      // Detected from Supabase hint
        'position',      // Common name
        'word_number',   // Alternative
        'id',           // Fallback to id
      ];
      
      String? workingQuery;
      
      // Find working column name
      for (var positionCol in possibleQueries) {
        final testUrl = '$supabaseUrl/rest/v1/words?surah=eq.$surahId&select=*&order=ayah.asc,$positionCol.asc&limit=1';
        
        final testResponse = await http.get(
          Uri.parse(testUrl),
          headers: _headers,
        );
        
        if (testResponse.statusCode == 200 || testResponse.statusCode == 206) {
          workingQuery = positionCol;
          print('✅ Using column: $positionCol for sorting');
          break;
        }
      }

      if (workingQuery == null) {
        throw Exception('Could not find valid sorting column');
      }

      // Fetch ALL data with pagination (Supabase limit is 1000 per request)
      List<dynamic> allData = [];
      int offset = 0;
      const int limit = 1000;
      bool hasMore = true;
      
      print('📥 Fetching words for Surah $surahId with pagination...');
      
      while (hasMore) {
        final url = '$supabaseUrl/rest/v1/words?surah=eq.$surahId&select=*&order=ayah.asc,$workingQuery.asc&limit=$limit&offset=$offset';
        
        final response = await http.get(
          Uri.parse(url),
          headers: _headers,
        );

        if (response.statusCode == 200 || response.statusCode == 206) {
          final List<dynamic> batch = jsonDecode(response.body);
          
          if (batch.isEmpty) {
            hasMore = false;
          } else {
            allData.addAll(batch);
            print('  📦 Batch ${(offset / limit).floor() + 1}: fetched ${batch.length} words (total: ${allData.length})');
            
            // Check if we got less than limit, meaning last page
            if (batch.length < limit) {
              hasMore = false;
            } else {
              offset += limit;
            }
          }
        } else {
          throw Exception('Failed to fetch batch at offset $offset: ${response.statusCode}');
        }
      }

      print('📊 Total fetched ${allData.length} words from Supabase');
      
      if (allData.isEmpty) {
        throw Exception('No data fetched for Surah $surahId');
      }
      
      final List<dynamic> data = allData;
        
        // Debug: print first word structure
        if (data.isNotEmpty) {
          print('📝 First word structure: ${data[0].keys.toList()}');
          print('📝 First word data: ${data[0]}');
        }
        
        // Get surah info from surat/chapters table
        final surahInfo = await getSurahInfo(surahId);
        
        // Debug: print first word structure
        if (data.isNotEmpty) {
          print('📋 First word keys: ${data[0].keys.toList()}');
          print('📋 First word sample: ${data[0]}');
        }
        
        // Group words by ayah number
        Map<int, List<String>> ayahWordsMap = {};
        for (var word in data) {
          int ayahNum = word['ayah'] as int;
          // Try different possible column names
          String wordText = word['text_uthmani'] as String? ?? 
                           word['text_simple'] as String? ?? 
                           word['text'] as String? ?? 
                           word['arabic'] as String? ??
                           word['word'] as String? ?? '';
          
          // Skip only truly empty words
          if (wordText.isEmpty) {
            continue;
          }
          
          if (!ayahWordsMap.containsKey(ayahNum)) {
            ayahWordsMap[ayahNum] = [];
          }
          ayahWordsMap[ayahNum]!.add(wordText);
        }
        
        print('📊 Grouped into ${ayahWordsMap.length} ayahs');
        
        // Debug: Show ayah range
        if (ayahWordsMap.isNotEmpty) {
          final firstAyah = ayahWordsMap.keys.reduce((a, b) => a < b ? a : b);
          final lastAyah = ayahWordsMap.keys.reduce((a, b) => a > b ? a : b);
          print('📊 Ayah range: $firstAyah to $lastAyah');
          print('📊 Expected for Surah $surahId: check if complete');
        }
        
        // Convert to Verse objects
        List<Verse> verses = ayahWordsMap.entries.map((entry) {
          int ayahNum = entry.key;
          List<String> words = entry.value;
          String fullText = words.join(' ');
          
          return Verse(
            number: ayahNum,
            text: fullText,
            words: words,
          );
        }).toList();
        
        // Sort verses by number
        verses.sort((a, b) => a.number.compareTo(b.number));
        
        print('✅ Created ${verses.length} verses');
        if (verses.isNotEmpty) {
          final previewText = verses.first.text.length > 30 
            ? verses.first.text.substring(0, 30) 
            : verses.first.text;
          print('📖 First verse: ${verses.first.number} - $previewText...');
        }
        
        // Handle Bismillah based on surah
        // Surah 1 (Al-Fatihah): Bismillah is ayah 1, keep it
        // Surah 9 (At-Taubah): No Bismillah at all
        // Other surahs: Bismillah is separate, not counted as ayah
        if (surahId != 1 && surahId != 9) {
          if (verses.isNotEmpty && verses.first.text.contains('بِسۡمِ ٱللَّهِ')) {
            print('🔄 Removing Bismillah from Surah $surahId (not ayah 1)');
            verses = verses.skip(1).map((verse) {
              return Verse(
                number: verse.number - 1,
                text: verse.text,
                words: verse.words,
              );
            }).toList();
            print('✅ Final verses count: ${verses.length}');
          }
        } else if (surahId == 1) {
          print('✅ Surah Al-Fatihah: Bismillah is ayah 1, keeping all ${verses.length} verses');
        } else if (surahId == 9) {
          print('✅ Surah At-Taubah: No Bismillah, keeping all ${verses.length} verses');
        }

        final surah = Surah(
          number: surahId,
          name: surahInfo['name'] ?? 'Unknown',
          nameArabic: surahInfo['nameArabic'] ?? 'سورة',
          verses: verses,
        );
        
      print('🎉 Returning Surah ${surah.number} (${surah.name}) with ${surah.verses.length} verses');
      return surah;
    } catch (e) {
      print('Error fetching surah from words: $e');
      rethrow;
    }
  }

  /// Fallback: Fetch from old m10_quran_ayah table
  Future<Surah> _getSurahFromM10(int surahId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/m10_quran_ayah?surah_id=eq.$surahId&select=*&order=ayah.asc',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Get surah info
        final surahInfo = await getSurahInfo(surahId);
        
        // Convert to Verse objects
        List<Verse> verses = data.map((ayah) {
          List<String> words = [];
          if (ayah['words_array'] != null && ayah['words_array'] is List) {
            words = List<String>.from(ayah['words_array']);
          } else {
            words = (ayah['arabic'] as String).split(' ');
          }
          
          return Verse(
            number: ayah['ayah'] as int,
            text: ayah['arabic'] as String,
            words: words,
          );
        }).toList();
        
        // Handle Bismillah based on surah (same logic as main getSurah)
        if (surahId != 1 && surahId != 9) {
          if (verses.isNotEmpty && verses.first.text.contains('بِسۡمِ ٱللَّهِ')) {
            verses = verses.skip(1).map((verse) {
              return Verse(
                number: verse.number - 1,
                text: verse.text,
                words: verse.words,
              );
            }).toList();
          }
        }

        return Surah(
          number: surahId,
          name: surahInfo['name'] ?? 'Unknown',
          nameArabic: surahInfo['nameArabic'] ?? 'سورة',
          verses: verses,
        );
      } else {
        throw Exception('Failed to load surah from fallback: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching surah from fallback: $e');
      rethrow;
    }
  }

  /// Get Surah information from chapters or surat table
  Future<Map<String, String?>> getSurahInfo(int surahId) async {
    try {
      // Try chapters table first
      var response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/chapters?id=eq.$surahId&select=*'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final chapter = data[0];
          return {
            'name': chapter['name_simple'] ?? chapter['name_arabic'] ?? 'Unknown',
            'nameArabic': chapter['name_arabic'] ?? '',
          };
        }
      }
      
      // Fallback: try surat table
      response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/surat?id=eq.$surahId&select=*'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final surah = data[0];
          return {
            'name': surah['namalatin'] ?? 'Unknown',
            'nameArabic': surah['nama'] ?? '',
          };
        }
      }
      
      return {
        'name': 'Surah $surahId',
        'nameArabic': 'سورة',
      };
    } catch (e) {
      print('Error fetching surah info: $e');
      return {
        'name': 'Surah $surahId',
        'nameArabic': 'سورة',
      };
    }
  }

  /// Get all Surahs list from chapters or surat table
  Future<List<Map<String, dynamic>>> getAllSurahs() async {
    try {
      // Try chapters table first
      var response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/chapters?select=*&order=id.asc'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      
      // Fallback: surat table
      response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/surat?select=*&order=id.asc'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      
      return [];
    } catch (e) {
      print('Error fetching surahs: $e');
      return [];
    }
  }
}



