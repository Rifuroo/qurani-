import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/stt_controller.dart';
import '../../../../services/bookmark_service.dart';
import '../../../../services/local_database_service.dart';
import '../../../../core/design_system/app_design_system.dart';

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

  @override
  void initState() {
    super.initState();
    _refreshBookmarks();
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
    switch (type) {
      case BookmarkSortType.quranAsc:
        return 'Urutan Quran naik';
      case BookmarkSortType.quranDesc:
        return 'Urutan Quran turun';
      case BookmarkSortType.firstBookmarked:
        return 'Pertama ditandai';
      case BookmarkSortType.lastBookmarked:
        return 'Terakhir ditandai';
      case BookmarkSortType.firstVisited:
        return 'Terawal dilihat';
      case BookmarkSortType.lastVisited:
        return 'Terakhir dilihat';
    }
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: AppColors.getSurface(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Penanda',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),

            // Sorting Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Urut berdasarkan',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondary(context),
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
                            child: Text(_getSortLabel(type)),
                          ),
                        )
                        .toList(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getSortLabel(_currentSort),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.unfold_more,
                          size: 16,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

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

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      return _buildBookmarkCard(context, bookmark);
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
            Icons.bookmark_border,
            size: 64,
            color: AppColors.getTextSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada penanda',
            style: TextStyle(
              color: AppColors.getTextSecondary(context),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkCard(
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceVariant(context).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.getBorderLight(context).withOpacity(0.5),
            ),
          ),
          child: InkWell(
            onTap: () async {
              Navigator.pop(context);
              await BookmarkService().markAsVisited(surahId, ayahNum);
              final effectiveController =
                  widget.controller ?? context.read<SttController>();
              effectiveController.jumpToAyah(surahId, ayahNum);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Box (Ayah Ref & Page)
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.getPrimary(context).withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$surahId:$ayahNum',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'hlm. $pageNum',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Middle: Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$surahName - Ayat $ayahNum',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildDateRow(context, 'Ditandai:', timestamp),
                        if (lastVisited != null)
                          _buildDateRow(
                            context,
                            'Terakhir Dikunjungi:',
                            lastVisited,
                          ),
                      ],
                    ),
                  ),

                  // Right: Delete
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.getTextSecondary(context),
                    ),
                    onPressed: () async {
                      await BookmarkService().removeBookmark(surahId, ayahNum);
                      _refreshBookmarks();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateRow(BuildContext context, String label, int timestamp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label ${_formatDate(timestamp)}',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.getTextSecondary(context),
        ),
      ),
    );
  }
}
