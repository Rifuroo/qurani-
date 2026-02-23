// lib/services/_listening_audio_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
  StreamController<WordHighlight>? _wordHighlightController;

  PlaybackSettings? _currentSettings;
  String? _reciterIdentifier;
  List<Map<String, dynamic>> _playlist = [];
  int _currentTrackIndex = 0;
  int _currentVerseRepeat = 0;
  int _currentRangeRepeat = 0;
  Timer? _highlightTimer; // ✅ NEW: Track timer for disposal safety

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  Stream<VerseReference>? get currentVerseStream =>
      _currentVerseController?.stream;
  Stream<WordHighlight>? get wordHighlightStream =>
      _wordHighlightController?.stream;
  AudioPlayer get player => _player;

  // Get current active track info
  VerseReference? get currentVerse {
    if (!_isPlaying ||
        _currentTrackIndex < 0 ||
        _currentTrackIndex >= _playlist.length) {
      return null;
    }
    final track = _playlist[_currentTrackIndex];
    return VerseReference(
      surahId: track['surah_number'] as int,
      verseNumber: track['ayah_number'] as int,
    );
  }

  // Initialize with reciter
  Future<void> initialize(
    PlaybackSettings settings,
    String reciterIdentifier,
  ) async {
    print('Ã°Å¸Å½Âµ ListeningAudioService: Initializing...');
    print('   Reciter: $reciterIdentifier');

    _currentSettings = settings;
    _reciterIdentifier = reciterIdentifier;
    _currentTrackIndex = 0;
    _currentVerseRepeat = 0;
    _currentRangeRepeat = 0;

    // Create stream controllers
    _currentVerseController = StreamController<VerseReference>.broadcast();
    _wordHighlightController = StreamController<WordHighlight>.broadcast();

    // Set playback speed
    await _player.setSpeed(settings.speed);

    // Load playlist
    await _loadPlaylist();

    print('Ã¢Å“â€¦ Initialized with ${_playlist.length} tracks');
  }

  Future<void> _loadPlaylist() async {
    _playlist.clear();

    if (_currentSettings == null || _reciterIdentifier == null) return;

    print(
      'Ã°Å¸â€œâ€¹ Loading playlist (GLOBAL): ${_currentSettings!.startSurahId}:${_currentSettings!.startVerse} - ${_currentSettings!.endSurahId}:${_currentSettings!.endVerse}',
    );

    // Ã¢Å“â€¦ Convert start/end ke GLOBAL ayat
    final startGlobal = GlobalAyatService.toGlobalAyat(
      _currentSettings!.startSurahId,
      _currentSettings!.startVerse,
    );
    final endGlobal = GlobalAyatService.toGlobalAyat(
      _currentSettings!.endSurahId,
      _currentSettings!.endVerse,
    );

    print('Ã°Å¸Å’Â Global range: $startGlobal - $endGlobal');

    // Ã¢Å“â€¦ Load SEMUA surah yang terlibat dalam range
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
            verse['ayah_number']
                as int; // Ã¢â€ Â Ini SUDAH GLOBAL dari database

        // Ã¢Å“â€¦ Filter: hanya ambil yang dalam range global
        if (globalAyahNum >= startGlobal && globalAyahNum <= endGlobal) {
          // Ã¢Å“â€¦ Convert GLOBAL ke LOCAL untuk UI display
          final localInfo = GlobalAyatService.fromGlobalAyat(globalAyahNum);

          _playlist.add({
            'surah_number': localInfo['surah_id']!,
            'ayah_number': localInfo['ayah_number']!,
            'global_ayah_number': globalAyahNum,
            'audio_url': verse['audio_url'],
            'duration': verse['duration'],
            'segments': verse['segments'],
          });

          /* print(
            '  ✅ Added: Surah ${localInfo['surah_id']} Ayah ${localInfo['ayah_number']} (Global #$globalAyahNum)',
          ); */
        }
      }
    }

    print('Ã¢Å“â€¦ Playlist ready: ${_playlist.length} tracks');
  }

  // Start playback
  Future<void> startPlayback() async {
    if (_playlist.isEmpty) {
      throw Exception('Playlist is empty');
    }

    _isPlaying = true;
    _isPaused = false;

    print('Ã¢â€“Â¶Ã¯Â¸Â Starting playback...');
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
          'Ã°Å¸â€Â Repeating range (${_currentRangeRepeat}/${_currentSettings!.rangeRepeat})',
        );
        await _playNextTrack();
      } else {
        print('Ã°Å¸ÂÂ Playback completed');
        _isPlaying = false;
        _isPaused = false;
        await _player.stop();
        if (!(_currentVerseController?.isClosed ?? true)) {
          _currentVerseController?.add(
            VerseReference(surahId: -999, verseNumber: -999),
          );
        }
        print('Ã¢Å“â€¦ Listening mode fully stopped');
      }
      return;
    }

    final currentAudio = _playlist[_currentTrackIndex];
    final surahNum = currentAudio['surah_number'] as int;
    final ayahNum = currentAudio['ayah_number'] as int;

    // Ã¢Å“â€¦  // ✅ REFINE: Removed aggressive reset between ayahs (prevents flicker)
    // _wordHighlightController?.add(WordHighlight(-1, 0));
    // print('🧹 Reset word highlight before starting new ayah');

    // Ã¢Å“â€¦ CRITICAL: Notify verse change FIRST, give UI time to update
    _currentVerseController?.add(
      VerseReference(surahId: surahNum, verseNumber: ayahNum),
    );
    print(
      'Ã°Å¸Å½Âµ Playing: $surahNum:$ayahNum (repeat ${_currentVerseRepeat + 1})',
    );

    // Ã¢Å“â€¦ CRITICAL: Add delay to ensure verse change subscription processes first
    await Future.delayed(const Duration(milliseconds: 150));
    print('Ã¢Å¡Â¡ Verse change processed, starting word highlighting...');

    // Get cached file path (download if not exists)
    final audioUrl = currentAudio['audio_url'] as String;
    String? filePath = await AudioDownloadService.getCachedFilePath(
      _reciterIdentifier!,
      audioUrl,
    );

    // If not cached, download it
    if (filePath == null) {
      print('Ã°Å¸â€œÂ¥ Audio not cached, downloading...');
      filePath = await AudioDownloadService.downloadAudio(
        _reciterIdentifier!,
        audioUrl,
      );
    }

    if (filePath == null) {
      print('Ã¢Å¡ Ã¯Â¸Â Audio file not available, skipping...');
      _moveToNextTrack();
      return;
    }

    try {
      // Load audio file
      await _player.setFilePath(filePath);

      // Ã¢Å“â€¦ FIX: Parse segments dari database
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

          print(
            'Ã°Å¸Å½Â¯ Loaded ${segments.length} word segments for $surahNum:$ayahNum',
          );
        } catch (e) {
          print('Ã¢Å¡ Ã¯Â¸Â Error parsing segments: $e');
        }
      }

      // ✅ FIX: Timer MUST start AFTER audio plays
      int currentHighlightedWord = -1;

      // ✅ NOW start the Timer (Round 8: Universal Normalization)
      if (segments.isNotEmpty) {
        // Pre-calculate min/max for universal normalization
        final minWordIdx = segments
            .map((s) => s['word_index'] as int)
            .reduce(min);
        final maxWordIdx = segments
            .map((s) => s['word_index'] as int)
            .reduce(max);

        // ✅ CRITICAL: Emit first word WITH normalization context
        final firstWordIndex = segments[0]['word_index'] as int;
        currentHighlightedWord = firstWordIndex;
        if (!(_wordHighlightController?.isClosed ?? true)) {
          _wordHighlightController?.add(
            WordHighlight(firstWordIndex, maxWordIdx, min: minWordIdx),
          );
        }
        print(
          '🎯 Emitted first word $firstWordIndex BEFORE audio starts (Range: $minWordIdx-$maxWordIdx)',
        );

        void checkPosition() {
          if (!_isPlaying || _isPaused) return;

          // ✅ BALANCED OFFSET (Round 9): 150ms look-ahead (refined for short ayahs)
          final rawPos = _player.position.inMilliseconds;
          final positionWithLookahead = rawPos + 150;
          final durationMs = _player.duration?.inMilliseconds ?? 0;

          int foundSegmentIdx = -1;

          // ✅ PROACTIVE END: Based on RAW position to avoid double-lookahead bias
          if (durationMs > 0 && rawPos >= durationMs - 100) {
            foundSegmentIdx = segments.length - 1;
          } else {
            // ROBUST SEARCH: Find latest started segment using look-ahead
            for (int i = 0; i < segments.length; i++) {
              if (positionWithLookahead >= (segments[i]['start_ms'] as int)) {
                foundSegmentIdx = i;
              } else {
                break;
              }
            }
          }

          if (foundSegmentIdx != -1) {
            final segment = segments[foundSegmentIdx];
            final wordIndex = segment['word_index'] as int;

            if (wordIndex != currentHighlightedWord) {
              currentHighlightedWord = wordIndex;
              if (!(_wordHighlightController?.isClosed ?? true)) {
                _wordHighlightController?.add(
                  WordHighlight(wordIndex, maxWordIdx, min: minWordIdx),
                );
              }
            }
          }
        }

        // Initial check
        checkPosition();
        _highlightTimer?.cancel();
        _highlightTimer = Timer.periodic(
          const Duration(milliseconds: 10),
          (_) => checkPosition(),
        );
      }

      // Start playback AFTER starting timer and emitting first word
      await _player.play();

      // Wait for audio to finish
      await _player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );

      // ✅ FIX: ALWAYS emit LAST word when audio completes (no condition)
      // This ensures words like "لِلْمُتَّقِينَ" and "يُوقِنُونَ" are always highlighted
      if (segments.isNotEmpty) {
        final lastWordIndex = segments.last['word_index'] as int;
        final minWordIdx = segments
            .map((s) => s['word_index'] as int)
            .reduce(min);
        final maxWordIdx = segments
            .map((s) => s['word_index'] as int)
            .reduce(max);

        print(
          '🏁 Audio completed - forcing last word emit: $lastWordIndex (was: $currentHighlightedWord)',
        );
        currentHighlightedWord = lastWordIndex;
        if (!(_wordHighlightController?.isClosed ?? true)) {
          _wordHighlightController?.add(
            WordHighlight(lastWordIndex, maxWordIdx, min: minWordIdx),
          );
        }
      }

      // ✅ Cancel timer
      _highlightTimer?.cancel();
      _highlightTimer = null;

      print('Ã¢Å“â€¦ Ayah $surahNum:$ayahNum completed');

      // ✅ CRITICAL: Delay before moving to next ayah
      // Increased to 600ms for better visibility of the last word
      await Future.delayed(const Duration(milliseconds: 600));

      // Check verse repeat
      if (_shouldRepeatVerse()) {
        _currentVerseRepeat++;
        await _playNextTrack();
      } else {
        _currentVerseRepeat = 0;
        _moveToNextTrack();
      }
    } catch (e) {
      print('Ã¢ÂÅ’ Error playing track: $e');
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
      // âœ… CRITICAL: Update state BEFORE await untuk UI update yang lebih cepat
      _isPaused = true;
      await _player.pause();
      print('Ã¢ÂÂ¸Ã¯Â¸Â Playback paused');
    }
  }

  Future<void> resumePlayback() async {
    if (_isPlaying && _isPaused) {
      // âœ… CRITICAL: Update state BEFORE await untuk UI update yang lebih cepat
      _isPaused = false;
      await _player.play();
      print('Ã¢â€“Â¶Ã¯Â¸Â Playback resumed');
    }
  }

  Future<void> stopPlayback() async {
    _isPlaying = false;
    _isPaused = false;
    await _player.stop();
    _currentVerseController?.add(VerseReference(surahId: 0, verseNumber: 0));
    print('Ã¢ÂÂ¹Ã¯Â¸Â Playback stopped');
  }

  void dispose() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    _player.dispose();
    _currentVerseController?.close();
    _wordHighlightController?.close();
  }
}

class WordHighlight {
  final int index;
  final int total;
  final int min;
  WordHighlight(this.index, this.total, {this.min = 0});
}
