// lib/services/_listening_audio_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:cuda_qurani/services/audio_download_services.dart';
import 'package:cuda_qurani/services/global_ayat_services.dart';
import 'package:cuda_qurani/services/reciter_manager_services.dart';
import 'package:just_audio/just_audio.dart';
import '../models/playback_settings_model.dart';

class ListeningAudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isPaused = false;

  StreamController<VerseReference>? _currentVerseController;
  StreamController<int>? _wordHighlightController;

  PlaybackSettings? _currentSettings;
  String? _reciterIdentifier;
  List<Map<String, dynamic>> _playlist = [];
  int _currentTrackIndex = 0;
  int _currentVerseRepeat = 0;
  int _currentRangeRepeat = 0;

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  Stream<VerseReference>? get currentVerseStream =>
      _currentVerseController?.stream;
  Stream<int>? get wordHighlightStream => _wordHighlightController?.stream;
  AudioPlayer get player => _player;

  // Initialize with reciter
  Future<void> initialize(
    PlaybackSettings settings,
    String reciterIdentifier,
  ) async {
    print('ðŸŽµ ListeningAudioService: Initializing...');
    print('   Reciter: $reciterIdentifier');

    _currentSettings = settings;
    _reciterIdentifier = reciterIdentifier;
    _currentTrackIndex = 0;
    _currentVerseRepeat = 0;
    _currentRangeRepeat = 0;

    // Create stream controllers
    _currentVerseController = StreamController<VerseReference>.broadcast();
    _wordHighlightController = StreamController<int>.broadcast();

    // Set playback speed
    await _player.setSpeed(settings.speed);

    // Load playlist
    await _loadPlaylist();

    print('âœ… Initialized with ${_playlist.length} tracks');
  }

  Future<void> _loadPlaylist() async {
    _playlist.clear();

    if (_currentSettings == null || _reciterIdentifier == null) return;

    print(
      'ðŸ“‹ Loading playlist (GLOBAL): ${_currentSettings!.startSurahId}:${_currentSettings!.startVerse} - ${_currentSettings!.endSurahId}:${_currentSettings!.endVerse}',
    );

    // âœ… Convert start/end ke GLOBAL ayat
    final startGlobal = GlobalAyatService.toGlobalAyat(
      _currentSettings!.startSurahId,
      _currentSettings!.startVerse,
    );
    final endGlobal = GlobalAyatService.toGlobalAyat(
      _currentSettings!.endSurahId,
      _currentSettings!.endVerse,
    );

    print('ðŸŒ Global range: $startGlobal - $endGlobal');

    // âœ… Load SEMUA surah yang terlibat dalam range
    for (
      int surah = _currentSettings!.startSurahId;
      surah <= _currentSettings!.endSurahId;
      surah++
    ) {
      final audioUrls = await ReciterManagerService.getSurahAudioUrls(
        _reciterIdentifier!,
        surah,
      );

      for (final verse in audioUrls) {
        final globalAyahNum =
            verse['ayah_number'] as int; // â† Ini SUDAH GLOBAL dari database

        // âœ… Filter: hanya ambil yang dalam range global
        if (globalAyahNum >= startGlobal && globalAyahNum <= endGlobal) {
          // âœ… Convert GLOBAL ke LOCAL untuk UI display
          final localInfo = GlobalAyatService.fromGlobalAyat(globalAyahNum);

          _playlist.add({
            'surah_number': localInfo['surah_id']!,
            'ayah_number': localInfo['ayah_number']!,
            'global_ayah_number': globalAyahNum,
            'audio_url': verse['audio_url'],
            'duration': verse['duration'],
            'segments': verse['segments'],
          });

          print(
            '  âœ… Added: Surah ${localInfo['surah_id']} Ayah ${localInfo['ayah_number']} (Global #$globalAyahNum)',
          );
        }
      }
    }

    print('âœ… Playlist ready: ${_playlist.length} tracks');
  }

  // Start playback
  Future<void> startPlayback() async {
    if (_playlist.isEmpty) {
      throw Exception('Playlist is empty');
    }

    _isPlaying = true;
    _isPaused = false;

    print('â–¶ï¸ Starting playback...');
    await _playNextTrack();
  }

  // REPLACE method _playNextTrack() di listening_audio_services.txt dengan kode ini:

  // Play next track
  // Play next track
Future<void> _playNextTrack() async {
  if (!_isPlaying || _currentTrackIndex >= _playlist.length) {
    // Range completed, check repeat
    if (_shouldRepeatRange()) {
      _currentRangeRepeat++;
      _currentTrackIndex = 0;
      _currentVerseRepeat = 0;
      print(
        'ðŸ” Repeating range (${_currentRangeRepeat}/${_currentSettings!.rangeRepeat})',
      );
      await _playNextTrack();
    } else {
      print('ðŸ Playback completed');
      _isPlaying = false;
      _isPaused = false;
      await _player.stop();
      _currentVerseController?.add(
        VerseReference(surahId: -999, verseNumber: -999),
      );
      print('âœ… Listening mode fully stopped');
    }
    return;
  }

  final currentAudio = _playlist[_currentTrackIndex];
  final surahNum = currentAudio['surah_number'] as int;
  final ayahNum = currentAudio['ayah_number'] as int;

 // âœ… FIX: Reset highlight SEBELUM notifikasi ayat baru
_wordHighlightController?.add(-1);
print('ðŸ"„ Reset word highlight before starting new ayah');

// âœ… CRITICAL: Notify verse change FIRST, give UI time to update
_currentVerseController?.add(
  VerseReference(surahId: surahNum, verseNumber: ayahNum),
);
print('ðŸŽµ Playing: $surahNum:$ayahNum (repeat ${_currentVerseRepeat + 1})');

// âœ… CRITICAL: Add delay to ensure verse change subscription processes first
await Future.delayed(const Duration(milliseconds: 150));
print('âš¡ Verse change processed, starting word highlighting...');

  // Get cached file path (download if not exists)
  final audioUrl = currentAudio['audio_url'] as String;
  String? filePath = await AudioDownloadService.getCachedFilePath(
    _reciterIdentifier!,
    audioUrl,
  );

  // If not cached, download it
  if (filePath == null) {
    print('ðŸ“¥ Audio not cached, downloading...');
    filePath = await AudioDownloadService.downloadAudio(
      _reciterIdentifier!,
      audioUrl,
    );
  }

  if (filePath == null) {
    print('âš ï¸ Audio file not available, skipping...');
    _moveToNextTrack();
    return;
  }

  try {
    // Load audio file
    await _player.setFilePath(filePath);

    // âœ… FIX: Parse segments dari database
    final segmentsJson = currentAudio['segments'] as String?;
    List<Map<String, dynamic>> segments = [];

    if (segmentsJson != null && segmentsJson.isNotEmpty) {
      try {
        final List<dynamic> segmentsList = jsonDecode(segmentsJson);
        segments = segmentsList
            .map(
              (s) => {
                'word_index': s[0] as int,
                'start_ms': s[2] as int,
                'end_ms': s[3] as int,
              },
            )
            .toList();

        print('ðŸŽ¯ Loaded ${segments.length} word segments for $surahNum:$ayahNum');
      } catch (e) {
        print('âš ï¸ Error parsing segments: $e');
      }
    }

    // âœ… FIX: Start word highlighting SEBELUM play
    StreamSubscription? positionSubscription;

    if (segments.isNotEmpty) {
      int currentHighlightedWord = -1;

      positionSubscription = _player.positionStream.listen((position) {
        final positionMs = position.inMilliseconds;

        // Find which word is currently playing
        for (int i = 0; i < segments.length; i++) {
          final segment = segments[i];
          final startMs = segment['start_ms'] as int;
          final endMs = segment['end_ms'] as int;

          if (positionMs >= startMs && positionMs <= endMs) {
            final wordIndex = segment['word_index'] as int;

            // Only emit if word changed (avoid spam)
            if (wordIndex != currentHighlightedWord) {
              currentHighlightedWord = wordIndex;
              _wordHighlightController?.add(wordIndex);
              print('âœ¨ Highlighting word $wordIndex at ${positionMs}ms (Surah $surahNum:$ayahNum)');
            }
            break;
          }
        }
      });
    }

    // Start playback
    await _player.play();

    // Wait for audio to finish
    await _player.playerStateStream.firstWhere(
      (state) => state.processingState == ProcessingState.completed,
    );

    // âœ… Cancel position subscription
    await positionSubscription?.cancel();

    print('âœ… Ayah $surahNum:$ayahNum completed');

    // Check verse repeat
    if (_shouldRepeatVerse()) {
      _currentVerseRepeat++;
      await _playNextTrack();
    } else {
      _currentVerseRepeat = 0;
      _moveToNextTrack();
    }
  } catch (e) {
    print('âŒ Error playing track: $e');
    _moveToNextTrack();
  }
}

  void _moveToNextTrack() {
    _currentTrackIndex++;
    _playNextTrack();
  }

  bool _shouldRepeatVerse() {
    if (_currentSettings == null) return false;
    final repeatCount = _currentSettings!.eachVerseRepeat;
    if (repeatCount == -1) return true;
    return _currentVerseRepeat < (repeatCount - 1);
  }

  bool _shouldRepeatRange() {
    if (_currentSettings == null) return false;
    final repeatCount = _currentSettings!.rangeRepeat;
    if (repeatCount == -1) return true;
    return _currentRangeRepeat < (repeatCount - 1);
  }

  Future<void> pausePlayback() async {
    if (_isPlaying && !_isPaused) {
      await _player.pause();
      _isPaused = true;
      print('â¸ï¸ Playback paused');
    }
  }

  Future<void> resumePlayback() async {
    if (_isPlaying && _isPaused) {
      await _player.play();
      _isPaused = false;
      print('â–¶ï¸ Playback resumed');
    }
  }

  Future<void> stopPlayback() async {
    _isPlaying = false;
    _isPaused = false;
    await _player.stop();
    _currentVerseController?.add(VerseReference(surahId: 0, verseNumber: 0));
    print('â¹ï¸ Playback stopped');
  }

  void dispose() {
    _player.dispose();
    _currentVerseController?.close();
    _wordHighlightController?.close();
  }
}


