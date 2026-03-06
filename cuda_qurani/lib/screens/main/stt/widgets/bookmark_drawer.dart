import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/stt_controller.dart';
import '../../../../services/bookmark_service.dart';
import '../../../../services/local_database_service.dart';
import '../../../../core/design_system/app_design_system.dart';
import '../../../../core/utils/language_helper.dart';

class BookmarkDrawer extends StatefulWidget {
  final SttController? controller;
  const BookmarkDrawer({super.key, this.controller});

  @override
  State<BookmarkDrawer> createState() => _BookmarkDrawerState();
}

enum BookmarkSortType {
  quranAsc,
  quranDesc,
  firstBookmarked,
  lastBookmarked,
  firstVisited,
  lastVisited,
}

class _BookmarkDrawerState extends State<BookmarkDrawer> {
  late Future<List<Map<String, dynamic>>> _bookmarksFuture;
  BookmarkSortType _currentSort = BookmarkSortType.lastBookmarked;
  Map<String, dynamic> _translations = {};

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _refreshBookmarks();
  }

  Future<void> _loadTranslations() async {
    final trans = await context.loadTranslations('stt');
    if (mounted) {
      setState(() {
        _translations = trans;
      });
    }
  }

  void _refreshBookmarks() {
    String sortBy = 'timestamp';
    bool ascending = false;

    switch (_currentSort) {
      case BookmarkSortType.quranAsc:
        sortBy = 'quran';
        ascending = true;
        break;
      case BookmarkSortType.quranDesc:
        sortBy = 'quran';
        ascending = false;
        break;
      case BookmarkSortType.firstBookmarked:
        sortBy = 'timestamp';
        ascending = true;
        break;
      case BookmarkSortType.lastBookmarked:
        sortBy = 'timestamp';
        ascending = false;
        break;
      case BookmarkSortType.firstVisited:
        sortBy = 'visited';
        ascending = true;
        break;
      case BookmarkSortType.lastVisited:
        sortBy = 'visited';
        ascending = false;
        break;
    }

    setState(() {
      _bookmarksFuture = BookmarkService().getAllBookmarks(
        sortBy: sortBy,
        ascending: ascending,
      );
    });
  }

  String _getSortLabel(BookmarkSortType type) {
    if (_translations.isEmpty) return '';
    switch (type) {
      case BookmarkSortType.quranAsc:
        return LanguageHelper.tr(_translations, 'bookmarks.sort_quran_asc');
      case BookmarkSortType.quranDesc:
        return LanguageHelper.tr(_translations, 'bookmarks.sort_quran_desc');
      case BookmarkSortType.firstBookmarked:
        return LanguageHelper.tr(
          _translations,
          'bookmarks.sort_first_bookmarked',
        );
      case BookmarkSortType.lastBookmarked:
        return LanguageHelper.tr(
          _translations,
          'bookmarks.sort_last_bookmarked',
        );
      case BookmarkSortType.firstVisited:
        return LanguageHelper.tr(_translations, 'bookmarks.sort_first_visited');
      case BookmarkSortType.lastVisited:
        return LanguageHelper.tr(_translations, 'bookmarks.sort_last_visited');
    }
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Pure white for light theme, fallback to surface for dark theme
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? AppColors.getSurface(context) : Colors.white;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Header & Sort
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Text(
                    LanguageHelper.tr(_translations, 'bookmarks.title'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<BookmarkSortType>(
                    initialValue: _currentSort,
                    onSelected: (type) {
                      setState(() {
                        _currentSort = type;
                      });
                      _refreshBookmarks();
                    },
                    itemBuilder: (context) => BookmarkSortType.values
                        .map(
                          (type) => PopupMenuItem(
                            value: type,
                            child: Text(
                              _getSortLabel(type),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    icon: Icon(
                      Icons.sort_rounded,
                      color: AppColors.getTextSecondary(context),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: AppColors.getBorderLight(context).withOpacity(0.5),
            ),

            // List of Bookmarks
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _bookmarksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final bookmarks = snapshot.data ?? [];

                  if (bookmarks.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: bookmarks.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: AppColors.getBorderLight(context).withOpacity(0.4),
                    ),
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      return _buildBookmarkItem(context, bookmark);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 48,
            color: AppColors.getTextSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            LanguageHelper.tr(_translations, 'bookmarks.empty_state'),
            style: TextStyle(
              color: AppColors.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkItem(
    BuildContext context,
    Map<String, dynamic> bookmark,
  ) {
    final surahId = bookmark['surah_id'] as int;
    final ayahNum = bookmark['ayah_number'] as int;
    final surahName = bookmark['surah_name'] as String;
    final timestamp = bookmark['timestamp'] as int;
    final lastVisited = bookmark['last_visited'] as int?;

    return FutureBuilder<int>(
      future: LocalDatabaseService.getPageNumber(surahId, ayahNum),
      builder: (context, pageSnapshot) {
        final pageNum = pageSnapshot.data ?? 0;

        return InkWell(
          onTap: () async {
            Navigator.pop(context);
            await BookmarkService().markAsVisited(surahId, ayahNum);
            final effectiveController =
                widget.controller ?? context.read<SttController>();
            effectiveController.jumpToAyah(surahId, ayahNum);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$surahName $surahId:$ayahNum',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hal $pageNum  •  ${_formatDate(lastVisited ?? timestamp)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Keep delete button subtle
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.getTextSecondary(context).withOpacity(0.6),
                  ),
                  onPressed: () => _confirmDelete(context, surahId, ayahNum),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    int surahId,
    int ayahNum,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          LanguageHelper.tr(_translations, 'bookmarks.delete_confirm_title'),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              LanguageHelper.tr(_translations, 'app_bar_actions.cancel_text'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              LanguageHelper.tr(_translations, 'bookmarks.delete_button'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BookmarkService().removeBookmark(surahId, ayahNum);
      if (mounted) _refreshBookmarks();
    }
  }
}
