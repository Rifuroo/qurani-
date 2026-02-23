import 'package:flutter/material.dart';
import '../../domain/entities/similarity_result.dart';
import '../../domain/repositories/similarity_repository.dart';
import 'package:cuda_qurani/services/global_ayat_services.dart';

class PhraseSimilarityController extends ChangeNotifier {
  final ISimilarityRepository _repository;

  int _surahId;
  int _ayahNumber;
  String _surahName;

  String? _verseText;
  List<SimilarPhrase> _similarPhrases = [];
  bool _isLoading = false;
  String? _errorMessage;

  PhraseSimilarityController({
    required ISimilarityRepository repository,
    required int initialSurahId,
    required int initialAyahNumber,
    required String initialSurahName,
  }) : _repository = repository,
       _surahId = initialSurahId,
       _ayahNumber = initialAyahNumber,
       _surahName = initialSurahName {
    loadData();
  }

  // Getters
  ISimilarityRepository get repository => _repository;
  int get surahId => _surahId;
  int get ayahNumber => _ayahNumber;
  String get surahName => _surahName;
  String? get verseText => _verseText;
  List<SimilarPhrase> get similarPhrases => _similarPhrases;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _verseText = await _repository.getVerseText(_surahId, _ayahNumber);
      _similarPhrases = await _repository.getSimilarPhrases(
        _surahId,
        _ayahNumber,
      );
    } catch (e) {
      _errorMessage = 'Error loading phrases: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void nextAyah() {
    final globalIndex = GlobalAyatService.toGlobalAyat(_surahId, _ayahNumber);
    if (GlobalAyatService.isValid(globalIndex + 1)) {
      final next = GlobalAyatService.fromGlobalAyat(globalIndex + 1);
      _updateAyah(next['surah_id']!, next['ayah_number']!);
    }
  }

  void previousAyah() {
    final globalIndex = GlobalAyatService.toGlobalAyat(_surahId, _ayahNumber);
    if (GlobalAyatService.isValid(globalIndex - 1)) {
      final prev = GlobalAyatService.fromGlobalAyat(globalIndex - 1);
      _updateAyah(prev['surah_id']!, prev['ayah_number']!);
    }
  }

  void _updateAyah(int newSurahId, int newAyahNumber) async {
    _surahId = newSurahId;
    _ayahNumber = newAyahNumber;
    try {
      _surahName = await _repository.getSurahName(newSurahId);
    } catch (e) {
      debugPrint('Error updating surah name: $e');
    }
    loadData();
  }

  @override
  void dispose() {
    _repository.clearCache();
    super.dispose();
  }
}
