// lib/services/in_app_purchase_service.dart
// In-App Purchase Service untuk Google Play

import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product IDs - sesuaikan dengan yang didaftarkan di Play Console
class IAPProductIds {
  static const String premiumMonthly = 'qurani_premium_monthly';
  static const String premiumYearly = 'qurani_premium_yearly';

  static const Set<String> subscriptions = {premiumMonthly, premiumYearly};
}

// ============================================================================
// DUMMY PRODUCTS - HAPUS BAGIAN INI SETELAH SETUP GOOGLE PLAY CONSOLE
// ============================================================================
class DummyProductDetails {
  final String id;
  final String title;
  final String description;
  final String price;

  const DummyProductDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });
}

const List<DummyProductDetails> _dummyProducts = [
  DummyProductDetails(
    id: IAPProductIds.premiumMonthly,
    title: 'Premium Bulanan',
    description: 'Akses semua fitur premium selama 1 bulan',
    price: 'Rp 29.000',
  ),
  DummyProductDetails(
    id: IAPProductIds.premiumYearly,
    title: 'Premium Tahunan',
    description: 'Akses semua fitur premium selama 1 tahun (hemat 40%)',
    price: 'Rp 199.000',
  ),
];
// ============================================================================
// END DUMMY PRODUCTS
// ============================================================================

class InAppPurchaseService {
  static final InAppPurchaseService _instance = InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];

  bool _isAvailable = false;
  bool _isLoading = false;
  String? _error;

  // Callbacks
  Function(PurchaseDetails)? onPurchaseSuccess;
  Function(String)? onPurchaseError;
  Function()? onPurchasePending;
  Function()? onPurchaseRestored;
  
  // DUMMY: Callback untuk dummy purchase - HAPUS SETELAH SETUP PLAY CONSOLE
  Function(String productId)? onDummyPurchaseSuccess;

  // Getters
  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ProductDetails> get products => _products;
  
  // DUMMY: Getter untuk dummy products - HAPUS SETELAH SETUP PLAY CONSOLE
  List<DummyProductDetails> get dummyProducts => _dummyProducts;
  bool get useDummy => _products.isEmpty;

  /// Get product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Get monthly subscription product
  ProductDetails? get monthlyProduct => getProduct(IAPProductIds.premiumMonthly);

  /// Get yearly subscription product
  ProductDetails? get yearlyProduct => getProduct(IAPProductIds.premiumYearly);

  /// Initialize IAP service
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;

    // Check if store is available
    _isAvailable = await _iap.isAvailable();

    if (!_isAvailable) {
      _error = 'Store tidak tersedia';
      _isLoading = false;
      return;
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        _error = error.toString();
        onPurchaseError?.call(_error!);
      },
    );

    // Load products from store
    await loadProducts();
    _isLoading = false;
  }

  /// Load products from Google Play
  Future<void> loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(IAPProductIds.subscriptions);

      if (response.error != null) {
        _error = 'Gagal memuat produk: ${response.error!.message}';
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        // Products not found in Play Console - ini normal kalau belum setup
        print('⚠️ IAP: Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      
      // Sort: monthly first, then yearly
      _products.sort((a, b) {
        if (a.id == IAPProductIds.premiumMonthly) return -1;
        if (b.id == IAPProductIds.premiumMonthly) return 1;
        return 0;
      });

    } catch (e) {
      _error = 'Gagal memuat produk: $e';
    }
  }

  /// Handle purchase updates from Google Play
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          onPurchasePending?.call();
          break;

        case PurchaseStatus.purchased:
          _verifyAndDeliverPurchase(purchase);
          break;

        case PurchaseStatus.restored:
          _verifyAndDeliverPurchase(purchase, isRestored: true);
          break;

        case PurchaseStatus.error:
          onPurchaseError?.call(purchase.error?.message ?? 'Pembelian gagal');
          break;

        case PurchaseStatus.canceled:
          onPurchaseError?.call('Pembelian dibatalkan');
          break;
      }

      // Complete purchase to acknowledge it
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  /// Verify and deliver purchase
  Future<void> _verifyAndDeliverPurchase(
    PurchaseDetails purchase, {
    bool isRestored = false,
  }) async {
    // TODO: Untuk keamanan production, verify purchase token dengan backend server
    // Contoh: await _verifyWithBackend(purchase.verificationData);

    if (isRestored) {
      onPurchaseRestored?.call();
    } else {
      onPurchaseSuccess?.call(purchase);
    }
  }

  /// Buy subscription
  Future<bool> buySubscription(ProductDetails product) async {
    if (!_isAvailable) {
      onPurchaseError?.call('Store tidak tersedia');
      return false;
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onPurchaseError?.call('Gagal memulai pembelian: $e');
      return false;
    }
  }

  // ============================================================================
  // DUMMY PURCHASE - HAPUS METHOD INI SETELAH SETUP GOOGLE PLAY CONSOLE
  // ============================================================================
  Future<bool> buyDummySubscription(DummyProductDetails product) async {
    // Simulate purchase delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Simulate success
    onDummyPurchaseSuccess?.call(product.id);
    return true;
  }
  // ============================================================================
  // END DUMMY PURCHASE
  // ============================================================================

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      onPurchaseError?.call('Store tidak tersedia');
      return;
    }

    try {
      await _iap.restorePurchases();
    } catch (e) {
      onPurchaseError?.call('Gagal memulihkan pembelian: $e');
    }
  }

  /// Dispose service
  void dispose() {
    _subscription?.cancel();
  }
}
