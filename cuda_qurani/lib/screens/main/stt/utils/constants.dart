// lib\screens\main\stt\utils\constants.dart

import 'package:flutter/material.dart';

// ==================== UI & THEME ====================
const Color backgroundColor = Color.fromARGB(255, 255, 255, 255);
const Color primaryColor = Color(0xFF247C64);
const Color correctColor = Color(0xFF27AE60);
const Color errorColor = Color(0xFFE74C3C);
const Color warningColor = Color(0xFFF39C12);
const Color unreadColor = Color(0xFFBDC3C7);
const Color listeningColor = Color.fromARGB(255, 0, 0, 0);
const Color accentColor = Color(0xFF9B59B6);
const Color skippedColor = Color(0xFF95A5A6);

// ==================== PRE-LOADING CACHE ====================
// ✅ OPTIMIZED: Increased cache radius and size for faster mushaf loading (Tarteel-style)
// ✅ CRITICAL: Large cache to prevent re-loading when swiping back and forth
const int cacheRadius = 20; // Preload ±20 pages for ultra-fast swipe
const int maxCacheSize = 500; // Increased to 500 (keep ALL visited pages in memory - no re-loading!)
const int quranServiceCacheSize = 500; // Increased for faster preload (dynamic: 604 QPC / 610 IndoPak)
const int cacheEvictionThreshold = 600; // Only evict when cache exceeds this (very large buffer)
const int cacheEvictionDistance = 300; // Only evict pages > 300 pages away from current

// ==================== PERFORMANCE TUNING ====================
const double averageAyatHeight = 170.0;
const int listViewCacheExtent = 500;



