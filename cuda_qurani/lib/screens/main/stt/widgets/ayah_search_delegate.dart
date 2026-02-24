import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/stt_controller.dart';
import '../../../../services/local_database_service.dart';
import '../../../../core/design_system/app_design_system.dart';

class AyahSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Search Surah or Verse...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: AppColors.getSurfaceVariant(context),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(color: AppColors.getTextSecondary(context)),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) {
      return Center(
        child: Text(
          'Enter at least 2 characters to search',
          style: TextStyle(color: AppColors.getTextSecondary(context)),
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalDatabaseService.searchVerses(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return const Center(child: Text('No results found'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            final surahId = result['surah_number'] as int;
            final ayahNum = result['ayah_number'] as int;
            final text = result['text'] as String;
            final surahName = result['surah_name'] as String;
            final matchType = result['match_type'] as String;

            return ListTile(
              title: Text(
                '$surahName ($surahId:$ayahNum)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'UthmanTN'),
              ),
              trailing: Icon(
                matchType == 'surah_name' ? Icons.book : Icons.text_snippet,
                size: 16,
                color: AppColors.getPrimary(context).withOpacity(0.5),
              ),
              onTap: () {
                final controller = context.read<SttController>();
                controller.jumpToAyah(surahId, ayahNum);
                close(context, null);
              },
            );
          },
        );
      },
    );
  }
}
