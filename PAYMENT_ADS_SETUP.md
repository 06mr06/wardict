# Ödeme ve Reklam Entegrasyonu Kurulum Kılavuzu

## 📱 Google Mobile Ads (AdMob) Kurulumu

### 1. Paket Ekleme
```yaml
# pubspec.yaml
dependencies:
  google_mobile_ads: ^5.2.0
```

### 2. Android Yapılandırması
`android/app/src/main/AndroidManifest.xml` dosyasına ekleyin:
```xml
<manifest>
    <application>
        <!-- AdMob App ID -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
    </application>
</manifest>
```

### 3. iOS Yapılandırması
`ios/Runner/Info.plist` dosyasına ekleyin:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
</array>
```

### 4. AdService Kullanımı
```dart
// Ödüllü reklam göster
final reward = await AdService.instance.showRewardedAd(defaultReward: 25);
if (reward > 0) {
  // Kullanıcıya ödül ver
}

// Interstitial reklam göster
await AdService.instance.showInterstitialAd();

// Oyun bittiğinde (her 4 oyunda bir reklam)
await AdService.instance.onGameCompleted();
```

### 5. Test Ad ID'leri
- Banner (Android): `ca-app-pub-3940256099942544/6300978111`
- Banner (iOS): `ca-app-pub-3940256099942544/2934735716`
- Interstitial (Android): `ca-app-pub-3940256099942544/1033173712`
- Interstitial (iOS): `ca-app-pub-3940256099942544/4411468910`
- Rewarded (Android): `ca-app-pub-3940256099942544/5224354917`
- Rewarded (iOS): `ca-app-pub-3940256099942544/1712485313`

---

## 💳 In-App Purchase Kurulumu

### 1. Paket Ekleme
```yaml
# pubspec.yaml
dependencies:
  in_app_purchase: ^3.2.0
```

### 2. Android (Google Play) Yapılandırması
1. Google Play Console'da uygulama oluşturun
2. "Monetization" > "Products" bölümünden ürünleri ekleyin:
   - `coins_100` - 100 Altın
   - `coins_500` - 500 Altın
   - `coins_1500` - 1500 Altın
   - `coins_5000` - 5000 Altın
   - `premium_monthly` - Aylık Premium
   - `premium_yearly` - Yıllık Premium
   - `remove_ads` - Reklamları Kaldır

### 3. iOS (App Store) Yapılandırması
1. App Store Connect'te uygulama oluşturun
2. "Features" > "In-App Purchases" bölümünden ürünleri ekleyin
3. Aynı Product ID'leri kullanın

### 4. PurchaseService Kullanımı
```dart
// Servisi başlat
await PurchaseService.instance.initialize();

// Ürünleri listele
final coinProducts = PurchaseService.instance.coinProducts;
final subscriptionProducts = PurchaseService.instance.subscriptionProducts;

// Satın alma
final result = await PurchaseService.instance.purchase('coins_100');
if (result.success) {
  // Ürünü kullanıcıya ver
}

// Premium durumunu kontrol et
if (PurchaseService.instance.isPremium) {
  // Premium özellikleri aç
}

// Satın almaları geri yükle
await PurchaseService.instance.restorePurchases();
```

---

## 🔧 Mevcut Dosyalar

### Servisler
- `lib/services/ad_service.dart` - Reklam yönetimi
- `lib/services/purchase_service.dart` - Satın alma yönetimi

### Entegre Ekranlar
- `lib/screens/shop/shop_screen.dart` - Mağaza ekranı
- `lib/main.dart` - Servislerin başlatılması

---

## 📋 Yapılacaklar Listesi

### Reklam Entegrasyonu
- [ ] `google_mobile_ads` paketini ekle
- [ ] AdMob hesabı oluştur
- [ ] Uygulama ID'lerini al
- [ ] Android manifest'i güncelle
- [ ] iOS plist'i güncelle
- [ ] Production ad unit ID'lerini ekle
- [ ] AdService'deki yorum satırlarını aç

### Satın Alma Entegrasyonu
- [ ] `in_app_purchase` paketini ekle
- [ ] Google Play Console'da ürünleri oluştur
- [ ] App Store Connect'te ürünleri oluştur
- [ ] PurchaseService'deki yorum satırlarını aç
- [ ] Sandbox test hesapları oluştur
- [ ] Test alımları yap

### Production Kontrolleri
- [ ] Test ID'lerini production ID'leriyle değiştir
- [ ] Reklam gösterim sıklığını ayarla
- [ ] Fiyatlandırmayı gözden geçir
- [ ] GDPR/ATT izin dialoglarını ekle

---

## ⚠️ Önemli Notlar

1. **Test Modu**: Debug modda otomatik olarak test ID'leri kullanılır
2. **Premium Kullanıcılar**: Premium üyeler reklam görmez
3. **Offline Destek**: Satın almalar SharedPreferences'da cache'lenir
4. **Subscription Yenileme**: Abonelik durumu her uygulama açılışında kontrol edilir
