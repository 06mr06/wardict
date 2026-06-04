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

⚠️ **ÖNEMLİ**: Firebase Console → Firestore Database → Rules sekmesinden bu kuralları ekleyin:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Kullanıcılar - Kendi profilini okuyabilir ve yazabilir
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && request.auth.uid == userId;
      allow delete: if false; // Profil silinemez
    }
    
    // Liderlik tablosu (herkes okuyabilir, giriş yapanlar yazabilir)
    match /leaderboard/{doc} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Practice sessions (sadece kendi verileri)
    match /practice_sessions/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Destek talepleri (kullanıcı kendi taleplerini görebilir/yazabilir)
    match /support_tickets/{ticketId} {
      // Kullanıcı kendi talebini okuyabilir
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
      // Kullanıcı yeni talep oluşturabilir
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      // Kullanıcı kendi talebine mesaj ekleyebilir (mesajlar array'e eklenir)
      allow update: if request.auth != null && resource.data.userId == request.auth.uid;
      // Silme yasak
      allow delete: if false;
    // Bildirimler - Kullanıcı sadece kendine gelenleri okuyabilir, herkes (giriş yapmış) gönderebilir
    match /notifications/{docId} {
      allow read, update, delete: if request.auth != null && request.auth.uid == resource.data.toUserId;
      allow create: if request.auth != null;
    }

    // Düello Maçları - Giriş yapmış herkes maç oluşturabilir ve dahil olduğu maçı okuyabilir/güncelleyebilir
    match /matches/{matchId} {
      allow create: if request.auth != null;
      allow read, update: if request.auth != null && (
        request.auth.uid == resource.data.hostUserId || 
        request.auth.uid == resource.data.guestUserId ||
        resource.data.status == "waiting"
      );
    }
  }
}
```

### ⚠️ "Permission Denied" Hatası Alıyorsanız

1. **Firebase Console** → **Firestore Database** → **Rules** sekmesine gidin
2. Yukarıdaki kuralları kopyalayıp yapıştırın
3. **Publish** butonuna tıklayın
4. Kuralların yayınlanması 1-2 dakika sürebilir

## 📊 Adım 7: Realtime Database (Düellolar İçin)

Düello eşleşmelerinin hızlı olması için Realtime Database (RTDB) kullanılır.

1.  **Firebase Console** -> **Realtime Database**
2.  **"Veritabanı oluştur"** tıklayın
3.  Konum: `europe-west1` (Firestore ile aynı olsun)
4.  **"Test modunda başlat"** seçin
5.  Oluşturulan URL'yi kopyalayın (`https://...firebaseio.com/` gibi)
6.  Gerekli Güvenlik Kurallarını (Rules) Firebase Console -> Realtime Database -> Rules sekmesinden ekleyin:

```json
{
  "rules": {
    "online_duels": {
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "presence": {
      ".read": "auth != null",
      "$user_id": {
        ".write": "$user_id === auth.uid"
      }
    }
  }
}
```

7.  Bu URL'yi `.env` dosyanıza `FIREBASE_DATABASE_URL` olarak ekleyin.

## 🧪 Adım 8: Test Etme

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
- [x] Destek sistemi (Firestore mesajlaşma)
- [ ] Gerçek zamanlı düello sistemi
- [ ] Push notifications
- [ ] Liderlik tablosu UI

---

## 📞 Destek Sistemi - Admin Yanıt Verme

Kullanıcı destek taleplerini yanıtlamak için Firebase Console kullanabilirsiniz:

### Firestore Console'dan Yanıt Verme

1. [Firebase Console](https://console.firebase.google.com) → **Firestore Database**
2. `support_tickets` koleksiyonunu açın
3. İlgili ticket belgesini seçin
4. `messages` array'ine yeni bir mesaj objesi ekleyin:

```json
{
  "id": "ticket_id_msg_admin_1",
  "senderId": "admin",
  "senderName": "Wardict Destek",
  "isAdmin": true,
  "message": "Merhaba! Size nasıl yardımcı olabiliriz?",
  "createdAt": <Timestamp>,
  "isRead": false
}
```

5. `status` alanını `"answered"` olarak güncelleyin
6. `unreadCount` alanını `1` artırın
7. `updatedAt` alanını güncelleyin

### Admin Panel (İleri Seviye)

İlerleyen dönemde ayrı bir admin web paneli oluşturulabilir:
- Next.js veya React ile
- Firebase Admin SDK kullanarak
- Tüm destek taleplerini görüntüleme
- Toplu yanıt verme

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

## 🍎 Apple Sign-In Kurulumu (iOS)

**iOS cihazlarda Apple ile giriş için aşağıdaki adımları izleyin:**

### Ön Koşullar

1. Apple Developer Program üyeliği ($99/yıl)
2. Xcode yüklü Mac bilgisayar
3. Bundle Identifier belirlenmeli

### Adım 1: Apple Developer Console Ayarları

1. [Apple Developer Console](https://developer.apple.com/account) açın
2. **Certificates, Identifiers & Profiles** → **Identifiers**
3. App ID'nizi seçin (veya yeni oluşturun)
4. **Capabilities** bölümünde **Sign In with Apple** seçeneğini aktifleştirin
5. **Configure** butonuna tıklayın:
   - **Primary App ID** seçin
   - **Kaydet**

### Adım 2: Xcode Ayarları

1. `ios/Runner.xcworkspace` dosyasını Xcode ile açın
2. **Runner** → **Signing & Capabilities** sekmesi
3. **+ Capability** butonuna tıklayın
4. **Sign in with Apple** ekleyin
5. Team ve Bundle Identifier'ın doğru olduğundan emin olun

### Adım 3: Firebase Console Ayarları

1. [Firebase Console](https://console.firebase.google.com) açın
2. **Authentication** → **Sign-in method**
3. **Apple** sağlayıcısını etkinleştirin
4. Bilgileri doldurun:
   - **Services ID**: `com.example.wardict_skeleton` (Bundle ID ile aynı olabilir)
   - **Apple Team ID**: Apple Developer hesabınızdan alın
   - **Key ID** ve **Private Key**: Apple Developer Console'dan oluşturun

### Adım 4: Apple Private Key Oluşturma

1. Apple Developer Console → **Keys**
2. **+** butonuna tıklayın
3. İsim: `WARDICT Sign In`
4. **Sign in with Apple** seçeneğini işaretleyin
5. **Configure** → Primary App ID seçin
6. **Register** → Private Key (.p8 dosyası) indirin
7. Key ID'yi not edin
8. Firebase Console'a bu bilgileri girin

### Adım 5: Test

```bash
flutter clean
flutter pub get
flutter run -d <your_ios_device>
```

iOS cihazda Apple ile giriş butonu görünecek ve çalışacaktır! 🍎

---

Sorularınız için GitHub Issues kullanabilirsiniz.
