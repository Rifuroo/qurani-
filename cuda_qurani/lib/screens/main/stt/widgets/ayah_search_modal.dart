import 'package:cuda_qurani/services/quran_resource_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/stt_controller.dart';
import '../../../../services/local_database_service.dart';
import '../../../../core/design_system/app_design_system.dart';

class AyahSearchModal extends StatefulWidget {
  final SttController? controller;
  const AyahSearchModal({super.key, this.controller});

  static Future<void> show(BuildContext context) {
    final controller = Provider.of<SttController>(context, listen: false);
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: AyahSearchModal(controller: controller),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  State<AyahSearchModal> createState() => _AyahSearchModalState();
}

class _AyahSearchModalState extends State<AyahSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resourceSvc = context.read<QuranResourceService>();

      // The naming pattern for DB is actually more complex in QuranResourceService.
      // Let's use the actual active DB name if possible.
      // After checking QuranResourceService, there isn't a direct getter for the DB name,
      // but we can infer it or add a getter.
      // For now, let's try to match how it's built in loadTranslation.

      final results = await LocalDatabaseService.searchVerses(
        query,
        translationDbName: resourceSvc.getTranslationDbName(),
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: EdgeInsets.only(top: topPadding + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Bar & Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(
                        color: AppColors.getTextPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Search Surah or Verse (e.g. Al-Fatihah, 36:1)',
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.getPrimary(context),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _performSearch('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.getSurfaceVariant(context),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: TextStyle(
                          color: AppColors.getTextSecondary(
                            context,
                          ).withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                      onChanged: _performSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Results Area
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    )
                  : _searchController.text.isEmpty
                  ? _buildInitialState()
                  : _searchResults.isEmpty
                  ? _buildEmptyState()
                  : _buildResultsList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    final resourceSvc = context.read<QuranResourceService>();
    final lang = resourceSvc.selectedTranslationLanguage?.toLowerCase() ?? '';
    final isIndo = lang.contains('indonesia');
    final isEnglish = lang.contains('english');

    List<String> hints = ['Al-Baqarah', '36:1', 'الحمد لله'];
    if (isIndo) {
      hints.add('Musa');
    } else if (isEnglish) {
      hints.add('Moses');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Examples:',
            style: TextStyle(
              color: AppColors.getTextSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hints.map((h) => _buildHintChip(h)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.getTextSecondary(context).withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.length < 2
                  ? 'Enter at least 2 characters'
                  : 'No results found',
              style: TextStyle(color: AppColors.getTextSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 24, endIndent: 24),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final surahId = result['surah_number'] as int;
        final ayahNum = result['ayah_number'] as int;
        final text = result['text'] as String;
        final surahName = result['surah_name'] as String;

        final translationText = result['translation_text'] as String?;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 4,
          ),
          title: Text(
            '$surahName ($surahId:$ayahNum)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (text.isNotEmpty)
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'UthmanTN', fontSize: 16),
                ),
              if (translationText != null)
                Text(
                  translationText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.getTextSecondary(context),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          onTap: () {
            final effectiveController =
                widget.controller ?? context.read<SttController>();
            effectiveController.jumpToAyah(surahId, ayahNum);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildHintChip(String label) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.getTextPrimary(context),
        ),
      ),
      backgroundColor: AppColors.getSurfaceVariant(context),
      onPressed: () {
        _searchController.text = label;
        _performSearch(label);
      },
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
