import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/stt_controller.dart';
import '../../../../services/bookmark_service.dart';
import '../../../../core/design_system/app_design_system.dart';

class BookmarkDrawer extends StatelessWidget {
  const BookmarkDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.getSurface(context),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.bookmark,
                    color: AppColors.getPrimary(context),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Bookmarks',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // List of Bookmarks
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: BookmarkService().getAllBookmarks(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final bookmarks = snapshot.data ?? [];

                  if (bookmarks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 64,
                            color: AppColors.getTextSecondary(
                              context,
                            ).withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookmarks yet',
                            style: TextStyle(
                              color: AppColors.getTextSecondary(context),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: bookmarks.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      final surahId = bookmark['surah_id'] as int;
                      final ayahNum = bookmark['ayah_number'] as int;
                      final surahName = bookmark['surah_name'] as String;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.getPrimary(
                              context,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              surahId.toString(),
                              style: TextStyle(
                                color: AppColors.getPrimary(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          surahName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          'Ayah $ayahNum',
                          style: TextStyle(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            await BookmarkService().removeBookmark(
                              surahId,
                              ayahNum,
                            );
                            // Refresh list (using setState would require StatefulWidget,
                            // but we can just pop and re-render if needed, or better use a Stream)
                            // For simplicity in this UI, we can trigger a rebuild of the parent/self
                            (context as Element).markNeedsBuild();
                          },
                        ),
                        onTap: () {
                          final controller = context.read<SttController>();
                          controller.jumpToAyah(surahId, ayahNum);
                          Navigator.pop(context); // Close drawer
                        },
                      );
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
}
