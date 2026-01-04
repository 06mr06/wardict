# 🚀 WARDICT - Play Store Yayın Rehberi

Bu rehber, WARDICT uygulamasını Google Play Store'da yayınlamak için gereken tüm adımları içerir.

---

## 📋 Kontrol Listesi

- [ ] 1. Release Keystore Oluşturma
- [ ] 2. Gradle Signing Yapılandırması
- [ ] 3. AdMob Hesabı ve Gerçek ID'ler
- [ ] 4. Google Play Console Hesabı
- [ ] 5. In-App Purchase Ürünleri
- [ ] 6. Store Listing Hazırlığı
- [ ] 7. Release APK/AAB Oluşturma
- [ ] 8. Play Store'a Yükleme

---

## 1️⃣ Release Keystore Oluşturma

Keystore, uygulamanızı imzalamak için kullanılan güvenlik anahtarıdır. **BU DOSYAYI KAYBETMEYİN!**

### Adım 1: Keystore Oluştur

PowerShell veya Terminal'de proje klasöründe:

```powershell
# Android klasörüne git
cd android

# Keystore oluştur (şifreleri not edin!)
keytool -genkey -v -keystore wardict-release.keystore -alias wardict -keyalg RSA -keysize 2048 -validity 10000
```

### Adım 2: Sorulan Bilgileri Doldur

```
Keystore şifresi: [GÜVENLİ BİR ŞİFRE - NOT ALIN!]
Adınız ve soyadınız: [İsminiz]
Organizasyon birimi: [Development]
Organizasyon: [WARDICT]
Şehir: [İstanbul]
İl: [İstanbul]
Ülke kodu: [TR]
```

### Adım 3: Keystore'u Güvenli Saklayın

⚠️ **ÖNEMLİ**: 
- `wardict-release.keystore` dosyasını yedekleyin
- Şifreleri güvenli bir yerde saklayın (1Password, Bitwarden vb.)
- Bu dosya kaybolursa uygulama güncellemesi yayınlayamazsınız!

---

## 2️⃣ Gradle Signing Yapılandırması

### Adım 1: key.properties Dosyası Oluştur

`android/key.properties` dosyası oluşturun:

```properties
storePassword=KEYSTORE_SIFRENIZ
keyPassword=KEY_SIFRENIZ
keyAlias=wardict
storeFile=../wardict-release.keystore
```

### Adım 2: .gitignore'a Ekle

`android/.gitignore` dosyasına ekleyin:

```
key.properties
*.keystore
*.jks
```

### Adım 3: build.gradle.kts Güncelle

`android/app/build.gradle.kts` dosyasını düzenleyin:

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Key properties dosyasını oku
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "wardict.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "wardict.app"
        minSdk = 21  // Android 5.0+
        targetSdk = 34  // Android 14
        versionCode = 1
        versionName = "1.0.0"
        
        // Multidex desteği
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            // ProGuard / R8 optimizasyonu
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
```

### Adım 4: ProGuard Kuralları Oluştur

`android/app/proguard-rules.pro` dosyası oluşturun:

```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# In-App Purchase
-keep class com.android.vending.billing.** { *; }

# Gson (Firebase kullanıyor)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Genel kurallar
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
```

---

## 3️⃣ AdMob Hesabı ve Gerçek ID'ler

### Adım 1: AdMob Hesabı Oluştur

1. https://admob.google.com adresine gidin
2. Google hesabınızla giriş yapın
3. Hesap oluşturma adımlarını tamamlayın

### Adım 2: Uygulama Ekle

1. AdMob Dashboard → **Uygulamalar** → **Uygulama Ekle**
2. Platform: **Android**
3. Uygulama adı: **WARDICT**
4. "Uygulamanız henüz yayınlanmadı mı?" → **Evet**

### Adım 3: Reklam Birimleri Oluştur

Her biri için ayrı reklam birimi oluşturun:

| Reklam Türü | Birim Adı | Örnek ID Format |
|-------------|-----------|-----------------|
| Banner | wardict_banner | ca-app-pub-XXXX/YYYY |
| Interstitial | wardict_interstitial | ca-app-pub-XXXX/ZZZZ |
| Rewarded | wardict_rewarded | ca-app-pub-XXXX/WWWW |

### Adım 4: ID'leri Uygulamaya Ekle

**1. AndroidManifest.xml** - App ID güncelle:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
```

**2. lib/services/ad_service.dart** - Reklam birim ID'leri:

```dart
// Production Ad IDs
static const String _androidBannerId = 'ca-app-pub-XXXX/banner_id';
static const String _androidInterstitialId = 'ca-app-pub-XXXX/interstitial_id';
static const String _androidRewardedId = 'ca-app-pub-XXXX/rewarded_id';
```

---

## 4️⃣ Google Play Console Hesabı

### Adım 1: Geliştirici Hesabı Oluştur

1. https://play.google.com/console adresine gidin
2. **25$ kayıt ücreti** ödemeniz gerekiyor (tek seferlik)
3. Kimlik doğrulama adımlarını tamamlayın

### Adım 2: Uygulama Oluştur

1. **Uygulama Oluştur** butonuna tıklayın
2. Uygulama adı: **WARDICT - Kelime Düello Oyunu**
3. Varsayılan dil: **Türkçe**
4. Uygulama türü: **Oyun**
5. Ücretsiz/Ücretli: **Ücretsiz** (In-App Purchase ile)

---

## 5️⃣ In-App Purchase Ürünleri

### Play Console'da Ürün Oluşturma

1. Play Console → Uygulamanız → **Para Kazanma** → **Ürünler**
2. **Ürün oluştur** → **Yönetilen ürün**

### Oluşturulacak Ürünler:

| Ürün ID | Ad | Fiyat | Tür |
|---------|-----|-------|-----|
| `coins_100` | 100 Altın | ₺29.99 | Tüketilebilir |
| `coins_500` | 550 Altın (+50 Bonus) | ₺99.99 | Tüketilebilir |
| `coins_1500` | 1800 Altın (+300 Bonus) | ₺249.99 | Tüketilebilir |
| `coins_5000` | 7000 Altın (+2000 Bonus) | ₺699.99 | Tüketilebilir |
| `premium_monthly` | Premium Aylık | ₺79.99/ay | Abonelik |
| `premium_yearly` | Premium Yıllık | ₺499.99/yıl | Abonelik |
| `remove_ads` | Reklamları Kaldır | ₺149.99 | Tüketilemez |

### Her Ürün İçin:

1. **Ürün ID**: Yukarıdaki ID'leri kullanın (değiştirmeyin!)
2. **Ad ve Açıklama**: Türkçe ve İngilizce ekleyin
3. **Fiyat**: Ülke bazlı fiyatlandırma yapın
4. **Durum**: Aktif yapın

---

## 6️⃣ Store Listing Hazırlığı

### Gerekli Materyaller:

| Materyal | Boyut | Adet |
|----------|-------|------|
| Uygulama İkonu | 512x512 px | 1 |
| Feature Graphic | 1024x500 px | 1 |
| Ekran Görüntüleri (Telefon) | Min 320px, 16:9 veya 9:16 | 2-8 |
| Ekran Görüntüleri (Tablet) | 7" ve 10" | Opsiyonel |

### Uygulama Açıklaması (Kısa - 80 karakter):

```
İngilizce kelime öğren, arkadaşlarınla düello yap, şampiyon ol! 🏆
```

### Uygulama Açıklaması (Uzun):

```
🎮 WARDICT - Kelime Düello Oyunu

İngilizce kelime öğrenmeyi eğlenceli bir oyuna dönüştür! Arkadaşlarınla yarış, seviye atla, kelime hazineni genişlet.

✨ ÖZELLİKLER:

⚔️ DÜELLO MODU
Arkadaşlarınla veya rastgele rakiplerle kelime düellosu yap. Kim daha hızlı, kim daha doğru?

📚 6 SEVİYE
A1'den C2'ye kadar tüm seviyelerde binlerce kelime. Seviyeni test et ve ilerle!

🎯 GÜNLÜK GÖREVLER
Her gün yeni görevler, her gün yeni ödüller. Seri yakalayarak bonus kazan!

🏆 LİDERLİK TABLOLARI
Haftalık ve aylık sıralamalarda en tepeye çık. Rozet ve ödüller kazan!

💡 AKILLI ÖĞRENME
Yanlış yaptığın kelimeler daha sık karşına çıkar. Zayıf noktalarını güçlendir!

🎨 KİŞİSELLEŞTİRME
Avatar, çerçeve ve powerup'larla kendini ifade et.

📱 Ücretsiz indir, hemen oynamaya başla!

#ingilizce #kelime #öğren #oyun #düello #quiz #vocabulary
```

### Kategori ve Etiketler:

- **Kategori**: Oyunlar → Kelime
- **İçerik Derecelendirmesi**: Herkes (Everyone)
- **Etiketler**: İngilizce, Kelime, Öğrenme, Quiz, Düello

---

## 7️⃣ Release APK/AAB Oluşturma

### App Bundle Oluştur (Önerilen)

```powershell
# Proje klasöründe
flutter clean
flutter pub get
flutter build appbundle --release
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`

### APK Oluştur (Alternatif)

```powershell
flutter build apk --release --split-per-abi
```

Çıktılar:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`

---

## 8️⃣ Play Store'a Yükleme

### Adım 1: Dahili Test (Önerilen)

1. Play Console → **Test** → **Dahili test**
2. **Yeni sürüm oluştur**
3. AAB dosyasını yükleyin
4. Test kullanıcılarını ekleyin (e-posta)
5. Sürümü yayınlayın

### Adım 2: Kapalı/Açık Test

1. Dahili testte sorun yoksa → **Kapalı test**
2. Daha geniş bir grupta test edin
3. Geri bildirimleri toplayın

### Adım 3: Production Yayını

1. Tüm testler başarılı → **Production**
2. **İncelemeye gönder**
3. Google incelemesi: 1-7 gün
4. Onaylandıktan sonra yayında! 🎉

---

## 🔒 Data Safety Form (Zorunlu)

Play Console'da **Uygulama içeriği** → **Data safety** bölümünü doldurun:

### Toplanan Veriler:

| Veri Türü | Toplanıyor mu? | Paylaşılıyor mu? |
|-----------|----------------|------------------|
| E-posta adresi | Evet (kayıt için) | Hayır |
| Kullanıcı adı | Evet | Hayır |
| Oyun ilerlemesi | Evet | Hayır |
| Satın alma geçmişi | Evet | Hayır |
| Reklam ID'si | Evet (reklamlar için) | Evet (AdMob) |
| Çökme raporları | Evet | Hayır |

---

## 📱 iOS App Store (Opsiyonel)

iOS için de yayınlamak isterseniz:

1. Apple Developer hesabı ($99/yıl)
2. Xcode ile build
3. App Store Connect'e yükleme
4. Benzer adımlar (In-App Purchase, Privacy Policy vb.)

---

## ❓ Sık Sorulan Sorular

### Keystore'u kaybettim, ne yapmalıyım?
Ne yazık ki uygulamayı aynı imzayla güncelleyemezsiniz. Yeni bir uygulama olarak yayınlamanız gerekir.

### İnceleme ne kadar sürer?
İlk yayında 1-7 gün, güncellemelerde genellikle 1-3 gün.

### Uygulama reddedildi, ne yapmalıyım?
Red sebebini okuyun, gerekli düzeltmeleri yapın ve tekrar gönderin.

### Reklamlar test modunda çalışmıyor?
Test cihazınızı AdMob'a test cihazı olarak eklediğinizden emin olun.

---

## 📞 Destek

Sorularınız için:
- 📧 E-posta: support@wardict.app
- 📚 Flutter Docs: https://docs.flutter.dev/deployment/android

---

**İyi yayınlar! 🚀**
