import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Kapselt die echten In-App-Käufe (Google Play Billing / Apple StoreKit) über
/// das offizielle `in_app_purchase`-Paket.
///
/// Entwurf für die Store-Veröffentlichung. Damit das PRO-Abo echt abgerechnet
/// wird, muss in der Play Console **und** in App Store Connect ein Abo-Produkt
/// mit der ID [proMonthlyId] angelegt werden. Ohne konfiguriertes Produkt (oder
/// auf Web/Desktop) meldet der Service `available == false`; die App fällt dann
/// auf den bestehenden Demo-/Gutschein-Weg zurück und bleibt voll nutzbar.
class BillingService {
  BillingService({required this.onPurchased});

  /// Produkt-ID des monatlichen PRO-Abos. **Muss** exakt der ID in Play Console
  /// / App Store Connect entsprechen.
  static const proMonthlyId = 'terraspot_pro_monthly';

  /// Wird aufgerufen, wenn ein Kauf erfolgreich verifiziert wurde (oder
  /// wiederhergestellt). Hier schaltet die App PRO frei.
  final VoidCallback onPurchased;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available = false;
  ProductDetails? _product;

  /// Sind Käufe verfügbar und das PRO-Produkt gefunden?
  bool get available => _available && _product != null;

  /// Anzeigepreis vom Store (z. B. "9,99 €"), sonst null.
  String? get priceLabel => _product?.price;

  Future<void> init() async {
    // Käufe gibt es nur auf echten Mobilgeräten mit Store.
    if (kIsWeb) return;
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;

      final response = await _iap.queryProductDetails({proMonthlyId});
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
      }

      _sub = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (Object e) => debugPrint('Billing-Fehler: $e'),
      );
    } catch (e) {
      debugPrint('Billing-Init fehlgeschlagen: $e');
      _available = false;
    }
  }

  /// Startet den Kauf des PRO-Abos. Gibt false zurück, wenn nicht verfügbar.
  Future<bool> buyPro() async {
    final product = _product;
    if (product == null) return false;
    final param = PurchaseParam(productDetails: product);
    // Abo -> buyNonConsumable (Abos laufen darüber).
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Stellt frühere Käufe wieder her (Pflicht-Button in vielen Stores).
  Future<void> restore() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        // TODO(Server): In Produktion sollte die Quittung serverseitig
        // (Play Developer API / App Store Server API) verifiziert werden,
        // bevor PRO freigeschaltet wird. Für den ersten Release genügt die
        // lokale Freischaltung.
        if (p.productID == proMonthlyId) onPurchased();
      }
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
