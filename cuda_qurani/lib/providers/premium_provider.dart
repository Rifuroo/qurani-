// lib/providers/premium_provider.dart
// Premium subscription state management

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:cuda_qurani/services/auth_service.dart';
import 'package:cuda_qurani/models/premium_features.dart';

class PremiumProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();

  // ✅ NEW: Auth state subscription untuk auto-refresh
  StreamSubscription<AuthState>? _authSubscription;

  String _plan = 'free';
  bool _isLoading = true;
  String? _error;
  bool _hasLoadedOnce = false; // Track if we've loaded at least once

  // Getters
  String get plan => _plan;
  // Premium = 'premium' atau 'pro'
  // Non-premium = 'free', 'basic', atau apapun selainnya
  bool get isPremium => _plan == 'premium' || _plan == 'pro';
  bool get isFree =>
      !isPremium; // Semua yang bukan premium = free (termasuk 'basic')
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Plan display name
  String get planDisplayName {
    switch (_plan) {
      case 'premium':
        return 'Premium';
      case 'pro':
        return 'Pro';
      default:
        return 'Free';
    }
  }

  /// Initialize and load user's subscription plan
  Future<void> initialize() async {
    print('🔐 PremiumProvider: Initializing...');

    // ✅ NEW: Listen to auth state changes to auto-refresh premium status
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      AuthState state,
    ) {
      print('🔔 PremiumProvider: Auth state changed - ${state.event}');

      // Refresh premium status when user signs in
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.initialSession) {
        if (state.session?.user != null) {
          print(
            '🔄 PremiumProvider: Auto-refreshing premium status after auth change...',
          );
          _loadPlanForUser(state.session!.user.id);
        }
      }

      // Reset to free when user signs out
      if (state.event == AuthChangeEvent.signedOut) {
        print('👋 PremiumProvider: User signed out, resetting to free');
        _plan = 'free';
        _hasLoadedOnce = false;
        notifyListeners();
      }
    });

    // Initial load (if user already authenticated)
    await loadUserPlan();
  }

  /// ✅ NEW: Load plan for specific user ID (used by auth listener)
  Future<void> _loadPlanForUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _plan = await _supabaseService.getUserSubscriptionPlan(userId);
      _hasLoadedOnce = true;
      print('✅ PremiumProvider: Plan loaded for user $userId: $_plan');
    } catch (e) {
      print('❌ PremiumProvider: Error loading plan: $e');
      _error = e.toString();
      _plan = 'free';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load user's subscription plan from database
  Future<void> loadUserPlan() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _authService.userId;
      if (userId == null) {
        print(
          '⚠️ PremiumProvider: No userId yet, defaulting to free (will auto-refresh on auth)',
        );
        _plan = 'free';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _plan = await _supabaseService.getUserSubscriptionPlan(userId);
      _hasLoadedOnce = true;
      print('✅ PremiumProvider: User plan loaded: $_plan');
    } catch (e) {
      print('❌ PremiumProvider: Error loading plan: $e');
      _error = e.toString();
      _plan = 'free';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Check if user can access a specific feature
  bool canAccess(PremiumFeature feature) {
    if (isPremium) return true;
    return !premiumOnlyFeatures.contains(feature);
  }

  /// Check if a feature is premium-only
  bool isPremiumFeature(PremiumFeature feature) {
    return premiumOnlyFeatures.contains(feature);
  }

  /// Manually set plan (for testing/admin purposes)
  void setPlan(String newPlan) {
    _plan = newPlan;
    notifyListeners();
    print('✅ Premium: Plan manually set to: $_plan');
  }

  /// Refresh plan from database
  Future<void> refresh() async {
    await loadUserPlan();
  }

  /// Clear premium state (on logout)
  void clear() {
    _plan = 'free';
    _isLoading = false;
    _error = null;
    _hasLoadedOnce = false;
    notifyListeners();
  }

  /// ✅ NEW: Dispose subscription when provider is disposed
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
