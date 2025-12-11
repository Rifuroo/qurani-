// lib/providers/premium_provider.dart
// Premium subscription state management

import 'package:flutter/foundation.dart';
import 'package:cuda_qurani/services/supabase_service.dart';
import 'package:cuda_qurani/services/auth_service.dart';
import 'package:cuda_qurani/models/premium_features.dart';

class PremiumProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();

  String _plan = 'free';
  bool _isLoading = true;
  String? _error;

  // Getters
  String get plan => _plan;
  // Premium = 'premium' atau 'pro'
  // Non-premium = 'free', 'basic', atau apapun selainnya
  bool get isPremium => _plan == 'premium' || _plan == 'pro';
  bool get isFree => !isPremium; // Semua yang bukan premium = free (termasuk 'basic')
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
    await loadUserPlan();
  }

  /// Load user's subscription plan from database
  Future<void> loadUserPlan() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _authService.userId;
      if (userId == null) {
        _plan = 'free';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _plan = await _supabaseService.getUserSubscriptionPlan(userId);
      print('✅ Premium: User plan loaded: $_plan');
    } catch (e) {
      print('❌ Premium: Error loading plan: $e');
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
    notifyListeners();
  }
}



