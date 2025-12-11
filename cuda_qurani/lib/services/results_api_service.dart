/// Word Results API Service
/// 
/// Provides methods to fetch word-by-word results from backend API
/// 
/// API Endpoints:
/// - GET /api/results/{session_id}/{surah} - Get all results + statistics
/// - GET /api/results/{session_id}/{surah}/statistics - Statistics only
/// - GET /api/results/{session_id}/{surah}/mistakes - Only mistakes
/// - GET /api/results/{session_id}/{surah}/ayah/{ayah} - Specific ayah

import 'dart:convert';
import 'package:http/http.dart' as http;

class ResultsApiService {
  // Backend API base URL
  static const String baseUrl = 'http://localhost:8000';
  
  /// Get all word results for a session/surah
  /// 
  /// Returns:
  /// ```json
  /// {
  ///   "session_id": "1764129034",
  ///   "surah": 2,
  ///   "results": {
  ///     "1:0": {"text": "الٓمٓ", "status": "benar", "similarity": 1.00},
  ///     "1:1": {"text": "١", "status": "salah", "similarity": 0.00}
  ///   },
  ///   "statistics": {
  ///     "total_words": 50,
  ///     "benar": 35,
  ///     "salah": 15,
  ///     "accuracy": 70.0,
  ///     "avg_similarity": 0.85
  ///   },
  ///   "ayah_statistics": {
  ///     "1": {"total": 2, "benar": 1, "salah": 1, "accuracy": 50.0}
  ///   },
  ///   "mistakes": {
  ///     "1:1": {"text": "١", "status": "salah", "similarity": 0.00}
  ///   }
  /// }
  /// ```
  static Future<Map<String, dynamic>?> getResults({
    required String sessionId,
    required int surah,
  }) async {
    try {
      final url = '$baseUrl/api/results/$sessionId/$surah';
      print('📡 GET $url');
      
      final response = await http.get(Uri.parse(url));
      
      print('📥 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ Loaded ${data['results']?.length ?? 0} word results');
        return data;
      } else if (response.statusCode == 404) {
        print('⚠️ No results found for session $sessionId surah $surah');
        return null;
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception getting results: $e');
      return null;
    }
  }
  
  /// Get statistics only (no word details)
  /// 
  /// Returns:
  /// ```json
  /// {
  ///   "total_words": 50,
  ///   "benar": 35,
  ///   "salah": 15,
  ///   "accuracy": 70.0,
  ///   "avg_similarity": 0.85
  /// }
  /// ```
  static Future<Map<String, dynamic>?> getStatistics({
    required String sessionId,
    required int surah,
  }) async {
    try {
      final url = '$baseUrl/api/results/$sessionId/$surah/statistics';
      print('📡 GET $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ Statistics: ${data['accuracy']}% accuracy');
        return data;
      } else {
        print('❌ Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception getting statistics: $e');
      return null;
    }
  }
  
  /// Get only mistakes (words with status="salah")
  /// 
  /// Returns:
  /// ```json
  /// {
  ///   "session_id": "1764129034",
  ///   "surah": 2,
  ///   "mistakes": {
  ///     "1:1": {"text": "١", "status": "salah", "similarity": 0.00},
  ///     "2:4": {"text": "فِيهِ", "status": "salah", "similarity": 0.45}
  ///   },
  ///   "total_mistakes": 2
  /// }
  /// ```
  static Future<Map<String, dynamic>?> getMistakes({
    required String sessionId,
    required int surah,
  }) async {
    try {
      final url = '$baseUrl/api/results/$sessionId/$surah/mistakes';
      print('📡 GET $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ Found ${data['total_mistakes']} mistakes');
        return data;
      } else {
        print('❌ Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception getting mistakes: $e');
      return null;
    }
  }
  
  /// Get results for specific ayah only
  /// 
  /// Returns:
  /// ```json
  /// {
  ///   "session_id": "1764129034",
  ///   "surah": 2,
  ///   "ayah": 1,
  ///   "results": {
  ///     "1:0": {"text": "الٓمٓ", "status": "benar", "similarity": 1.00},
  ///     "1:1": {"text": "١", "status": "salah", "similarity": 0.00}
  ///   },
  ///   "statistics": {
  ///     "total_words": 2,
  ///     "benar": 1,
  ///     "salah": 1,
  ///     "accuracy": 50.0
  ///   }
  /// }
  /// ```
  static Future<Map<String, dynamic>?> getAyahResults({
    required String sessionId,
    required int surah,
    required int ayah,
  }) async {
    try {
      final url = '$baseUrl/api/results/$sessionId/$surah/ayah/$ayah';
      print('📡 GET $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ Ayah $ayah: ${data['statistics']?['accuracy']}% accuracy');
        return data;
      } else {
        print('❌ Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception getting ayah results: $e');
      return null;
    }
  }
  
  /// Helper: Calculate overall progress from results
  static double calculateProgress(Map<String, dynamic>? resultsData) {
    if (resultsData == null) return 0.0;
    
    final stats = resultsData['statistics'] as Map<String, dynamic>?;
    if (stats == null) return 0.0;
    
    return (stats['accuracy'] as num?)?.toDouble() ?? 0.0;
  }
  
  /// Helper: Get mistake count from results
  static int getMistakeCount(Map<String, dynamic>? resultsData) {
    if (resultsData == null) return 0;
    
    final mistakes = resultsData['mistakes'] as Map<String, dynamic>?;
    return mistakes?.length ?? 0;
  }
  
  /// Helper: Get correct word count
  static int getCorrectCount(Map<String, dynamic>? resultsData) {
    if (resultsData == null) return 0;
    
    final stats = resultsData['statistics'] as Map<String, dynamic>?;
    if (stats == null) return 0;
    
    return (stats['benar'] as int?) ?? 0;
  }
  
  /// Helper: Get total word count
  static int getTotalWords(Map<String, dynamic>? resultsData) {
    if (resultsData == null) return 0;
    
    final stats = resultsData['statistics'] as Map<String, dynamic>?;
    if (stats == null) return 0;
    
    return (stats['total_words'] as int?) ?? 0;
  }
}



