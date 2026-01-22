// lib/screens/main/stt/services/mushaf_widget_cache.dart

import 'package:flutter/material.dart';
import 'package:cuda_qurani/core/enums/mushaf_layout.dart';
import '../data/models.dart';

/// ✅ ULTIMATE OPTIMIZATION: Widget cache untuk render 1x only!
///
/// Service ini menyimpan widget yang sudah di-render sehingga:
/// - Swipe tidak trigger rebuild berulang-ulang
/// - Setiap page hanya di-build 1x seumur hidup
/// - Memory-efficient dengan LRU eviction
/// - Support pre-rendering semua page di background
class MushafWidgetCache {
  static final MushafWidgetCache _instance = MushafWidgetCache._internal();
  factory MushafWidgetCache() => _instance;
  MushafWidgetCache._internal();

  // ✅ Cache utama: Key = "page_${pageNumber}_${layout}"
  final Map<String, Widget> _widgetCache = {};

  // ✅ LRU tracking untuk eviction
  final List<String> _accessOrder = [];

  // ✅ Track which pages are being rendered (prevent duplicate renders)
  final Set<String> _renderingPages = {};

  // ✅ Configuration
  static const int maxCacheSize = 20; // Keep 20 pages in memory (current + surroundings)
  static const int preloadRadius = 3; // Preload 3 pages before/after current

  // ✅ Statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _totalBuilds = 0;

  /// Generate cache key for a page
  String _getCacheKey(int pageNumber, MushafLayout layout) {
    return 'page_${pageNumber}_${layout.name}';
  }

  /// Check if page is already cached
  bool isCached(int pageNumber, MushafLayout layout) {
    final key = _getCacheKey(pageNumber, layout);
    return _widgetCache.containsKey(key);
  }

  /// Get cached widget (returns null if not cached)
  Widget? getWidget(int pageNumber, MushafLayout layout) {
    final key = _getCacheKey(pageNumber, layout);

    if (_widgetCache.containsKey(key)) {
      _cacheHits++;
      _trackAccess(key);
      print('⚡ WIDGET CACHE HIT: Page $pageNumber (${_cacheHits} hits / ${_cacheMisses} misses)');
      return _widgetCache[key];
    }

    _cacheMisses++;
    print('❌ WIDGET CACHE MISS: Page $pageNumber (${_cacheHits} hits / ${_cacheMisses} misses)');
    return null;
  }

  /// Cache a rendered widget
  void cacheWidget(int pageNumber, MushafLayout layout, Widget widget) {
    final key = _getCacheKey(pageNumber, layout);

    if (_widgetCache.containsKey(key)) {
      // Already cached, just update access order
      _trackAccess(key);
      return;
    }

    _totalBuilds++;
    _widgetCache[key] = widget;
    _trackAccess(key);

    print('💾 CACHED WIDGET: Page $pageNumber (Total: ${_widgetCache.length} pages, ${_totalBuilds} builds)');

    // Evict old pages if cache is too large
    _evictIfNeeded();
  }

  /// Track access for LRU
  void _trackAccess(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  /// Evict least recently used pages if cache exceeds limit
  void _evictIfNeeded() {
    if (_widgetCache.length <= maxCacheSize) return;

    final toRemove = _widgetCache.length - maxCacheSize;
    final keysToEvict = _accessOrder.take(toRemove).toList();

    for (final key in keysToEvict) {
      _widgetCache.remove(key);
      _accessOrder.remove(key);
    }

    print('🗑️ EVICTED $toRemove pages from widget cache (kept ${_widgetCache.length})');
  }

  /// Mark page as being rendered (prevent duplicate renders)
  bool startRendering(int pageNumber, MushafLayout layout) {
    final key = _getCacheKey(pageNumber, layout);

    if (_renderingPages.contains(key)) {
      return false; // Already being rendered
    }

    _renderingPages.add(key);
    return true;
  }

  /// Mark page rendering as complete
  void finishRendering(int pageNumber, MushafLayout layout) {
    final key = _getCacheKey(pageNumber, layout);
    _renderingPages.remove(key);
  }

  /// Check if page is currently being rendered
  bool isRendering(int pageNumber, MushafLayout layout) {
    final key = _getCacheKey(pageNumber, layout);
    return _renderingPages.contains(key);
  }

  /// Clear cache for specific layout (when switching layouts)
  void clearLayout(MushafLayout layout) {
    final keysToRemove = _widgetCache.keys
        .where((key) => key.endsWith('_${layout.name}'))
        .toList();

    for (final key in keysToRemove) {
      _widgetCache.remove(key);
      _accessOrder.remove(key);
    }

    print('🗑️ CLEARED ${keysToRemove.length} pages for layout ${layout.name}');
  }

  /// Clear entire cache
  void clearAll() {
    final count = _widgetCache.length;
    _widgetCache.clear();
    _accessOrder.clear();
    _renderingPages.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
    _totalBuilds = 0;

    print('🗑️ CLEARED ALL WIDGET CACHE ($count pages)');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final hitRate = _cacheHits + _cacheMisses > 0
        ? (_cacheHits / (_cacheHits + _cacheMisses) * 100).toStringAsFixed(1)
        : '0.0';

    return {
      'cached_pages': _widgetCache.length,
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'hit_rate': '$hitRate%',
      'total_builds': _totalBuilds,
      'rendering_now': _renderingPages.length,
    };
  }

  /// Print cache statistics
  void printStats() {
    final stats = getStats();
    print('📊 WIDGET CACHE STATS:');
    print('   Cached Pages: ${stats['cached_pages']}');
    print('   Cache Hits: ${stats['cache_hits']}');
    print('   Cache Misses: ${stats['cache_misses']}');
    print('   Hit Rate: ${stats['hit_rate']}');
    print('   Total Builds: ${stats['total_builds']}');
    print('   Rendering Now: ${stats['rendering_now']}');
  }

  /// Get list of pages to preload around current page
  List<int> getPreloadPages(int currentPage, int totalPages) {
    final List<int> pages = [];

    // Preload pages in radius around current
    for (int offset = -preloadRadius; offset <= preloadRadius; offset++) {
      if (offset == 0) continue; // Skip current page

      final page = currentPage + offset;
      if (page >= 1 && page <= totalPages) {
        pages.add(page);
      }
    }

    return pages;
  }

  /// Prioritize caching for pages near current page
  void prioritizePages(int currentPage, int totalPages) {
    // Move nearby pages to end of access order (keep them in cache)
    final nearbyPages = getPreloadPages(currentPage, totalPages);
    nearbyPages.add(currentPage);

    for (final page in nearbyPages) {
      final qpcKey = _getCacheKey(page, MushafLayout.qpc);
      final indopakKey = _getCacheKey(page, MushafLayout.indopak);

      if (_widgetCache.containsKey(qpcKey)) {
        _trackAccess(qpcKey);
      }
      if (_widgetCache.containsKey(indopakKey)) {
        _trackAccess(indopakKey);
      }
    }
  }

  /// ✅ EXPERIMENTAL: Pre-render specific pages in isolate (background thread)
  /// This is complex and might not work well with Flutter's widget tree
  /// Better approach: Render on-demand with aggressive caching
  Future<void> warmupPages({
    required List<int> pageNumbers,
    required MushafLayout layout,
    required Function(int, MushafLayout) renderFunction,
  }) async {
    int rendered = 0;

    for (final pageNumber in pageNumbers) {
      if (isCached(pageNumber, layout)) {
        continue; // Skip already cached pages
      }

      if (!startRendering(pageNumber, layout)) {
        continue; // Skip if already being rendered
      }

      try {
        // Call render function (this will build and cache the widget)
        renderFunction(pageNumber, layout);
        rendered++;

        // Yield to prevent blocking main thread
        if (rendered % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      } catch (e) {
        print('❌ Failed to warmup page $pageNumber: $e');
      } finally {
        finishRendering(pageNumber, layout);
      }
    }

    print('🔥 WARMUP COMPLETE: Rendered $rendered pages');
  }
}

/// ✅ Widget wrapper that uses cache
class CachedMushafPage extends StatelessWidget {
  final int pageNumber;
  final MushafLayout layout;
  final Widget Function() builder;

  const CachedMushafPage({
    Key? key,
    required this.pageNumber,
    required this.layout,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cache = MushafWidgetCache();

    // Try to get from cache
    final cached = cache.getWidget(pageNumber, layout);
    if (cached != null) {
      return cached;
    }

    // Build new widget
    if (!cache.startRendering(pageNumber, layout)) {
      // Already being rendered, show loading
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    try {
      final widget = RepaintBoundary(
        key: ValueKey('mushaf_${pageNumber}_${layout.name}'),
        child: builder(),
      );

      // Cache the built widget
      cache.cacheWidget(pageNumber, layout, widget);

      return widget;
    } finally {
      cache.finishRendering(pageNumber, layout);
    }
  }
}
