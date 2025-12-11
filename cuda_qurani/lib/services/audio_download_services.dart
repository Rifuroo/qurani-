// lib/services/_audio_download_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double percentage;
  final double speedBytesPerSecond;
  
  DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.percentage,
    required this.speedBytesPerSecond,
  });
  
  String get speedFormatted {
    if (speedBytesPerSecond < 1024) {
      return '${speedBytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (speedBytesPerSecond < 1024 * 1024) {
      return '${(speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }
}

class AudioDownloadService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  
  static final Map<String, CancelToken> _activeDownloads = {};
  
  // Get reciter cache directory
  static Future<Directory> _getReciterCacheDirectory(String reciterId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, 'audio_cache', reciterId));
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }
  
  // Generate cache file name from URL
  static String _getCacheFileName(String url) {
    final uri = Uri.parse(url);
    return path.basename(uri.path);
  }
  
  // Check if audio file exists for specific reciter
  static Future<bool> isAudioCached(String reciterId, String audioUrl) async {
    try {
      final cacheDir = await _getReciterCacheDirectory(reciterId);
      final fileName = _getCacheFileName(audioUrl);
      final file = File(path.join(cacheDir.path, fileName));
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
  
  // Get cached file path
  static Future<String?> getCachedFilePath(String reciterId, String audioUrl) async {
    try {
      final cacheDir = await _getReciterCacheDirectory(reciterId);
      final fileName = _getCacheFileName(audioUrl);
      final filePath = path.join(cacheDir.path, fileName);
      final file = File(filePath);
      
      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      print('❌ Error getting cached file: $e');
      return null;
    }
  }
  
  // Download single audio file with progress
  static Future<String?> downloadAudio(
    String reciterId,
    String audioUrl, {
    Function(DownloadProgress)? onProgress,
  }) async {
    try {
      // Check if already cached
      final cached = await getCachedFilePath(reciterId, audioUrl);
      if (cached != null) {
        print('✅ Using cached audio: $cached');
        return cached;
      }
      
      final cacheDir = await _getReciterCacheDirectory(reciterId);
      final fileName = _getCacheFileName(audioUrl);
      final filePath = path.join(cacheDir.path, fileName);
      
      // Create cancel token for this download
      final cancelToken = CancelToken();
      _activeDownloads[audioUrl] = cancelToken;
      
      int lastReceivedBytes = 0;
      DateTime lastUpdateTime = DateTime.now();
      
      await _dio.download(
        audioUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          
          final now = DateTime.now();
          final timeDiff = now.difference(lastUpdateTime).inMilliseconds;
          
          if (timeDiff > 0) {
            final bytesDiff = received - lastReceivedBytes;
            final speed = (bytesDiff / timeDiff) * 1000; // bytes per second
            
            onProgress?.call(DownloadProgress(
              receivedBytes: received,
              totalBytes: total,
              percentage: (received / total) * 100,
              speedBytesPerSecond: speed,
            ));
            
            lastReceivedBytes = received;
            lastUpdateTime = now;
          }
        },
      );
      
      _activeDownloads.remove(audioUrl);
      print('✅ Downloaded: $filePath');
      return filePath;
      
    } catch (e) {
      _activeDownloads.remove(audioUrl);
      if (e is DioException && e.type == DioExceptionType.cancel) {
        print('⚠️ Download cancelled: $audioUrl');
      } else {
        print('❌ Download failed: $e');
      }
      return null;
    }
  }
  
  // Cancel specific download
  static void cancelDownload(String audioUrl) {
    _activeDownloads[audioUrl]?.cancel();
    _activeDownloads.remove(audioUrl);
  }
  
  // Cancel all downloads
  static void cancelAllDownloads() {
    for (final token in _activeDownloads.values) {
      token.cancel();
    }
    _activeDownloads.clear();
  }
  
  // Get storage info for specific reciter
  static Future<Map<String, dynamic>> getReciterStorageInfo(String reciterId) async {
    try {
      final cacheDir = await _getReciterCacheDirectory(reciterId);
      if (!await cacheDir.exists()) {
        return {
          'totalBytes': 0,
          'fileCount': 0,
          'formattedSize': '0 KB',
        };
      }
      
      int totalBytes = 0;
      int fileCount = 0;
      
      await for (final entity in cacheDir.list(recursive: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
          fileCount++;
        }
      }
      
      return {
        'totalBytes': totalBytes,
        'fileCount': fileCount,
        'formattedSize': _formatBytes(totalBytes),
      };
    } catch (e) {
      print('❌ Error getting storage info: $e');
      return {
        'totalBytes': 0,
        'fileCount': 0,
        'formattedSize': '0 KB',
      };
    }
  }
  
  // Get total storage used by all reciters
  static Future<Map<String, dynamic>> getTotalStorageInfo() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioCacheDir = Directory(path.join(appDir.path, 'audio_cache'));
      
      if (!await audioCacheDir.exists()) {
        return {
          'totalBytes': 0,
          'fileCount': 0,
          'formattedSize': '0 KB',
        };
      }
      
      int totalBytes = 0;
      int fileCount = 0;
      
      await for (final entity in audioCacheDir.list(recursive: true)) {
        if (entity is File) {
          totalBytes += await entity.length();
          fileCount++;
        }
      }
      
      return {
        'totalBytes': totalBytes,
        'fileCount': fileCount,
        'formattedSize': _formatBytes(totalBytes),
      };
    } catch (e) {
      print('❌ Error getting total storage: $e');
      return {
        'totalBytes': 0,
        'fileCount': 0,
        'formattedSize': '0 KB',
      };
    }
  }

  // ✅ NEW: Get all cached file names at once (super fast)
static Future<Set<String>> getAllCachedFiles(String reciterId) async {
  try {
    final cacheDir = await _getReciterCacheDirectory(reciterId);
    if (!await cacheDir.exists()) {
      return {};
    }
    
    final Set<String> fileNames = {};
    
    // ✅ Single directory scan (very fast)
    await for (final entity in cacheDir.list(recursive: false)) {
      if (entity is File) {
        fileNames.add(path.basename(entity.path));
      }
    }
    
    print('✅ Scanned cache: ${fileNames.length} files found');
    return fileNames;
  } catch (e) {
    print('❌ Error scanning cache: $e');
    return {};
  }
}

// ✅ NEW: Public method to get cache filename from URL
static String getCacheFileNameFromUrl(String url) {
  return _getCacheFileName(url);
}
  
  // Clear cache for specific reciter
  static Future<void> clearReciterCache(String reciterId) async {
    try {
      final cacheDir = await _getReciterCacheDirectory(reciterId);
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('🗑️ Cleared cache for reciter: $reciterId');
      }
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }
  
  // Clear all caches
  static Future<void> clearAllCaches() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioCacheDir = Directory(path.join(appDir.path, 'audio_cache'));
      
      if (await audioCacheDir.exists()) {
        await audioCacheDir.delete(recursive: true);
        print('🗑️ All audio caches cleared');
      }
    } catch (e) {
      print('❌ Error clearing all caches: $e');
    }
  }
  
  // Format bytes to human readable
  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}


