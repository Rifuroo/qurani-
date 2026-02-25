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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AyahSearchModal(controller: controller),
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
      final results = await LocalDatabaseService.searchVerses(query);
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
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.65, // ✅ Adjusted to 65% as requested
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getBorderLight(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search Surah or Verse (e.g. Al-Fatihah, 1:1)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.getSurfaceVariant(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _performSearch,
                ),
              ),
              const SizedBox(height: 8),

              // Example Hints
              if (_searchController.text.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildHintChip('Al-Baqarah'),
                          _buildHintChip('36:1'),
                          _buildHintChip('الحمد لله'),
                          _buildHintChip('اهدنا الصراط'),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              const Divider(height: 1),

              // Results
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.length < 2
                              ? 'Enter at least 2 characters'
                              : 'No results found',
                          style: TextStyle(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          final surahId = result['surah_number'] as int;
                          final ayahNum = result['ayah_number'] as int;
                          final text = result['text'] as String;
                          final surahName = result['surah_name'] as String;
                          final matchType = result['match_type'] as String;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            title: Text(
                              '$surahName ($surahId:$ayahNum)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'UthmanTN'),
                            ),
                            trailing: Icon(
                              matchType == 'surah_name'
                                  ? Icons.book
                                  : Icons.text_snippet,
                              size: 16,
                              color: AppColors.getPrimary(
                                context,
                              ).withOpacity(0.5),
                            ),
                            onTap: () {
                              final effectiveController =
                                  widget.controller ??
                                  context.read<SttController>();
                              effectiveController.jumpToAyah(surahId, ayahNum);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHintChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        _searchController.text = label;
        _performSearch(label);
      },
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
