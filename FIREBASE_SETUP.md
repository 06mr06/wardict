# 🔥 Firebase Kurulum Rehberi - WARDICT

Bu rehber WARDICT uygulaması için Firebase entegrasyonunu tamamlamak için gerekli adımları içerir.

## 📋 Ön Hazırlık

Flutter Firebase paketleri zaten yüklendi:
- ✅ firebase_core
- ✅ firebase_auth  
- ✅ cloud_firestore

## 🚀 Adım 1: Firebase Console'da Proje Oluşturma

1. [Firebase Console](https://console.firebase.google.com/) adresine gidin
2. **"Proje Ekle"** butonuna tıklayın
3. Proje adı: `wardict` (veya istediğiniz isim)
4. Google Analytics'i etkinleştirin (opsiyonel)
5. Proje oluşturulana kadar bekleyin

## 📱 Adım 2: Android Uygulaması Ekleme

1. Firebase Console'da projenizi açın
2. **"Android"** ikonuna tıklayın
3. Bilgileri doldurun:
   - **Paket Adı**: `com.example.wardict_skeleton` (veya pubspec.yaml'daki isim)
   - **Uygulama takma adı**: WARDICT
   - **SHA-1**: (opsiyonel, Google Sign-In için gerekli)

4. `google-services.json` dosyasını indirin
5. Dosyayı şu konuma kopyalayın:
   ```
   android/app/google-services.json
   ```

### Android Gradle Yapılandırması

**android/build.gradle.kts** dosyasına ekleyin:
```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

**android/app/build.gradle.kts** dosyasına ekleyin:
```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

## 🌐 Adım 3: Web Uygulaması Ekleme

1. Firebase Console'da **"Web"** ikonuna tıklayın
2. Uygulama adı: `WARDICT Web`
3. Firebase Hosting'i atlayabilirsiniz
4. Verilen yapılandırma bilgilerini kopyalayın

5. `lib/services/firebase/firebase_service.dart` dosyasını güncelleyin:

```dart
FirebaseOptions _getFirebaseOptions() {
  if (kIsWeb) {
    return const FirebaseOptions(
      apiKey: 'BURAYA_API_KEY',
      authDomain: 'PROJECT_ID.firebaseapp.com',
      projectId: 'PROJECT_ID',
      storageBucket: 'PROJECT_ID.appspot.com',
      messagingSenderId: 'SENDER_ID',
      appId: 'WEB_APP_ID',
    );
  }
  // ...
}
```

## 🔐 Adım 4: Authentication Ayarları

1. Firebase Console → **Authentication** → **Sign-in method**
2. Şu yöntemleri etkinleştirin:
   - ✅ **Email/Password**
   - ✅ **Anonymous** (Misafir girişi için)

## 📊 Adım 5: Firestore Veritabanı

1. Firebase Console → **Firestore Database**
2. **"Veritabanı oluştur"** tıklayın
3. **Test modunda başlat** seçin (geliştirme için)
4. Konum: `europe-west1` (veya size yakın)

### Firestore Güvenlik Kuralları (Üretim için)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Kullanıcılar
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Liderlik tablosu (herkes okuyabilir)
    match /leaderboard/{doc} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## 🧪 Adım 6: Test Etme

```bash
flutter run -d chrome
```

Uygulama açıldığında:
1. Login ekranı görünmeli
2. "Kayıt Ol" ile yeni hesap oluşturun
3. Firestore Console'da `users` koleksiyonunda kullanıcıyı görün

## 📁 Oluşturulan Dosyalar

```
lib/
├── services/
│   └── firebase/
│       ├── firebase_service.dart    # Firebase başlatma
│       ├── auth_service.dart        # Kimlik doğrulama
│       └── firestore_service.dart   # Veritabanı işlemleri
├── screens/
│   └── auth/
│       └── login_screen.dart        # Giriş/Kayıt ekranı
├── app.dart                         # Güncellendi (AuthWrapper)
└── main.dart                        # Güncellendi (Firebase init)
```

## ⚠️ Önemli Notlar

1. **API Anahtarlarını Gizli Tutun**: `.gitignore`'a `google-services.json` ekleyin
2. **Test Modunda Çalışın**: Üretim öncesi güvenlik kurallarını güncelleyin
3. **Firestore Indexleri**: Bazı sorgular için index gerekebilir

## 🔜 Sonraki Adımlar

- [x] Google Sign-In ekleme
- [ ] Gerçek zamanlı düello sistemi
- [ ] Push notifications
- [ ] Liderlik tablosu UI

---

## 🔑 Google Sign-In için SHA-1 Ekleme (Android)

**Google ile giriş yapabilmek için SHA-1 fingerprint gereklidir!**

### Adım 1: Debug SHA-1 Almak

Terminal'de şu komutu çalıştırın:

**Windows:**
```bash
cd android
./gradlew signingReport
```

**Mac/Linux:**
```bash
cd android
./gradlew signingReport
```

Çıktıda "SHA1:" satırını bulun. Örnek:
```
SHA1: A1:B2:C3:D4:E5:F6:...
```

### Adım 2: Firebase'e SHA-1 Ekleme

1. [Firebase Console](https://console.firebase.google.com/) açın
2. Projenizi seçin
3. ⚙️ **Project Settings** → **Your apps** → Android uygulamanız
4. **"Add fingerprint"** butonuna tıklayın
5. SHA-1 değerini yapıştırın
6. **Kaydet**

### Adım 3: google-services.json Güncelleme

1. Firebase Console'dan yeni `google-services.json` indirin
2. Eski dosyanın üzerine yazın: `android/app/google-services.json`

### Adım 4: Flutter Clean

```bash
flutter clean
flutter pub get
flutter run
```

Artık Google ile giriş yapabilirsiniz! 🎉

---

Sorularınız için GitHub Issues kullanabilirsiniz.
